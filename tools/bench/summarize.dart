// TEMPORARY (goal 2's cleanup removes it): turns tools/bench/bench's measurements into the Q32/Q33
// guardrails and writes them, with the fastest runs they come from, to tools/bench/results.json.
// Usage: dart run tools/bench/summarize.dart <measurements dir> <results.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const baselines = ['ick', 'rick', 'intercal64', 'clc'];
const flavors = ['ciwapa-llvm', 'ciwapa-dart'];

class Program {
  Program(this.name, this.implementations, this.blockedBy);

  final String name;
  final String implementations;
  final String blockedBy;

  bool runsOn(String impl) =>
      implementations == 'all' || implementations.split(',').contains(impl);
}

class Guardrail {
  Guardrail(this.name, this.ratio, this.target, {this.blockedBy = ''});

  final String name;
  final double? ratio;
  final double target;
  final String blockedBy;

  bool get met => blockedBy.isEmpty && ratio != null && ratio! >= target;

  Map<String, Object?> toJson() => {
    'name': name,
    'ratio': ratio == null ? null : double.parse(ratio!.toStringAsFixed(2)),
    'target': target,
    'met': met,
    if (blockedBy.isNotEmpty) 'blocked': blockedBy,
  };
}

double geometricMean(Iterable<double> values) =>
    exp(values.map(log).reduce((a, b) => a + b) / values.length);

void main(List<String> args) {
  final dir = args[0];
  final programs = [
    for (final line in File('tools/bench/programs.txt').readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        (line.split('|').map((f) => f.trim()).toList()),
  ].map((f) => Program(f[0], f[3], f[4])).toList();

  final runs = <String, Map<String, Map<String, dynamic>>>{};
  for (final line in File('$dir/runs.jsonl').readAsLinesSync()) {
    final run = jsonDecode(line) as Map<String, dynamic>;
    final byImpl = runs[run['program'] as String] ??= {};
    final impl = run['impl'] as String;
    byImpl[impl] = {
      ...?byImpl[impl],
      for (final MapEntry(:key, :value) in run.entries) key: ?value,
    };
  }

  // A run counts only when it printed what ciwapa-llvm printed and exited the same way.
  final notes = <String>{};
  int? runUs(String program, String impl) {
    final run = runs[program]?[impl];
    final reference = runs[program]?['ciwapa-llvm'];
    if (run == null || reference == null || run['error'] != null) {
      if (run?['error'] != null) notes.add('$impl $program: ${run!['error']}');
      return null;
    }
    if (run['stdout'] != reference['stdout'] ||
        run['exit'] != reference['exit']) {
      notes.add('$impl $program: output differs from ciwapa-llvm');
      return null;
    }
    final spawn = run['spawn_us'] as int;
    return max((run['run_us'] as List).cast<int>().reduce(min) - spawn, 1);
  }

  int? buildMs(String program, String impl) =>
      runs[program]?[impl]?['build_ms'] as int?;

  final guardrails = <Guardrail>[];
  final measured = programs.where((p) => p.blockedBy.isEmpty).toList();
  final blocked = programs.where((p) => p.blockedBy.isNotEmpty).toList();
  final blockers = {for (final p in blocked) p.blockedBy}.join(', ');

  double? speedup(int? slower, int? faster) =>
      slower == null || faster == null ? null : max(slower, 1) / max(faster, 1);

  // Q32, LLVM: never slower than any baseline on any program.
  for (final p in programs) {
    final llvm = runUs(p.name, 'ciwapa-llvm');
    final ratios = [
      for (final b in baselines)
        if (p.runsOn(b)) speedup(runUs(p.name, b), llvm),
    ].whereType<double>();
    guardrails.add(
      Guardrail(
        'llvm runtime, ${p.name}: no baseline is faster',
        ratios.isEmpty ? null : ratios.reduce(min),
        1,
        blockedBy: p.blockedBy,
      ),
    );
  }
  // Q32, Dart: faster than every non-native baseline on every program.
  for (final p in programs) {
    final dart = runUs(p.name, 'ciwapa-dart');
    final ratios = [
      for (final b in ['intercal64', 'clc'])
        if (p.runsOn(b)) speedup(runUs(p.name, b), dart),
    ].whereType<double>();
    if (ratios.isEmpty && p.blockedBy.isEmpty) continue;
    guardrails.add(
      Guardrail(
        'dart runtime, ${p.name}: faster than INTERCAL-64 and CLC-INTERCAL',
        ratios.isEmpty ? null : ratios.reduce(min),
        1,
        blockedBy: p.blockedBy,
      ),
    );
  }

  // Q32, geometric means: over the whole set, so they wait for every program to be measurable.
  double? geometric(double? Function(Program) ratio) {
    final ratios = measured.map(ratio).whereType<double>().toList();
    return ratios.isEmpty ? null : geometricMean(ratios);
  }

  guardrails
    ..add(
      Guardrail(
        'llvm runtime, geometric mean: 1.5x faster than the fastest baseline',
        geometric((p) {
          final fastest = [
            for (final b in baselines)
              if (p.runsOn(b)) runUs(p.name, b),
          ].whereType<int>();
          return fastest.isEmpty
              ? null
              : speedup(fastest.reduce(min), runUs(p.name, 'ciwapa-llvm'));
        }),
        1.5,
        blockedBy: blockers,
      ),
    )
    ..add(
      Guardrail(
        'dart runtime, geometric mean: at least as fast as ick -O',
        geometric(
          (p) => speedup(runUs(p.name, 'ick'), runUs(p.name, 'ciwapa-dart')),
        ),
        1,
        blockedBy: blockers,
      ),
    );

  // Q33: front end + emission within 100 ms for every pit program.
  final frontEnd = [
    for (final line in File('$dir/frontend.jsonl').readAsLinesSync())
      jsonDecode(line) as Map<String, dynamic>,
  ];
  final slowest = frontEnd
      .map((f) => max(f['llvm_us'] as int, f['dart_us'] as int))
      .reduce(max);
  guardrails.add(
    Guardrail(
      'front end + emission: every program within 100 ms (slowest ${(slowest / 1000).toStringAsFixed(1)} ms)',
      100000 / slowest,
      1,
    ),
  );

  // Q33: end to end.
  final emptyDart = File('$dir/empty-dart-ms')
      .readAsLinesSync()
      .map(int.parse)
      .reduce(min);
  for (final p in programs) {
    guardrails
      ..add(
        Guardrail(
          'llvm end to end, ${p.name}: no slower than ick + gcc',
          p.runsOn('ick')
              ? speedup(buildMs(p.name, 'ick'), buildMs(p.name, 'ciwapa-llvm'))
              : null,
          1,
          blockedBy: p.blockedBy,
        ),
      )
      ..add(
        Guardrail(
          'dart end to end, ${p.name}: within 1.5x an empty dart compile exe ($emptyDart ms)',
          speedup(emptyDart * 3 ~/ 2, buildMs(p.name, 'ciwapa-dart')),
          1,
          blockedBy: p.blockedBy,
        ),
      );
  }

  final results = {
    'measured': DateTime.now().toUtc().toIso8601String(),
    'machine':
        '${Platform.operatingSystem} ${Platform.version.split(' ').last}',
    'programs': {
      for (final p in measured)
        p.name: {
          for (final impl in [...flavors, ...baselines])
            if (runs[p.name]?[impl] != null)
              impl: {
                'run_us': runUs(p.name, impl),
                'build_ms': buildMs(p.name, impl),
              },
        },
    },
    'notes': [...notes],
    'guardrails': [for (final g in guardrails) g.toJson()],
  };
  File(args[1]).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(results)}\n',
  );

  for (final g in guardrails) {
    final state = g.blockedBy.isNotEmpty
        ? 'BLOCKED (${g.blockedBy})'
        : g.met
        ? 'ok'
        : 'FAIL';
    stdout.writeln(
      '${state.padRight(14)} ${g.name}: ${g.ratio?.toStringAsFixed(2) ?? '-'} (target ${g.target})',
    );
  }
  for (final n in notes) {
    stdout.writeln('note: $n');
  }
}
