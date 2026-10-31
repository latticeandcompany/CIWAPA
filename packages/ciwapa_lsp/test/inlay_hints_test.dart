import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;

  Future<List<String>> hints(String uri, String text, {Object? range}) async {
    await client.open(uri, text);
    final all = await client.request<List<Object?>>('textDocument/inlayHint', {
      'textDocument': {'uri': uri},
      'range':
          range ??
          {
            'start': {'line': 0, 'character': 0},
            'end': {'line': 999, 'character': 0},
          },
    });
    return [
      for (final h in all.cast<Map<String, Object?>>())
        '${(h['position'] as Map)['line']}:${(h['position'] as Map)['character']} ${h['label']}',
    ];
  }

  group('R8: inlay hints', () {
    setUp(() async {
      client = TestClient(const CiwapaFrontend());
      await client.initialize();
    });

    test('statement ordinals, as runtime errors count them', () async {
      final shown = await hints(
        'file:///w/a.i',
        '(1) DO .1 <- #1\n    PLEASE GIVE UP\nDO .2 <- #2\n',
      );
      expect(shown, containsAll(['0:0 1:', '1:4 2:', '2:0 3:']));
    });

    test('constants in hex and binary, but not 0 and 1', () async {
      final shown = await hints(
        'file:///w/a.i',
        'DO .1 <- #42\nPLEASE .2 <- #1\nDO GIVE UP\n',
      );
      expect(shown, contains('0:12 0x2A 0b101010'));
      expect(shown.where((h) => h.startsWith('1:')), ['1:0 2:']);
    });

    test('the value of a mingle or select of constants', () async {
      final shown = await hints(
        'file:///w/a.i',
        "DO :1 <- #1\$#1\nPLEASE .2 <- '#179~#201'\$.3\nDO .4 <- .5~#3\nDO GIVE UP\n",
      );
      expect(shown, contains('0:14 = 3'));
      expect(shown, contains("1:24 = 9"));
      expect(
        shown.where((h) => h.contains('=') && h.startsWith('2:')),
        isEmpty,
      );
    });

    test('no folding outside base 2, where mingle and select differ', () async {
      final shown = await hints(
        'file:///w/a.3i',
        'DO :1 <- #1\$#1\nPLEASE GIVE UP\nDO GIVE UP\n',
      );
      expect(shown.where((h) => h.contains('=')), isEmpty);
    });

    test('only hints inside the range', () async {
      final shown = await hints(
        'file:///w/a.i',
        'DO .1 <- #42\nPLEASE GIVE UP\nDO .2 <- #43\n',
        range: {
          'start': {'line': 2, 'character': 0},
          'end': {'line': 2, 'character': 12},
        },
      );
      expect(shown.where((h) => !h.contains('PLEASE')), [
        '2:0 3:',
        '2:12 0x2B 0b101011',
      ]);
    });
  });

  group('R8: politeness', () {
    const text = 'PLEASE DO .1 <- #1\nDO .2 <- #2\nDO .3 <- #3\nDO GIVE UP\n';

    test(
      'intercal/politeness carries the ratio, and an inlay hint shows it',
      () async {
        client = TestClient(const CiwapaFrontend());
        await client.initialize();
        final notified = client.next(
          (m) => m['method'] == 'intercal/politeness',
        );
        final shown = await hints('file:///w/a.i', text);
        expect((await notified)['params'], {
          'uri': 'file:///w/a.i',
          'polite': 1,
          'total': 4,
          'text': 'PLEASE 1/4, 25%',
        });
        expect(shown, contains('0:18 PLEASE 1/4, 25%'));
      },
    );

    test('an editor with a status bar gets no hint for it', () async {
      client = TestClient(const CiwapaFrontend());
      await client.initialize({'politenessInStatusBar': true});
      final shown = await hints('file:///w/a.i', text);
      expect(shown.where((h) => h.contains('PLEASE')), isEmpty);
    });
  });
}
