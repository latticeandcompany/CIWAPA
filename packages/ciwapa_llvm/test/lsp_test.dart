import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  test('R3: ciwapa-llvm lsp speaks LSP on stdin and stdout', () async {
    final client = await TestClient.start(Platform.resolvedExecutable, [
      '--suppress-analytics',
      'run',
      'bin/ciwapa_llvm.dart',
      'lsp',
    ]);
    final result = await client.initialize();
    expect(result['serverInfo'], {
      'name': 'ciwapa-llvm',
      'version': ciwapaVersion,
    });
    expect(
      codesOf(
        await client.open(
          'file:///w/a.xc',
          '(1) DO GIVE UP\n(1) PLEASE GIVE UP\n',
        ),
      ),
      ['E182', 'E182'],
    );
    await client.shutdown();
    expect(await client.exitCode, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
