// E774 can't be in the conformance suite, which always builds with --no-random-bug, so these
// tests build seeded programs through this flavor's real backend instead.
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:test/test.dart';

/// Among four statements, --seed 486 plants a bug on statement 1 only and --seed 43 on
/// statement 3 only.
const seed = '486';
const seedThird = '43';

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
    ], DartBackend());
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

  test('T23: it fires before the % roll', () async {
    final result = await buildAndRun('PLEASE %0 GIVE UP\nDO GIVE UP\n', [
      '--seed',
      seed,
    ]);
    expect(result.stderr, IclError.of(774).format(2));
  });

  test('T23: a bug on a COME FROM fires when its jump arrives, ahead of its own faults', () async {
    for (final percent in ['', '%101 ']) {
      final result = await buildAndRun(
        '(1) DO .1 <- #1\nDO GIVE UP\nPLEASE ${percent}COME FROM (1)\nDO GIVE UP\n',
        ['--seed', seedThird],
      );
      expect(result.stderr, IclError.of(774).format(4), reason: percent);
    }
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
