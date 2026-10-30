import 'package:ciwapa_core/ciwapa_core.dart';

/// An LSP position: a 0-based line and a UTF-16 offset in it.
class Position implements Comparable<Position> {
  const Position(this.line, this.character);

  factory Position.fromJson(Object? json) {
    if (json case {'line': final int line, 'character': final int character}) {
      return Position(line, character);
    }
    throw const FormatException('not a Position');
  }

  final int line;
  final int character;

  Map<String, Object?> toJson() => {'line': line, 'character': character};

  @override
  int compareTo(Position other) => line != other.line
      ? line.compareTo(other.line)
      : character.compareTo(other.character);

  @override
  bool operator ==(Object other) =>
      other is Position && other.line == line && other.character == character;

  @override
  int get hashCode => Object.hash(line, character);

  @override
  String toString() => '$line:$character';
}

/// A document as the editor holds it, and the [Source] the compiler reads from it.
///
/// [Source] strips `\r` and counts runes; LSP counts UTF-16 units on the text as it is, and ends
/// lines at `\n`, `\r\n` or a lone `\r`. Every position the server sends goes through [position],
/// and every one it receives through [offset].
class EditorText {
  EditorText(this.path, this.text) : source = Source(path, text) {
    var line = 0, character = 0;
    final runes = text.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      final r = runes[i];
      if (r == 0x0D) {
        // A `\r` is no rune of the Source. On its own it still ends an LSP line.
        if (i + 1 >= runes.length || runes[i + 1] != 0x0A) {
          line++;
          character = 0;
        }
        continue;
      }
      _lines.add(line);
      _characters.add(character);
      if (r == 0x0A) {
        line++;
        character = 0;
      } else {
        character += r > 0xFFFF ? 2 : 1;
      }
    }
    _lines.add(line);
    _characters.add(character);
  }

  final String path;
  final String text;
  final Source source;

  /// The position of each of [source]'s rune offsets, and of its end.
  final _lines = <int>[];
  final _characters = <int>[];

  Position position(int offset) {
    final i = offset.clamp(0, _lines.length - 1);
    return Position(_lines[i], _characters[i]);
  }

  Map<String, Object?> range(Span span) => {
    'start': position(span.start).toJson(),
    'end': position(span.end).toJson(),
  };

  /// The rune offset at [position], or the nearest one after it.
  int offset(Position position) {
    var lo = 0, hi = _lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (Position(_lines[mid], _characters[mid]).compareTo(position) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
