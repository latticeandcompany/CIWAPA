import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'model.dart';

/// Semantic tokens are the only highlighter (R5, Q155): every color comes from the real lexer.
/// Standard token types, so every theme already has colors for them.
const tokenTypes = [
  'comment',
  'keyword',
  'modifier',
  'enumMember',
  'function',
  'variable',
  'number',
  'operator',
  'string',
];

const tokenModifiers = [
  'declaration',
  'defaultLibrary',
  'extension',
  'dialect',
  'spot',
  'twoSpot',
  'tail',
  'hybrid',
  'doubleCateye',
  'doubleHybrid',
];

const legend = {'tokenTypes': tokenTypes, 'tokenModifiers': tokenModifiers};

int _type(Role role) => tokenTypes.indexOf(switch (role) {
  Role.comment => 'comment',
  Role.keyword => 'keyword',
  Role.identifier => 'modifier',
  Role.gerund => 'enumMember',
  Role.label => 'function',
  Role.variable => 'variable',
  Role.constant => 'number',
  Role.operator => 'operator',
  Role.string => 'string',
});

int _modifiers(Piece piece, Document document) {
  final names = [
    if (piece.definition) 'declaration',
    if (piece.extension) 'extension',
    if (piece.dialect) 'dialect',
    if (piece.role == Role.label &&
        !piece.definition &&
        document.libraryRoutine(piece.token!.value) != null)
      'defaultLibrary',
    if (piece.role == Role.variable)
      piece.token!.kind == TokenKind.oneSpot ? 'spot' : piece.token!.kind.name,
  ];
  var bits = 0;
  for (final name in names) {
    final index = tokenModifiers.indexOf(name);
    if (index >= 0) bits |= 1 << index;
  }
  return bits;
}

/// `textDocument/semanticTokens/full`: the pieces in LSP's relative encoding, one token per line
/// for a piece that spans lines.
Map<String, Object?> semanticTokens(Document document) {
  final text = document.text;
  final data = <int>[];
  var lastLine = 0, lastStart = 0;
  void add(int line, int start, int length, int type, int modifiers) {
    if (length <= 0) return;
    data.addAll([
      line - lastLine,
      line == lastLine ? start - lastStart : start,
      length,
      type,
      modifiers,
    ]);
    lastLine = line;
    lastStart = start;
  }

  for (final piece in document.model.pieces) {
    final start = text.position(piece.span.start);
    final end = text.position(piece.span.end);
    final type = _type(piece.role);
    final modifiers = _modifiers(piece, document);
    if (start.line == end.line) {
      add(
        start.line,
        start.character,
        end.character - start.character,
        type,
        modifiers,
      );
      continue;
    }
    add(
      start.line,
      start.character,
      text.lineLength(start.line) - start.character,
      type,
      modifiers,
    );
    for (var line = start.line + 1; line < end.line; line++) {
      add(line, 0, text.lineLength(line), type, modifiers);
    }
    add(end.line, 0, end.character, type, modifiers);
  }
  return {'data': data};
}
