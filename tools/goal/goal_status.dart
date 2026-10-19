// TEMPORARY (removed last, by goal 3's cleanup): judges goal 3's acceptance criteria
// (docs/INTERSTATES_PLAN.md) from the working tree plus the GitHub state that
// tools/goal/goal-status saved in .cache/goal.
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

/// Goal 2's suite on its last mega HEAD (1dd0a73): R1 of goal 3 says it must not change.
const conformanceBaseline = (total: 1163, superset: 401);

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
  final criteria = [
    for (final MapEntry(key: title, value: items) in sections.entries)
      if (title == 'New error codes')
        _errorCodes(title, items)
      else
        _section(title, items),
    _suite(
      'The Mode 1 and EXTRACAL conformance suite passes unchanged in both flavors on every platform',
      'conformance',
      baseline: conformanceBaseline,
    ),
    _suite(
      'The Interstates suite passes in both flavors on every platform',
      'interstates',
    ),
    _ci(),
    _archives(),
    _scaffolding(),
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
  for (final line in _read('docs/INTERSTATES_CHECKLIST.md').split('\n')) {
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

/// The questions still open in QUESTIONS.md, such as `L35`.
final Set<String> _openQuestions = {
  for (final m in RegExp(
    r'^## (L\d+):',
    multiLine: true,
  ).allMatches(_read('docs/QUESTIONS.md')))
    m.group(1)!,
};

Criterion _section(String title, List<String> items) {
  if (items.isEmpty) {
    return Criterion('INTERSTATES_CHECKLIST.md: $title', false, [
      'the section has no items',
    ]);
  }
  var done = 0, open = 0, blocked = 0;
  final problems = <String>[];
  for (final item in items) {
    final checked = item.startsWith('- [x]');
    final tests = _linkedTests(item);
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
  return Criterion('INTERSTATES_CHECKLIST.md: $title', met, [
    '${items.length} items: $done done, $open open, $blocked blocked',
    ...problems,
  ], blocked: !met && blocked + done == items.length);
}

List<String> _linkedTests(String item) {
  final testsText = item.contains('Tests:')
      ? item.substring(item.indexOf('Tests:'))
      : '';
  return RegExp(r'`([^`]+)`')
      .allMatches(testsText)
      .map((m) => m.group(1)!)
      .toList();
}

/// Besides its checklist item, each Interstates error code needs its own SPEC_DECISIONS.md entry
/// and a test that expects its message.
Criterion _errorCodes(String title, List<String> items) {
  final section = _section(title, items);
  final codes = {
    for (final m in RegExp(
      r'IclError\(\s*(\d+)',
    ).allMatches(_read('apps/interstates/lib/src/errors.dart')))
      int.parse(m.group(1)!),
  };
  final decisions = _read('docs/SPEC_DECISIONS.md');
  final start = decisions.indexOf('## INTERCAL on Interstates error codes');
  final entries = start < 0 ? '' : decisions.substring(start);
  final tested = _expectedMessages();
  final problems = <String>[
    if (codes.isEmpty) 'apps/interstates/lib/src/errors.dart defines no codes',
    for (final code in codes) ...[
      if (!RegExp('^### E${_pad(code)}:', multiLine: true).hasMatch(entries))
        'E${_pad(code)} has no entry under "INTERCAL on Interstates error codes"',
      if (!tested.contains(code)) 'E${_pad(code)} has no test expecting it',
    ],
  ];
  return Criterion(section.title, section.met && problems.isEmpty, [
    ...section.details,
    '${codes.length} codes: ${codes.map((c) => 'E${_pad(c)}').join(', ')}',
    ...problems,
  ], blocked: section.blocked && problems.isEmpty);
}

String _pad(int code) => code.toString().padLeft(3, '0');

/// The codes some Interstates test expects, as `ICLnnnI` in an expected-output file or test source.
Set<int> _expectedMessages() {
  final dir = Directory('apps/interstates/test');
  if (!dir.existsSync()) return {};
  final codes = <int>{};
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    final String text;
    try {
      text = f.readAsStringSync();
    } on FileSystemException {
      continue;
    }
    for (final m in RegExp(r'ICL(\d{3})I').allMatches(text)) {
      codes.add(int.parse(m.group(1)!));
    }
  }
  return codes;
}

/// A golden suite's results, uploaded by every CI job as `<name>-<platform>-<flavor>`.
Criterion _suite(
  String title,
  String name, {
  ({int total, int superset})? baseline,
}) {
  final details = <String>[];
  var met = true;
  final totals = <int>{};
  for (final platform in platforms) {
    for (final flavor in flavors) {
      final file = File(
        '$cache/artifacts/$name-$platform-$flavor/results.json',
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
      if (total == 0 || failed.isNotEmpty) met = false;
      if (baseline != null &&
          (total < baseline.total || superset < baseline.superset)) {
        met = false;
        details.add(
          '$platform $flavor: fewer tests than goal 2 left ($total, $superset superset; '
          'goal 2 had ${baseline.total}, ${baseline.superset})',
        );
      }
      details.add(
        '$platform $flavor: ${total - failed.length}/$total passed'
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

Criterion _ci() => _jobsGreen(
  'CI on the mega HEAD is green for all 10 platform × flavor jobs',
  'run-ci.json',
  ['ci'],
);

/// CIWAPA's own archives must keep building next to the new `ioi-<flavor>-<os>-<arch>` ones.
Criterion _archives() {
  final jobs = _jobsGreen(
    'All 20 release archives (ciwapa-* and ioi-*) build and pass their smoke tests',
    'run-release-archives.json',
    ['archive', 'ioi-archive'],
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
      final ciwapa = RegExp('^ciwapa-$flavor-\\d+\\.\\d+\\.\\d+.*-$platform\$');
      if (!names.any(ciwapa.hasMatch)) {
        met = false;
        details.add('no ciwapa-$flavor-<ver>-$platform archive uploaded');
      }
      if (!names.contains('ioi-$flavor-$platform')) {
        met = false;
        details.add('no ioi-$flavor-$platform archive uploaded');
      }
    }
  }
  return Criterion(jobs.title, met, details);
}

Criterion _jobsGreen(String title, String runFile, List<String> jobPrefixes) {
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
  var met = true, count = 0;
  for (final prefix in jobPrefixes) {
    for (final platform in platforms) {
      for (final flavor in flavors) {
        count++;
        final state = jobs['$prefix ($platform, $flavor)'] ?? 'missing';
        if (state != 'success') {
          met = false;
          details.add('$prefix ($platform, $flavor): $state');
        }
      }
    }
  }
  if (met) details.add('$count/$count jobs succeeded');
  return Criterion(title, met, details);
}

/// Goal 3 adds no temporary scaffolding but tools/goal, which goes last (after this report, so it
/// can't be checked here). Anything else marked TEMPORARY would still have to go.
Criterion _scaffolding() {
  const title =
      'No temporary scaffolding is left but tools/goal, which is removed last';
  final marked = _read('$cache/temporary-files')
      .split('\n')
      .where((l) => l.trim().isNotEmpty && !l.startsWith('tools/goal/'))
      .toList();
  return Criterion(title, marked.isEmpty, [
    if (marked.isEmpty)
      'nothing outside tools/goal is marked TEMPORARY'
    else
      'still marked TEMPORARY: ${marked.take(5).join(', ')}${marked.length > 5 ? ', …' : ''}',
  ]);
}

String _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}
