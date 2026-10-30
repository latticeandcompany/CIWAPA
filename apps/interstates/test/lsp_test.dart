import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:interstates/interstates.dart';
import 'package:test/test.dart';

const database =
    'DO COME FROM (16000)\nPLEASE DO .1 <- #1\n'
    'DO INTO DATABASE #1~#2\$#3 <- ,1\nDO GIVE UP\n';

void main() {
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
        // As plain EXTRACAL, INTO DATABASE is no statement, so the COME FROM has nowhere to come from.
        expect(codesOf(await client.open('file:///w/site.xc', database)), [
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
