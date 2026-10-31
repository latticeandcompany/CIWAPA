import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  late Map<String, Object?> capabilities;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    capabilities =
        (await client.initialize())['capabilities'] as Map<String, Object?>;
  });

  /// Each lens as `line: title -> target line`.
  Future<List<String>> lenses(String uri) async => [
    for (final lens in (await client.request<List<Object?>>(
      'textDocument/codeLens',
      {
        'textDocument': {'uri': uri},
      },
    )).cast<Map<String, Object?>>())
      () {
        final line = ((lens['range'] as Map)['start'] as Map)['line'];
        final command = lens['command'] as Map;
        final [_, target as Map] = command['arguments'] as List;
        expect(command['command'], 'intercal.goTo');
        return '$line: ${command['title']} -> ${target['line']}';
      }(),
  ];

  group('R7: the COME FROM code lens', () {
    test(
      'lists every COME FROM and NEXT FROM that names a statement',
      () async {
        const text =
            '(10) PLEASE DO .1 <- #1\n'
            '(20) DO .2 <- #2\n'
            'DO COME FROM (10)\n'
            'DO GIVE UP\n'
            'PLEASE NEXT FROM (20)\n'
            'DO GIVE UP\n';
        await client.open('file:///w/a.xc', text);
        expect(await lenses('file:///w/a.xc'), [
          '0: COMES FROM: line 3 -> 2',
          '1: NEXTS FROM: line 5 -> 4',
        ]);
      },
    );

    test('several COME FROMs give several lenses, in file order', () async {
      const text =
          '(1) PLEASE DO .1 <- #1\n'
          'DO COME FROM (1)\n'
          'DO GIVE UP\n'
          'DO COME FROM (1)\n'
          'PLEASE GIVE UP\n';
      await client.open('file:///w/a.xc', text);
      expect(await lenses('file:///w/a.xc'), [
        '0: COMES FROM: line 2 -> 1',
        '0: COMES FROM: line 4 -> 3',
      ]);
    });

    test(
      'labels nothing comes from, and files with no statements, have none',
      () async {
        await client.open(
          'file:///w/a.i',
          '(1) PLEASE DO .1 <- #1\nDO (1) NEXT\nDO GIVE UP\n',
        );
        expect(await lenses('file:///w/a.i'), isEmpty);
        await client.open('file:///w/b.i', '');
        expect(await lenses('file:///w/b.i'), isEmpty);
      },
    );

    test('a WHILE\'s own COME FROMs stay out of sight', () async {
      const text =
          '(1) PLEASE DO .1 <- #1 WHILE .2 <- #2\n'
          'DO GIVE UP\n'
          'DO .3 <- #3\n';
      await client.open('file:///w/a.xc', text);
      expect(await lenses('file:///w/a.xc'), isEmpty);
    });

    for (final (kind, comeFrom) in [
      ('computed', 'DO COME FROM .1'),
      ('gerund', 'DO COME FROM CALCULATING'),
    ]) {
      test(
        'a $kind COME FROM puts the warning on the first statement',
        () async {
          final text =
              'Some prose.\n'
              '(1) PLEASE DO .1 <- #1\n'
              'DO GIVE UP\n'
              '$comeFrom\n'
              'DO COME FROM (1)\n';
          await client.open('file:///w/a.xc', text);
          expect(await lenses('file:///w/a.xc'), [
            '0: This file has computed COME FROMs. Anything could come from anywhere. -> 3',
            '1: COMES FROM: line 5 -> 4',
          ]);
        },
      );
    }

    test('clicking a lens has the server show the line', () async {
      expect(capabilities['executeCommandProvider'], {
        'commands': ['intercal.goTo'],
      });
      final shown = client.next((m) => m['method'] == 'window/showDocument');
      await client.request<Object?>('workspace/executeCommand', {
        'command': 'intercal.goTo',
        'arguments': [
          'file:///w/a.xc',
          {'line': 2, 'character': 0},
        ],
      });
      expect((await shown)['params'], {
        'uri': 'file:///w/a.xc',
        'takeFocus': true,
        'selection': {
          'start': {'line': 2, 'character': 0},
          'end': {'line': 2, 'character': 0},
        },
      });
      final unknown = await client.send('workspace/executeCommand', {
        'command': 'intercal.nothing',
      });
      expect(unknown['error'], isNotNull);
    });
  });
}
