import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

IrProgram build(
  String text, {
  String path = 'test.i',
  IrOptions options = const IrOptions(randomBug: false),
}) => lower(analyze(Source(path, text)), options: options);

List<int> faults(IrStatement s) => [for (final f in s.faults) f.code];

void main() {
  group('ordinals and the next-statement map (decision T33)', () {
    test(
      'a plain statement is followed by the next ordinal; the last by last + 1',
      () {
        final ir = build('DO .1 <- #1\nDO .2 <- #2');
        expect([for (final s in ir.statements) s.next], [2, 3]);
      },
    );

    test('a NEXT is followed by its target', () {
      final ir = build('PLEASE DO (3) NEXT\nDO GIVE UP\n(3) DO RESUME #1');
      expect(ir.at(1).next, 3);
      expect((ir.at(1).op as IrNext).target, 3);
    });

    test('a COME FROM target is followed by the COME FROM', () {
      final ir = build('(1) DO .1 <- #1\nDO GIVE UP\nPLEASE COME FROM (1)');
      expect(ir.at(1).next, 3);
      expect(ir.at(1).comeFrom, 3);
      expect(ir.at(2).comeFrom, isNull);
    });

    test('a NEXT to a missing label faults with E129 and is followed by the next statement', () {
      final ir = build('DO (9) NEXT\nDO GIVE UP');
      expect(faults(ir.at(1)), [129]);
      expect(ir.at(1).next, 2);
    });
  });

  group('statement-local faults fire when the statement executes (decisions Q80, Q81)', () {
    test('a constant above the small maximum is E017', () {
      expect(faults(build('DO .1 <- #65536').at(1)), [17]);
      expect(faults(build('DO .1 <- #65535').at(1)), isEmpty);
      expect(faults(build('DO .1 <- #59049', path: 't.3i').at(1)), [17]);
      expect(faults(build('DO .1 <- #59048', path: 't.3i').at(1)), isEmpty);
    });

    test('a variable numbered 0 or above 65535 is E200', () {
      expect(faults(build('DO .0 <- #1').at(1)), [200]);
      expect(faults(build('DO .1 <- ,65536SUB#1').at(1)), [200]);
      expect(faults(build('DO .0001 <- #1').at(1)), isEmpty);
    });

    test('a label of 0 or above 65535 is E197', () {
      expect(faults(build('(0) DO GIVE UP').at(1)), [197]);
      expect(faults(build('(65536) DO GIVE UP').at(1)), [197]);
    });

    test('an ungrouped chain and a percentage above 100 are E017', () {
      expect(faults(build('DO .1 <- #1~#2~#3').at(1)), [17]);
      final s = build('DO %101 GIVE UP').at(1);
      expect(faults(s), [17]);
      expect(s.percent, isNull);
    });

    test('ABSTAIN and REINSTATE of a missing label are E139', () {
      expect(faults(build('DO ABSTAIN FROM (5)').at(1)), [139]);
      expect(faults(build('DO REINSTATE (5)').at(1)), [139]);
    });

    test('faults keep source order', () {
      expect(faults(build('(0) DO %200 .0 <- #70000').at(1)), [
        197,
        17,
        200,
        17,
      ]);
    });
  });

  group('static types (decisions Q77, Q79)', () {
    IrExpr value(String e) => (build('DO :1 <- $e').at(1).op as IrAssign).value;

    test(
      'spot, tail and mesh are small; two-spot, hybrid and mingle are large',
      () {
        expect(value('.1').large, isFalse);
        expect(value(',1SUB#1').large, isFalse);
        expect(value('#1').large, isFalse);
        expect(value(':1').large, isTrue);
        expect(value(';1SUB#1').large, isTrue);
        expect(value(r'#1$#2').large, isTrue);
      },
    );

    test('a select has the type of its right operand', () {
      expect(value(':1~.2').large, isFalse);
      expect(value('.1~:2').large, isTrue);
    });

    test('a unary operator has the type of its operand', () {
      expect(value(r"'&#1$#2'").large, isTrue);
      expect(value('.&1').large, isFalse);
    });
  });

  group('ABSTAIN analysis (decisions T20, T21)', () {
    test('gerund targets: CALCULATING covers dimensioning, ABSTAINING covers both forms', () {
      final ir = build('''
        DO .1 <- #1
        DO ,1 <- #2
        PLEASE ABSTAIN FROM (1)
        DO ABSTAIN FROM CALCULATING + ABSTAINING
        PLEASE REINSTATE NEXTING
        (1) DO GIVE UP
      ''');
      expect((ir.at(4).op as IrAbstain).targets, [1, 2, 3, 4]);
      expect((ir.at(5).op as IrAbstain).targets, isEmpty);
    });

    test(
      'ABSTAIN of a GIVE UP by label works; REINSTATE of one does nothing',
      () {
        final ir = build(
          'PLEASE ABSTAIN FROM (1)\nDO REINSTATE (1)\n(1) DO GIVE UP',
        );
        expect((ir.at(1).op as IrAbstain).targets, [3]);
        expect((ir.at(2).op as IrAbstain).targets, isEmpty);
      },
    );

    test('only NOT and ABSTAIN make a statement abstainable', () {
      final ir = build(
        "DON'T GIVE UP\nDO .1 <- #1\n(1) DO .2 <- #2\nPLEASE ABSTAIN FROM (1)\nDO REINSTATE CALCULATING",
      );
      expect(
        [for (final s in ir.statements) s.abstainable],
        [true, false, true, false, false],
      );
    });
  });

  group('E774 placement (decision T23)', () {
    final program = [
      for (var i = 0; i < 2000; i++)
        i % 4 == 0 ? 'PLEASE DO .1 <- #1' : 'DO .1 <- #1',
    ].join('\n');

    test('is off with --no-random-bug', () {
      expect(build(program).statements.where((s) => s.bug), isEmpty);
    });

    test('plants about 1 in 128 statements, reproducibly with a seed', () {
      List<int> bugs(int seed) => [
        for (final s in build(
          program,
          options: IrOptions(seed: seed),
        ).statements)
          if (s.bug) s.ordinal,
      ];
      expect(bugs(7), bugs(7));
      expect(bugs(7), isNot(bugs(8)));
      expect(bugs(7).length, inInclusiveRange(5, 35));
    });
  });

  test('undecodable statements keep their whole source lines', () {
    final ir = build("DO .1 <- #1 DO GARBAGE\n  MORE GARBAGE\nPLEASE GIVE UP");
    expect(
      (ir.at(2).op as IrUndecodable).text,
      'DO .1 <- #1 DO GARBAGE\n\t  MORE GARBAGE',
    );
  });

  test('limits per base (§6.4, decision T40)', () {
    expect(
      [for (var b = 2; b <= 7; b++) smallMax(b)],
      [65535, 59048, 65535, 15624, 46655, 16806],
    );
    expect(
      [for (var b = 2; b <= 7; b++) largeMax(b)],
      [4294967295, 3486784400, 4294967295, 244140624, 2176782335, 282475248],
    );
  });
}
