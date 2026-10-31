import 'diagnostics.dart';
import 'document.dart';
import 'extension.dart';
import 'text.dart';

/// The `file:` URI of a companion's path.
String companionUri(String path) => Uri.file(path).toString();

/// Every companion of every open program, by URI, with the text its places are in (R10). A file
/// two programs depend on is checked once for each, so each program's word on it is there.
Map<String, List<(Companion, EditorText)>> companionsByUri(
  Iterable<Document> documents,
) {
  final byUri = <String, List<(Companion, EditorText)>>{};
  for (final document in documents.where((d) => d.handled)) {
    for (final companion in document.companions) {
      final text = companion.text;
      if (text == null) continue;
      (byUri[companionUri(companion.path)] ??= []).add((
        companion,
        EditorText(companion.path, text),
      ));
    }
  }
  return byUri;
}

/// The diagnostics for one companion file, without repeats.
List<Map<String, Object?>> companionDiagnostics(
  List<(Companion, EditorText)> companions,
  String source,
) {
  final seen = <String>{};
  return [
    for (final (companion, text) in companions)
      for (final d in companion.diagnostics)
        if (seen.add(
          '${d.error.error.code} ${d.span.start} ${d.span.end} ${d.note}',
        ))
          {
            'range': text.range(d.span),
            'severity': errorSeverity,
            'code': 'E${d.error.error.code.toString().padLeft(3, '0')}',
            'source': source,
            'message': [messageOf(d.error), ?d.note].join('\n'),
          },
  ];
}

/// The hover at [position] in a companion file, from every program that depends on it.
Map<String, Object?>? companionHover(
  List<(Companion, EditorText)> companions,
  Position position,
) {
  final hovers = <String>{};
  Map<String, Object?>? range;
  for (final (companion, text) in companions) {
    final offset = text.offset(position);
    for (final h in companion.hovers) {
      if (h.span.start <= offset &&
          offset < h.span.end &&
          hovers.add(h.markdown)) {
        range ??= text.range(h.span);
      }
    }
  }
  if (hovers.isEmpty) return null;
  return {
    'contents': {'kind': 'markdown', 'value': hovers.join('\n\n---\n\n')},
    'range': range,
  };
}

/// Go to definition from where a program names a companion: the companion's start.
List<Map<String, Object?>>? companionDefinition(
  Document document,
  Position position,
) {
  final offset = document.text.offset(position);
  for (final companion in document.companions) {
    if (companion.reference.start <= offset &&
        offset < companion.reference.end) {
      return [
        {
          'uri': companionUri(companion.path),
          'range': {
            'start': {'line': 0, 'character': 0},
            'end': {'line': 0, 'character': 0},
          },
        },
      ];
    }
  }
  return null;
}
