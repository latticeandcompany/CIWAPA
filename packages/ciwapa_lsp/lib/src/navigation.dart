import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'libraries.dart';
import 'model.dart';
import 'rpc.dart';
import 'text.dart';

Map<String, Object?> location(String uri, EditorText text, Span span) => {
  'uri': uri,
  'range': text.range(span),
};

/// The label piece at [position], if the position is on a label.
Piece? labelAt(Document document, Position position) {
  final piece = document.model.pieceAt(document.text.offset(position));
  return piece?.role == Role.label ? piece : null;
}

/// Every label piece in the file whose number is [label].
Iterable<Piece> labelPieces(Document document, int label) => document
    .model
    .pieces
    .where((p) => p.role == Role.label && p.token!.value == label);

/// `textDocument/definition` (R6): the statements with the label, wherever a label is used. A
/// label defined twice (E182) offers both; one nobody defines offers nothing. A library label
/// opens the library's source.
List<Map<String, Object?>>? definition(Document document, Position position) {
  final piece = labelAt(document, position);
  if (piece == null) return null;
  final label = piece.token!.value;
  final own = labelPieces(document, label).where((p) => p.definition);
  if (own.isNotEmpty) {
    return [for (final p in own) location(document.uri, document.text, p.span)];
  }
  final provided = document.server.extension.definitionsOf(
    document.path,
    label,
    document.model,
  );
  if (provided != null) {
    return [
      for (final span in provided) location(document.uri, document.text, span),
    ];
  }
  final library = document.libraryOf(label);
  final span = library?.labels[label];
  if (library == null || span == null) return const [];
  return [location(library.uri, library.text, span)];
}

/// `textDocument/references` (R6): every literal use of the label in the file.
List<Map<String, Object?>>? references(
  Document document,
  Position position, {
  required bool includeDeclaration,
}) {
  final piece = labelAt(document, position);
  if (piece == null) return null;
  return [
    for (final p in labelPieces(document, piece.token!.value))
      if (includeDeclaration || !p.definition)
        location(document.uri, document.text, p.span),
  ];
}

/// `textDocument/prepareRename`: a label of the file's own, not one of a library's.
Map<String, Object?>? prepareRename(Document document, Position position) {
  final piece = labelAt(document, position);
  if (piece == null) return null;
  final label = piece.token!.value;
  if (!document.definedLabels.contains(label) &&
      document.libraryOf(label) != null) {
    throw ResponseError(
      ResponseError.requestFailed,
      '($label) belongs to the library. Renaming it here would only break the call.',
    );
  }
  return {'range': document.text.range(piece.span), 'placeholder': '$label'};
}

/// `textDocument/rename` (R6, Q166): every literal use of the label. [warn] hears when the file
/// has computed targets, which might still mean the old number.
Map<String, Object?>? rename(
  Document document,
  Position position,
  String newName,
  void Function(String warning) warn,
) {
  final prepared = prepareRename(document, position);
  if (prepared == null) return null;
  final label = labelAt(document, position)!.token!.value;
  final digits = RegExp(r'^\(?\s*(\d+)\s*\)?$').firstMatch(newName.trim());
  final number = digits == null ? null : int.tryParse(digits.group(1)!);
  if (number == null || !isValidLabel(number)) {
    throw const ResponseError(
      ResponseError.invalidParams,
      'Labels go from 1 to 65535. Counting is hard; we get it.',
    );
  }
  if (number != label && document.definedLabels.contains(number)) {
    throw ResponseError(
      ResponseError.invalidParams,
      '($number) is taken, and two statements with one label is E182.',
    );
  }
  if (hasComputedTargets(document)) {
    warn(
      'Renamed every ($label) written in the file. It also has computed targets (a computed or '
      'gerund COME FROM, a computed ABSTAIN or CREATE), and one of them might still mean '
      '$label. INTERCAL declines to say which.',
    );
  }
  return {
    'changes': {
      document.uri: [
        for (final p in labelPieces(document, label))
          {'range': document.text.range(p.span), 'newText': '($number)'},
      ],
    },
  };
}

/// Whether some statement's target is computed when it runs, so no tool can follow it (Q166).
bool hasComputedTargets(Document document) => document.model.statements.any(
  (s) => switch (s.statement.body) {
    ComputedComeFrom() || GerundComeFrom() => true,
    AbstainBody(count: _?) => true,
    Create(target: _?) => true,
    _ => false,
  },
);

/// `intercal/librarySource`: the text of a `ciwapa-lib:` document.
Map<String, Object?> librarySource(
  Map<String, Object?> params,
  LibraryDocument? Function(String name) find,
) {
  final uri = params['uri'];
  final name = uri is String && uri.startsWith('${LibraryDocument.scheme}:')
      ? Uri.parse(uri).pathSegments.lastOrNull
      : null;
  final library = name == null ? null : find(name);
  if (library == null) {
    throw ResponseError(
      ResponseError.invalidParams,
      'No library document at $uri.',
    );
  }
  return {'text': library.text.text};
}
