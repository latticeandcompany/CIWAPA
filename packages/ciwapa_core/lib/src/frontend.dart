import 'ast.dart';
import 'errors.dart';
import 'lexer.dart';
import 'parser.dart';
import 'source.dart';

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
  Program(this.source, this.base, this.statements);

  final Source source;

  /// The numeric base picked by the file extension, 2 through 7.
  final int base;
  final List<Statement> statements;
}

bool isValidLabel(int label) => label >= 1 && label <= 65535;

/// Parses [source] and runs the whole-program checks, in C-INTERCAL 0.15's order.
Program analyze(Source source, {bool traditional = false}) {
  final base = Source.baseOf(source.path);
  if (base == null) throw CompileError(998, 1);
  if (traditional && base != 2) throw CompileError(111, 1);

  final statements = Parser(source).parse();
  if (traditional) {
    for (final (i, s) in statements.indexed) {
      if (s.body is ComeFrom) throw CompileError(111, i + 1);
    }
  }
  _checkPoliteness(statements);
  _checkLabels(statements);
  _checkOperators(statements, base);
  return Program(source, base, statements);
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

void _checkLabels(List<Statement> statements) {
  final firstWithLabel = <int, int>{};
  final duplicated = <int>{};
  for (final (i, s) in statements.indexed) {
    final label = s.label;
    if (label == null || !isValidLabel(label)) continue;
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
    if (!firstWithLabel.containsKey(body.label)) throw CompileError(444, i + 1);
    if (!targeted.add(body.label)) throw CompileError(555, i + 1);
  }
}

/// `^` and `@` exist only in bases 3–7, and `N@` only where N ≤ base − 2 (§6.6, decision T40).
void _checkOperators(List<Statement> statements, int base) {
  bool allowed(UnaryOp op) => switch (op) {
    UnaryOp.and || UnaryOp.or || UnaryOp.xor => true,
    UnaryOp.sharkfin => base >= 3,
    _ => op.whirlpoolDigit + 2 <= base,
  };
  for (final (i, s) in statements.indexed) {
    for (final e in expressionsOf(s.body)) {
      if (unaryOps(e).any((op) => !allowed(op))) throw CompileError(997, i + 1);
    }
  }
}

/// Every top-level expression a statement body evaluates or assigns to.
Iterable<Expr> expressionsOf(Body body) => switch (body) {
  Calculate(:final target, :final value) => [target, value],
  Dimension(:final dimensions) => dimensions,
  Forget(:final count) || Resume(:final count) => [count],
  IoBody(:final items) => items,
  _ => const [],
};

Iterable<UnaryOp> unaryOps(Expr e) sync* {
  switch (e) {
    case Unary(:final op, :final operand):
      yield op;
      yield* unaryOps(operand);
    case Binary(:final left, :final right):
      yield* unaryOps(left);
      yield* unaryOps(right);
    case Element(:final subscripts):
      for (final s in subscripts) {
        yield* unaryOps(s);
      }
    case Constant() || Scalar() || ArrayItem():
      break;
  }
}
