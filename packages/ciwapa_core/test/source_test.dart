import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

void main() {
  group('Source', () {
    test('strips carriage returns, so CRLF files read like LF files', () {
      final source = Source('crlf.i', 'DO GIVE UP\r\nPLEASE GIVE UP\r\n');
      expect(source.text, 'DO GIVE UP\nPLEASE GIVE UP\n');
      expect(source.line(1), 'PLEASE GIVE UP');
    });

    test('decodes UTF-8, so the change sign is one character', () {
      final source = Source.fromBytes('mingle.i', [
        0x23,
        0x31,
        0xC2,
        0xA2,
        0x23,
        0x32,
      ]);
      expect(source.runes, '#1¢#2'.runes.toList());
    });

    test('maps rune offsets to lines', () {
      final source = Source('lines.i', 'DO\n\nGIVE UP');
      expect(source.lineCount, 3);
      expect(source.lineOf(0), 0);
      expect(source.lineOf(3), 1);
      expect(source.lineOf(4), 2);
      expect(source.line(2), 'GIVE UP');
    });
  });

  group('the extension picks the base', () {
    test('.i and .2i are binary', () {
      expect(Source.baseOf('hello.i'), 2);
      expect(Source.baseOf('dir.with.dots/hello.2i'), 2);
    });

    test('.3i through .7i are bases 3 to 7', () {
      for (var base = 3; base <= 7; base++) {
        expect(Source.baseOf('tri.${base}i'), base);
      }
    });

    test('anything else is invalid (E998)', () {
      for (final path in [
        'hello',
        'hello.c',
        'hello.1i',
        'hello.8i',
        'hello.33i',
        'hello.I',
        'hello.i.bak',
      ]) {
        expect(Source.baseOf(path), isNull, reason: path);
      }
    });
  });
}
