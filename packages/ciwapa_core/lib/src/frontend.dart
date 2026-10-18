import 'ast.dart';
import 'errors.dart';
import 'lexer.dart';
import 'parser.dart';
import 'source.dart';
import 'syslib/syslib.g.dart';

/// A whole-program error, reported at compile time (decision Q80).
class CompileError implements Exception {
  CompileError(int code, this.statement) : error = IclError.of(code);

  final IclError error;

  /// The offending statement's ordinal. Errors with no offending statement report statement 1, the
  /// statement that would have run first (decision T33).
  final int statement;

  @override
  String toString() => error.format(statement);
}

/// A parsed program that passed every whole-program check.
class Program {
  Program(
    this.source,
    this.base,
    this.statements,
    this.userStatements, {
    required this.extracal,
  });

  final Source source;

  /// The numeric base picked by the file extension, 2 through 7.
  final int base;

  /// Whether the file extension picked EXTRACAL rather than Mode 1 (decisions Q43, Q56).
  final bool extracal;

  /// The user's statements, followed by the system library's when it was included (§7.3).
  final List<Statement> statements;

  /// How many of [statements] are the user's.
  final int userStatements;
}

bool isValidLabel(int label) => label >= 1 && label <= 65535;

/// Parses [source] and runs the whole-program checks, in C-INTERCAL 0.15's order.
/// [memoryLimit] is test-only (decision L7): see [Parser.memoryLimit].
Program analyze(Source source, {bool traditional = false, int? memoryLimit}) {
  final dialect = Source.dialectOf(source.path);
  if (dialect == null) throw CompileError(998, 1);
  final base = dialect.base;
  if (traditional && base != 2) throw CompileError(111, 1);

  final statements = Parser(
    source,
    memoryLimit: memoryLimit,
    wide: dialect.extracal && base == 2,
    extensions: dialect.extracal,
  ).parse();
  if (traditional) {
    for (final (i, s) in statements.indexed) {
      final gerund = s.body.gerund;
      final body = s.body;
      if (gerund == Gerund.comingFrom ||
          gerund == Gerund.nextingFrom ||
          (body is AbstainBody && body.count != null) ||
          s.onceAgain != OnceAgain.none ||
          body is TryAgain ||
          body is Create ||
          body is GoBack ||
          body is GoAhead ||
          s.maybe ||
          s.whileBody != null) {
        throw CompileError(111, i + 1);
      }
    }
  }
  _expandWhiles(statements);
  _checkPoliteness(statements);
  // `ick` allows nothing after a TRY AGAIN, not even a comment.
  final tryAgain = statements.indexWhere((s) => s.body is TryAgain);
  if (tryAgain >= 0 && tryAgain < statements.length - 1) {
    throw CompileError(993, tryAgain + 2);
  }
  final userStatements = statements.length;
  if (_needsLibrary(statements, base)) {
    statements.addAll(Parser(Source('syslib.i', syslibSource)).parse());
  }
  _checkLabels(statements, extracal: dialect.extracal);
  _checkOperators(statements, base);
  _demoteUnreadable(statements, base);
  return Program(
    source,
    base,
    statements,
    userStatements,
    extracal: dialect.extracal,
  );
}

/// `ick`'s `(x) DO a WHILE b` (R3), expanded the way `ick`'s preprocessor does it, into 11
/// statements with internal labels l0 to l3:
///
///     (l0) DO REINSTATE (l3)              weaving on
///     (l1) DO COME FROM (l2) AGAIN
///          DO b
///          DO COME FROM (l0)
///          DO NOTHING
///          DO NOTHING
///     (l2) DO NOTHING
///          DO GIVE UP
///          DO COME FROM (l0)
///      (x) DO a                           with the statement's own qualifiers
///     (l3) DON'T ABSTAIN FROM (l1) AGAIN  weaving off
///
/// The two COME FROMs on l0 split the thread: the new one runs b over and over, sharing the
/// variables, until a finishes and abstains l1. Three of the added statements count as polite, as
/// in `ick`.
void _expandWhiles(List<Statement> statements) {
  var next = 65536;
  for (var i = statements.length - 1; i >= 0; i--) {
    final a = statements[i];
    final b = a.whileBody;
    if (b == null) continue;
    final l0 = next, l1 = next + 1, l2 = next + 2, l3 = next + 3;
    next += 4;
    Statement added(
      Body body, {
      int? label,
      bool polite = false,
      bool not = false,
      OnceAgain onceAgain = OnceAgain.none,
      int weave = 0,
    }) => Statement(
      source: a.source,
      start: a.start,
      end: a.end,
      label: label,
      polite: polite,
      not: not,
      percent: null,
      body: body,
      onceAgain: onceAgain,
      preproc: true,
      weave: weave,
    );
    statements.replaceRange(i, i + 1, [
      added(
        AbstainBody(abstain: false, label: l3),
        label: l0,
        polite: true,
        weave: 1,
      ),
      added(ComeFrom(l2), label: l1, polite: true, onceAgain: OnceAgain.again),
      Statement(
        source: a.source,
        start: a.start,
        end: a.end,
        label: null,
        polite: false,
        not: false,
        percent: null,
        body: b,
      ),
      added(ComeFrom(l0)),
      added(const Nothing()),
      added(const Nothing()),
      added(const Nothing(), label: l2),
      added(const GiveUp()),
      added(ComeFrom(l0)),
      Statement(
        source: a.source,
        start: a.start,
        end: a.end,
        label: a.label,
        polite: a.polite,
        not: a.not,
        percent: a.percent,
        body: a.body,
        chain: a.chain,
        onceAgain: a.onceAgain,
        maybe: a.maybe,
      ),
      added(
        AbstainBody(abstain: true, label: l1),
        label: l3,
        polite: true,
        not: true,
        onceAgain: OnceAgain.again,
        weave: -1,
      ),
    ]);
  }
}

/// §7.3 and decision T36: the library is included when a NEXT targets a label from 1000 to 1999
/// and the program defines no label in that range. It is binary, so only base 2 programs get it
/// (decision L9).
bool _needsLibrary(List<Statement> statements, int base) {
  bool inRange(int? label) => label != null && label >= 1000 && label <= 1999;
  if (base != 2 || statements.any((s) => inRange(s.label))) return false;
  return statements.any(
    (s) => switch (s.body) {
      Next(:final label) => inRange(label),
      _ => false,
    },
  );
}

/// §10.4 and decision T35: fewer than 1/5 polite statements is E079, more than 1/3 is E099, using
/// exact fractions, and only for programs of more than 2 statements.
void _checkPoliteness(List<Statement> statements) {
  final total = statements.length;
  if (total <= 2) return;
  final polite = statements.where((s) => s.polite).length;
  if (5 * polite < total) throw CompileError(79, 1);
  if (3 * polite > total) throw CompileError(99, 1);
}

void _checkLabels(List<Statement> statements, {required bool extracal}) {
  final firstWithLabel = <int, int>{};
  final duplicated = <int>{};
  for (final (i, s) in statements.indexed) {
    final label = s.label;
    if (label == null || !(isValidLabel(label) || s.preproc)) continue;
    if (firstWithLabel.containsKey(label)) duplicated.add(label);
    firstWithLabel.putIfAbsent(label, () => i);
  }
  if (duplicated.isNotEmpty) {
    final earliest = duplicated
        .map((l) => firstWithLabel[l]!)
        .reduce((a, b) => a < b ? a : b);
    throw CompileError(182, earliest + 1);
  }

  final targeted = <int>{};
  for (final (i, s) in statements.indexed) {
    final body = s.body;
    if (body is! ComeFrom) continue;
    // Only WHILE's own statements can reach its internal labels.
    final reachable = isValidLabel(body.label) || s.preproc;
    if (!reachable || !firstWithLabel.containsKey(body.label)) {
      throw CompileError(444, i + 1);
    }
    // In EXTRACAL, several COME FROMs on one label start threads (R3).
    if (!targeted.add(body.label) && !extracal) throw CompileError(555, i + 1);
  }
}

/// `^` and `@` exist only in bases 3–7, and `N@` only where N ≤ base − 2 (§6.6, decision T40).
void _checkOperators(List<Statement> statements, int base) {
  for (final (i, s) in statements.indexed) {
    for (final e in expressionsOf(s.body)) {
      if (unaryOps(e).any((op) => !_allowed(op, base))) {
        throw CompileError(997, i + 1);
      }
    }
  }
}

/// An unknown statement stays a comment, as in Mode 1, when no CREATE could give it a meaning, or
/// when its operands use an operator the base doesn't have (rather than failing the whole
/// program). A comment's ONCE or AGAIN is part of the comment (L22).
void _demoteUnreadable(List<Statement> statements, int base) {
  final creates = statements.any((s) => s.body is Create);
  for (final s in statements) {
    final body = s.body;
    if (body is! Unknown) continue;
    final ops = body.operands.expand(unaryOps);
    if (!creates || ops.any((op) => !_allowed(op, base))) {
      s
        ..body = const Undecodable()
        ..onceAgain = OnceAgain.none;
    }
  }
}

bool _allowed(UnaryOp op, int base) => switch (op) {
  UnaryOp.and || UnaryOp.or || UnaryOp.xor => true,
  UnaryOp.sharkfin => base >= 3,
  _ => op.whirlpoolDigit + 2 <= base,
};

/// Every top-level expression a statement body evaluates or assigns to.
Iterable<Expr> expressionsOf(Body body) => switch (body) {
  Calculate(:final target, :final value) => [target, value],
  Dimension(:final dimensions) => dimensions,
  Forget(:final count) || Resume(:final count) => [count],
  ComputedComeFrom(:final label) => [label],
  AbstainBody(:final count?) => [count],
  Create(:final target?) => [target],
  IoBody(:final items) => items,
  _ => const [],
};

Iterable<UnaryOp> unaryOps(Expr e) sync* {
  switch (e) {
    case Unary(:final op, :final operand):
      yield op;
      yield* unaryOps(operand);
    case Binary(:final left, :final right) ||
        CreatedOp(:final left, :final right):
      yield* unaryOps(left);
      yield* unaryOps(right);
    case Element(:final subscripts):
      for (final s in subscripts) {
        yield* unaryOps(s);
      }
    case Slat(:final expr):
      yield* unaryOps(expr);
    case Constant() || Scalar() || ArrayItem():
      break;
  }
}
