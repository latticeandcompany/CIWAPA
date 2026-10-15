import 'dart:io';

import 'package:test/test.dart';

import '../tool/embed_runtime.dart';

/// Compiles test/runtime_test.c, which includes runtime.c, with the clang on the PATH.
void main() {
  late List<String> lines;

  setUpAll(() async {
    final temp = Directory.systemTemp.createTempSync('runtime-c-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final exe = '${temp.path}/runtime_test${Platform.isWindows ? '.exe' : ''}';
    final build = await Process.run('clang', [
      '-O2',
      '-w',
      'test/runtime_test.c',
      '-o',
      exe,
    ]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final run = await Process.run(exe, const []);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    lines = (run.stdout as String).replaceAll('\r', '').trimRight().split('\n');
  });

  test(
    '§3.4.1 mingle goldens',
    () => expect(lines[0], '2863311530 1431655765 65535 65536'),
  );
  test('§3.4.1 select goldens', () => expect(lines[1], '9 17 31 15'));
  test('§3.4.2 unary goldens', () => expect(lines[2], '4 32879 32875'));
  test(
    '32-bit unary operators rotate through bit 31',
    () => expect(lines[3], '2147483649 3221225472 4294967295'),
  );
  test('§3.4.3 grouping goldens', () => expect(lines[4], '15 34915'));

  test(
    '§5.2, T31: after the end of input, the next character reads as itself + 1',
    () {
      expect(lines[5], '65 256 67');
    },
  );

  test('§5.2, T31: Turing Text output is flushed at a newline', () {
    expect(lines[6], 'A');
    expect(lines[7], 'flushes 1');
  });

  test('T22: by default the % rolls are seeded from the clock, like +seed', () {
    final [clock, seed] = lines[8].split(' ');
    expect(clock, seed);
    expect(clock, contains('1'));
    expect(clock, contains('0'));
  });

  test('the embedded copy matches runtime.c', () {
    expect(
      File('lib/src/runtime_c.g.dart').readAsStringSync(),
      embed(File('runtime.c').readAsStringSync()),
      reason: 'run `dart run tool/embed_runtime.dart`',
    );
  });
}
