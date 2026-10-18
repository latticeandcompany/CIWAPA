// TEMPORARY (removed last, by goal 2's cleanup): judges goal 2's acceptance criteria
// (docs/EXTRACAL_PLAN.md) from the working tree plus the GitHub state that tools/goal/goal-status
// saved in .cache/goal.
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

  final sections = _checklistSections();
  final rest = [
    for (final MapEntry(key: title, value: items) in sections.entries)
      _section(title, items),
    _conformance(),
    _oracle(),
    _noRegression(),
    _ci(),
    _archives(),
  ];
  final criteria = [...rest, _scaffolding(waiting: rest.any((c) => c.blocked))];
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

/// The checklist's items, grouped by its `##` sections. An item's indented continuation lines are
/// part of it.
Map<String, List<String>> _checklistSections() {
  final sections = <String, List<String>>{};
  var inFence = false;
  String? section;
  for (final line in _read('docs/EXTRACAL_CHECKLIST.md').split('\n')) {
    if (line.startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    final items = section == null ? null : sections[section];
    if (line.startsWith('## ')) {
      section = line.substring(3);
      sections[section] = [];
    } else if (items != null && RegExp(r'^- \[[ x]\] ').hasMatch(line)) {
      items.add(line);
    } else if (items != null && items.isNotEmpty && line.startsWith('  ')) {
      items[items.length - 1] += ' ${line.trim()}';
    }
  }
  return sections;
}

/// The questions still open in QUESTIONS.md, such as `L14`.
final Set<String> _openQuestions = {
  for (final m in RegExp(
    r'^## (L\d+):',
    multiLine: true,
  ).allMatches(_read('docs/QUESTIONS.md')))
    m.group(1)!,
};

Criterion _section(String title, List<String> items) {
  if (items.isEmpty) {
    return Criterion('EXTRACAL_CHECKLIST.md: $title', false, [
      'the section has no items',
    ]);
  }
  var done = 0, open = 0, blocked = 0;
  final problems = <String>[];
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
    final summary = item.length > 110 ? '${item.substring(0, 110)}…' : item;
    final waitingOn = RegExp(r'\*\*BLOCKED\*\* \((L\d+)\)')
        .allMatches(item)
        .map((m) => m.group(1)!)
        .where(_openQuestions.contains);
    if (waitingOn.isNotEmpty) {
      blocked++;
      problems.add('blocked on ${waitingOn.join(', ')}: $summary');
    } else if (item.contains('**BLOCKED**')) {
      open++;
      problems.add(
        'marked blocked, but cites no open QUESTIONS.md entry: $summary',
      );
    } else if (!checked) {
      open++;
      problems.add('open: $summary');
    } else if (tests.isEmpty || missing.isNotEmpty) {
      problems.add('checked without an existing linked test: $summary');
    } else {
      done++;
    }
  }
  final met = done == items.length;
  return Criterion('EXTRACAL_CHECKLIST.md: $title', met, [
    '${items.length} items: $done done, $open open, $blocked blocked',
    ...problems,
  ], blocked: !met && blocked + done == items.length);
}

Criterion _conformance() {
  const title =
      'The conformance suite, superset runs included, passes in both flavors on every platform';
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
      final superset = results['superset'] as int? ?? 0;
      final failed = (results['failed'] as List).cast<String>();
      totals.add(total);
      if (total == 0 || superset == 0 || failed.isNotEmpty) met = false;
      details.add(
        '$platform $flavor: ${total - failed.length}/$total passed, $superset of them superset runs'
        '${failed.isEmpty ? '' : ' (failed: ${failed.take(5).join(', ')}${failed.length > 5 ? ', …' : ''})'}',
      );
    }
  }
  if (totals.length > 1) {
    met = false;
    details.add('the jobs ran different numbers of tests: $totals');
  }
  return Criterion(title, met, details);
}

/// The oracle's verdict is copied here before tools/oracle is removed, so it outlives it.
Criterion _oracle() {
  const title =
      'The pit/ programs using ick extensions match C-INTERCAL 0.35, or differ only by recorded divergences';
  final file = File('tools/goal/oracle.json');
  if (!file.existsSync()) {
    return Criterion(title, false, [
      'no tools/goal/oracle.json yet: the EXTRACAL oracle run writes it',
    ]);
  }
  final triage = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final freshness = _read('$cache/oracle-freshness').trim();
  if (freshness != 'current' || (triage['programs'] as int? ?? 0) == 0) {
    return Criterion(title, false, [
      freshness == 'current' ? 'no programs were compared' : freshness,
    ]);
  }
  final differences = (triage['differences'] as List)
      .cast<Map<String, dynamic>>();
  final untriaged = differences.where(
    (d) => !const {
      'fixed',
      'divergence',
      'not a difference',
    }.contains(d['status']),
  );
  final blocked = differences.where((d) => d['status'] == 'blocked');
  return Criterion(title, untriaged.isEmpty, [
    '${triage['programs']} programs compared, ${differences.length} differences, '
        '${untriaged.length} untriaged',
    for (final d in untriaged.take(10)) '${d['status']}: ${d['program']}',
  ], blocked: untriaged.isNotEmpty && untriaged.length == blocked.length);
}

/// Written by tools/bench/no-regression, which compares with goal 1's timings (Q111).
Criterion _noRegression() {
  const title =
      'Mode 1 benchmark timings show no regression against goal 1 (Q111)';
  final file = File('tools/goal/no-regression.json');
  if (!file.existsSync()) {
    return Criterion(title, false, [
      'no tools/goal/no-regression.json: run tools/bench/no-regression',
    ]);
  }
  final verdict = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final freshness = _read('$cache/no-regression-freshness').trim();
  return Criterion(title, verdict['met'] == true && freshness == 'current', [
    if (freshness != 'current') freshness,
    for (final line in verdict['summary'] as List) '$line',
  ]);
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

/// Goal 1's and goal 2's temporary scaffolding (Q140). tools/goal and the image this script runs
/// in are removed right after it reports, so they can't be checked here. While other criteria wait
/// on QUESTIONS.md the scaffolding is still needed to finish them, so it is [waiting] too.
Criterion _scaffolding({required bool waiting}) {
  final toolchain = _read('$cache/toolchain-image').trim();
  const title =
      'The temporary scaffolding from goals 1 and 2 is removed (Q140); tools/goal and ciwapa-toolchain go last';
  final tracked = _read('$cache/tracked-scaffolding')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final images = _read('$cache/docker-images')
      .split('\n')
      .where((l) => l.startsWith('ciwapa-') && l != toolchain)
      .toList();
  final problems = [
    if (tracked.isNotEmpty)
      'still tracked: ${tracked.take(5).join(', ')}${tracked.length > 5 ? ', …' : ''}',
    if (FileSystemEntity.typeSync('pit') != FileSystemEntityType.notFound)
      'the pit/ download is still here',
    if (_read('docs/PLAN.md').contains('## Performance guardrails'))
      'docs/PLAN.md still has the performance-guardrails section',
    if (_read('.github/workflows/ci.yml').contains('tools/bench'))
      'the CI performance-regression check is still in ci.yml',
    for (final i in images) 'Docker image still present: $i',
  ];
  return Criterion(title, problems.isEmpty, [
    ...problems,
    if (problems.isEmpty)
      'tools/oracle, tools/bench, pit/ and their images are gone',
  ]);
}

String _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}
