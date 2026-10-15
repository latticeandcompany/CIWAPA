// TEMPORARY (goal 2's cleanup removes it): compares a CI benchmark run with tools/bench/results.json.
// Usage: dart run tools/bench/regression.dart <runs.jsonl> <results.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Below this, a program is too quick for a 2x change to mean anything on a shared CI runner.
const floorUs = 5000;

void main(List<String> args) {
  final recorded =
      (jsonDecode(File(args[1]).readAsStringSync()) as Map)['programs'] as Map;
  var failed = false;
  for (final line in File(args[0]).readAsLinesSync()) {
    final run = jsonDecode(line) as Map<String, dynamic>;
    final program = run['program'] as String;
    final impl = run['impl'] as String;
    if (run['error'] != null) {
      stdout.writeln('FAIL $impl $program: ${run['error']}');
      failed = true;
      continue;
    }
    final fastest = (run['run_us'] as List).cast<int>().reduce(min);
    final now = max(fastest - (run['spawn_us'] as int), 1);
    final before = recorded[program]?[impl]?['run_us'] as int?;
    if (before == null) {
      stdout.writeln('new  $impl $program: $now us');
      continue;
    }
    final slower = now > 2 * before && now > floorUs;
    failed |= slower;
    stdout.writeln(
      '${slower ? 'FAIL' : 'ok  '} $impl $program: $now us (recorded $before us)',
    );
  }
  if (failed) exit(1);
}
