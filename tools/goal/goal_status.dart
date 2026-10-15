// TEMPORARY (goal 2's cleanup removes it): judges goal 1's acceptance criteria from the
// working tree plus the GitHub state that tools/goal/goal-status saved in .cache/goal.
import 'dart:convert';
import 'dart:io';

const platforms = [
  'linux-x64',
  'linux-arm64',
  'macos-arm64',
  'windows-x64',
  'windows-arm64',
];
const flavors = ['dart', 'llvm'];
const cache = '.cache/goal';

class Criterion {
  Criterion(this.title, this.met, this.details, {this.blocked = false});

  final String title;
  final bool met;
  final List<String> details;

  /// Not met, but only because of open QUESTIONS.md entries.
  final bool blocked;
}

void main() {
  final megaSha = _read('$cache/mega-sha').trim();
  final headSha = _read('$cache/head-sha').trim();
  print('goal-status for mega ${megaSha.substring(0, 12)}');
  if (headSha != megaSha) {
    print(
      '  warning: the working tree is at ${headSha.substring(0, 12)}, not the mega HEAD',
    );
  }
  print('');

  final criteria = [
    _checklist(),
    _conformance(),
    _ci(),
    _archives(),
    _performance(),
    _oracle(),
  ];
  for (final (i, c) in criteria.indexed) {
    final state = c.met
        ? '[MET]    '
        : c.blocked
        ? '[BLOCKED]'
        : '[NOT MET]';
    print('$state ${i + 1}. ${c.title}');
    for (final d in c.details) {
      print('            $d');
    }
  }

  print('');
  print('Temporary scaffolding still present (kept for goal 2):');
  for (final path in ['tools/oracle', 'tools/bench', 'tools/goal', 'pit']) {
    print(
      '  $path: ${FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound ? 'absent' : 'present'}',
    );
  }

  print('');
  final left = [
    for (final (i, c) in criteria.indexed)
      if (!c.met) '${i + 1}. ${c.title}',
  ];
  if (left.isEmpty) {
    print('GOAL: MET');
  } else {
    print('Left to do:');
    for (final l in left) {
      print('  $l');
    }
    final blocked = criteria.every((c) => c.met || c.blocked);
    print(
      blocked
          ? 'GOAL: BLOCKED (everything left waits on docs/QUESTIONS.md)'
          : 'GOAL: NOT MET',
    );
  }
}

Criterion _checklist() {
  const title =
      'Every SPEC_CHECKLIST.md item is checked and links to a passing test (or is blocked)';
  final lines = _read('docs/SPEC_CHECKLIST.md').split('\n');
  final items = <String>[];
  var inFence = false;
  for (final line in lines) {
    if (line.startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (line.startsWith('## Excluded by decision')) break;
    if (RegExp(r'^- \[[ x]\] ').hasMatch(line)) {
      items.add(line);
    } else if (items.isNotEmpty && line.startsWith('  ')) {
      items[items.length - 1] += '\n$line';
    } else if (line.startsWith('#')) {
      items.add('');
    }
  }
  items.removeWhere((i) => i.isEmpty);

  var done = 0, open = 0, blocked = 0;
  final invalid = <String>[];
  for (final item in items) {
    final checked = item.startsWith('- [x]');
    final testsText = item.contains('Tests:')
        ? item.substring(item.indexOf('Tests:'))
        : '';
    final tests = RegExp(r'`([^`]+)`')
        .allMatches(testsText)
        .map((m) => m.group(1)!)
        .toList();
    final missing = tests.where(
      (t) => FileSystemEntity.typeSync(t) == FileSystemEntityType.notFound,
    );
    if (item.contains('**BLOCKED**')) {
      blocked++;
    } else if (!checked) {
      open++;
    } else if (tests.isEmpty || missing.isNotEmpty) {
      invalid.add(item.split('\n').first);
    } else {
      done++;
    }
  }
  return Criterion(title, open == 0 && invalid.isEmpty, [
    '${items.length} items: $done done, $open open, $blocked blocked',
    for (final i in invalid) 'checked but without an existing linked test: $i',
  ]);
}

Criterion _conformance() {
  const title =
      'The conformance suite passes in both flavors with identical stdout, stderr and exit codes';
  final details = <String>[];
  var met = true;
  final totals = <int>{};
  for (final platform in platforms) {
    for (final flavor in flavors) {
      final file = File(
        '$cache/artifacts/conformance-$platform-$flavor/results.json',
      );
      if (!file.existsSync()) {
        met = false;
        details.add('$platform $flavor: no results on the mega HEAD CI run');
        continue;
      }
      final results =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final total = results['total'] as int;
      final failed = (results['failed'] as List).cast<String>();
      totals.add(total);
      if (total == 0 || failed.isNotEmpty) met = false;
      details.add(
        '$platform $flavor: ${total - failed.length}/$total passed'
        '${failed.isEmpty ? '' : ' (failed: ${failed.take(5).join(', ')}${failed.length > 5 ? ', …' : ''})'}',
      );
    }
  }
  if (totals.length > 1) {
    met = false;
    details.add('the flavors ran different numbers of tests: $totals');
  }
  return Criterion(title, met, details);
}

Criterion _ci() => _jobsGreen(
  'CI on the mega HEAD is green for all 10 platform × flavor jobs',
  'run-ci.json',
  'ci',
);

Criterion _archives() {
  final jobs = _jobsGreen(
    'All 10 release archives build and pass their smoke test',
    'run-release-archives.json',
    'archive',
  );
  final details = [...jobs.details];
  var met = jobs.met;
  final artifactsFile = File('$cache/artifacts-release-archives.json');
  final names = artifactsFile.existsSync()
      ? [
          for (final a in jsonDecode(artifactsFile.readAsStringSync()) as List)
            if (a['expired'] != true) a['name'] as String,
        ]
      : <String>[];
  for (final platform in platforms) {
    for (final flavor in flavors) {
      final archive = RegExp(
        '^ciwapa-$flavor-\\d+\\.\\d+\\.\\d+.*-$platform\$',
      );
      if (!names.any(archive.hasMatch)) {
        met = false;
        details.add('no ciwapa-$flavor-<ver>-$platform archive uploaded');
      }
    }
  }
  return Criterion(jobs.title, met, details);
}

Criterion _jobsGreen(String title, String runFile, String jobPrefix) {
  final file = File('$cache/$runFile');
  if (!file.existsSync()) {
    return Criterion(title, false, ['no push run on the mega HEAD']);
  }
  final run = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final jobs = {
    for (final j in run['jobs'] as List)
      j['name'] as String: switch (j['conclusion']) {
        String c when c.isNotEmpty => c,
        _ => j['status'] as String,
      },
  };
  final details = <String>[];
  var met = true;
  for (final platform in platforms) {
    for (final flavor in flavors) {
      final state = jobs['$jobPrefix ($platform, $flavor)'] ?? 'missing';
      if (state != 'success') {
        met = false;
        details.add('$jobPrefix ($platform, $flavor): $state');
      }
    }
  }
  if (met) details.add('10/10 jobs succeeded');
  return Criterion(title, met, details);
}

Criterion _performance() {
  const title = 'Every performance guardrail is met';
  final file = File('tools/bench/results.json');
  if (!file.existsSync()) {
    return Criterion(title, false, [
      'no benchmark results recorded in tools/bench/results.json',
    ]);
  }
  final results = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final guardrails = (results['guardrails'] as List)
      .cast<Map<String, dynamic>>();
  final unmet = guardrails.where((g) => g['met'] != true);
  return Criterion(title, unmet.isEmpty, [
    for (final g in guardrails)
      '${g['met'] == true
          ? 'ok     '
          : g['blocked'] != null
          ? 'BLOCKED'
          : 'FAIL   '} ${g['name']}: ${g['ratio']} (target ${g['target']})${g['blocked'] != null ? ' (QUESTIONS.md ${g['blocked']})' : ''}',
  ], blocked: unmet.isNotEmpty && unmet.every((g) => g['blocked'] != null));
}

Criterion _oracle() {
  const title =
      'Every difference from the 0.35 oracle is fixed or recorded under Divergences';
  final file = File('tools/oracle/triage.json');
  if (!file.existsSync()) {
    return Criterion(title, false, [
      'the oracle has not been run (no tools/oracle/triage.json)',
    ]);
  }
  final triage = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final differences = (triage['differences'] as List)
      .cast<Map<String, dynamic>>();
  final untriaged = differences.where(
    (d) => !const {
      'fixed',
      'divergence',
      'not a difference',
    }.contains(d['status']),
  );
  return Criterion(title, untriaged.isEmpty, [
    '${triage['programs']} programs compared, ${differences.length} differences, ${untriaged.length} untriaged',
    for (final d in untriaged.take(10)) 'untriaged: ${d['program']}',
  ]);
}

String _read(String path) => File(path).readAsStringSync();
