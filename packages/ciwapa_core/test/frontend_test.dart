import 'package:ciwapa_core/src/errors.dart';
import 'package:ciwapa_core/src/frontend.dart';
import 'package:ciwapa_core/src/source.dart';
import 'package:test/test.dart';

Program compile(
  String text, {
  String path = 'test.i',
  bool traditional = false,
}) => analyze(Source(path, text), traditional: traditional);

Matcher throwsIcl(int code, int statement) => throwsA(
  isA<CompileError>()
      .having((e) => e.error.code, 'code', code)
      .having((e) => e.statement, 'statement', statement),
);

/// [polite] polite statements followed by impolite ones, [total] in all.
String program(int polite, int total) => [
  for (var i = 0; i < total; i++) i < polite ? 'PLEASE GIVE UP' : 'DO GIVE UP',
].join('\n');

void main() {
  group('E998 and the base (decision T40)', () {
    test('an invalid extension is E998, reported against statement 1', () {
      expect(() => compile('DO GIVE UP', path: 'hello.c'), throwsIcl(998, 1));
    });

    test('the extension picks the base', () {
      expect(compile('DO GIVE UP', path: 'x.5i').base, 5);
    });

    test('the extension picks Mode 1 or EXTRACAL (decisions Q43, Q56)', () {
      expect(compile('DO GIVE UP', path: 'x.i').extracal, isFalse);
      expect(compile('DO GIVE UP', path: 'x.xc').extracal, isTrue);
      final tri = compile('DO GIVE UP', path: 'x.4xc');
      expect(tri.extracal, isTrue);
      expect(tri.base, 4);
    });

    test('a front end can supply the dialect for an extension of its own', () {
      expect(() => compile('DO GIVE UP', path: 'x.site'), throwsIcl(998, 1));
      final program = analyze(
        Source('x.site', 'DO GIVE UP'),
        dialect: const Dialect(2, extracal: true),
      );
      expect(program.extracal, isTrue);
      expect(program.base, 2);
    });
  });

  group('--traditional (decision T39)', () {
    test('bases other than 2 are E111', () {
      expect(
        () => compile('DO GIVE UP', path: 'x.3i', traditional: true),
        throwsIcl(111, 1),
      );
      expect(compile('DO GIVE UP', path: 'x.2i', traditional: true).base, 2);
    });

    test('COME FROM is E111 at the first COME FROM', () {
      expect(
        () =>
            compile('(1) DO GIVE UP\nPLEASE COME FROM (1)', traditional: true),
        throwsIcl(111, 2),
      );
    });
  });

  group('politeness (§10.4, decision T35)', () {
    test('fewer than 1/5 polite is E079', () {
      expect(() => compile(program(1, 6)), throwsIcl(79, 1));
      expect(() => compile(program(0, 3)), throwsIcl(79, 1));
    });

    test('more than 1/3 polite is E099', () {
      expect(() => compile(program(4, 11)), throwsIcl(99, 1));
      expect(() => compile(program(3, 3)), throwsIcl(99, 1));
    });

    test('exactly 1/5 and exactly 1/3 pass', () {
      expect(compile(program(1, 5)).statements, hasLength(5));
      expect(compile(program(2, 6)).statements, hasLength(6));
    });

    test('programs of 2 statements or fewer are not checked', () {
      expect(compile(program(0, 2)).statements, hasLength(2));
      expect(compile(program(2, 2)).statements, hasLength(2));
    });

    test('comments count as statements', () {
      final comments = List.filled(
        5,
        'DO NOTE THAT THIS IS A COMMENT',
      ).join('\n');
      expect(() => compile('PLEASE GIVE UP\n$comments'), throwsIcl(79, 1));
    });

    test('a PLEASE inside a comment starts a polite statement of its own', () {
      final statements = compile('DO GIVE UP\nDO NOTE PLEASE READ\nDO GIVE UP')
          .statements;
      expect(
        [for (final s in statements) s.polite],
        [false, false, true, false],
      );
    });

    test('PLEASE, whitespace, DO is one identifier', () {
      final statements = compile('DO GIVE UP\nDO NOTE PLEASE\nDO GIVE UP')
          .statements;
      expect([for (final s in statements) s.polite], [false, false, true]);
    });
  });

  group('labels', () {
    test('a duplicate label is E182 at the earliest statement with a duplicated label', () {
      expect(
        () => compile(
          '(1) PLEASE GIVE UP\n(2) DO GIVE UP\n(2) DO GIVE UP\n(1) DO GIVE UP',
        ),
        throwsIcl(182, 1),
      );
    });

    test(
      'invalid labels are not duplicates (they raise E197 when they execute)',
      () {
        expect(
          compile('(0) PLEASE GIVE UP\n(0) DO GIVE UP').statements,
          hasLength(2),
        );
      },
    );

    test('a COME FROM aimed at no label is E444', () {
      expect(
        () => compile('PLEASE COME FROM (7)\nDO GIVE UP'),
        throwsIcl(444, 1),
      );
    });

    test(
      'two COME FROMs aimed at one label is E555, abstained ones included',
      () {
        expect(
          () => compile(
            "(1) PLEASE GIVE UP\nDO COME FROM (1)\nDON'T COME FROM (1)",
          ),
          throwsIcl(555, 3),
        );
      },
    );

    test('labels on undecodable statements are still labels', () {
      expect(
        compile('(1) PLEASE NOTE THIS\nDO COME FROM (1)').statements,
        hasLength(2),
      );
    });
  });

  group("the checks run in 0.15's order", () {
    test('E998 before E111', () {
      expect(
        () => compile('DO GIVE UP', path: 'x.c', traditional: true),
        throwsIcl(998, 1),
      );
    });

    test('E111 before E079', () {
      expect(
        () => compile(
          '(1) DO GIVE UP\nDO COME FROM (1)\nDO GIVE UP',
          traditional: true,
        ),
        throwsIcl(111, 2),
      );
    });

    test('E079 before E182', () {
      expect(
        () => compile('(1) DO GIVE UP\n(1) DO GIVE UP\nDO GIVE UP'),
        throwsIcl(79, 1),
      );
    });

    test('E182 before E444', () {
      expect(
        () => compile('(1) PLEASE GIVE UP\n(1) DO GIVE UP\nDO COME FROM (9)'),
        throwsIcl(182, 1),
      );
    });

    test('E444 and E555 in statement order', () {
      expect(
        () => compile(
          '(1) PLEASE GIVE UP\nDO COME FROM (9)\nDO COME FROM (1)\nDO COME FROM (1)',
        ),
        throwsIcl(444, 2),
      );
      expect(
        () => compile(
          '(1) PLEASE GIVE UP\nDO COME FROM (1)\nDO COME FROM (1)\nDO COME FROM (9)',
        ),
        throwsIcl(555, 3),
      );
    });

    test('E555 before E997', () {
      expect(
        () => compile(
          '(1) PLEASE DO .1 <- .^1\nDO COME FROM (1)\nDO COME FROM (1)',
        ),
        throwsIcl(555, 3),
      );
    });

    test('a COME FROM aimed at an invalid label is E444', () {
      expect(
        () => compile('PLEASE COME FROM (0)\nDO GIVE UP'),
        throwsIcl(444, 1),
      );
      expect(
        () => compile('PLEASE COME FROM (70000)\nDO GIVE UP'),
        throwsIcl(444, 1),
      );
    });
  });

  group('E997 (§6.6, decision T40)', () {
    test('^ and @ are illegal in base 2', () {
      expect(
        () => compile('PLEASE DO .1 <- .^1\nDO GIVE UP'),
        throwsIcl(997, 1),
      );
      expect(
        () => compile('PLEASE DO .1 <- .@1\nDO GIVE UP', path: 'x.2i'),
        throwsIcl(997, 1),
      );
    });

    test('N@ needs N ≤ base − 2', () {
      expect(compile('PLEASE DO .1 <- .3@1', path: 'x.5i').base, 5);
      expect(
        () => compile('PLEASE DO .1 <- .4@1', path: 'x.5i'),
        throwsIcl(997, 1),
      );
      expect(
        () => compile('PLEASE DO .1 <- .2@1', path: 'x.3i'),
        throwsIcl(997, 1),
      );
      expect(compile('PLEASE DO .1 <- .@1', path: 'x.3i').base, 3);
    });

    test('operators inside comments are not checked', () {
      expect(compile('PLEASE NOTE MAIL@HOST^').statements, hasLength(1));
    });

    test('0@ is not an operator: the statement is undecodable', () {
      expect(
        compile(
          'PLEASE DO .1 <- .0@1',
          path: 'x.5i',
        ).statements.single.body.runtimeType.toString(),
        'Undecodable',
      );
    });
  });

  group('error messages (§9.1, decision T33)', () {
    test('have four lines: official text, joke, next statement, resubmit', () {
      final lines = IclError.of(633).format(43).split('\n');
      expect(
        lines[0],
        'ICL633I EXECUTION HAS PASSED BEYOND THE LAST STATEMENT OF THE PROGRAM.',
      );
      expect(lines[1], startsWith('        '));
      expect(lines[2], '\tON THE WAY TO STATEMENT 43');
      expect(lines[3], '        CORRECT SOURCE AND RESUBMIT');
      expect(lines[4], '');
    });

    test('use the literal §4 messages', () {
      expect(
        IclError.of(123).text,
        'PROGRAM HAS DISAPPEARED INTO THE BLACK LAGOON.',
      );
      expect(IclError.of(436).text, 'THROW STICK BEFORE RETRIEVING.');
      expect(IclError.of(275).text, "DON'T BYTE OFF MORE THAN YOU CAN CHEW.");
    });

    test('exit with the code mod 256 (decision T34)', () {
      expect(IclError.of(0).exitStatus, 0);
      expect(IclError.of(436).exitStatus, 180);
      expect(IclError.of(633).exitStatus, 121);
    });

    test('every code has its own joke', () {
      final jokes = IclError.all.map((e) => e.joke).toSet();
      expect(jokes, hasLength(IclError.all.length));
    });

    test(
      'E000 prints the statement lines, tab-indented, cut at 500 characters',
      () {
        expect(
          undecodableText(['(1) DO SOMETHING', '    ELSE']),
          '(1) DO SOMETHING\n\t    ELSE',
        );
        final long = undecodableText(['X' * 600]);
        expect(long, '${'X' * 500}...');
      },
    );
  });
}
