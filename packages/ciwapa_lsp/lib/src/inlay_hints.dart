import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'model.dart';
import 'politeness.dart';
import 'text.dart';

const _constantRun = {
  TokenKind.mesh,
  TokenKind.fence,
  TokenKind.stockade,
  TokenKind.number,
  TokenKind.mingle,
  TokenKind.select,
  TokenKind.spark,
  TokenKind.ears,
};

/// `textDocument/inlayHint` (R8, Q164): each statement's ordinal, each constant in hex and binary,
/// the value of each mingle or select of constants, and, unless the editor shows it in a status
/// bar, the file's politeness on its first statement.
List<Map<String, Object?>> inlayHints(Document document, Object? range) {
  final text = document.text;
  final model = document.model;
  final (from, to) = switch (range) {
    {'start': final Object? start, 'end': final Object? end} => (
      text.offset(Position.fromJson(start)),
      text.offset(Position.fromJson(end)),
    ),
    _ => (0, text.source.runes.length),
  };
  bool inRange(int offset) => offset >= from && offset <= to;
  Map<String, Object?> hint(
    int offset,
    String label, {
    bool before = false,
    String? tooltip,
  }) => {
    'position': text.position(offset).toJson(),
    'label': label,
    if (before) 'paddingRight': true else 'paddingLeft': true,
    'tooltip': ?tooltip,
  };
  final politeness = Politeness.of(document);
  return [
    if (!document.server.politenessInStatusBar &&
        politeness != null &&
        model.statements.isNotEmpty)
      hint(
        _endOfFirstLine(text, model.statements.first),
        politeness.text,
        tooltip: politeness.tooltip,
      ),
    for (final s in model.statements)
      if (inRange(s.statement.start))
        hint(
          s.statement.start,
          '${s.ordinal}:',
          before: true,
          tooltip: 'Statement ${s.ordinal}, as runtime errors count them.',
        ),
    for (final piece in model.pieces)
      if (piece.role == Role.constant &&
          piece.token!.kind != TokenKind.number &&
          inRange(piece.span.end))
        if (_constantValue(document, piece) case final value?)
          hint(piece.span.end, _hexAndBinary(value)),
    if (model.program.base == 2)
      for (final (end, value) in _foldedConstants(model))
        if (inRange(end)) hint(end, '= $value'),
  ];
}

int _endOfFirstLine(EditorText text, FileStatement statement) {
  final line = text.position(statement.statement.start).line;
  var offset = statement.statement.start;
  while (offset < statement.statement.end &&
      text.position(offset + 1).line == line) {
    offset++;
  }
  return offset;
}

int? _constantValue(Document document, Piece piece) {
  final runes = document.text.source.runes;
  final digits = String.fromCharCodes(
    runes.sublist(piece.span.start, piece.span.end),
  ).replaceAll(RegExp(r'\D'), '');
  final value = int.tryParse(digits);
  if (value == null || value < 2) return null;
  // Too big for a `#` is E017 when it runs, and no value at all.
  return piece.token!.kind == TokenKind.mesh && value > 0xFFFF ? null : value;
}

String _hexAndBinary(int value) =>
    '0x${value.toRadixString(16).toUpperCase()} 0b${value.toRadixString(2)}';

/// Each mingle or select whose operands are all constants, as where it ends and its value. The
/// syntax tree has no places, so the trees and the runs of constant tokens are matched up in order,
/// and a statement where they don't pair up gets no hints.
Iterable<(int, int)> _foldedConstants(SyntaxModel model) sync* {
  for (final s in model.statements) {
    final folded = <(Expr, int)>[];
    void visit(Expr e) {
      final value = e is Binary ? _fold(e) : null;
      if (value != null) {
        folded.add((e, value));
        return;
      }
      switch (e) {
        case Binary(:final left, :final right) ||
            CreatedOp(:final left, :final right):
          visit(left);
          visit(right);
        case Unary(:final operand):
          visit(operand);
        case Slat(:final expr):
          visit(expr);
        case Element(:final subscripts):
          subscripts.forEach(visit);
        default:
      }
    }

    for (final e in s.bodies.expand(_expressions)) {
      visit(e);
    }
    if (folded.isEmpty) continue;
    final runs = _constantRuns(s.tokens);
    if (runs.length != folded.length) continue;
    // A run must be its tree token for token, or the hint would sit beside something else.
    var same = true;
    for (var i = 0; i < runs.length && same; i++) {
      final (operators, constants) = _shape(folded[i].$1);
      same =
          runs[i].where(_isOperator).length == operators &&
          runs[i].where((t) => _meshes.contains(t.kind)).length == constants;
    }
    if (!same) continue;
    for (var i = 0; i < runs.length; i++) {
      yield (runs[i].last.end, folded[i].$2);
    }
  }
}

const _meshes = {TokenKind.mesh, TokenKind.fence, TokenKind.stockade};

bool _isOperator(Token t) =>
    t.kind == TokenKind.mingle || t.kind == TokenKind.select;

/// How many operators and constants a folded tree has.
(int, int) _shape(Expr e) => switch (e) {
  Binary(:final left, :final right) => () {
    final (lo, lc) = _shape(left);
    final (ro, rc) = _shape(right);
    return (lo + ro + 1, lc + rc);
  }(),
  _ => (0, 1),
};

Iterable<Expr> _expressions(Body body) => switch (body) {
  Calculate(:final target, :final value) => [target, value],
  IoBody(:final items) => items,
  Resume(:final count) || Forget(:final count) => [count],
  _ => const [],
};

int? _fold(Expr e) => switch (e) {
  Constant(:final value, :final width, overflow: false)
      when width != 16 || value <= 0xFFFF =>
    value,
  Binary(:final op, :final left, :final right, ungrouped: false) => switch ((
    _fold(left),
    _fold(right),
  )) {
    (final l?, final r?) when op == BinaryOp.mingle =>
      l <= 0xFFFF && r <= 0xFFFF ? _mingle(l, r) : null,
    (final l?, final r?) => l >= 0 && r >= 0 ? _select(l, r) : null,
    _ => null,
  },
  _ => null,
};

int _mingle(int left, int right) {
  var result = 0;
  for (var bit = 15; bit >= 0; bit--) {
    result = (result << 2) | (((left >> bit) & 1) << 1) | ((right >> bit) & 1);
  }
  return result;
}

int _select(int value, int mask) {
  var result = 0, place = 0;
  for (var bit = 0; bit < 63; bit++) {
    if ((mask >> bit) & 1 == 1) {
      result |= ((value >> bit) & 1) << place++;
    }
  }
  return result;
}

/// Each run of constant tokens holding an operator, trimmed of the operators at its edges. A run
/// with unbalanced sparks or ears is part of a bigger expression, and doesn't count.
List<List<Token>> _constantRuns(List<Token> tokens) {
  final runs = <List<Token>>[];
  var i = 0;
  while (i < tokens.length) {
    if (!_constantRun.contains(tokens[i].kind)) {
      i++;
      continue;
    }
    var j = i;
    while (j < tokens.length && _constantRun.contains(tokens[j].kind)) {
      j++;
    }
    var run = tokens.sublist(i, j);
    while (run.isNotEmpty && _isOperator(run.first)) {
      run = run.sublist(1);
    }
    while (run.isNotEmpty && _isOperator(run.last)) {
      run = run.sublist(0, run.length - 1);
    }
    final balanced =
        run.where((t) => t.kind == TokenKind.spark).length.isEven &&
        run.where((t) => t.kind == TokenKind.ears).length.isEven;
    if (balanced && run.any(_isOperator)) runs.add(run);
    i = j;
  }
  return runs;
}
