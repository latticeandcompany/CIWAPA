import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'model.dart';
import 'rpc.dart';

const goToCommand = 'intercal.goTo';

const computedWarning =
    'This file has computed COME FROMs. Anything could come from anywhere.';

/// `textDocument/codeLens` (R7, Q152): above every labelled statement that a COME FROM or NEXT
/// FROM names, one lens per statement that comes from it. A file with computed or gerund COME
/// FROMs, which nothing can follow, says so on its first statement.
List<Map<String, Object?>> codeLenses(Document document) {
  final text = document.text;
  final statements = document.model.statements;
  final comers = <int, List<FileStatement>>{};
  FileStatement? firstComputed;
  for (final s in statements) {
    switch (s.statement.body) {
      case ComeFrom(:final label):
        (comers[label] ??= []).add(s);
      case ComputedComeFrom() || GerundComeFrom():
        firstComputed ??= s;
      default:
    }
  }
  Map<String, Object?> lens(Span at, String title, FileStatement target) => {
    'range': text.range(at),
    'command': {
      'title': title,
      'command': goToCommand,
      'arguments': [
        document.uri,
        text.position(target.statement.start).toJson(),
      ],
    },
  };
  return [
    if (firstComputed != null && statements.isNotEmpty)
      lens(statements.first.span, computedWarning, firstComputed),
    for (final s in statements)
      if (s.statement.label case final label?)
        for (final comer in comers[label] ?? const <FileStatement>[])
          lens(
            s.span,
            '${(comer.statement.body as ComeFrom).nexting ? 'NEXTS' : 'COMES'} FROM: '
            'line ${text.position(comer.statement.start).line + 1}',
            comer,
          ),
  ];
}

/// `workspace/executeCommand` for [goToCommand]: the arguments a lens carries, as the
/// `window/showDocument` request that takes the editor there.
Map<String, Object?> showDocumentFor(Object? arguments) {
  if (arguments case [
    final String uri,
    {'line': final int line, 'character': final int character},
  ]) {
    final at = {'line': line, 'character': character};
    return {
      'uri': uri,
      'takeFocus': true,
      'selection': {'start': at, 'end': at},
    };
  }
  throw const ResponseError(
    ResponseError.invalidParams,
    '$goToCommand takes a URI and a position.',
  );
}
