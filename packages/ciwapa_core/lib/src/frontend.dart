import 'ast.dart';
import 'errors.dart';
import 'lexer.dart';
import 'parser.dart';
import 'source.dart';
import 'extracal/blocks.dart';
import 'syslib/syslib.g.dart';

/// A whole-program error, reported at compile time (decision Q80), or for an editor, a
/// statement-local one that fires when its statement runs (R2).
class CompileError implements Exception {
  CompileError(
    int code,
    this.statement, {
    this.span,
    this.token,
    this.whenRun = false,
  }) : error = IclError.of(code);

  /// An error of a language built on CIWAPA's, which isn't in [IclError.all].
  CompileError.of(
    this.error,
    this.statement, {
    this.span,
    this.token,
    this.whenRun = false,
  });

  final IclError error;

  /// The offending statement's ordinal. Errors with no offending statement report statement 1, the
  /// statement that would have run first (decision T33).
  final int statement;

  /// The runes of the offending statement in the user's file, when it has one there.
  final Span? span;

  /// The runes of the one token the error is about, when it is about one.
  final Span? token;

  /// A statement-local error (decisions Q80, Q81): the program builds, and the error fires only if
  /// the statement runs.
  final bool whenRun;

  /// This error, placed at [statement] of [statements] when that statement is in [source].
  CompileError placed(
    List<Statement> statements,
    Source source, {
    Span? token,
  }) {
    final s = statement >= 1 && statement <= statements.length
        ? statements[statement - 1]
        : null;
    final inFile = s != null && identical(s.source, source);
    return CompileError.of(
      error,
      statement,
      span: span ?? (inFile ? Span(s.start, s.end) : null),
      token: this.token ?? (inFile ? token : null),
      whenRun: whenRun,
    );
  }

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
    this.tokens = const [],
  });

  final Source source;

  /// The user's file as the lexer saw it.
  final List<Token> tokens;

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

/// Parses [source] and runs the whole-program checks, in C-INTERCAL 0.15's order, throwing the first
/// [CompileError]. With [onError], every error goes there instead and the checks carry on, so that
/// an editor sees them all (R2); the first one is the one that would have been thrown.
/// [memoryLimit] is test-only (decision L7): see [Parser.memoryLimit].
///
/// A language built on CIWAPA's passes its own [parser], and [libraries]: blocks of its own that
/// EXTRACAL programs get in the same way as the standard library's. It passes the [dialect] when
/// its files have an extension of its own, which [Source.dialectOf] doesn't know.
Program analyze(
  Source source, {
  bool traditional = false,
  int? memoryLimit,
  Parser Function(
    Source source, {
    required bool wide,
    required bool extensions,
  })?
  parser,
  List<LibraryBlock> libraries = const [],
  Dialect? dialect,
  void Function(CompileError error)? onError,
}) {
  var statements = const <Statement>[];
  void report(CompileError error, {Span? token}) {
    final placed = error.placed(statements, source, token: token);
    if (onError == null) throw placed;
    onError(placed);
  }

  dialect ??= Source.dialectOf(source.path);
  if (dialect == null) {
    report(CompileError(998, 1));
    return Program(source, 2, const [], 0, extracal: false);
  }
  final base = dialect.base;
  if (traditional && base != 2) report(CompileError(111, 1));
  final wide = dialect.extracal && base == 2;
  final parsing =
      parser?.call(source, wide: wide, extensions: dialect.extracal) ??
      Parser(
        source,
        memoryLimit: memoryLimit,
        wide: wide,
        extensions: dialect.extracal,
      );
  statements = parsing.parse();
  final tokens = parsing.tokens;
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
          s.whileBody != null ||
          body is Petition ||
          body is HostCall ||
          (body is IoBody && body.baudot)) {
        report(CompileError(111, i + 1));
      }
    }
  }
  _expandWhiles(statements);
  _checkPoliteness(statements, report);
  // `ick` allows nothing after a TRY AGAIN, not even a comment.
  final tryAgain = statements.indexWhere((s) => s.body is TryAgain);
  if (tryAgain >= 0 && tryAgain < statements.length - 1) {
    report(CompileError(993, tryAgain + 2));
  }
  final userStatements = statements.length;
  // `--traditional` has none of EXTRACAL's library, which is built on PETITION.
  _includeLibraries(
    statements,
    base,
    extracal: dialect.extracal && !traditional,
    libraries: libraries,
  );
  final lex = _StatementTokens(tokens, source);
  _checkLabels(statements, lex, report, extracal: dialect.extracal);
  _checkOperators(statements, base, lex, report);
  _demoteUnreadable(statements, base);
  return Program(
    source,
    base,
    statements,
    userStatements,
    extracal: dialect.extracal,
    tokens: tokens,
  );
}

typedef _Report = void Function(CompileError error, {Span? token});

/// The tokens of each statement of the user's file.
class _StatementTokens {
  _StatementTokens(this.tokens, this.source);

  final List<Token> tokens;
  final Source source;

  /// [s]'s tokens; none for a statement from a library.
  Iterable<Token> of(Statement s) => identical(s.source, source)
      ? tokens.where(
          (t) =>
              t.kind != TokenKind.end && t.start >= s.start && t.end <= s.end,
        )
      : const [];

  /// The span of [s]'s label, when it has one.
  Span? labelOf(Statement s) {
    final first = of(s).firstOrNull;
    return first != null && first.kind == TokenKind.label
        ? Span(first.start, first.end)
        : null;
  }

  /// The span of the first label [s] names in its body, such as a COME FROM's. A WHILE's second
  /// statement shares the first's text, label included, so the text decides what to skip.
  Span? targetOf(Statement s) {
    final tokens = of(s).toList();
    final labelled = tokens.isNotEmpty && tokens.first.kind == TokenKind.label;
    final target = tokens
        .skip(labelled ? 1 : 0)
        .where((t) => t.kind == TokenKind.label)
        .firstOrNull;
    return target == null ? null : Span(target.start, target.end);
  }
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
      )..data = a.data,
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

/// §7.3 and decision T36: the system library is included when a NEXT targets a label from 1000
/// to 1999 and the program defines no label in that range. EXTRACAL's library blocks follow the
/// same rule for their own ranges (R10), and a block's NEXTs can bring in the system library or
/// another block. All of them are binary, so only base 2 programs get them (decisions L9, L17).
void _includeLibraries(
  List<Statement> statements,
  int base, {
  required bool extracal,
  required List<LibraryBlock> libraries,
}) {
  if (base != 2) return;
  final user = statements.length;
  final blocks = [
    (name: 'syslib.i', first: 1000, last: 1999, source: syslibSource),
    if (extracal)
      for (final b in [...libraryBlocks, ...libraries])
        (name: b.name, first: b.first, last: b.last, source: b.source),
  ];
  final included = <String>{};
  var changed = true;
  while (changed) {
    changed = false;
    for (final block in blocks) {
      if (included.contains(block.name)) continue;
      bool inRange(int? label) =>
          label != null && label >= block.first && label <= block.last;
      if (statements.take(user).any((s) => inRange(s.label))) continue;
      final wanted = statements.any(
        (s) => switch (s.body) {
          Next(:final label) => inRange(label),
          _ => false,
        },
      );
      if (!wanted) continue;
      final extensions = block.name.endsWith('.xc');
      statements.addAll(
        Parser(
          Source(block.name, block.source),
          wide: extensions,
          extensions: extensions,
        ).parse(),
      );
      included.add(block.name);
      changed = true;
    }
  }
}

/// §10.4 and decision T35: fewer than 1/5 polite statements is E079, more than 1/3 is E099, using
/// exact fractions, and only for programs of more than 2 statements.
void _checkPoliteness(List<Statement> statements, _Report report) {
  final total = statements.length;
  if (total <= 2) return;
  final polite = statements.where((s) => s.polite).length;
  if (5 * polite < total) report(CompileError(79, 1));
  if (3 * polite > total) report(CompileError(99, 1));
}

void _checkLabels(
  List<Statement> statements,
  _StatementTokens lex,
  _Report report, {
  required bool extracal,
}) {
  final firstWithLabel = <int, int>{};
  final duplicated = <int>{};
  for (final (i, s) in statements.indexed) {
    final label = s.label;
    if (label == null || !(isValidLabel(label) || s.preproc)) continue;
    if (firstWithLabel.containsKey(label)) duplicated.add(label);
    firstWithLabel.putIfAbsent(label, () => i);
  }
  // Every statement with a duplicated label, in order, so the first is the earliest first use.
  for (final (i, s) in statements.indexed) {
    if (duplicated.contains(s.label) && (isValidLabel(s.label!) || s.preproc)) {
      report(CompileError(182, i + 1), token: lex.labelOf(s));
    }
  }

  final targeted = <int>{};
  for (final (i, s) in statements.indexed) {
    final body = s.body;
    if (body is! ComeFrom) continue;
    // Only WHILE's own statements can reach its internal labels.
    final reachable = isValidLabel(body.label) || s.preproc;
    if (!reachable || !firstWithLabel.containsKey(body.label)) {
      report(CompileError(444, i + 1), token: lex.targetOf(s));
      continue;
    }
    // In EXTRACAL, several COME FROMs on one label start threads (R3).
    if (!targeted.add(body.label) && !extracal) {
      report(CompileError(555, i + 1), token: lex.targetOf(s));
    }
  }
}

/// `^` and `@` exist only in bases 3–7, and `N@` only where N ≤ base − 2 (§6.6, decision T40).
void _checkOperators(
  List<Statement> statements,
  int base,
  _StatementTokens lex,
  _Report report,
) {
  for (final (i, s) in statements.indexed) {
    final banned = expressionsOf(s.body)
        .any((e) => unaryOps(e).any((op) => !_allowed(op, base)));
    if (!banned) continue;
    final token = lex
        .of(s)
        .where((t) => t.unary != null && !_allowed(t.unary!, base))
        .firstOrNull;
    report(
      CompileError(997, i + 1),
      token: token == null ? null : Span(token.start, token.end),
    );
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
  HostCall(:final values) => values,
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
