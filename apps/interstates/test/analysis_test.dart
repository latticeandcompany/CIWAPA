import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:interstates/interstates.dart';
import 'package:test/test.dart';

void main() {
  final frontend = InterstatesFrontend();

  List<(int, int)> codes(Analysis a) => [
    for (final e in a.errors) (e.error.code, e.statement),
  ];

  test('R2: a .ioi reports every error, Interstates\' own included', () {
    final dir = Directory.systemTemp.createTempSync('ioi-analysis-');
    addTearDown(() => dir.deleteSync(recursive: true));
    const text =
        'DO COME FROM (16000)\n'
        'PLEASE DO .1 <- #1\n'
        'DO INTO DATABASE #1~#2\$#3 <- ,1\n'
        'DO INTO DATABASE #1~#2\$#3 <- ,1\n'
        'PLEASE READ OUT #0 WITH TEMPLATE "missing.html"\n'
        'DO GIVE UP\n';
    final a = frontend.analyzeAll(
      Source('${dir.path}/site.ioi', text),
      traditional: false,
    );
    expect(codes(a), [(827, 3), (827, 4), (777, 5)]);
    final fourth = text.lastIndexOf('DO INTO DATABASE');
    expect(a.errors[1].span, Span(fourth, fourth + 31));
  });

  test(
    'R2, R3: a .3ioi is E998, and --traditional is E111, as the CLIs say',
    () {
      expect(
        codes(
          frontend.analyzeAll(
            Source('p.3ioi', 'DO GIVE UP\n'),
            traditional: false,
          ),
        ),
        [(998, 1)],
      );
      expect(
        codes(
          frontend.analyzeAll(
            Source('p.ioi', 'DO GIVE UP\n'),
            traditional: true,
          ),
        ),
        [(111, 1)],
      );
    },
  );

  test('R3: any other file is diagnosed as ciwapa-* would', () {
    // ioi-* builds no .i, but its server diagnoses one with CIWAPA's own front end.
    const text = '(1) DO .1 <- #1\n(1) PLEASE GIVE UP\n';
    expect(
      codes(frontend.analyzeAll(Source('p.i', text), traditional: false)),
      [(182, 1), (182, 2)],
    );
    expect(frontend.handles('p.i'), isTrue);
    expect(frontend.handles('p.ioi'), isTrue);
    expect(frontend.handles('p.2xc'), isTrue);
    expect(frontend.handles('p.html'), isFalse);
    expect(const CiwapaFrontend().handles('p.ioi'), isFalse);
  });

  test(
    'R2: the first collected error is the one ioi-* throws, for every golden',
    () {
      final sources = Directory('test/golden')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.ioi'))
          .toList();
      expect(sources, hasLength(127));
      for (final file in sources) {
        final source = Source.fromBytes(file.path, file.readAsBytesSync());
        CompileError? thrown;
        try {
          analyzeInterstates(source);
        } on CompileError catch (e) {
          thrown = e;
        }
        final compile = frontend
            .analyzeAll(source, traditional: false)
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
    },
  );
}
