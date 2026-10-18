// TEMPORARY (goal 2's cleanup removes it): records goal 1's Mode 1 timings, or judges a new run
// against them (Q111). Each program's fastest run is compared. Noise on a laptop's Docker VM is a
// few percent, so "no regression" means: per flavor, the geometric mean of the ratios is at most
// 1.05, and no program is more than 1.15× slower unless it lost less than a millisecond.
// Usage: dart run tools/bench/no_regression.dart --record <runs.jsonl> <baseline.json>
//        dart run tools/bench/no_regression.dart --compare <runs.jsonl> <baseline.json> <verdict.json>
//            <commit> <dirty: true|false>
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const flavors = ['ciwapa-llvm', 'ciwapa-dart'];
const meanLimit = 1.05, programLimit = 1.15, slackUs = 1000;

Map<String, Map<String, int>> fastest(String path) {
  final timings = <String, Map<String, int>>{};
  for (final line in File(path).readAsLinesSync()) {
    final run = jsonDecode(line) as Map<String, dynamic>;
    if (run['error'] != null) {
      stderr.writeln('${run['impl']} ${run['program']}: ${run['error']}');
      exit(1);
    }
    (timings[run['impl'] as String] ??= {})[run['program'] as String] =
        (run['run_us'] as List).cast<int>().reduce(min);
  }
  return timings;
}

void main(List<String> args) {
  final runs = fastest(args[1]);
  const encoder = JsonEncoder.withIndent('  ');
  if (args[0] == '--record') {
    File(args[2]).writeAsStringSync(
      '${encoder.convert({'measured': DateTime.now().toUtc().toIso8601String(), 'run_us': runs})}\n',
    );
    return;
  }
  final baseline =
      (jsonDecode(File(args[2]).readAsStringSync()) as Map)['run_us'] as Map;
  var met = true;
  final summary = <String>[];
  for (final flavor in flavors) {
    final before = (baseline[flavor] as Map).cast<String, int>();
    final now = runs[flavor] ?? const {};
    var logSum = 0.0;
    for (final MapEntry(key: program, value: old) in before.entries) {
      final current = now[program];
      if (current == null) {
        met = false;
        summary.add('$flavor $program: not measured');
        continue;
      }
      final ratio = current / old;
      logSum += log(ratio);
      final slower = ratio > programLimit && current - old > slackUs;
      met &= !slower;
      summary.add(
        '${slower ? 'SLOWER' : 'ok    '} $flavor $program: $current us (goal 1: $old us, ${ratio.toStringAsFixed(2)}x)',
      );
    }
    final mean = exp(logSum / before.length);
    met &= mean <= meanLimit;
    summary.add(
      '${mean <= meanLimit ? 'ok    ' : 'SLOWER'} $flavor geometric mean: ${mean.toStringAsFixed(3)}x (limit $meanLimit)',
    );
  }
  File(args[3]).writeAsStringSync(
    '${encoder.convert({'met': met, 'sha': args[4], 'dirty': args[5] == 'true', 'summary': summary})}\n',
  );
  summary.forEach(print);
  if (!met) exit(1);
}
