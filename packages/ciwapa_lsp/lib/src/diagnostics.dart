import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';

const errorSeverity = 1, informationSeverity = 3;

/// Every error the front end found, as Error diagnostics on its token or statement (R2, R4), and
/// an Information hint on every undecodable statement: the comments everyone writes as `DO NOTE`
/// are E000 only if they ever run, so they never get a warning (Q163).
List<Map<String, Object?>> diagnosticsOf(Document document) {
  final analysis = document.analysis;
  return [
    for (final s in document.model.statements.where((s) => s.undecodable))
      {
        'range': document.text.range(s.span),
        'severity': informationSeverity,
        'code': 'E000',
        'source': document.server.name,
        'message': s.statement.not
            ? 'A comment, abstained from the start: E000 only if something REINSTATEs it and it runs.'
            : 'A comment to the compiler, and E000 if it ever runs. PLEASE NOTE keeps it from running.',
      },
    for (final e in analysis.errors)
      {
        'range': document.text.range(placeOf(e, analysis)),
        'severity': errorSeverity,
        'code': 'E${e.error.code.toString().padLeft(3, '0')}',
        'source': document.server.name,
        'message': messageOf(e),
      },
  ];
}

/// Where an error goes: its token, or its statement, or failing those (an error with no statement
/// in the file, such as politeness in a file of one statement) the first statement or the start.
Span placeOf(CompileError e, Analysis analysis) {
  if (e.token ?? e.span case final span?) return span;
  final program = analysis.program;
  final first = program.statements
      .take(program.userStatements)
      .where((s) => identical(s.source, program.source))
      .firstOrNull;
  return first == null ? const Span(0, 0) : Span(first.start, first.end);
}

/// The ICL line and the joke, as the CLI prints them.
String messageOf(CompileError e) {
  final code = e.error.code.toString().padLeft(3, '0');
  final message = 'ICL${code}I ${e.error.text}\n${e.error.joke}';
  return e.whenRun ? 'When this statement runs: $message' : message;
}
