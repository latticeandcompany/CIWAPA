import 'ast.dart';
import 'errors.dart';
import 'frontend.dart';
import 'ir.dart';
import 'lexer.dart';
import 'source.dart';

/// Everything a front end found in a file, for an editor: the program and every error with its
/// place (R2), the compile errors first, in the order the compiler meets them.
class Analysis {
  Analysis(this.program, this.errors, [this.ir]);

  final Program program;
  final List<CompileError> errors;

  /// The program lowered without the random bug, or null when it has errors that stop lowering.
  final IrProgram? ir;

  Source get source => program.source;
}

/// Runs [analyze], collecting every compile error, then [lower]s the program without the random
/// bug, so that E774 never appears, to find each user statement's statement-local error: the one
/// it would raise if it ran. A language built on CIWAPA's adds its own statement-local errors with
/// [faultOf].
Analysis collectErrors(
  Program Function(void Function(CompileError error) onError) analyze,
  IrProgram Function(Program program, IrOptions options) lower, {
  IclError? Function(Statement statement)? faultOf,
}) {
  final compile = <CompileError>[];
  final program = analyze(compile.add);
  // Errors reported before the statements were parsed, such as E111 for the base, still belong on
  // statement 1.
  final errors = [
    for (final e in compile) e.placed(program.statements, program.source),
  ];
  if (program.statements.isEmpty) return Analysis(program, errors);
  final IrProgram ir;
  try {
    ir = lower(program, const IrOptions(randomBug: false));
  } on Object {
    // A program with compile errors may not lower at all, such as a COME FROM to nowhere. Its
    // compile errors are what the editor shows until they are fixed.
    if (errors.isEmpty) rethrow;
    return Analysis(program, errors);
  }
  final defined = {
    for (final s in program.statements)
      if (s.label case final label? when isValidLabel(label)) label,
  };
  // A WHILE's two statements share their text, so the same error can come up twice.
  final seen = <(int, Span?, Span?)>{};
  for (final s in ir.statements.take(program.userStatements)) {
    final statement = program.statements[s.ordinal - 1];
    final IclError error;
    if (s.faults.isNotEmpty) {
      error = IclError.of(s.faults.first.code);
    } else if (faultOf?.call(statement) case final own?) {
      error = own;
    } else {
      continue;
    }
    final tokens = program.tokens
        .where((t) => t.start >= statement.start && t.end <= statement.end)
        .toList();
    final placed = CompileError.of(error, s.ordinal, whenRun: true).placed(
      program.statements,
      program.source,
      token: _faultToken(error.code, tokens, program.base, defined),
    );
    if (seen.add((error.code, placed.span, placed.token))) errors.add(placed);
  }
  return Analysis(program, errors, ir);
}

const _sigils = {
  TokenKind.oneSpot,
  TokenKind.twoSpot,
  TokenKind.tail,
  TokenKind.hybrid,
  TokenKind.doubleCateye,
  TokenKind.doubleHybrid,
};

/// The token a statement-local error is about, when it is about one.
Span? _faultToken(int code, List<Token> tokens, int base, Set<int> defined) {
  Span span(Token from, [Token? to]) => Span(from.start, (to ?? from).end);
  Token? after(int i) => i + 1 < tokens.length ? tokens[i + 1] : null;
  final labels = tokens.where((t) => t.kind == TokenKind.label);
  switch (code) {
    case 197:
      final bad = labels.where((t) => !isValidLabel(t.value)).firstOrNull;
      return bad == null ? null : span(bad);
    case 129 || 139:
      final uses = tokens.isNotEmpty && tokens.first.kind == TokenKind.label
          ? labels.skip(1)
          : labels;
      final missing = uses
          .where((t) => isValidLabel(t.value) && !defined.contains(t.value))
          .firstOrNull;
      return missing == null ? null : span(missing);
    case 200:
      for (final (i, t) in tokens.indexed) {
        final number = after(i);
        if (_sigils.contains(t.kind) &&
            number?.kind == TokenKind.number &&
            (number!.value < 1 || number.value > 65535)) {
          return span(t, number);
        }
      }
    case 17:
      for (final (i, t) in tokens.indexed) {
        if (t.kind == TokenKind.percent && t.value > 100) return span(t);
        final number = after(i);
        if (number?.kind != TokenKind.number) continue;
        final tooBig = switch (t.kind) {
          TokenKind.mesh => number!.value > smallMax(base),
          TokenKind.fence =>
            number!.bits == null ||
                number.bits! < 0 ||
                number.bits! > 0xFFFFFFFF,
          TokenKind.stockade => number!.bits == null,
          _ => false,
        };
        if (tooBig) return span(t, number);
      }
    case 801:
      for (final (i, t) in tokens.indexed) {
        if (t.kind == TokenKind.petition && after(i) != null) {
          return span(t, tokens.skip(i + 1).take(2).last);
        }
      }
  }
  return null;
}
