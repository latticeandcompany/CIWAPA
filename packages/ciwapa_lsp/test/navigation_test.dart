import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    await client.initialize();
  });

  Map<String, Object?> at(String uri, int line, int character) => {
    'textDocument': {'uri': uri},
    'position': {'line': line, 'character': character},
  };

  /// Each location as `uri line:character-line:character`.
  List<String> places(Object? locations) => [
    for (final l in (locations as List).cast<Map<String, Object?>>())
      () {
        final range = l['range'] as Map;
        final start = range['start'] as Map, end = range['end'] as Map;
        return '${l['uri']} ${start['line']}:${start['character']}-${end['line']}:${end['character']}';
      }(),
  ];

  group('R6: go to definition', () {
    test('works from every kind of label use', () async {
      const text =
          '(10) PLEASE DO .1 <- #1\n'
          'DO (10) NEXT\n'
          'DO ABSTAIN FROM (10)\n'
          'PLEASE REINSTATE (10)\n'
          'DO COME FROM (10)\n'
          'DO NEXT FROM (10)\n'
          'DO GIVE UP\n';
      await client.open('file:///w/a.xc', text);
      for (final (line, character) in [
        (1, 4),
        (2, 17),
        (3, 18),
        (4, 14),
        (5, 14),
      ]) {
        expect(
          places(
            await client.request(
              'textDocument/definition',
              at('file:///w/a.xc', line, character),
            ),
          ),
          ['file:///w/a.xc 0:0-0:4'],
          reason: 'line $line',
        );
      }
    });

    test('a label defined twice offers both, and a missing one nothing', () async {
      const text =
          '(1) DO .1 <- #1\n(1) PLEASE DO .2 <- #2\nDO (1) NEXT\nDO (7) NEXT\nDO GIVE UP\n';
      await client.open('file:///w/a.i', text);
      expect(
        places(
          await client.request(
            'textDocument/definition',
            at('file:///w/a.i', 2, 4),
          ),
        ),
        ['file:///w/a.i 0:0-0:3', 'file:///w/a.i 1:0-1:3'],
      );
      expect(
        await client.request(
          'textDocument/definition',
          at('file:///w/a.i', 3, 4),
        ),
        isEmpty,
      );
      // Not on a label at all.
      expect(
        await client.request(
          'textDocument/definition',
          at('file:///w/a.i', 0, 5),
        ),
        isNull,
      );
    });
  });

  group('R6: library labels open read-only library documents', () {
    test('the system library\'s, through intercal/librarySource', () async {
      await client.open('file:///w/a.i', 'PLEASE DO (1009) NEXT\nDO GIVE UP\n');
      final locations = await client.request(
        'textDocument/definition',
        at('file:///w/a.i', 0, 12),
      );
      expect(places(locations), ['ciwapa-lib:/syslib.i 10:0-10:6']);
      final source = await client.request<Map<String, Object?>>(
        'intercal/librarySource',
        {'uri': 'ciwapa-lib:/syslib.i'},
      );
      expect(source['text'], syslibSource);
      expect((source['text'] as String).split('\n')[10], startsWith('(1009)'));
    });

    test('EXTRACAL\'s, in EXTRACAL files', () async {
      await client.open(
        'file:///w/a.xc',
        'PLEASE DO (2000) NEXT\nDO GIVE UP\n',
      );
      final locations = await client.request(
        'textDocument/definition',
        at('file:///w/a.xc', 0, 12),
      );
      expect(places(locations).single, startsWith('ciwapa-lib:/io.xc '));
      final source = await client.request<Map<String, Object?>>(
        'intercal/librarySource',
        {'uri': 'ciwapa-lib:/io.xc'},
      );
      expect(source['text'], contains('(2000)'));
    });

    test('an unknown library document is an error', () async {
      final response = await client.send('intercal/librarySource', {
        'uri': 'ciwapa-lib:/nope.i',
      });
      expect((response['error'] as Map)['code'], -32602);
    });
  });

  group('R6: references and rename', () {
    const text =
        '(10) PLEASE DO .1 <- #1\n'
        'DO (10) NEXT\n'
        'DO ABSTAIN FROM (10)\n'
        'PLEASE COME FROM (10)\n'
        'DO (20) NEXT\n'
        'DO GIVE UP\n';

    test('references find every literal use', () async {
      await client.open('file:///w/a.xc', text);
      final all = await client.request('textDocument/references', {
        ...at('file:///w/a.xc', 1, 4),
        'context': {'includeDeclaration': true},
      });
      expect(places(all), [
        'file:///w/a.xc 0:0-0:4',
        'file:///w/a.xc 1:3-1:7',
        'file:///w/a.xc 2:16-2:20',
        'file:///w/a.xc 3:17-3:21',
      ]);
      final uses = await client.request('textDocument/references', {
        ...at('file:///w/a.xc', 0, 1),
        'context': {'includeDeclaration': false},
      });
      expect(places(uses), hasLength(3));
    });

    test('rename changes every literal use', () async {
      await client.open('file:///w/a.xc', text);
      final prepared = await client.request<Map<String, Object?>>(
        'textDocument/prepareRename',
        at('file:///w/a.xc', 2, 17),
      );
      expect(prepared['placeholder'], '10');
      final edit = await client.request<Map<String, Object?>>(
        'textDocument/rename',
        {...at('file:///w/a.xc', 2, 17), 'newName': '30'},
      );
      final edits = ((edit['changes'] as Map)['file:///w/a.xc'] as List)
          .cast<Map<String, Object?>>();
      expect(
        [for (final e in edits) e['newText']],
        ['(30)', '(30)', '(30)', '(30)'],
      );
      expect(
        client.notifications.where((m) => m['method'] == 'window/showMessage'),
        isEmpty,
      );
    });

    test(
      'rename refuses labels that aren\'t labels, and ones that are taken',
      () async {
        await client.open(
          'file:///w/a.xc',
          '(10) PLEASE DO .1 <- #1\n(20) DO (10) NEXT\nDO GIVE UP\n',
        );
        for (final name in ['0', '65536', 'ten']) {
          final response = await client.send('textDocument/rename', {
            ...at('file:///w/a.xc', 1, 9),
            'newName': name,
          });
          expect(
            (response['error'] as Map)['message'],
            contains('1 to 65535'),
            reason: name,
          );
        }
        final taken = await client.send('textDocument/rename', {
          ...at('file:///w/a.xc', 1, 9),
          'newName': '(20)',
        });
        expect((taken['error'] as Map)['message'], contains('E182'));
      },
    );

    test('a library\'s label isn\'t the file\'s to rename', () async {
      await client.open('file:///w/a.i', 'PLEASE DO (1000) NEXT\nDO GIVE UP\n');
      final response = await client.send(
        'textDocument/prepareRename',
        at('file:///w/a.i', 0, 12),
      );
      expect(
        (response['error'] as Map)['message'],
        contains('belongs to the library'),
      );
    });

    for (final (kind, statement) in [
      ('a computed COME FROM', 'DO COME FROM .1'),
      ('a gerund COME FROM', 'DO COME FROM NEXTING'),
      ('a computed ABSTAIN', 'DO ABSTAIN #1 FROM (10)'),
    ]) {
      test('renaming in a file with $kind warns about it', () async {
        await client.open(
          'file:///w/a.xc',
          '(10) PLEASE DO .1 <- #1\nDO (10) NEXT\n$statement\nDO GIVE UP\n',
        );
        final warned = client.next((m) => m['method'] == 'window/showMessage');
        final edit = await client.request<Map<String, Object?>>(
          'textDocument/rename',
          {...at('file:///w/a.xc', 1, 4), 'newName': '11'},
        );
        expect((edit['changes'] as Map)['file:///w/a.xc'], isNotEmpty);
        final params = (await warned)['params'] as Map;
        expect(params['type'], 2);
        expect(params['message'], contains('might still mean 10'));
      });
    }
  });
}
