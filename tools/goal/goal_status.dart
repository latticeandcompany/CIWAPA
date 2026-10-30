// TEMPORARY (removed last, by goal 4's cleanup): judges goal 4's acceptance criteria
// (docs/EDITORS_PLAN.md) from the working tree plus the GitHub state that
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
const editors = ['vscode', 'jetbrains', 'neovim'];
const cache = '.cache/goal';

/// The suites on goal 3's last mega HEAD (bfdcd0c). Goal 4 may add tests, never lose them.
const conformanceBaseline = (total: 1163, superset: 401);
const interstatesBaseline = (total: 127, superset: 0);

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

  final changed = _lines('$cache/changed-goldens');
  final criteria = [
    for (final MapEntry(key: title, value: items)
        in _checklistSections().entries)
      _section(title, items),
    _suite(
      'The conformance suite passes unchanged in both flavors on every platform (R2)',
      'conformance',
      baseline: conformanceBaseline,
      problems: [
        for (final line in changed)
          if (line.contains('packages/conformance/'))
            'conformance golden changed: $line',
      ],
    ),
    _suite(
      "Goal 3's suite passes under its .ioi names in both flavors on every platform (R1)",
      'interstates',
      baseline: interstatesBaseline,
      problems: [
        for (final line in changed)
          if (line.contains('apps/interstates/') && !_renamedToIoi(line))
            'Interstates golden changed other than by its .ioi rename: $line',
      ],
    ),
    _separation(),
    _ci(),
    _release(),
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

/// `R100<TAB>old.xc<TAB>new.ioi`: a golden renamed with no change to its contents.
bool _renamedToIoi(String line) {
  final parts = line.split('\t');
  return parts.length == 3 &&
      parts[0] == 'R100' &&
      parts[1].endsWith('.xc') &&
      parts[2].endsWith('.ioi');
}

/// The checklist's items, grouped by its `##` sections. An item's indented continuation lines are
/// part of it.
Map<String, List<String>> _checklistSections() {
  final sections = <String, List<String>>{};
  var inFence = false;
  String? section;
  for (final line in _read('docs/EDITORS_CHECKLIST.md').split('\n')) {
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

/// The questions still open in QUESTIONS.md, such as `L43`.
final Set<String> _openQuestions = {
  for (final m in RegExp(
    r'^## (L\d+):',
    multiLine: true,
  ).allMatches(_read('docs/QUESTIONS.md')))
    m.group(1)!,
};

Criterion _section(String title, List<String> items) {
  if (items.isEmpty) {
    return Criterion('EDITORS_CHECKLIST.md: $title', false, [
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
  return Criterion('EDITORS_CHECKLIST.md: $title', met, [
    '${items.length} items: $done done, $open open, $blocked blocked',
    ...problems,
  ], blocked: !met && blocked + done == items.length);
}

/// The paths in backticks after an item's `Tests:`. A path may end in `#name`, naming the test.
List<String> _linkedTests(String item) {
  final at = item.indexOf('Tests:');
  if (at < 0) return const [];
  return RegExp(r'`([^`]+)`')
      .allMatches(item.substring(at))
      .map((m) => m.group(1)!.split('#').first.trim())
      .toList();
}

/// A golden suite's results, uploaded by every CI job as `<name>-<platform>-<flavor>`.
Criterion _suite(
  String title,
  String name, {
  required ({int total, int superset}) baseline,
  List<String> problems = const [],
}) {
  final details = [...problems];
  var met = problems.isEmpty;
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
      if (total < baseline.total || superset < baseline.superset) {
        met = false;
        details.add(
          '$platform $flavor: fewer tests than goal 3 left ($total, $superset superset; '
          'goal 3 had ${baseline.total}, ${baseline.superset})',
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

/// The CI run's job states, by name, or null when there was no push run on the mega HEAD.
Map<String, String>? _jobs(String runFile) {
  final file = File('$cache/$runFile');
  if (!file.existsSync()) return null;
  final run = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final j in run['jobs'] as List)
      j['name'] as String: switch (j['conclusion']) {
        String c when c.isNotEmpty => c,
        _ => j['status'] as String,
      },
  };
}

/// Every job must succeed, and the jobs named by [required] (each a name prefix) must exist.
Criterion _jobsGreen(String title, String runFile, List<String> required) {
  final jobs = _jobs(runFile);
  if (jobs == null) {
    return Criterion(title, false, ['no push run on the mega HEAD']);
  }
  final details = <String>[];
  var met = true;
  for (final prefix in required) {
    if (!jobs.keys.any((name) => name.startsWith(prefix))) {
      met = false;
      details.add('$prefix: missing');
    }
  }
  for (final MapEntry(key: name, value: state) in jobs.entries) {
    if (state != 'success' && state != 'skipped') {
      met = false;
      details.add('$name: $state');
    }
  }
  if (met) details.add('${jobs.length}/${jobs.length} jobs succeeded');
  return Criterion(title, met, details);
}

Criterion _ci() => _jobsGreen(
  'CI on the mega HEAD is green, the three editor smoke tests included',
  'run-ci.json',
  [
    for (final platform in platforms)
      for (final flavor in flavors) 'ci ($platform, $flavor)',
    for (final editor in editors) '$editor smoke test',
  ],
);

/// R14: the release builds the compiler archives as before, and the .vsix and the plugin .zip with
/// the compilers' version.
Criterion _release() {
  final jobs = _jobsGreen(
    "The release builds every archive, the .vsix and the JetBrains plugin .zip, with the compilers' version",
    'run-release-archives.json',
    [
      for (final platform in platforms)
        for (final flavor in flavors) ...[
          'archive ($platform, $flavor)',
          'ioi-archive ($platform, $flavor)',
        ],
      'vscode extension',
      'jetbrains plugin',
    ],
  );
  final details = [...jobs.details];
  var met = jobs.met;
  final version = RegExp(
    r'^version: *(\S+)',
    multiLine: true,
  ).firstMatch(_read('packages/ciwapa_llvm/pubspec.yaml'))?.group(1);
  final artifactsFile = File('$cache/artifacts-release-archives.json');
  final names = artifactsFile.existsSync()
      ? [
          for (final a in jsonDecode(artifactsFile.readAsStringSync()) as List)
            if (a['expired'] != true) a['name'] as String,
        ]
      : <String>[];
  for (final name in [
    'intercal-vscode-$version',
    'intercal-jetbrains-$version',
  ]) {
    if (names.contains(name)) {
      details.add('uploaded $name');
    } else {
      met = false;
      details.add('no $name artifact uploaded');
    }
  }
  return Criterion(jobs.title, met, details);
}

/// Goal 4 adds no temporary scaffolding but tools/goal, which goes last (after this report, so it
/// can't be checked here). Anything else marked TEMPORARY would still have to go.
Criterion _scaffolding() {
  const title =
      'No temporary scaffolding is left but tools/goal, which is removed last';
  final marked = _lines('$cache/temporary-files')
      .where((l) => !l.startsWith('tools/goal/'))
      .toList();
  return Criterion(title, marked.isEmpty, [
    if (marked.isEmpty)
      'nothing outside tools/goal is marked TEMPORARY'
    else
      'still marked TEMPORARY: ${marked.take(5).join(', ')}${marked.length > 5 ? ', …' : ''}',
  ]);
}

/// R1 and R3: CIWAPA's own packages, ciwapa_lsp included, never learn about Interstates.
Criterion _separation() {
  final naming = _lines('$cache/packages-naming-interstates');
  return Criterion(
    'Nothing under packages/ names Interstates, ciwapa_lsp included (R1, R3)',
    naming.isEmpty,
    [
      if (naming.isEmpty)
        'no file under packages/ mentions interstates, ioi- or .ioi'
      else
        'names it: ${naming.take(5).join(', ')}',
    ],
  );
}

List<String> _lines(String path) =>
    _read(path).split('\n').where((l) => l.trim().isNotEmpty).toList();

String _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}
