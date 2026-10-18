import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

/// The codes Mode 1 already had. Every other code is new in EXTRACAL and needs its own entry.
const _mode1Codes = {
  0,
  17,
  79,
  99,
  111,
  123,
  129,
  139,
  182,
  197,
  200,
  222,
  240,
  241,
  275,
  333,
  436, //
  444, 533, 555, 562, 579, 621, 632, 633, 666, 774, 777, 778, 888, 997, 998,
};

typedef _Entry = ({String text, String joke, List<String> tests});

/// The entries under SPEC_DECISIONS.md's "EXTRACAL error codes", by code.
Map<int, _Entry> _entries() {
  final spec = File('../../docs/SPEC_DECISIONS.md').readAsStringSync();
  final section = spec
      .split('\n## EXTRACAL error codes\n')[1]
      .split('\n## ')[0];
  String field(String entry, String name) =>
      RegExp('- \\*\\*$name:\\*\\* `([^`]*)`').firstMatch(entry)?[1] ?? '';
  return {
    for (final entry in section.split('\n### E').skip(1))
      int.parse(entry.substring(0, 3)): (
        text: field(entry, 'Text'),
        joke: field(entry, 'Joke'),
        tests: [
          for (final m in RegExp(
            '`([^`]+\\.xc)`',
          ).allMatches(RegExp(r'- \*\*Tests:\*\*.*').stringMatch(entry) ?? ''))
            m[1]!,
        ],
      ),
  };
}

void main() {
  final entries = _entries();
  final errors = {for (final e in IclError.all) e.code: e};

  test('every new code has an entry under EXTRACAL error codes (R11)', () {
    final unrecorded = errors.keys
        .toSet()
        .difference(_mode1Codes)
        .difference(entries.keys.toSet());
    expect(unrecorded, isEmpty);
  });

  for (final MapEntry(key: code, value: entry) in entries.entries) {
    test(
      'E$code has its documented text and joke, and tests that raise it',
      () {
        expect(errors[code]?.text, entry.text);
        expect(errors[code]?.joke, entry.joke);
        expect(entry.tests, isNotEmpty);
        for (final path in entry.tests) {
          final err = File(
            '../../${path.replaceFirst(RegExp(r'\.xc$'), '.err')}',
          );
          expect(
            err.readAsStringSync(),
            startsWith('ICL${'$code'.padLeft(3, '0')}I'),
            reason: path,
          );
        }
      },
    );
  }
}
