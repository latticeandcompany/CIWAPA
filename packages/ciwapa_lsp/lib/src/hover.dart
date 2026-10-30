import 'package:ciwapa_core/ciwapa_core.dart';

import 'diagnostics.dart';
import 'document.dart';
import 'help.dart';
import 'model.dart';
import 'text.dart';
import 'words.dart';

/// `textDocument/hover` (R4): the errors at the position, then what the token under it is.
Map<String, Object?>? hover(Document document, Position position) {
  final offset = document.text.offset(position);
  final analysis = document.analysis;
  final sections = <String>[];
  Span? range;
  for (final e in analysis.errors) {
    final place = placeOf(e, analysis);
    if (place.start <= offset && offset < place.end) {
      sections.add(errorHover(e.error, document));
      range ??= place;
    }
  }
  final statement = document.model.statementAt(offset);
  if (statement != null && statement.undecodable) {
    sections.add(undecodableHover(statement, document));
    range ??= statement.span;
  }
  final piece = document.model.pieceAt(offset);
  final words = piece == null ? null : _pieceHover(piece, document);
  if (words != null) {
    sections.add(words);
    range ??= piece!.span;
  }
  if (sections.isEmpty) return null;
  return {
    'contents': {'kind': 'markdown', 'value': sections.join('\n\n---\n\n')},
    'range': document.text.range(range!),
  };
}

/// The ICL line and the joke exactly as the CLI prints them, then what it means and what to do
/// about it (Q180).
String errorHover(IclError error, Document document, {String? message}) {
  final code = error.code.toString().padLeft(3, '0');
  final help =
      errorHelp[error.code] ?? document.server.extension.errorHelp[error.code];
  return [
    '```text',
    'ICL${code}I ${message ?? error.text}',
    '        ${error.joke}',
    '```',
    if (help != null) ...[help.description, '', '**What to do:** ${help.fix}'],
  ].join('\n');
}

String undecodableHover(FileStatement statement, Document document) {
  final source = document.text.source;
  final first = source.lineOf(statement.statement.start);
  final last = source.lineOf(
    statement.statement.end > statement.statement.start
        ? statement.statement.end - 1
        : statement.statement.start,
  );
  final abstained = statement.statement.not
      ? '\n\nIt starts abstained, so only a REINSTATE can make it run.'
      : '';
  return errorHover(
        IclError.of(0),
        document,
        message: undecodableText([
          for (var l = first; l <= last; l++) source.line(l),
        ]),
      ) +
      abstained;
}

String? _pieceHover(Piece piece, Document document) {
  final token = piece.token;
  if (token == null) return null;
  return switch (piece.role) {
    Role.label => _labelHover(token.value, piece.definition, document),
    Role.variable || Role.constant
        when sigils.contains(token.kind) || meshes.contains(token.kind) =>
      sigilHelp(token.kind),
    Role.operator => operatorHelp(token),
    Role.gerund => gerundHelp(token.gerund!),
    Role.identifier => switch (token.kind) {
      TokenKind.not => notHelp,
      TokenKind.percent => percentHelp,
      _ => token.maybe ? maybeHelp : identifierHelp,
    },
    _ => null,
  };
}

String? _labelHover(int label, bool definition, Document document) {
  if (definition) return null;
  final routine = document.libraryRoutine(label);
  if (routine != null) return routine.toMarkdown();
  final own = document.server.extension.labelHelp(document.path, label);
  if (own != null) return own;
  final target = document.model.statements
      .where((s) => s.statement.label == label)
      .firstOrNull;
  if (target == null) return '**($label)**: no statement has this label.';
  final line = document.text.position(target.statement.start).line + 1;
  return '**($label)**: statement ${target.ordinal}, on line $line.';
}
