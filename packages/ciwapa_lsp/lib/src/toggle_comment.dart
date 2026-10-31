import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'model.dart';
import 'text.dart';

final _note = RegExp(r'^NOTE\b\s*');

/// `intercal/toggleComment` (R9, Q174): every statement on the lines the range covers becomes
/// `PLEASE NOTE` with its label kept, which lexes as an abstained undecodable statement, so it
/// never runs. When every one already is `PLEASE NOTE` or `DO NOTE`, they all go back to `DO`.
/// Like an editor's line comments, it works in whole lines: a selection that ends at the start of
/// a line leaves that line alone.
List<Map<String, Object?>> toggleComment(Document document, Object? range) {
  final text = document.text;
  final (start, end) = switch (range) {
    {'start': final Object? start, 'end': final Object? end} => (
      Position.fromJson(start),
      Position.fromJson(end),
    ),
    _ => throw const FormatException('toggleComment takes a range'),
  };
  final lastLine = end.line > start.line && end.character == 0
      ? end.line - 1
      : end.line;
  final heads = [
    for (final s in document.model.statements)
      if (text.position(s.statement.start).line <= lastLine &&
          text.position(s.statement.end).line >= start.line)
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
        {
          'range': text.range(head.identifier),
          'newText': head.glued ? 'PLEASE NOTE ' : 'PLEASE NOTE',
        },
  ];
}

/// A statement's identifier; where the `NOTE` after it ends with its spaces, if it is a comment
/// that toggling made or would make; and whether a `N'T` follows the identifier with no space,
/// as in `DON'T`, which `PLEASE NOTE` would otherwise swallow.
({Span identifier, int? note, bool glued})? _head(
  Document document,
  FileStatement s,
) {
  final at = s.tokens.indexWhere((t) => t.kind == TokenKind.identifier);
  if (!s.statement.hasIdentifier || at < 0) return null;
  final identifier = s.tokens[at];
  final next = at + 1 < s.tokens.length ? s.tokens[at + 1] : null;
  final runes = document.text.source.runes;
  final word = String.fromCharCodes(
    runes,
    identifier.start,
    identifier.end,
  ).replaceAll(RegExp(r'\s+'), ' ');
  var after = identifier.end;
  while (after < s.statement.end && _isSpace(runes[after])) {
    after++;
  }
  final rest = String.fromCharCodes(
    runes,
    after,
    (after + 40).clamp(after, s.statement.end),
  );
  final note = word == 'DO' || word == 'PLEASE' ? _note.firstMatch(rest) : null;
  return (
    identifier: Span(identifier.start, identifier.end),
    note: note == null ? null : after + note.end,
    glued: next?.kind == TokenKind.not && next!.start == identifier.end,
  );
}

bool _isSpace(int rune) => rune == 0x20 || rune == 0x09 || rune == 0x0A;
