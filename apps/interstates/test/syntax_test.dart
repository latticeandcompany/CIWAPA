import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:interstates/interstates.dart';
import 'package:interstates/src/errors.dart';
import 'package:interstates/src/services.dart';
import 'package:interstates/src/syntax.dart';
import 'package:test/test.dart';

List<Statement> parse(String text) =>
    analyzeInterstates(Source('t.xc', text)).statements;

Statement only(String text) => parse(text).single;

/// The values of a HostCall, with each constant as its number and anything else as text.
List<Object> values(Body body) => [
  for (final v in (body as HostCall).values)
    v is Constant ? v.value : v.toString(),
];

void main() {
  group('routes (R3, Q142)', () {
    test('COME FROM (16000) WITH ROUTE is a route, never a COME FROM', () {
      final s = only('DO COME FROM (16000) WITH ROUTE "/blog/:id"\n');
      expect(s.body, isA<Nothing>());
      final route = s.data as RouteDecl;
      expect(route.label, 16000);
      expect(route.pattern, '/blog/:id');
    });

    test('a bare COME FROM (16000) is the catch-all', () {
      final s = only('DO COME FROM (16000)\n');
      expect(s.body, isA<Nothing>());
      expect((s.data as RouteDecl).pattern, isNull);
    });

    test('a route on another label keeps its label, and is no trap door', () {
      final dir = Directory.systemTemp.createTempSync('ioi-routes-');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/a.html')
          .writeAsStringSync('<a href="/a">a</a><a href="/b">b</a>');
      final statements = analyzeInterstates(
        Source(
          '${dir.path}/t.xc',
          '(5) PLEASE READ OUT #0 WITH TEMPLATE "a.html"\n'
              'DO COME FROM (5) WITH ROUTE "/a"\n'
              'DO COME FROM (5) WITH ROUTE "/b"\n',
        ),
      ).statements;
      for (final s in statements.skip(1)) {
        expect(s.body, isA<Nothing>());
        expect((s.data as RouteDecl).label, 5);
      }
      expect(
        [for (final s in statements.skip(1)) (s.data as RouteDecl).pattern],
        ['/a', '/b'],
      );
    });

    test('a plain COME FROM keeps its meaning', () {
      expect(
        parse('(5) DO .1 <- #1\nPLEASE COME FROM (5)\n')[1].body,
        isA<ComeFrom>(),
      );
    });

    test('WITH ROUTE fits only a COME FROM', () {
      final s = parse('DO .1 <- #1 WITH ROUTE "/a"\nPLEASE GIVE UP\n').first;
      expect(s.body, isA<Undecodable>());
    });
  });

  group('string literals (R5)', () {
    test(
      'a literal can hold statement identifiers and rabbit ears\' partner',
      () {
        final s = parse(
          'DO COME FROM (16000) WITH ROUTE "/DO/PLEASE/(1)"\nPLEASE GIVE UP\n',
        );
        expect(s, hasLength(2));
        expect((s.first.data as RouteDecl).pattern, '/DO/PLEASE/(1)');
      },
    );

    test('anywhere else, " is still rabbit ears', () {
      final s = only(
        r'PLEASE DO .1 <- "#1$#2"~#3'
        '\n',
      );
      expect(s.body, isA<Calculate>());
    });

    test('a literal ends on its own line', () {
      final s = parse(
        'DO COME FROM (16000) WITH ROUTE "/a\n"\nPLEASE GIVE UP\n',
      ).first;
      expect(s.body, isA<Undecodable>());
    });
  });

  group('templates (R6)', () {
    test('READ OUT #n WITH TEMPLATE records the template and its count', () {
      final s = only('PLEASE READ OUT #3 WITH TEMPLATE "blog_post.html"\n');
      expect((s.body as HostCall).service, HostService.render);
      expect(s.body.gerund, Gerund.readingOut);
      final use = s.data as TemplateUse;
      expect(use.count, 3);
      expect(use.path, 'blog_post.html');
    });

    test('it takes one #n and nothing else', () {
      for (final out in ['.1', '#1 + #2', 'SIGNED #1']) {
        final s = parse(
          'PLEASE READ OUT $out WITH TEMPLATE "a.html"\nDO GIVE UP\n',
        ).first;
        expect(s.body, isA<Undecodable>(), reason: out);
      }
    });
  });

  group('arrays of strings (R5)', () {
    test(',1 <- ;4400 SUB #1 copies a route parameter', () {
      final s = only('DO ,1 <- ;4400 SUB #1\n');
      expect((s.body as HostCall).service, HostService.paramToArray);
      expect((s.body as HostCall).arrays, [const VarRef(VarKind.tail, 1)]);
      expect(values(s.body), [1]);
    });

    test(',1 <- ;49221 SUB .2 copies a template argument back', () {
      final s = only('DO ,1 <- ;49221 SUB .2\n');
      expect((s.body as HostCall).service, HostService.argToArray);
      expect(values(s.body), ['.2']);
    });

    test(';49221 SUB #2 <- ,5 stores a string', () {
      final s = only('DO ;49221 SUB #2 <- ,5\n');
      expect((s.body as HostCall).service, HostService.arrayToArg);
      expect((s.body as HostCall).arrays, [const VarRef(VarKind.tail, 5)]);
      expect(values(s.body), [2]);
    });

    test(';49221 SUB #1 <- ;4400 SUB #2 moves a string between them', () {
      final s = only('DO ;49221 SUB #1 <- ;4400 SUB #2\n');
      expect((s.body as HostCall).service, HostService.paramToArg);
      expect(values(s.body), [1, 2]);
    });

    test('any other use is E822 when it runs', () {
      for (final misuse in [
        '.1 <- ;4400 SUB #1',
        ';49221 SUB #1 <- #5',
        ';4400 SUB #1 <- ,1',
        ';49221 <- #3',
        'STASH ;49221',
        'READ OUT ;4400 SUB #1',
        ';1 <- ;4400 SUB #1',
      ]) {
        final s = parse('DO $misuse\nPLEASE GIVE UP\n').first;
        expect(values(s.body), [822], reason: misuse);
        expect((s.body as HostCall).service, HostService.fault);
      }
    });

    test('a string as an index or row is E822 too', () {
      for (final misuse in [
        ',1 <- ;4400 SUB ;4400 SUB #1',
        ';49221 SUB ;4400 SUB #1 <- ,1',
        ';49221 SUB #1 <- ;49221 SUB ;4400 SUB #1',
        ";49221 <- 'FROM DATABASE #1~#1' SUB ;4400 SUB #1",
      ]) {
        final s = parse('DO $misuse\nPLEASE GIVE UP\n').first;
        expect(values(s.body), [822], reason: misuse);
      }
    });

    test(
      'E822 keeps the statement\'s gerund, so abstaining its kind skips it',
      () {
        expect(
          parse('DO .1 <- ;4400 SUB #1\nPLEASE GIVE UP\n').first.body.gerund,
          Gerund.calculating,
        );
        expect(
          parse('DO STASH ;49221\nPLEASE GIVE UP\n').first.body.gerund,
          Gerund.stashing,
        );
      },
    );
  });

  group('ActiveCassette (R7, Q145)', () {
    test('a read names a table, columns, a row and HAVING pairs', () {
      final s = only(
        "DO ;49221 <- 'FROM DATABASE #1~#3\$#4\$#5' SUB .7 HAVING #1 ,3 + #2 ;4400 SUB #1\n",
      );
      final call = s.body as HostCall;
      expect(call.service, HostService.read);
      expect(call.arrays, [const VarRef(VarKind.tail, 3)]);
      // table, 3 columns, row .7, 2 pairs: column 1 = array 0, column 2 = parameter #1.
      expect(values(call), [1, 3, 3, 4, 5, '.7', 2, 1, 1, 0, 2, 2, 1]);
    });

    test('without SUB a read takes the first row, and HAVING is optional', () {
      final s = only('DO ;49221 <- "FROM DATABASE #2~#1"\n');
      expect(values(s.body), [2, 1, 1, 1, 0]);
    });

    test('INTO DATABASE inserts, and with HAVING updates', () {
      final insert = only(
        r'DO INTO DATABASE #1~#2$#3 <- ,1 + .2'
        '\n',
      );
      expect((insert.body as HostCall).service, HostService.insert);
      expect(values(insert.body), [1, 2, 2, 3, 1, 0, 0, '.2']);
      final update = only(
        r'DO INTO DATABASE #1~#2 <- ,1 HAVING #1 #7'
        '\n',
      );
      expect((update.body as HostCall).service, HostService.update);
      expect(values(update.body), [1, 1, 2, 1, 0, 1, 1, 0, 7]);
    });

    test('INTO DATABASE needs one value per column (E827)', () {
      expect(
        () => parse(
          r'DO INTO DATABASE #1~#2$#3 <- ,1'
          '\nPLEASE GIVE UP\n',
        ),
        throwsA(
          isA<CompileError>()
              .having((e) => e.error.code, 'code', 827)
              .having((e) => e.statement, 'statement', 1),
        ),
      );
    });

    test('FORGET DATABASE names only a table', () {
      final s = parse(
        'DO FORGET DATABASE #1~#2 HAVING #1 #1\nPLEASE GIVE UP\n',
      );
      expect(s.first.body, isA<Undecodable>());
    });

    test(
      'a WHILE keeps what the front end needs to know (E827 still fires)',
      () {
        expect(
          () => parse(
            r'DO .1 <- #1 WHILE INTO DATABASE #1~#2$#3 <- ,1'
            '\nPLEASE GIVE UP\n',
          ),
          throwsA(isA<CompileError>().having((e) => e.error.code, 'code', 827)),
        );
      },
    );

    test('FORGET DATABASE deletes, and AMNESIA drops everything', () {
      final delete = only('DO FORGET DATABASE #4 HAVING #1 ,9\n');
      expect((delete.body as HostCall).service, HostService.delete);
      expect(delete.body.gerund, Gerund.forgetting);
      expect(values(delete.body), [4, 1, 1, 1, 0]);
      final amnesia = only('PLEASE DO AMNESIA\n');
      expect((amnesia.body as HostCall).service, HostService.amnesia);
    });

    test('a number that uses a string is E822 when it runs', () {
      final s = only(
        "DO ;49221 <- 'FROM DATABASE #1~#1' HAVING #1 ;4400 SUB #1~#1\n",
      );
      expect(values(s.body), [822]);
    });
  });

  group('the hello-world tolerances (Q141)', () {
    test('text before the first statement is a comment, not a statement', () {
      final s = parse(
        'NOTE At the start, handle the route.\n\nDO COME FROM (16000)\n',
      );
      expect(s, hasLength(1));
      expect(s.single.data, isA<RouteDecl>());
    });

    test('a comment that mentions a label is still only a comment', () {
      final s = parse('NOTE routes start at (16000).\nDO COME FROM (16000)\n');
      expect(s, hasLength(1));
    });

    test('nothing else from the site\'s other examples is accepted', () {
      // Example D's STASH with an assignment, and example B's bare READ OUT.
      final d = parse(
        "DO COME FROM (16000)\nPLEASE DO STASH ;49221 SUB #1 <- 'FROM DATABASE #0~#1' SUB #3\n",
      );
      expect(d.last.body, isA<Undecodable>());
      final b = parse(
        '(15) DO COME FROM (16000) WITH ROUTE "/home"\n(16) READ OUT #0 WITH TEMPLATE "home.html"\nPLEASE GIVE UP\n',
      );
      expect(b.first.body, isA<Undecodable>());
    });

    test('a bare GIVE UP is DO GIVE UP', () {
      final s = parse(
        'DO COME FROM (16000)\nPLEASE READ OUT #0 WITH TEMPLATE "hello.html"\nGIVE UP\n',
      );
      expect(s, hasLength(3));
      expect(s[1].data, isA<TemplateUse>());
      expect(s[2].body, isA<GiveUp>());
      expect(s[2].polite, isFalse);
    });
  });

  for (final backend in [ioiDart(), ioiLlvm()]) {
    group('${backend.name} runs', () {
      late Directory temp;
      setUp(() => temp = Directory.systemTemp.createTempSync('ioi-syntax-'));
      tearDown(() => temp.deleteSync(recursive: true));

      Future<ProcessResult> build(String program, List<String> flags) async {
        final source = File('${temp.path}/p.xc')..writeAsStringSync(program);
        final exe = '${temp.path}/p${Platform.isWindows ? '.exe' : ''}';
        final status = await runCli(
          ['build', '--no-random-bug', ...flags, source.path, '-o', exe],
          backend,
          frontend: InterstatesFrontend(),
        );
        expect(status, 0);
        return Process.run(exe, const []);
      }

      const program =
          'NOTE says hello\nDO COME FROM (16000)\nDO .1 <- #2\nPLEASE READ OUT .1\nGIVE UP\n';

      test('Q141: under -s, a leading NOTE and a bare GIVE UP work', () async {
        final run = await build(program, ['-s']);
        expect(
          run.stdout,
          'Status: 200 OK\nContent-Type: text/html; charset=utf-8\n\n'
          '  \nII\n',
        );
        expect(run.stderr, '');
        expect(run.exitCode, 0);
      });

      test('Q141: without -s they are what they always were', () async {
        // The NOTE is statement 1, undecodable, and the bare GIVE UP splatters the READ OUT.
        final run = await build(
          program.replaceFirst('DO COME FROM (16000)\n', ''),
          [],
        );
        expect(run.stderr, startsWith('ICL000I NOTE says hello'));
      });

      test('E827 stops the build at the INTO DATABASE', () async {
        final source = File('${temp.path}/p.xc')
          ..writeAsStringSync(
            'PLEASE DO .1 <- #1\nDO INTO DATABASE #1~#2\$#3 <- ,1\nDO GIVE UP\n',
          );
        final err = StringBuffer();
        final status = await IOOverrides.runZoned(
          () => runCli(
            ['build', '-s', source.path, '-o', '${temp.path}/p'],
            backend,
            frontend: InterstatesFrontend(),
          ),
          stderr: () => _Sink(err),
        );
        expect(err.toString(), interstatesError(827).format(2));
        expect(status, 827 % 256);
      });

      test('Q147: politeness still applies', () async {
        final source = File('${temp.path}/p.xc')
          ..writeAsStringSync('DO .1 <- #1\nDO .1 <- #2\nDO GIVE UP\n');
        final status = await runCli(
          ['build', '-s', source.path, '-o', '${temp.path}/p'],
          backend,
          frontend: InterstatesFrontend(),
        );
        expect(status, 79);
      });
    });
  }
}

class _Sink implements Stdout {
  _Sink(this.buffer);

  final StringBuffer buffer;

  @override
  void write(Object? object) => buffer.write(object);

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
