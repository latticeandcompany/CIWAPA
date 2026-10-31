import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'model.dart';

/// How polite a file is, counted as the compiler counts it (§10.4): every statement of the file,
/// a WHILE's added ones included.
class Politeness {
  const Politeness(this.polite, this.total);

  /// Null when the file has no statements to count.
  static Politeness? of(Document document) {
    final program = document.analysis.program;
    final statements = program.statements.where(
      (s) => identical(s.source, program.source),
    );
    if (statements.isEmpty) return null;
    return Politeness(
      statements.where((s) => s.polite).length,
      statements.length,
    );
  }

  final int polite;
  final int total;

  /// Empty for a file with nothing to count, so that a status bar can clear.
  String get text => total == 0
      ? ''
      : 'PLEASE $polite/$total, ${(100 * polite / total).round()}%';

  String get tooltip => total <= 2
      ? 'Programs of two statements or fewer can be as polite as they like.'
      : 'Between ${_least(total)} and ${_most(total)} of these $total statements must say PLEASE.';

  /// `intercal/politeness` (R8, Q173).
  Map<String, Object?> toJson(String uri) => {
    'uri': uri,
    'polite': polite,
    'total': total,
    'text': text,
  };
}

int _least(int total) => (total + 4) ~/ 5;
int _most(int total) => total ~/ 3;

/// `textDocument/codeAction` (R8, Q173): on E079, a quick fix that adds just enough PLEASEs; on
/// E099, one that removes just enough. Either spreads its changes evenly through the file, and
/// changes only statements whose identifier is DO, PLEASE or PLEASE DO, and no WHILE, whose
/// politeness counts more than once.
List<Map<String, Object?>> politenessFixes(Document document, Object? context) {
  final diagnostics = switch (context) {
    {'diagnostics': final List<Object?> d} => d.whereType<Map>(),
    _ => const <Map>[],
  };
  final politeness = Politeness.of(document);
  if (politeness == null) return const [];
  return [
    for (final diagnostic in diagnostics)
      if (_fix(document, politeness, diagnostic['code']) case (
        final title,
        final edits,
      ))
        {
          'title': title,
          'kind': 'quickfix',
          'isPreferred': true,
          'diagnostics': [diagnostic],
          'edit': {
            'changes': {document.uri: edits},
          },
        },
  ];
}

(String, List<Map<String, Object?>>)? _fix(
  Document document,
  Politeness politeness,
  Object? code,
) {
  final runes = document.text.source.runes;
  final candidates = <(FileStatement, Token, String)>[];
  for (final s in document.model.statements) {
    if (!s.statement.hasIdentifier || s.whileBody != null) continue;
    final identifier = s.tokens
        .where((t) => t.kind == TokenKind.identifier)
        .firstOrNull;
    if (identifier == null) continue;
    final word = String.fromCharCodes(
      runes.sublist(identifier.start, identifier.end),
    ).replaceAll(RegExp(r'\s+'), ' ');
    if (const {'DO', 'PLEASE', 'PLEASE DO'}.contains(word)) {
      candidates.add((s, identifier, word));
    }
  }
  final (count, chosen, replacement, title) = switch (code) {
    'E079' => (
      _least(politeness.total) - politeness.polite,
      [
        for (final c in candidates)
          if (c.$3 == 'DO') c,
      ],
      'PLEASE DO',
      'Add PLEASE to',
    ),
    'E099' => (
      politeness.polite - _most(politeness.total),
      [
        for (final c in candidates)
          if (c.$3 != 'DO') c,
      ],
      'DO',
      'Take PLEASE off',
    ),
    _ => (0, const <(FileStatement, Token, String)>[], '', ''),
  };
  if (count <= 0 || chosen.length < count) return null;
  final edits = [
    for (var i = 0; i < count; i++)
      () {
        final (_, identifier, _) =
            chosen[((2 * i + 1) * chosen.length) ~/ (2 * count)];
        return {
          'range': document.text.range(Span(identifier.start, identifier.end)),
          'newText': replacement,
        };
      }(),
  ];
  return (
    '$title ${count == 1 ? 'one statement' : '$count statements'}',
    edits,
  );
}
