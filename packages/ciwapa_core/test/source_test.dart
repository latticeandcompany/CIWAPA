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

    test('a newline belongs to the line it ends; a trailing newline starts an empty line', () {
      final source = Source('trailing.i', 'DO\n');
      expect(source.lineCount, 2);
      expect(source.lineOf(2), 0);
      expect(source.lineOf(3), 1);
      expect(source.line(1), '');
    });

    test('an empty file is one empty line', () {
      final source = Source('empty.i', '');
      expect(source.lineCount, 1);
      expect(source.line(0), '');
      expect(source.lineOf(0), 0);
    });

    test(
      'offsets count runes, so characters outside the BMP are one offset each',
      () {
        final source = Source('emoji.i', '😀\nDO');
        expect(source.runes, hasLength(4));
        expect(source.lineOf(2), 1);
        expect(source.slice(0, 1), '😀');
        expect(source.slice(2, 4), 'DO');
      },
    );

    test('offsets outside the text are an error, not a guess', () {
      final source = Source('short.i', 'DO');
      expect(() => source.lineOf(-1), throwsRangeError);
      expect(() => source.lineOf(3), throwsRangeError);
    });

    test('runes cannot be modified', () {
      expect(
        () => Source('frozen.i', 'DO').runes.add(1),
        throwsUnsupportedError,
      );
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
