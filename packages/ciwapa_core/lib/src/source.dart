import 'dart:convert';

/// A source file, decoded as UTF-8 with carriage returns stripped (decisions T7, T14).
///
/// Every offset in the compiler is an index into [runes], never into a Dart string.
class Source {
  factory Source(String path, String text) =>
      Source._(path, text.replaceAll('\r', '').runes.toList());

  Source._(this.path, List<int> runes)
    : runes = List.unmodifiable(runes),
      _lineStarts = _findLineStarts(runes);

  factory Source.fromBytes(String path, List<int> bytes) =>
      Source(path, utf8.decode(bytes, allowMalformed: true));

  final String path;
  final List<int> runes;
  final List<int> _lineStarts;

  String get text => String.fromCharCodes(runes);

  static List<int> _findLineStarts(List<int> runes) => List.unmodifiable([
    0,
    for (var i = 0; i < runes.length; i++)
      if (runes[i] == 0x0A) i + 1,
  ]);

  /// The number of lines. Text after the last newline, even none, is a line of its own.
  int get lineCount => _lineStarts.length;

  /// The 0-based line holding rune offset [offset]. A newline belongs to the line it ends.
  int lineOf(int offset) {
    RangeError.checkValueInInterval(offset, 0, runes.length, 'offset');
    var lo = 0, hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The text of 0-based [line], without its newline.
  String line(int line) {
    final start = _lineStarts[line];
    final end = line + 1 < _lineStarts.length
        ? _lineStarts[line + 1] - 1
        : runes.length;
    return String.fromCharCodes(runes, start, end);
  }

  /// The text between rune offsets [start] and [end].
  String slice(int start, int end) => String.fromCharCodes(runes, start, end);

  /// The numeric base selected by the file extension (§6.3, §6.6, decision T40), or null when the
  /// extension is invalid (E998).
  static int? baseOf(String path) {
    final match = RegExp(r'\.([2-7]?)i$').firstMatch(path);
    if (match == null) return null;
    final digit = match.group(1)!;
    return digit.isEmpty ? 2 : int.parse(digit);
  }
}
