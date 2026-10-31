import 'package:ciwapa_lsp/ciwapa_lsp.dart';
import 'package:test/test.dart';

void main() {
  group('positions are UTF-16 on the text the editor holds', () {
    test('LF', () {
      final t = EditorText('a.i', 'DO\nPLEASE');
      expect(t.position(3), const Position(1, 0));
      expect(t.position(9), const Position(1, 6));
    });

    test('CRLF and a lone CR, which the Source strips', () {
      final t = EditorText('a.i', 'DO\r\nPLEASE\rX\nGIVE');
      expect(t.source.text, 'DO\nPLEASEX\nGIVE');
      expect(t.position(2), const Position(0, 2));
      expect(t.position(3), const Position(1, 0));
      // The lone CR ends an LSP line, though it's no line break to the compiler.
      expect(t.position(9), const Position(2, 0));
      expect(t.position(11), const Position(3, 0));
    });

    test('characters outside the BMP take two units, others one', () {
      final t = EditorText('a.i', '¢🎉¥ DO');
      expect(t.position(1), const Position(0, 1));
      expect(t.position(2), const Position(0, 3));
      expect(t.position(3), const Position(0, 4));
      expect(t.position(5), const Position(0, 6));
    });

    test('offset is position backwards', () {
      final t = EditorText('a.i', 'DO\r\n¢🎉\r\nX');
      for (var i = 0; i <= t.source.runes.length; i++) {
        expect(t.offset(t.position(i)), i);
      }
      // Past the end of a line is the end of that line, not the next one.
      expect(t.offset(const Position(0, 3)), 2);
      expect(t.offset(const Position(99, 0)), t.source.runes.length);
    });
  });
}
