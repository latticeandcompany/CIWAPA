// E774 can't be in the conformance suite, which always builds with --no-random-bug, so these
// tests build seeded programs through this flavor's real backend instead.
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';
import 'package:test/test.dart';

/// --seed 486 plants a bug on the first statement and not on the second.
const seed = '486';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('random-bug-'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<ProcessResult> buildAndRun(
    String program,
    List<String> flags, [
    List<String> args = const [],
  ]) async {
    final source = File('${temp.path}/prog.i')..writeAsStringSync(program);
    final exe = '${temp.path}/prog${Platform.isWindows ? '.exe' : ''}';
    final status = await runCli([
      'build',
      ...flags,
      source.path,
      '-o',
      exe,
    ], LlvmBackend());
    expect(status, 0);
    return Process.run(exe, args);
  }

  test(
    '§12, T23: a planted bug fires E774 when its statement is reached',
    () async {
      final result = await buildAndRun('PLEASE GIVE UP\nDO GIVE UP\n', [
        '--seed',
        seed,
      ]);
      expect(result.stderr, IclError.of(774).format(2));
      expect(result.exitCode, 774 % 256);
    },
  );

  test('T23: it fires even when the statement is abstained', () async {
    final result = await buildAndRun("DON'T GIVE UP\nDO GIVE UP\n", [
      '--seed',
      seed,
    ]);
    expect(result.stderr, IclError.of(774).format(2));
  });

  test('§10.2: --no-random-bug plants nothing', () async {
    final result = await buildAndRun('PLEASE GIVE UP\nDO GIVE UP\n', [
      '--seed',
      seed,
      '--no-random-bug',
    ]);
    expect(result.stderr, '');
    expect(result.exitCode, 0);
  });

  test('§12: the bug option does not affect E778', () async {
    final result = await buildAndRun(
      'PLEASE GIVE UP\nDO GIVE UP\n',
      ['--seed', seed],
      ['+help'],
    );
    expect(result.exitCode, 778 % 256);
    expect(result.stderr, endsWith(IclError.of(778).format(1)));
  });
}
