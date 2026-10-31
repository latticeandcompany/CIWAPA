import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'errors.dart';
import 'syntax.dart';

/// What a piece of a template prints (R6).
enum PieceKind {
  /// Its text, as it is.
  text,

  /// Template argument [Piece.index], `;49221 SUB index`, which the template names `,(145-index)`.
  arg,

  /// The route parameter whose number is the piece's value: `;4400 SUB e`.
  param,

  /// The template argument whose number is the piece's value: `;49221 SUB e`.
  argValue,

  /// The piece's value, as a butchered Roman numeral.
  number,
}

/// One piece of a compiled template.
class Piece {
  const Piece.text(this.text)
    : kind = PieceKind.text,
      index = 0,
      raw = false,
      attribute = false;

  const Piece(
    this.kind, {
    this.index = 0,
    required this.raw,
    required this.attribute,
  }) : text = '';

  final PieceKind kind;
  final String text;
  final int index;

  /// Triple grumpies: a string isn't HTML-escaped.
  final bool raw;

  /// Inside an attribute value, where a numeral's overlines can't be markup.
  final bool attribute;

  /// Whether the piece takes the next of its statement's values.
  bool get valued =>
      kind == PieceKind.param ||
      kind == PieceKind.argValue ||
      kind == PieceKind.number;
}

/// A template compiled for one `READ OUT … WITH TEMPLATE`: its pieces, and the expressions whose
/// values the valued pieces print, in order.
class Template {
  Template(this.pieces, this.values);

  final List<Piece> pieces;
  final List<Expr> values;
}

/// A template's path, relative to the source file's folder.
String templatePath(Source source, String path) {
  if (File(path).isAbsolute) return path;
  return '${File(source.path).parent.path}${Platform.pathSeparator}$path';
}

/// A template's text, as UTF-8 with malformed bytes as U+FFFD: E777 if it can't be read, as for a
/// source file that can't be.
String readTemplate(Source source, String path, int statement) {
  try {
    return utf8.decode(
      File(templatePath(source, path)).readAsBytesSync(),
      allowMalformed: true,
    );
  } on FileSystemException {
    throw CompileError(777, statement);
  }
}

/// Compiles the template [path] for the statement [statement] (`READ OUT #count`): E777 if it
/// can't be read, E820 for a grumpy that isn't one or sits where no value can go, E821 unless
/// [count] is the number of arguments the template uses, and E997 for an operator binary doesn't
/// have.
Template compileTemplate(Source source, String path, int count, int statement) {
  final scan = scanTemplate(
    readTemplate(source, path, statement),
    path,
    count,
    (problem) => throw problem.code == 997
        ? CompileError(997, statement)
        : interstatesCompileError(problem.code, statement),
  );
  return Template(scan.pieces, scan.values);
}

/// A problem in a template, where it is in the template's text, in runes.
typedef TemplateProblem = ({int code, int start, int end});

/// A grumpy that names an argument, `,m`, where it is in the template's text, in runes.
typedef ArgumentGrumpy = ({int m, int start, int end});

/// What [scanTemplate] finds: the template's pieces, the values its valued pieces print, and its
/// argument grumpies.
typedef TemplateScan = ({
  List<Piece> pieces,
  List<Expr> values,
  List<ArgumentGrumpy> arguments,
});

/// Reads a template's [text] as [compileTemplate] does, reporting each problem to [report] and
/// carrying on past it where it can. [count] is the `READ OUT #count` it is rendered with.
TemplateScan scanTemplate(
  String text,
  String path,
  int count,
  void Function(TemplateProblem problem) report,
) {
  final runes = text.runes.toList();
  final source = String.fromCharCodes(runes);
  final pieces = <Piece>[];
  final values = <Expr>[];
  final grumpies = <ArgumentGrumpy>[];
  var arguments = 0;
  final literal = StringBuffer();
  final html = _HtmlContext();
  var i = 0;
  // Runes, not UTF-16 units, so that a problem's place is the Source's.
  bool at(String s, int offset) =>
      offset + s.length <= runes.length &&
      String.fromCharCodes(runes, offset, offset + s.length) == s;
  int find(String s, int from) {
    for (var j = from; j + s.length <= runes.length; j++) {
      if (at(s, j)) return j;
    }
    return -1;
  }

  while (i < runes.length) {
    if (!at('{{', i)) {
      final c = String.fromCharCode(runes[i]);
      html.feed(c);
      literal.write(c);
      i++;
      continue;
    }
    final raw = at('{{{', i);
    final close = raw ? '}}}' : '}}';
    final start = i + close.length;
    final end = find(close, start);
    if (end < 0) {
      report((code: 820, start: i, end: runes.length));
      break;
    }
    final grumpy = (start: i, end: end + close.length);
    i = grumpy.end;
    if (literal.isNotEmpty) {
      pieces.add(Piece.text(literal.toString()));
      literal.clear();
    }
    final inner = String.fromCharCodes(runes, start, end);
    final place = html.grumpy();
    if (place == _Place.nowhere) {
      report((code: 820, start: grumpy.start, end: grumpy.end));
      continue;
    }
    final attribute = place == _Place.noMarkup;
    final argument = RegExp(r'^\s*,\s*([0-9][0-9\s]*)$').firstMatch(inner);
    if (argument != null) {
      final m = int.tryParse(argument.group(1)!.replaceAll(RegExp(r'\s'), ''));
      if (m == null || m < 1 || m > 144) {
        report((code: 820, start: grumpy.start, end: grumpy.end));
        continue;
      }
      final k = 145 - m;
      if (k > arguments) arguments = k;
      grumpies.add((m: m, start: grumpy.start, end: grumpy.end));
      pieces.add(
        Piece(PieceKind.arg, index: k, raw: raw, attribute: attribute),
      );
      continue;
    }
    final e = InterstatesParser(Source(path, inner)).parseExpression();
    if (e == null || !_valid(e)) {
      report((code: 820, start: grumpy.start, end: grumpy.end));
      continue;
    }
    if (unaryOps(e).any((op) => op.index > UnaryOp.xor.index)) {
      report((code: 997, start: grumpy.start, end: grumpy.end));
      continue;
    }
    final kind = switch (e) {
      Element(:final array) when array == params => PieceKind.param,
      Element(:final array) when array == args => PieceKind.argValue,
      _ => PieceKind.number,
    };
    if (kind == PieceKind.number && mentionsStrings(e)) {
      report((code: 820, start: grumpy.start, end: grumpy.end));
      continue;
    }
    values.add(kind == PieceKind.number ? e : (e as Element).subscripts.single);
    pieces.add(Piece(kind, raw: raw, attribute: attribute));
  }
  if (literal.isNotEmpty) pieces.add(Piece.text(literal.toString()));
  if (arguments != count) {
    // About the grumpy that sets the count, or the whole template when none does.
    final lowest = grumpies.isEmpty
        ? null
        : grumpies.reduce((a, b) => a.m <= b.m ? a : b);
    report((
      code: 821,
      start: lowest?.start ?? 0,
      end: lowest?.end ?? source.runes.length,
    ));
  }
  return (pieces: pieces, values: values, arguments: grumpies);
}

/// What a template's expression may be: INTERCAL's operands and operators over the program's
/// variables, without tail arrays (in a template those are its arguments, whole strings), slats or
/// created operators; a string element must have one subscript.
bool _valid(Expr e) => switch (e) {
  Element(:final array, :final subscripts) =>
    array.kind != VarKind.tail &&
        (!isStringArray(array) || subscripts.length == 1) &&
        subscripts.every(_valid),
  Binary(:final left, :final right) => _valid(left) && _valid(right),
  Unary(:final operand) => _valid(operand),
  Constant() || Scalar() => true,
  ArrayItem() || Slat() || CreatedOp() => false,
};

/// Where a grumpy sits: in text, where markup can go; where it can't (a quoted attribute value, or
/// the text of a `<title>` or `<textarea>`); or where no value belongs (a tag's name, between its
/// attributes, an unquoted value, or a `<script>` or `<style>`), which is E820.
enum _Place { text, noMarkup, nowhere }

/// Follows an HTML document character by character, far enough to know where each grumpy sits.
class _HtmlContext {
  var _state = _State.text;
  var _quote = '';
  var _recent = '';
  var _name = '';
  var _closing = false;
  var _raw = '';

  static const _rawElements = {'script', 'style', 'title', 'textarea'};

  _Place grumpy() => switch (_state) {
    _State.text || _State.comment => _Place.text,
    _State.raw =>
      _raw == 'title' || _raw == 'textarea' ? _Place.noMarkup : _Place.nowhere,
    _State.value when _quote.isNotEmpty => _Place.noMarkup,
    _ => _Place.nowhere,
  };

  void feed(String c) {
    _recent = _recent.length >= 16 ? _recent.substring(1) + c : _recent + c;
    final letter = RegExp(r'[A-Za-z]').hasMatch(c);
    final space = RegExp(r'\s').hasMatch(c);
    switch (_state) {
      case _State.text:
        if (c == '<') _state = _State.tagStart;
      case _State.tagStart:
        if (c == '/' || letter) {
          _closing = c == '/';
          _name = letter ? c : '';
          _state = _State.tagName;
        } else if (c == '!' || c == '?') {
          _state = _State.tag;
        } else {
          _state = c == '<' ? _State.tagStart : _State.text;
        }
      case _State.tagName:
        if (RegExp(r'[A-Za-z0-9-]').hasMatch(c)) {
          _name += c;
        } else if (c == '>') {
          _endTag();
        } else {
          _state = _State.tag;
        }
      case _State.tag:
        if (_recent.endsWith('<!--')) {
          _state = _State.comment;
        } else if (c == '>') {
          _endTag();
        } else if (c == '=') {
          _state = _State.beforeValue;
        }
      case _State.beforeValue:
        if (c == '"' || c == "'") {
          _quote = c;
          _state = _State.value;
        } else if (c == '>') {
          _endTag();
        } else if (!space) {
          _quote = '';
          _state = _State.value;
        }
      case _State.value:
        if (_quote.isEmpty ? (c == '>' || space) : c == _quote) {
          if (c == '>') {
            _endTag();
          } else {
            _state = _State.tag;
          }
        }
      case _State.comment:
        if (_recent.endsWith('-->')) _state = _State.text;
      case _State.raw:
        if (_recent.toLowerCase().endsWith('</$_raw')) {
          _closing = true;
          _name = _raw;
          _state = _State.tagName;
        }
    }
  }

  void _endTag() {
    final name = _name.toLowerCase();
    if (!_closing && _rawElements.contains(name)) {
      _raw = name;
      _state = _State.raw;
    } else {
      _state = _State.text;
    }
  }
}

enum _State { text, tagStart, tagName, tag, beforeValue, value, comment, raw }
