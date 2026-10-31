import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'model.dart';
import 'text.dart';

final _note = RegExp(r'^NOTE\b\s*');

/// `intercal/toggleComment` (R9, Q174): every statement the range touches becomes `PLEASE NOTE`
/// with its label kept, which lexes as an abstained undecodable statement, so it never runs. When
/// every one already is `PLEASE NOTE` or `DO NOTE`, they all go back to `DO`.
List<Map<String, Object?>> toggleComment(Document document, Object? range) {
  final text = document.text;
  final (from, to) = switch (range) {
    {'start': final Object? start, 'end': final Object? end} => (
      text.offset(Position.fromJson(start)),
      text.offset(Position.fromJson(end)),
    ),
    _ => throw ArgumentError('range'),
  };
  final heads = [
    for (final s in document.model.statements)
      if (s.statement.start <= to &&
          (s.statement.end > from || s.statement.start == from))
        ?_head(document, s),
  ];
  final uncomment = heads.isNotEmpty && heads.every((h) => h.note != null);
  return [
    for (final head in heads)
      if (uncomment)
        {
          'range': text.range(Span(head.identifier.start, head.note!)),
          'newText': 'DO ',
        }
      else if (head.note == null)
        {'range': text.range(head.identifier), 'newText': 'PLEASE NOTE'},
  ];
}

/// A statement's identifier, and where the `NOTE` after it ends with its spaces, if it is a
/// comment that toggling made or would make.
({Span identifier, int? note})? _head(Document document, FileStatement s) {
  final identifier = s.tokens
      .where((t) => t.kind == TokenKind.identifier)
      .firstOrNull;
  if (!s.statement.hasIdentifier || identifier == null) return null;
  final runes = document.text.source.runes;
  final word = String.fromCharCodes(
    runes,
    identifier.start,
    identifier.end,
  ).replaceAll(RegExp(r'\s+'), ' ');
  if (!const {'DO', 'PLEASE', 'PLEASE DO'}.contains(word)) return null;
  var after = identifier.end;
  while (after < s.statement.end && _isSpace(runes[after])) {
    after++;
  }
  final rest = String.fromCharCodes(
    runes,
    after,
    (after + 40).clamp(after, s.statement.end),
  );
  final note = word == 'PLEASE DO' ? null : _note.firstMatch(rest);
  return (
    identifier: Span(identifier.start, identifier.end),
    note: note == null ? null : after + note.end,
  );
}

bool _isSpace(int rune) => rune == 0x20 || rune == 0x09 || rune == 0x0A;
