import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';

const errorSeverity = 1, informationSeverity = 3;

/// Every error the front end found, as Error diagnostics on its token or statement (R2, R4).
List<Map<String, Object?>> diagnosticsOf(Document document) {
  final analysis = document.analysis;
  return [
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
