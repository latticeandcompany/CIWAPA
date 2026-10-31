import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

/// Its own front end, except that a file saying BOOM breaks it.
class _Fragile extends CiwapaFrontend {
  const _Fragile();

  @override
  Analysis analyzeAll(Source source, {required bool traditional}) {
    if (source.text.contains('BOOM')) throw StateError('BOOM');
    return super.analyzeAll(source, traditional: traditional);
  }
}

const duplicated = '(1) DO .1 <- #1\n(1) PLEASE DO .2 <- #2\nDO GIVE UP\n';

void main() {
  late TestClient client;
  setUp(() => client = TestClient(const CiwapaFrontend(), name: 'ciwapa-llvm'));

  group('R3: lifecycle', () {
    test('requests before initialize are refused', () async {
      final response = await client.send('textDocument/hover', {});
      expect((response['error'] as Map)['code'], -32002);
    });

    test('initialize reports the name and the compilers\' version', () async {
      final result = await client.initialize();
      expect(result['serverInfo'], {
        'name': 'ciwapa-llvm',
        'version': ciwapaVersion,
      });
      final sync = (result['capabilities'] as Map)['textDocumentSync'] as Map;
      expect(sync['change'], 1);
    });

    test('an unknown request is method-not-found', () async {
      await client.initialize();
      final response = await client.send('intercal/nonsense', {});
      expect((response['error'] as Map)['code'], -32601);
    });

    test('shutdown then exit ends with 0', () async {
      await client.initialize();
      await client.shutdown();
      expect(await client.exitCode, 0);
    });

    test('requests after shutdown are refused', () async {
      await client.initialize();
      await client.request<Object?>('shutdown');
      final response = await client.send('textDocument/hover', {});
      expect((response['error'] as Map)['code'], -32600);
    });

    test('notifications before initialize are dropped', () async {
      client.notify('textDocument/didOpen', {
        'textDocument': {
          'uri': 'file:///w/a.i',
          'languageId': 'intercal',
          'version': 1,
          'text': duplicated,
        },
      });
      await client.initialize();
      expect(client.server!.documents, isEmpty);
    });

    test('exit before initialize ends with 1', () async {
      client.notify('exit');
      expect(await client.exitCode, 1);
    });

    test(
      'a failure inside the server is answered, and the server lives on',
      () async {
        client = TestClient(const _Fragile());
        await client.initialize();
        await client.open('file:///w/fine.i', duplicated);
        client.notify('textDocument/didOpen', {
          'textDocument': {
            'uri': 'file:///w/broken.i',
            'languageId': 'intercal',
            'version': 1,
            'text': 'BOOM',
          },
        });
        expect(
          codesOf(
            await client.change('file:///w/fine.i', duplicated, version: 2),
          ),
          ['E182', 'E182'],
        );
        await client.shutdown();
        expect(await client.exitCode, 0);
      },
    );

    test('exit without shutdown ends with 1', () async {
      await client.initialize();
      client.notify('exit');
      expect(await client.exitCode, 1);
    });
  });

  group('R3: diagnostics', () {
    setUp(() => client.initialize());

    test('.i and .xc files are diagnosed, each with every error', () async {
      expect(codesOf(await client.open('file:///w/a.i', duplicated)), [
        'E182',
        'E182',
      ]);
      expect(codesOf(await client.open('file:///w/b.2xc', duplicated)), [
        'E182',
        'E182',
      ]);
    });

    test(
      'an error is placed on its token, as a range of UTF-16 positions',
      () async {
        final diagnostics = [
          for (final d in await client.open(
            'file:///w/a.i',
            'DO NOTE ¢🎉\r\n(1) DO .1 <- #1\r\n(1) PLEASE DO .2 <- #2\r\nDO GIVE UP\r\n',
          ))
            if (d['severity'] == 1) d,
        ];
        expect(diagnostics[0]['range'], {
          'start': {'line': 1, 'character': 0},
          'end': {'line': 1, 'character': 3},
        });
        expect(diagnostics[1]['range'], {
          'start': {'line': 2, 'character': 0},
          'end': {'line': 2, 'character': 3},
        });
        expect(diagnostics[0]['severity'], 1);
        expect(diagnostics[0]['source'], 'ciwapa-llvm');
        expect(
          diagnostics[0]['message'],
          'ICL182I A LINE LABEL HAS BEEN MULTIPLY DEFINED.\n'
          'TWO STATEMENTS ANSWERED TO THE SAME NAME. BOTH ARE EMBARRASSED.',
        );
      },
    );

    test(
      'a statement-local error says it waits for the statement to run',
      () async {
        final diagnostics = await client.open(
          'file:///w/a.i',
          'DO .1 <- #70000\nPLEASE GIVE UP\n',
        );
        expect(codesOf(diagnostics), ['E017']);
        expect(
          diagnostics.single['message'],
          startsWith('When this statement runs: ICL017I'),
        );
      },
    );

    test('every change is diagnosed again, with its version', () async {
      await client.open('file:///w/a.i', duplicated);
      final published = client.next(
        (m) => m['method'] == 'textDocument/publishDiagnostics',
      );
      client.notify('textDocument/didChange', {
        'textDocument': {'uri': 'file:///w/a.i', 'version': 7},
        'contentChanges': [
          {'text': 'PLEASE GIVE UP\n'},
        ],
      });
      final params = (await published)['params'] as Map;
      expect(params['version'], 7);
      expect(params['diagnostics'], isEmpty);
    });

    test('closing a document clears its diagnostics', () async {
      await client.open('file:///w/a.i', duplicated);
      final cleared = client.diagnosticsFor('file:///w/a.i');
      client.notify('textDocument/didClose', {
        'textDocument': {'uri': 'file:///w/a.i'},
      });
      expect(await cleared, isEmpty);
    });

    test('files the front end doesn\'t compile are left alone', () async {
      client.notify('textDocument/didOpen', {
        'textDocument': {
          'uri': 'file:///w/page.html',
          'languageId': 'html',
          'version': 1,
          'text': '<p>DO GIVE UP</p>',
        },
      });
      // The next diagnostics published are the .i file's: nothing came for the HTML.
      await client.open('file:///w/a.i', 'PLEASE GIVE UP\n');
      expect(
        client.notifications.where(
          (m) => (m['params'] as Map?)?['uri'] == 'file:///w/page.html',
        ),
        isEmpty,
      );
    });

    test('Windows drive-letter URIs work', () async {
      expect(
        codesOf(await client.open('file:///c%3A/Users/r/a.i', duplicated)),
        ['E182', 'E182'],
      );
    });

    test(
      'an empty file, and a file of nothing but prose, have no errors',
      () async {
        expect(await client.open('file:///w/empty.i', ''), isEmpty);
        // Prose is one undecodable statement: a hint, not an error.
        expect(
          codesOf(
            await client.open('file:///w/prose.i', 'This is not INTERCAL.\n'),
          ),
          ['E000'],
        );
      },
    );
  });

  test('R3: a long file has no E774 end to end (analysis_test guards the lowering)', () async {
    await client.initialize();
    final text = [
      for (var i = 0; i < 3000; i++)
        i % 4 == 0 ? 'PLEASE DO .1 <- #1' : 'DO .1 <- #1',
      'PLEASE GIVE UP',
    ].join('\n');
    expect(await client.open('file:///w/long.i', text), isEmpty);
  });

  group('R3: settings', () {
    const comeFrom = 'DO COME FROM (1)\n(1) PLEASE DO .1 <- #1\nDO GIVE UP\n';

    test(
      'traditional makes INTERCAL-72 of it, as --traditional does',
      () async {
        await client.initialize({'traditional': true});
        expect(codesOf(await client.open('file:///w/a.i', comeFrom)), ['E111']);
      },
    );

    test('changing the settings diagnoses every open file again', () async {
      await client.initialize();
      expect(await client.open('file:///w/a.i', comeFrom), isEmpty);
      final again = client.diagnosticsFor('file:///w/a.i');
      client.notify('workspace/didChangeConfiguration', {
        'settings': {
          'intercal': {'traditional': true},
        },
      });
      expect(codesOf(await again), ['E111']);
    });

    test(
      'clockface changes what programs print, so no diagnostic changes',
      () async {
        await client.initialize({'clockface': true});
        expect(codesOf(await client.open('file:///w/a.i', duplicated)), [
          'E182',
          'E182',
        ]);
        expect(await client.open('file:///w/b.i', comeFrom), isEmpty);
      },
    );
  });
}
