import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_core/src/syslib/native.dart' show syslibDepth;
import 'package:test/test.dart';

import '../tool/embed_syslib.dart';

IrProgram build(
  String text, {
  String path = 'test.i',
  IrOptions options = const IrOptions(randomBug: false),
}) => lower(analyze(Source(path, text)), options: options);

int ordinalOf(IrProgram ir, int label) =>
    ir.statements.firstWhere((s) => s.label == label).ordinal;

Map<int, NativeCall> nativesByLabel(IrProgram ir) => {
  for (final call in findNativeCalls(ir).values) call.label: call,
};

String names(Iterable<Slot> slots) =>
    slots.map((s) => '${s.ref.kind.sigil}${s.ref.number}').join(' ');

void main() {
  test('the embedded copy matches syslib.i', () {
    expect(
      File('lib/src/syslib/syslib.g.dart').readAsStringSync(),
      embed(File('lib/src/syslib/syslib.i').readAsStringSync()),
      reason: 'run `dart run tool/embed_syslib.dart`',
    );
  });

  group('automatic inclusion (§7.3, decision T36)', () {
    test(
      'a NEXT into 1000–1999 appends the library after the user statements',
      () {
        final ir = build('DO (1000) NEXT\nPLEASE GIVE UP');
        expect(ir.userStatements, 2);
        expect(ir.statements.length, greaterThan(2));
        expect((ir.at(1).op as IrNext).target, ordinalOf(ir, 1000));
        expect(ordinalOf(ir, 1000), 3);
      },
    );

    test('an ABSTAIN aimed at a library label does not include it', () {
      final ir = build('DO ABSTAIN FROM (1000)\nPLEASE GIVE UP');
      expect(ir.statements.length, 2);
      expect([for (final f in ir.at(1).faults) f.code], [139]);
    });

    test('a user label in 1000–1999 keeps the library out', () {
      final ir = build('DO (1000) NEXT\n(1500) PLEASE GIVE UP');
      expect(ir.statements.length, 2);
      expect([for (final f in ir.at(1).faults) f.code], [129]);
    });

    test('bases 3–7 never include the binary library (QUESTIONS.md L9)', () {
      final ir = build('DO (1000) NEXT\nPLEASE GIVE UP', path: 'test.3i');
      expect(ir.statements.length, 2);
      expect([for (final f in ir.at(1).faults) f.code], [129]);
    });
  });

  group('native fast paths (decision Q37)', () {
    test('every routine with a depth is a library entry', () {
      final ir = build('DO (1000) NEXT\nPLEASE GIVE UP');
      final labels = {for (final s in ir.statements) s.label};
      expect(labels.containsAll(syslibDepth.keys), isTrue);
    });

    test('a plain program gets every arithmetic routine natively', () {
      final natives = nativesByLabel(build('DO (1009) NEXT\nPLEASE GIVE UP'));
      expect(natives.keys, unorderedEquals(syslibDepth.keys));
      final add = natives[1009]!;
      expect(names(add.args), '.1 .2');
      expect(names([add.result]), '.3');
      expect(names([add.flag!]), '.4');
      expect(add.depth, 4);
      expect(add.watched, isEmpty);
      expect(natives[1050]!.args.map((s) => s.ref.kind), [
        VarKind.twoSpot,
        VarKind.spot,
      ]);
    });

    test('a program without the library has no native calls', () {
      expect(findNativeCalls(build('DO .1 <- #1\nPLEASE GIVE UP')), isEmpty);
    });

    test('a COME FROM aimed inside a routine disables every routine that reaches it', () {
      final natives = nativesByLabel(
        build('DO (1009) NEXT\nPLEASE DO COME FROM (1601)\nDO GIVE UP'),
      );
      expect(natives.keys, isNot(contains(1009)));
      expect(natives.keys, isNot(contains(1500)));
      expect(natives.keys, containsAll([1060, 1520, 1525]));
    });

    test(
      'an ABSTAIN aimed at a library label guards the routines that reach it',
      () {
        final ir = build(
          'DO (1009) NEXT\nPLEASE ABSTAIN FROM (1990)\nDO GIVE UP',
        );
        final natives = nativesByLabel(ir);
        expect(natives[1009]!.abstainable, [ordinalOf(ir, 1990)]);
        expect(natives[1060]!.abstainable, isEmpty);
      },
    );

    test(
      'a REINSTATE alone can never abstain anything, so it guards nothing',
      () {
        final natives = nativesByLabel(
          build('DO (1009) NEXT\nPLEASE REINSTATE (1990)\nDO GIVE UP'),
        );
        expect(natives[1009]!.abstainable, isEmpty);
      },
    );

    test('a gerund that matches library statements guards every routine that has one', () {
      final calculating = build(
        'DO (1060) NEXT\nPLEASE ABSTAIN FROM CALCULATING\nDO GIVE UP',
      );
      final natives = nativesByLabel(calculating);
      expect(natives.keys, unorderedEquals(syslibDepth.keys));
      expect(natives[1060]!.abstainable, [ordinalOf(calculating, 1060)]);
      final nexting = nativesByLabel(
        build('DO (1060) NEXT\nPLEASE ABSTAIN FROM NEXTING\nDO GIVE UP'),
      );
      expect(nexting[1060]!.abstainable, isEmpty);
      expect(nexting[1009]!.abstainable, isNotEmpty);
    });

    test('an IGNOREd variable the routine touches is watched', () {
      final natives = nativesByLabel(
        build('DO (1009) NEXT\nPLEASE IGNORE .5\nDO GIVE UP'),
      );
      expect(names(natives[1009]!.watched), '.5');
      expect(natives[1060]!.watched, isEmpty);
    });

    test('a bug planted inside a routine disables it', () {
      const text = 'DO (1009) NEXT\nPLEASE GIVE UP';
      for (var seed = 0; ; seed++) {
        final ir = build(text, options: IrOptions(seed: seed));
        final bugged = ir.at(ordinalOf(ir, 1601)).bug;
        final bitwise = ordinalOf(ir, 1060);
        final quiet = [
          for (var o = bitwise; o < ordinalOf(ir, 1500); o++) ir.at(o),
        ].every((s) => !s.bug);
        if (!bugged || !quiet) continue;
        final natives = nativesByLabel(ir);
        expect(natives.keys, isNot(contains(1009)));
        expect(natives.keys, containsAll([1060, 1070, 1080]));
        return;
      }
    });
  });

  group('live library statements', () {
    test('only what the user NEXTs into can run', () {
      final ir = build('DO (1060) NEXT\nPLEASE GIVE UP');
      final first = ordinalOf(ir, 1060);
      expect(liveLibrary(ir), {first, first + 1});
    });

    test(
      'a RESUME that can be abstained falls through to the statements after it',
      () {
        final ir = build(
          'DO (1060) NEXT\nPLEASE ABSTAIN FROM RESUMING\nDO GIVE UP',
        );
        expect(liveLibrary(ir), contains(ordinalOf(ir, 1070)));
        expect(liveLibrary(ir), contains(ir.statements.length));
      },
    );

    test('nothing is live without a NEXT into the library', () {
      expect(liveLibrary(build('DO .1 <- #1\nPLEASE GIVE UP')), isEmpty);
    });
  });
}
