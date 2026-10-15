import 'dart:convert';

/// A source file, decoded as UTF-8 with carriage returns stripped (decisions T7, T14).
class Source {
  Source(this.path, String text) : text = text.replaceAll('\r', '') {
    runes = this.text.runes.toList();
    _lineStarts = [0];
    for (var i = 0; i < runes.length; i++) {
      if (runes[i] == 0x0A) _lineStarts.add(i + 1);
    }
  }

  factory Source.fromBytes(String path, List<int> bytes) =>
      Source(path, utf8.decode(bytes, allowMalformed: true));

  final String path;
  final String text;
  late final List<int> runes;
  late final List<int> _lineStarts;

  int get lineCount => _lineStarts.length;

  /// The 0-based line holding rune offset [offset].
  int lineOf(int offset) {
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
