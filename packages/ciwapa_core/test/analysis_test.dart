import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

Analysis collect(
  String text, {
  String path = 't.i',
  bool traditional = false,
}) => const CiwapaFrontend().analyzeAll(
  Source(path, text),
  traditional: traditional,
);

/// Where [needle] is in [text] (ASCII, so runes and code units agree).
Span at(String text, String needle) {
  final start = text.indexOf(needle);
  expect(start, isNonNegative, reason: needle);
  return Span(start, start + needle.length);
}

List<(int, int, Span?, Span?, bool)> summary(Analysis a) => [
  for (final e in a.errors)
    (e.error.code, e.statement, e.span, e.token, e.whenRun),
];

void main() {
  group('R2: every compile error, with its statement', () {
    test('label errors keep coming after the first', () {
      const text =
          '(1) DO .1 <- #1\n'
          '(1) PLEASE DO .2 <- #2\n'
          'DO COME FROM (5)\n'
          'DO COME FROM (1)\n'
          'DO COME FROM (1)\n'
          'PLEASE GIVE UP\n';
      final fifth = text.lastIndexOf('DO COME FROM (1)');
      expect(summary(collect(text)), [
        (182, 1, at(text, '(1) DO .1 <- #1'), at(text, '(1)'), false),
        (182, 2, at(text, '(1) PLEASE DO .2 <- #2'), Span(16, 19), false),
        (444, 3, at(text, 'DO COME FROM (5)'), at(text, '(5)'), false),
        (555, 5, Span(fifth, fifth + 16), Span(fifth + 13, fifth + 16), false),
      ]);
    });

    test('--traditional, politeness and operators are all reported', () {
      const text = 'DO COME FROM (1)\n(1) DO .1 <- ^#1\nDO GIVE UP\n';
      final a = collect(text, path: 't.3i', traditional: true);
      expect(
        [for (final e in a.errors) (e.error.code, e.statement)],
        [(111, 1), (111, 1), (79, 1)],
      );
      expect(a.errors[1].span, at(text, 'DO COME FROM (1)'));
    });

    test('an operator the base lacks points at the operator', () {
      const text = 'PLEASE DO .1 <- .^1\nDO .2 <- #1\nDO GIVE UP\n';
      expect(summary(collect(text)), [
        (997, 1, at(text, 'PLEASE DO .1 <- .^1'), at(text, '^'), false),
      ]);
    });

    test('an unknown extension is E998, with nothing else to say', () {
      final a = collect('DO GIVE UP\n', path: 't.c');
      expect(summary(a), [(998, 1, null, null, false)]);
      expect(a.program.statements, isEmpty);
    });

    test('a clean program has no errors', () {
      expect(collect('PLEASE GIVE UP\n').errors, isEmpty);
    });
  });

  group('R2: statement-local errors carry their token', () {
    const text =
        'DO .1 <- #70000\n'
        'PLEASE DO .0 <- #1\n'
        'DO (77) NEXT\n'
        'DO ABSTAIN FROM (88)\n'
        '(70000) DO .2 <- #1\n'
        'DO %150 .3 <- #1\n'
        'PLEASE GIVE UP\n';

    test('each one fires only when its statement runs', () {
      // The program builds: nothing here is a whole-program error.
      expect(() => analyze(Source('t.i', text)), returnsNormally);
      expect(summary(collect(text)), [
        (17, 1, at(text, 'DO .1 <- #70000'), at(text, '#70000'), true),
        (200, 2, at(text, 'PLEASE DO .0 <- #1'), at(text, '.0'), true),
        (129, 3, at(text, 'DO (77) NEXT'), at(text, '(77)'), true),
        (139, 4, at(text, 'DO ABSTAIN FROM (88)'), at(text, '(88)'), true),
        (197, 5, at(text, '(70000) DO .2 <- #1'), at(text, '(70000)'), true),
        (17, 6, at(text, 'DO %150 .3 <- #1'), at(text, '%150'), true),
      ]);
    });

    test('EXTRACAL\'s wide constants too', () {
      const wide = 'DO :1 <- ##4294967296\nPLEASE GIVE UP\n';
      expect(summary(collect(wide, path: 't.xc')), [
        (
          17,
          1,
          at(wide, 'DO :1 <- ##4294967296'),
          at(wide, '##4294967296'),
          true,
        ),
      ]);
    });

    test('an ungrouped chain is about the whole statement', () {
      const chain = 'DO .1 <- #1\$#2~#3\nPLEASE GIVE UP\n';
      expect(summary(collect(chain)), [
        (17, 1, at(chain, 'DO .1 <- #1\$#2~#3'), null, true),
      ]);
    });
  });

  test('R3: the random compiler bug is never reported', () {
    // At 1 in 128 per statement, a build of this would almost surely plant some.
    final text = [
      'PLEASE DO .1 <- #1',
      for (var i = 0; i < 2000; i++)
        i % 4 == 0 ? 'PLEASE DO .1 <- #1' : 'DO .1 <- #1',
      'PLEASE GIVE UP',
    ].join('\n');
    expect(collect(text).errors, isEmpty);
  });

  test('R2: the first collected error is exactly the one the CLI throws, '
      'for every conformance program', () {
    final sources = Directory('../conformance/tests')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => RegExp(r'\.[2-7]?(i|xc)$').hasMatch(f.path))
        .toList();
    expect(sources.length, greaterThan(500));
    var failing = 0;
    for (final file in sources) {
      final flags = File(file.path.replaceFirst(RegExp(r'\.[^.]*$'), '.flags'));
      final traditional =
          flags.existsSync() &&
          flags.readAsStringSync().contains('--traditional');
      final source = Source.fromBytes(file.path, file.readAsBytesSync());
      CompileError? thrown;
      try {
        analyze(source, traditional: traditional);
      } on CompileError catch (e) {
        thrown = e;
        failing++;
      }
      final compile = const CiwapaFrontend()
          .analyzeAll(source, traditional: traditional)
          .errors
          .where((e) => !e.whenRun);
      expect(
        compile.isEmpty
            ? null
            : (compile.first.error.code, compile.first.statement),
        thrown == null ? null : (thrown.error.code, thrown.statement),
        reason: file.path,
      );
    }
    expect(failing, greaterThan(20));
  });
}
