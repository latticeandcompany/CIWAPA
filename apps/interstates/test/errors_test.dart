import 'dart:io';

import 'package:interstates/src/errors.dart';
import 'package:test/test.dart';

typedef _Entry = ({String text, String joke, List<String> tests});

/// The entries under SPEC_DECISIONS.md's "INTERCAL on Interstates error codes", by code.
Map<int, _Entry> _entries() {
  final spec = File('../../docs/SPEC_DECISIONS.md').readAsStringSync();
  final section = spec
      .split('\n## INTERCAL on Interstates error codes\n')[1]
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
            '`(apps/[^`]+)`',
          ).allMatches(RegExp(r'- \*\*Tests:\*\*.*').stringMatch(entry) ?? ''))
            m[1]!,
        ],
      ),
  };
}

void main() {
  final entries = _entries();

  test('every Interstates code has an entry, and every entry a code', () {
    expect(entries.keys.toSet(), {for (final e in interstatesErrors) e.code});
  });

  for (final error in interstatesErrors) {
    final code = error.code.toString().padLeft(3, '0');
    test(
      'E$code has its documented text and joke, and tests that raise it',
      () {
        final entry = entries[error.code]!;
        expect(error.text, entry.text);
        expect(error.joke, entry.joke);
        expect(entry.tests, isNotEmpty);
        for (final path in entry.tests) {
          final file = '../../$path';
          if (path.endsWith('.xc')) {
            expect(
              File(file.replaceFirst(RegExp(r'\.xc$'), '.err'))
                  .readAsStringSync(),
              matches(RegExp('^ICL${code}I', multiLine: true)),
              reason: path,
            );
          } else {
            expect(
              File(file).readAsStringSync(),
              matches(RegExp("ICL${code}I|'code', ${error.code}\\b|E$code\\b")),
              reason: path,
            );
          }
        }
      },
    );
  }
}
