import 'package:ciwapa_core/src/ast.dart';
import 'package:ciwapa_core/src/lexer.dart';
import 'package:ciwapa_core/src/parser.dart';
import 'package:ciwapa_core/src/source.dart';
import 'package:test/test.dart';

List<Statement> parse(String text) => Parser(Source('test.i', text)).parse();

Statement one(String text) {
  final statements = parse(text);
  expect(statements, hasLength(1), reason: 'expected one statement in: $text');
  return statements.single;
}

Expr rhs(String expression) {
  final s = one('DO .1 <- $expression');
  expect(s.body, isA<Calculate>(), reason: expression);
  return (s.body as Calculate).value;
}

bool undecodable(String text) => parse(text).first.body is Undecodable;

const samplePogram = '''
        DO (5) NEXT
    (5) DO FORGET #1
        PLEASE WRITE IN :1
        DO .1 <- '?":1~'#32768¢#0'"¢#1'~#3
        DO (1) NEXT
        DO :1 <- "'?":1~'#65535¢#0'"¢#65535'
                ~'#0¢#65535'"¢"'?":1~'#0¢#65535'"
                ¢#65535'~'#0¢#65535'"
        DO :2 <- #1
        PLEASE DO (4) NEXT
    (4) DO FORGET #1
        DO .1 <- "?':1~:2'¢#1"~#3
        DO :1 <- "'?":1~'#65535¢#0'"¢":2~'#65535
                ¢#0'"'~'#0¢#65535'"¢"'?":1~'#0
                ¢#65535'"¢":2~'#65535¢#0'"'~'#0¢#65535'"
        DO (1) NEXT
        DO :2 <- ":2~'#0¢#65535'"
                ¢"'":2~'#65535¢#0'"¢#0'~'#32767¢#1'"
        DO (4) NEXT
    (2) DO RESUME .1
    (1) PLEASE DO (2) NEXT
        PLEASE FORGET #1
        DO READ OUT :1
        PLEASE DO .1 <- '?"':1~:1'~#1"¢#1'~#3
        DO (3) NEXT
        PLEASE DO (5) NEXT
    (3) DO (2) NEXT
        PLEASE GIVE UP
''';

void main() {
  test(
    '§2.1: the sample program has 23 decodable statements, 7 of them polite',
    () {
      final statements = parse(samplePogram);
      expect(statements, hasLength(23));
      expect(statements.where((s) => s.body is Undecodable), isEmpty);
      expect(statements.where((s) => s.ungroupedChain), isEmpty);
      expect(statements.where((s) => s.polite), hasLength(7));
      expect(
        [for (final s in statements) s.label],
        [
          null,
          5,
          null,
          null,
          null,
          null,
          null,
          null,
          4,
          null,
          null,
          null,
          null,
          null, //
          2, 1, null, null, null, null, null, 3, null,
        ],
      );
      expect(statements[3].body.toString(), contains('Calculate'));
    },
  );

  group('§3.4.3 grouping (decisions T1–T3, Q97)', () {
    test('sparks and ears group', () {
      expect(rhs("'#165¢#203'~#358").toString(), r'(~ ($ #165 #203) #358)');
      expect(rhs("#165¢'#203~#358'").toString(), r'($ #165 (~ #203 #358))');
    });

    test('an ungrouped chain decodes but is flagged for E017', () {
      final s = one('DO .1 <- #165¢#203~#358');
      expect(s.body, isA<Calculate>());
      expect(s.ungroupedChain, isTrue);
    });

    test('a chain inside a group makes the statement undecodable (L4)', () {
      expect(one("DO .1 <- '#1¢#2~#3'").body, isA<Undecodable>());
      expect(one("DO .1 <- '#1¢#2~#3'¢#4").body, isA<Undecodable>());
      expect(one("DO .1 <- '#1¢#2'~#3").ungroupedChain, isFalse);
    });

    test('a unary operator after an opening grouper applies to the group', () {
      expect(rhs("'?#&123'").toString(), 'xor(and(#123))');
      expect(rhs("'?\"&#123\"'").toString(), 'xor(and(#123))');
    });

    test('the rabbit is just ears followed by a spot', () {
      expect(rhs('".1~.2"').toString(), '(~ .1 .2)');
    });

    test('junk after a chain makes the statement undecodable, not a chain', () {
      final s = parse('DO .1 <- #1¢#2~#3 JUNK DO GIVE UP').first;
      expect(s.body, isA<Undecodable>());
      expect(s.ungroupedChain, isFalse);
    });

    test('the wow is a spark followed by a spot', () {
      expect(rhs("!1~.2'").toString(), rhs("'.1~.2'").toString());
      expect(rhs("\"V!1¢.2'\"").toString(), rhs("'V.1¢.2'").toString());
    });

    test('a subscript list ends at the first binary operator (T2)', () {
      expect(rhs(',1SUB#1#1¢#1').toString(), r'($ (,1 SUB #1 #1) #1)');
      expect(rhs(',1 SUB #1 ~ #2').toString(), '(~ (,1 SUB #1) #2)');
    });

    test('a nested subscript takes the rest of the list', () {
      expect(
        rhs(',1 SUB ,2 SUB #1 #2 #3').toString(),
        '(,1 SUB (,2 SUB #1 #2 #3))',
      );
    });

    test('only the first subscript can be a group, so the third ambiguous example is undecodable', () {
      expect(
        undecodable('DO .1 <- ,1 SUB " ,2 SUB " ,3 SUB #1 " #2 " " #3 "'),
        isTrue,
      );
      expect(rhs(",1 SUB '#1~#2' #3").toString(), '(,1 SUB (~ #1 #2) #3)');
    });

    test('§12: alternating sparks and ears nest subscripts', () {
      expect(rhs("\",1SUB',2SUB#1'#2\"").toString(), '(,1 SUB (,2 SUB #1) #2)');
    });

    test(
      "§12: the Princeton compiler's restricted form parses the same way here",
      () {
        expect(rhs('",1SUB",2SUB#1"#2"').toString(), '(,1 SUB (,2 SUB #1) #2)');
      },
    );

    test('§4.4.1: the least-significant-bit example', () {
      final s = one("DO ,1SUB#1#1 <- '?,1SUB#1#1¢#1'~'#0¢#65535'");
      final body = s.body as Calculate;
      expect(body.target.toString(), '(,1 SUB #1 #1)');
      expect(
        body.value.toString(),
        r'(~ xor(($ (,1 SUB #1 #1) #1)) ($ #0 #65535))',
      );
    });

    test('§4.4.1: the two dimensioning statements differ', () {
      final a =
          one("DO ;7 <- #7 BY .7 BY \",7SUB#7\"¢':7~#7'").body as Dimension;
      final b =
          one("DO ;7 <- #7 BY .7 BY ,7SUB\"#7¢':7~#7'\"").body as Dimension;
      expect(a.dimensions.last.toString(), r'($ (,7 SUB #7) (~ :7 #7))');
      expect(b.dimensions.last.toString(), r'(,7 SUB ($ #7 (~ :7 #7)))');
    });
  });

  group('§3.4.2 unary operators (decision T4)', () {
    test('go between the type character and the number', () {
      expect(rhs('.&123').toString(), 'and(.123)');
      expect(rhs('#?123').toString(), 'xor(#123)');
      expect(rhs(':V1').toString(), 'or(:1)');
    });

    test('on an array name they apply to the element', () {
      expect(rhs(',&7SUB#1').toString(), 'and((,7 SUB #1))');
    });

    test('cannot be concatenated or prefixed', () {
      expect(undecodable('DO .1 <- #V&123'), isTrue);
      expect(undecodable('DO .1 <- &.1'), isTrue);
    });

    test('the overpunches spell XOR and mingle', () {
      expect(rhs('#V\b-77').toString(), 'xor(#77)');
      expect(rhs('#-\bV77').toString(), 'xor(#77)');
      expect(rhs('#1c\b/#2').toString(), r'($ #1 #2)');
      expect(rhs(r'#1$#2').toString(), r'($ #1 #2)');
    });

    test(
      'TriINTERCAL operators lex in any base; the checks reject them in base 2',
      () {
        expect(rhs('.@3').toString(), 'whirlpool(.3)');
        expect(rhs('.2@3').toString(), 'whirlpool2(.3)');
        expect(rhs('.^3').toString(), 'sharkfin(.3)');
        expect(rhs('.23').toString(), '.23');
      },
    );
  });

  group('§4.1 format (decisions T5–T7)', () {
    test('free format: statements share lines and span lines', () {
      expect(parse('DO .1 <- #1 DO .2\n<-\n#2'), hasLength(2));
    });

    test('spaces inside a number join its digits', () {
      expect(rhs('#1 2').toString(), '#12');
      expect(one('( 1 2 3 ) DO GIVE UP').label, 123);
      expect(one('DO % 5 0 GIVE UP').percent, 50);
    });

    test('multi-word keywords may drop their spaces', () {
      for (final text in [
        'DO READOUT .1',
        'DO GIVEUP',
        'DO WRITEIN .1',
        'DO COMEFROM (1)',
        'PLEASEDO GIVE UP',
      ]) {
        expect(undecodable(text), isFalse, reason: text);
      }
      expect(one('PLEASEDO GIVE UP').polite, isTrue);
    });

    test('single words and the angle-worm cannot be split', () {
      expect(undecodable('DO FOR GET #1'), isTrue);
      expect(undecodable('DO .1 < - #1'), isTrue);
    });

    test('tabs and newlines separate tokens like spaces', () {
      expect(undecodable('DO\t.1\t<-\n#1'), isFalse);
    });

    test('lowercase is undecodable', () {
      expect(undecodable('DO give up'), isTrue);
    });
  });

  group('§4.3 identifiers and qualifiers (decisions T11–T13)', () {
    test('DO PLEASE is polite', () {
      expect(one('DO PLEASE GIVE UP').polite, isTrue);
      expect(one('DO GIVE UP').polite, isFalse);
    });

    test("NOT and N'T", () {
      for (final text in [
        "DON'T GIVE UP",
        'DO NOT GIVE UP',
        "PLEASE DON'T GIVE UP",
        'PLEASE NOT GIVE UP',
      ]) {
        final s = one(text);
        expect(s.not, isTrue, reason: text);
        expect(s.body, isA<GiveUp>(), reason: text);
      }
    });

    test('NOT comes before the percentage', () {
      expect(one('DO NOT %50 GIVE UP').percent, 50);
      expect(undecodable('DO %50 NOT GIVE UP'), isTrue);
    });

    test('percentages above 100 still decode (E017 fires when the statement executes)', () {
      expect(one('DO %101 GIVE UP').percent, 101);
      expect(one('DO %0 GIVE UP').percent, 0);
    });
  });

  group('§4.5 comments and undecodable statements (decisions T8–T10, T15)', () {
    test('a NOT comment is undecodable, abstained and polite', () {
      final s = one('PLEASE NOTE THAT THIS LINE HAS NO EFFECT');
      expect(s.not, isTrue);
      expect(s.body, isA<Undecodable>());
    });

    test('DO is recognized mid-word', () {
      final statements = parse('PLEASE NOTE THAT THIS LINE DOES NOTHING');
      expect(statements, hasLength(2));
      expect(statements.every((s) => s.body is Undecodable), isTrue);
    });

    test('D-space-O is not an identifier', () {
      final statements = parse(
        "(123) DON'T YOU REALIZE THIS STATEMENT SHOULD ONLY BE ENCOUNTERED\n    ONCE?\nPLEASE REINSTATE (123)",
      );
      expect(statements, hasLength(2));
      expect(statements[0].label, 123);
      expect(statements[0].not, isTrue);
      expect(statements[0].body, isA<Undecodable>());
      expect(statements[1].body, isA<AbstainBody>());
    });

    test('junk after a complete statement makes it undecodable', () {
      final statements = parse('DO GIVE UP JUNK DO GIVE UP');
      expect(statements, hasLength(2));
      expect(statements[0].body, isA<Undecodable>());
      expect(statements[1].body, isA<GiveUp>());
      expect(undecodable('DO GIVE UP * DO GIVE UP'), isTrue);
    });

    test(
      'a label after garbage starts the next statement, keeping its label',
      () {
        final statements = parse('DO HELLO (5) DO GIVE UP');
        expect(statements, hasLength(2));
        expect(statements[1].label, 5);
        expect(statements[1].body, isA<GiveUp>());
      },
    );

    test(
      'a label without an identifier is swallowed by the statement before it',
      () {
        final statements = parse('DO GIVE UP (5) HELLO DO GIVE UP');
        expect(statements, hasLength(2));
        expect(statements[0].body, isA<Undecodable>());
        expect(statements[1].label, isNull);
      },
    );

    test(
      'garbage before the first statement is a statement with no identifier',
      () {
        final statements = parse('HELLO DO GIVE UP');
        expect(statements, hasLength(2));
        expect(statements[0].hasIdentifier, isFalse);
        expect(statements[0].body, isA<Undecodable>());
      },
    );

    test('a statement has at most one label', () {
      final statements = parse('(1) (2) DO GIVE UP');
      expect(statements, hasLength(2));
      expect(statements[0].hasIdentifier, isFalse);
      expect(statements[1].label, 2);
      expect(statements[1].body, isA<GiveUp>());
    });

    test('TONSIL characters with no use make their statement undecodable', () {
      for (final c in [
        '=',
        '`',
        '|',
        '>',
        '[',
        ']',
        '{',
        '}',
        '_',
        '/',
        r'\',
        '¬',
        '*',
      ]) {
        expect(undecodable('DO .1 <- #1 $c'), isTrue, reason: c);
      }
    });

    test('an undecodable statement keeps its label and qualifiers', () {
      final s = one("(7) DON'T %30 EAT THE SPEC");
      expect(
        [s.label, s.not, s.percent, s.body is Undecodable],
        [7, true, 30, true],
      );
    });
  });

  group('statements', () {
    test('every statement type decodes', () {
      final bodies = parse('''
        DO .1 <- #1 DO ,1 <- #3 BY .1 DO (1) NEXT DO FORGET #1 DO RESUME #1
        DO STASH .1+:2+,3+;4 DO RETRIEVE .1 DO IGNORE ,3 DO REMEMBER ;4
        DO ABSTAIN FROM (1) DO ABSTAIN FROM CALCULATING + READING OUT + COMING FROM
        DO REINSTATE (1) DO REINSTATE NEXTING DO WRITE IN .1+,2SUB#1+,3
        DO READ OUT .1+#2+,3SUB#1+;4 DO GIVE UP DO COME FROM (1)
      ''').map((s) => s.body.runtimeType.toString());
      expect(bodies, [
        'Calculate', 'Dimension', 'Next', 'Forget', 'Resume', //
        'VarListBody', 'VarListBody', 'VarListBody', 'VarListBody',
        'AbstainBody', 'AbstainBody', 'AbstainBody', 'AbstainBody', 'IoBody',
        'IoBody', 'GiveUp', 'ComeFrom',
      ]);
    });

    test('gerund lists', () {
      final s =
          one('PLEASE ABSTAIN FROM IGNORING + FORGETTING').body as AbstainBody;
      expect(s.gerunds, [Gerund.ignoring, Gerund.forgetting]);
      expect((one('DO REINSTATE WRITINGIN').body as AbstainBody).gerunds, [
        Gerund.writingIn,
      ]);
    });

    test('invalid forms are undecodable', () {
      for (final text in [
        'DO STASH ,1 SUB #1',
        'DO ABSTAIN FROM (1) + CALCULATING',
        'DO ABSTAIN FROM GIVING UP',
        'DO REINSTATE GIVING UP',
        'DO REINSTATE .1',
        'DO WRITE IN #1',
        'DO READ OUT .1~.2',
        'DO .&1 <- #1',
        'DO .1 <- ,1',
        'DO .1 <- #1 #2',
      ]) {
        expect(undecodable(text), isTrue, reason: text);
      }
    });
  });

  group('CREATE and just-in-case compilation (R3)', () {
    List<Statement> xc(String text) =>
        Parser(Source('test.xc', text), extensions: true).parse();

    test(
      'an undecodable statement of letters and operands has a signature',
      () {
        final body = xc('DO SWITCH .1 WITH ,2 SUB #1 AND ,3 OR #4~.5')
            .single
            .body;
        expect(body, isA<Unknown>());
        expect((body as Unknown).signature, 'SWITCH.WITH;AND,OR~');
        expect(body.operands, hasLength(4));
        expect(body.operands[2], isA<ArrayItem>());
      },
    );

    test('two operands in a row, or a keyword, keep a statement a comment', () {
      expect(xc('DO FOO .1 .2').single.body, isA<Undecodable>());
      expect(xc('DO FOO .1 FROM .2').single.body, isA<Undecodable>());
      // A trailing ONCE attaches; without a CREATE, the front end makes it a comment again.
      final once = xc('PLEASE NOTE THIS RUNS ONCE').single;
      expect(once.body, isA<Unknown>());
      expect(once.onceAgain, OnceAgain.once);
    });

    test('Mode 1 has no unknown statements', () {
      expect(parse('DO SWITCH .1 WITH .2').single.body, isA<Undecodable>());
    });

    test('CREATE takes a template or an operator', () {
      final statement = xc('DO CREATE (5) SWITCH .1 WITH .2').single.body;
      expect(statement, isA<Create>());
      expect((statement as Create).signature, 'SWITCH.WITH.');
      expect(statement.label, 5);
      final operator = xc('DO CREATE (6) x').single.body as Create;
      expect(operator.signature, 'u78');
      final computed = xc('DO CREATE .5 =').single.body as Create;
      expect(computed.signature, 'u3d');
      expect(computed.target, isA<Scalar>());
      final overstrike = xc('DO CREATE (7) o\b-').single.body as Create;
      expect(overstrike.signature, 'o2dx6f');
    });

    test('a computed CREATE template starts with a letter', () {
      final body = xc('DO CREATE .5~.6 TWICE .1').single.body as Create;
      expect(body.target, isA<Binary>());
      expect(body.signature, 'TWICE.');
    });

    test('a created operator parses like a mingle', () {
      final s = xc('DO .1 <- #1 x .2').single.body as Calculate;
      expect(s.value, isA<CreatedOp>());
      expect((s.value as CreatedOp).signature, 'u78');
    });
  });
}
