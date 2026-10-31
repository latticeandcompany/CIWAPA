import 'dart:io';

import 'package:ciwapa_lsp/test_client.dart';
import 'package:interstates/interstates.dart';
import 'package:test/test.dart';

const site =
    'PLEASE COME FROM (16000) WITH ROUTE "/:name"\n'
    'DO ;49221 SUB #1 <- ;4400 SUB #1\n'
    '(5) PLEASE READ OUT #2 WITH TEMPLATE "page.html"\n'
    'DO GIVE UP\n'
    'DO COME FROM (5) WITH ROUTE "/secret"\n'
    'DO GIVE UP\n';

const broken = '<p>{{,144}}</p>\n<{{,144}}>\n';
const fixed = '<p>{{,144}} {{,143}}</p>\n<a href="/secret">x</a>\n';

void main() {
  late Directory dir;
  late TestClient client;
  late String siteUri, pageUri;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('templates_lsp');
    File('${dir.path}/site.ioi').writeAsStringSync(site);
    File('${dir.path}/page.html').writeAsStringSync(broken);
    siteUri = Uri.file('${dir.path}/site.ioi').toString();
    pageUri = Uri.file('${dir.path}/page.html').toString();
    client = TestClient(
      InterstatesFrontend(),
      name: 'ioi-llvm',
      extension: const InterstatesEditing(),
    );
    await client.initialize();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// The next diagnostics published for [uri].
  Future<List<Map<String, Object?>>> nextDiagnostics(String uri) async {
    final message = await client.next(
      (m) =>
          m['method'] == 'textDocument/publishDiagnostics' &&
          (m['params'] as Map)['uri'] == uri,
    );
    return (((message['params'] as Map)['diagnostics']) as List)
        .cast<Map<String, Object?>>();
  }

  /// Opens the site and returns what the server says about its template.
  Future<List<Map<String, Object?>>> openSite() async {
    final page = nextDiagnostics(pageUri);
    await client.open(siteUri, site);
    return page;
  }

  List<String> placed(List<Map<String, Object?>> diagnostics) => [
    for (final d in diagnostics)
      () {
        final start = (d['range'] as Map)['start'] as Map;
        final end = (d['range'] as Map)['end'] as Map;
        return '${d['code']} ${start['line']}:${start['character']}-${end['line']}:${end['character']}';
      }(),
  ];

  group('R10: templates', () {
    test('a named template gets E820, E821 and E443 in the template', () async {
      final diagnostics = await openSite();
      expect(placed(diagnostics), [
        'E820 1:1-1:9',
        'E821 0:3-0:11',
        'E443 0:0-0:15',
      ]);
      expect(
        diagnostics.last['message'],
        contains(
          'Nothing here links to "/secret", which line 5 restricts to this page.',
        ),
      );
      expect(diagnostics.first['message'], contains('line 3 of site.ioi'));
    });

    test(
      'the editor\'s text wins over the disk\'s, and fixing it clears them',
      () async {
        await openSite();
        final page = nextDiagnostics(pageUri);
        client.openQuietly(pageUri, fixed, languageId: 'html');
        expect(await page, isEmpty);
        final again = nextDiagnostics(pageUri);
        await client.change(pageUri, broken, version: 2);
        expect(placed(await again), hasLength(3));
      },
    );

    test('a grumpy hover says which ;49221 SUB #k it is', () async {
      await client.open(siteUri, site);
      client.openQuietly(pageUri, fixed, languageId: 'html');
      final hover = await client.request<Map<String, Object?>?>(
        'textDocument/hover',
        {
          'textDocument': {'uri': pageUri},
          'position': {'line': 0, 'character': 15},
        },
      );
      expect(
        (hover!['contents'] as Map)['value'],
        '`,143` is `;49221 SUB #2`: argument 2 of the READ OUT #2 WITH TEMPLATE on line 3 of site.ioi.',
      );
    });

    test(
      'go to definition from WITH TEMPLATE "path" opens the template',
      () async {
        await client.open(siteUri, site);
        final locations = await client.request<List<Object?>>(
          'textDocument/definition',
          {
            'textDocument': {'uri': siteUri},
            'position': {'line': 2, 'character': 40},
          },
        );
        expect((locations.single as Map)['uri'], pageUri);
      },
    );

    test(
      'two programs that disagree about a template each have their say',
      () async {
        File('${dir.path}/page.html').writeAsStringSync(fixed);
        await openSite();
        final other = Uri.file('${dir.path}/other.ioi').toString();
        final page = nextDiagnostics(pageUri);
        await client.open(
          other,
          'DO COME FROM (16000)\nPLEASE READ OUT #1 WITH TEMPLATE "page.html"\nDO GIVE UP\n',
        );
        final diagnostics = await page;
        expect(placed(diagnostics), ['E821 0:12-0:20']);
        expect(diagnostics.single['message'], contains('line 2 of other.ioi'));
      },
    );

    test('HTML no open program names is left alone', () async {
      final other = Uri.file('${dir.path}/other.html').toString();
      await client.open(siteUri, site);
      client.openQuietly(other, broken, languageId: 'html');
      expect(
        client.notifications.where(
          (m) => (m['params'] as Map?)?['uri'] == other,
        ),
        isEmpty,
      );
      expect(
        await client.request<Object?>('textDocument/hover', {
          'textDocument': {'uri': other},
          'position': {'line': 0, 'character': 5},
        }),
        isNull,
      );
    });

    test('closing the program takes its word on the template away', () async {
      await openSite();
      final page = nextDiagnostics(pageUri);
      client.notify('textDocument/didClose', {
        'textDocument': {'uri': siteUri},
      });
      expect(await page, isEmpty);
    });
  });

  test('R8: in .ioi files, inlay hints name template arguments', () async {
    await client.open(siteUri, site);
    final hints = await client.request<List<Object?>>(
      'textDocument/inlayHint',
      {
        'textDocument': {'uri': siteUri},
        'range': {
          'start': {'line': 0, 'character': 0},
          'end': {'line': 9, 'character': 0},
        },
      },
    );
    final labels = [
      for (final h in hints.cast<Map<String, Object?>>())
        if ((h['label'] as String).startsWith(','))
          '${(h['position'] as Map)['line']}:${(h['position'] as Map)['character']} ${h['label']}',
    ];
    expect(labels, ['1:16 ,144', '2:48 ,144 to ,143']);
  });
}
