import 'frontend.dart';
import 'ir.dart';
import 'lexer.dart';
import 'source.dart';

/// Everything a front end found in a file, for an editor: the program and every error with its
/// place (R2), the compile errors first, in the order the compiler meets them.
class Analysis {
  Analysis(this.program, this.errors);

  final Program program;
  final List<CompileError> errors;

  Source get source => program.source;
}

/// Runs [analyze], collecting every compile error, then [lower]s the program without the random
/// bug, so that E774 never appears, to find each user statement's statement-local error: the one
/// it would raise if it ran.
Analysis collectErrors(
  Program Function(void Function(CompileError error) onError) analyze,
  IrProgram Function(Program program, IrOptions options) lower,
) {
  final errors = <CompileError>[];
  final program = analyze(errors.add);
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
  for (final s in ir.statements.take(program.userStatements)) {
    if (s.faults.isEmpty) continue;
    final code = s.faults.first.code;
    final statement = program.statements[s.ordinal - 1];
    final tokens = program.tokens
        .where((t) => t.start >= statement.start && t.end <= statement.end)
        .toList();
    errors.add(
      CompileError(code, s.ordinal, whenRun: true).placed(
        program.statements,
        program.source,
        token: _faultToken(code, tokens, program.base, defined),
      ),
    );
  }
  return Analysis(program, errors);
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
