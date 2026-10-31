// Punchline 7: the site's hello world (INTERSTATES_PLAN.md, Appendix A) compiles with both
// ioi-* and serves its page through gross, exactly as written.
import 'dart:io';

import 'package:interstates/interstates.dart';
import 'package:interstates/src/gross.dart';
import 'package:test/test.dart';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'support.dart';

/// Example A, from the first fenced block of the plan's Appendix A.
final appendixA = RegExp(r'## Appendix A[\s\S]*?```\n([\s\S]*?)```')
    .firstMatch(File('../../docs/INTERSTATES_PLAN.md').readAsStringSync())![1]!;

void main() {
  test('the golden source is Appendix A, byte for byte', () {
    expect(appendixA, startsWith('NOTE At the start of the program'));
    expect(File('test/golden/hello/hello.ioi').readAsStringSync(), appendixA);
  });

  for (final backend in [ioiDart(), ioiLlvm()]) {
    test(
      '${backend.name} builds it, and gross serves it on any path',
      () async {
        final temp = Directory.systemTemp.createTempSync('ioi-hello-');
        addTearDown(() => deleteSoon(temp));
        File('test/golden/hello/hello.html')
            .copySync('${temp.path}/hello.html');
        final source = File('${temp.path}/hello.ioi')
          ..writeAsStringSync(appendixA);
        final exe = '${temp.path}/hello${Platform.isWindows ? '.exe' : ''}';
        final status = await runCli(
          ['build', '--no-random-bug', source.path, '-o', exe],
          backend,
          frontend: InterstatesFrontend(),
        );
        expect(status, 0);
        final gross = await Gross.start(
          GrossConfig(program: exe, port: 0),
          log: (_) {},
        );
        addTearDown(gross.close);
        for (final path in ['/', '/anything/at/all']) {
          final client = HttpClient();
          final response = await (await client.get(
            '127.0.0.1',
            gross.port,
            path,
          )).close();
          expect(response.statusCode, 200);
          expect(
            await response.transform(const SystemEncoding().decoder).join(),
            File('test/golden/hello/hello.html').readAsStringSync(),
          );
          client.close();
        }
      },
    );
  }
}
