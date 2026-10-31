import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:interstates/interstates.dart';
import 'package:interstates/src/errors.dart';
import 'package:test/test.dart';

import '../tool/embed_docs.dart' as embed;

const database =
    'DO COME FROM (16000)\nPLEASE DO .1 <- #1\n'
    'DO INTO DATABASE #1~#2\$#3 <- ,1\nDO GIVE UP\n';

void main() {
  group('editing', editingTests);

  for (final flavor in ['llvm', 'dart']) {
    test('R3: ioi-$flavor lsp speaks LSP on stdin and stdout', () async {
      final client = await TestClient.start(Platform.resolvedExecutable, [
        '--suppress-analytics',
        'run',
        'bin/ioi_$flavor.dart',
        'lsp',
      ]);
      final result = await client.initialize();
      expect(result['serverInfo'], {
        'name': 'ioi-$flavor',
        'version': ciwapaVersion,
      });
      expect(codesOf(await client.open('file:///w/site.ioi', database)), [
        'E827',
      ]);
      await client.shutdown();
      expect(await client.exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  group(
    'R3: ioi-* lsp diagnoses each file as the CLI that builds it would',
    () {
      late TestClient client;
      setUp(() async {
        client = TestClient(InterstatesFrontend(), name: 'ioi-llvm');
        await client.initialize();
      });

      test('.ioi with Interstates\' front end', () async {
        expect(codesOf(await client.open('file:///w/site.ioi', database)), [
          'E827',
        ]);
        expect(codesOf(await client.open('file:///w/p.3ioi', 'DO GIVE UP\n')), [
          'E998',
        ]);
      });

      test('.i and .xc with CIWAPA\'s', () async {
        // As plain EXTRACAL, INTO DATABASE is undecodable (a hint), and the COME FROM has nowhere
        // to come from.
        expect(codesOf(await client.open('file:///w/site.xc', database)), [
          'E000',
          'E444',
        ]);
        expect(
          codesOf(
            await client.open(
              'file:///w/p.i',
              '(1) DO GIVE UP\n(1) PLEASE GIVE UP\n',
            ),
          ),
          ['E182', 'E182'],
        );
      });

      test('traditional is E111 for a .ioi, as --traditional is', () async {
        final traditional = TestClient(InterstatesFrontend(), name: 'ioi-llvm');
        await traditional.initialize({'traditional': true});
        expect(
          codesOf(
            await traditional.open(
              'file:///w/site.ioi',
              'DO COME FROM (16000)\nPLEASE GIVE UP\n',
            ),
          ),
          ['E111'],
        );
      });
    },
  );

  test('R3: ciwapa-* lsp leaves .ioi files alone', () async {
    final client = TestClient(const CiwapaFrontend(), name: 'ciwapa-llvm');
    await client.initialize();
    client.notify('textDocument/didOpen', {
      'textDocument': {
        'uri': 'file:///w/site.ioi',
        'languageId': 'intercal',
        'version': 1,
        'text': database,
      },
    });
    await client.open('file:///w/a.i', 'PLEASE GIVE UP\n');
    expect(
      client.notifications.where(
        (m) => (m['params'] as Map?)?['uri'] == 'file:///w/site.ioi',
      ),
      isEmpty,
    );
  });
}

void editingTests() {
  late TestClient client;
  late Map<String, Object?> legend;
  setUp(() async {
    client = TestClient(
      InterstatesFrontend(),
      name: 'ioi-llvm',
      extension: const InterstatesEditing(),
    );
    final init = await client.initialize();
    legend =
        ((init['capabilities'] as Map)['semanticTokensProvider']
                as Map)['legend']
            as Map<String, Object?>;
  });

  Future<String?> hoverAt(String uri, int line, int character) async {
    final result = await client.request<Map<String, Object?>?>(
      'textDocument/hover',
      {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character},
      },
    );
    return (result?['contents'] as Map?)?['value'] as String?;
  }

  test('R4: every Interstates error has a description and a fix', () {
    expect(interstatesErrorHelp.keys.toSet(), {
      for (final e in interstatesErrors) e.code,
    });
  });

  test('R4: the embedded library tables match the README', () {
    expect(
      embed.generate(),
      File('lib/src/library_docs.g.dart').readAsStringSync(),
      reason: 'run dart run tool/embed_docs.dart',
    );
  });

  test('R4: Interstates\' errors hover with their own help', () async {
    await client.open('file:///w/site.ioi', database);
    expect(
      await hoverAt('file:///w/site.ioi', 2, 5),
      allOf(
        startsWith(
          '```text\nICL827I AN INTO DATABASE HAS THE WRONG NUMBER OF VALUES.',
        ),
        contains('**What to do:** Give one value for each column.'),
      ),
    );
  });

  test(
    'R4: Interstates\' library labels and the entry label have hovers',
    () async {
      await client.open(
        'file:///w/site.ioi',
        'DO COME FROM (16000)\nPLEASE DO (16010) NEXT\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/site.ioi', 1, 12),
        allOf(
          startsWith('**(16010)**, in the Interstates library'),
          contains('- **Out:** ,1 = the query string'),
        ),
      );
      expect(
        await hoverAt('file:///w/site.ioi', 0, 15),
        startsWith('**(16000)**: where every request comes in.'),
      );
      // In a .xc, neither the library nor the entry label exists.
      await client.open(
        'file:///w/p.xc',
        'PLEASE DO (16010) NEXT\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/p.xc', 0, 12),
        contains('no statement has this label'),
      );
    },
  );

  test(
    'R6: (16000) goes to the routes, and library labels to the library',
    () async {
      const text =
          'DO COME FROM (16000) WITH ROUTE "/a"\n'
          'PLEASE DO (16010) NEXT\n'
          'DO COME FROM (16000) WITH ROUTE "/b"\n'
          'DO GIVE UP\n';
      await client.open('file:///w/site.ioi', text);
      Future<List<Map<String, Object?>>> definitions(
        int line,
        int character,
      ) async =>
          (await client.request<List<Object?>>('textDocument/definition', {
            'textDocument': {'uri': 'file:///w/site.ioi'},
            'position': {'line': line, 'character': character},
          })).cast<Map<String, Object?>>();
      final routes = await definitions(0, 15);
      expect(
        [for (final r in routes) ((r['range'] as Map)['start'] as Map)['line']],
        [0, 2],
      );
      final library = (await definitions(1, 12)).single;
      expect(library['uri'], 'ciwapa-lib:/interstates.xc');
      final source = await client.request<Map<String, Object?>>(
        'intercal/librarySource',
        {'uri': library['uri']},
      );
      final line = ((library['range'] as Map)['start'] as Map)['line'] as int;
      expect((source['text'] as String).split('\n')[line], contains('(16010)'));
    },
  );

  test('R6: (16000) isn\'t the file\'s to rename', () async {
    await client.open(
      'file:///w/site.ioi',
      'DO COME FROM (16000) WITH ROUTE "/a"\nDO GIVE UP\n',
    );
    final response = await client.send('textDocument/prepareRename', {
      'textDocument': {'uri': 'file:///w/site.ioi'},
      'position': {'line': 0, 'character': 15},
    });
    expect(
      (response['error'] as Map)['message'],
      contains('means something to the compiler'),
    );
  });

  test(
    'R6: an Interstates library document opens before anything asks for it',
    () async {
      final source = await client.request<Map<String, Object?>>(
        'intercal/librarySource',
        {'uri': 'ciwapa-lib:/interstates.xc'},
      );
      expect(source['text'], contains('(16010)'));
    },
  );

  test('R5: Interstates\' words and strings are highlighted', () async {
    const text =
        'Prose comes first.\n'
        'DO COME FROM (16000) WITH ROUTE "/hello"\n'
        'PLEASE READ OUT #0 WITH TEMPLATE "hello.html"\n'
        'GIVE UP\n';
    await client.open('file:///w/site.ioi', text);
    final tokens = decodeTokens(
      await client.request<Map<String, Object?>>(
        'textDocument/semanticTokens/full',
        {
          'textDocument': {'uri': 'file:///w/site.ioi'},
        },
      ),
      legend,
    );
    final colored = coloredText(text, tokens);
    expect(
      colored,
      containsAllInOrder([
        ('Prose comes first.', 'comment'),
        ('COME FROM', 'keyword'),
        ('(16000)', 'function'),
        ('WITH ROUTE', 'keyword'),
        ('"/hello"', 'string'),
        ('WITH TEMPLATE', 'keyword'),
        ('"hello.html"', 'string'),
        ('GIVE UP', 'keyword'),
      ]),
    );
    expect(tokens[colored.indexOf(('WITH ROUTE', 'keyword'))].modifiers, {
      'dialect',
    });
  });
}
