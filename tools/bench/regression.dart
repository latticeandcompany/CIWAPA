// TEMPORARY (goal 2's cleanup removes it): the loose CI check (Q34). Compares a CI benchmark run with
// the CI baseline in tools/bench/results.json, recorded from an earlier CI run on the same kind of
// runner, so the runner's speed cancels out.
// Usage: dart run tools/bench/regression.dart <runs.jsonl> <results.json>
//        dart run tools/bench/regression.dart --record <results.json> <runs.jsonl>...
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Below this, a program is too quick for a 2x change to mean anything on a shared CI runner.
const floorUs = 5000;

List<Map<String, dynamic>> read(String path) => [
  for (final line in File(path).readAsLinesSync())
    jsonDecode(line) as Map<String, dynamic>,
];

int fastest(Map<String, dynamic> run) =>
    (run['run_us'] as List).cast<int>().reduce(min);

void main(List<String> args) {
  if (args.first == '--record') {
    final file = File(args[1]);
    final results = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final programs = <String, Map<String, Object?>>{};
    for (final path in args.skip(2)) {
      for (final run in read(path)) {
        if (run['error'] != null) continue;
        (programs[run['program'] as String] ??= {})[run['impl'] as String] = {
          'run_us': fastest(run),
          'stdout': run['stdout'],
          'exit': run['exit'],
        };
      }
    }
    results['ci'] = {'programs': programs};
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(results)}\n',
    );
    return;
  }

  final recorded =
      ((jsonDecode(File(args[1]).readAsStringSync()) as Map)['ci']
              as Map?)?['programs']
          as Map?;
  if (recorded == null) {
    stdout.writeln('no CI baseline recorded yet: nothing to compare');
    return;
  }
  var failed = false;
  for (final run in read(args[0])) {
    final program = run['program'] as String;
    final impl = run['impl'] as String;
    final before = recorded[program]?[impl] as Map?;
    if (run['error'] != null) {
      stdout.writeln('FAIL $impl $program: ${run['error']}');
      failed = true;
      continue;
    }
    if (before == null) {
      stdout.writeln('new  $impl $program: ${fastest(run)} us');
      continue;
    }
    final now = fastest(run);
    final wrong =
        run['stdout'] != before['stdout'] || run['exit'] != before['exit'];
    final slower = now > 2 * (before['run_us'] as int) && now > floorUs;
    failed |= wrong || slower;
    stdout.writeln(
      '${wrong || slower ? 'FAIL' : 'ok  '} $impl $program: $now us (recorded ${before['run_us']} us)'
      '${wrong ? ', different output or exit' : ''}',
    );
  }
  if (failed) exit(1);
}
