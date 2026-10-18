import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_core/src/extracal/blocks.dart';
import 'package:ciwapa_core/src/syslib/native.dart' show libraryRoutines;
import 'package:test/test.dart';

import '../tool/embed_extracal.dart';

/// The sources a program ends up with, by name.
Set<String> included(String path, String text) => {
  for (final s in analyze(Source(path, text)).statements) s.source.path,
};

void main() {
  test('the embedded copy matches lib/extracal', () {
    expect(
      File('lib/src/extracal/library.g.dart').readAsStringSync(),
      embed(sources()),
      reason: 'run `dart run tool/embed_extracal.dart`',
    );
  });

  test('every service fits the runtimes\' fixed registers', () {
    for (final MapEntry(:key, :value) in petitionServices.entries) {
      expect(value.scalars.length, lessThanOrEqualTo(4), reason: '#$key');
      expect(value.arrays.length, lessThanOrEqualTo(3), reason: '#$key');
    }
  });

  test('every block has a source', () {
    for (final block in libraryBlocks) {
      expect(block.source, contains('(${block.first})'), reason: block.name);
    }
  });

  group('auto-inclusion (R10, T36)', () {
    const callsSystem = 'DO (8000) NEXT\nPLEASE GIVE UP\n';

    test('a NEXT into a block brings it in', () {
      expect(included('p.xc', callsSystem), {'p.xc', 'system.xc'});
    });

    test('a program that defines a label in the block gets none of it', () {
      expect(included('p.xc', '$callsSystem(8999) DO GIVE UP\n'), {'p.xc'});
      expect(included('p.xc', 'DO (8999) NEXT\n(8999) PLEASE GIVE UP\n'), {
        'p.xc',
      });
    });

    test('a program that never NEXTs into a block gets none of it', () {
      expect(included('p.xc', 'PLEASE GIVE UP\n'), {'p.xc'});
    });

    test('only binary EXTRACAL programs get blocks (L17)', () {
      expect(included('p.i', callsSystem), {'p.i'});
      expect(included('p.3xc', callsSystem), {'p.3xc'});
    });

    test('a program can use the system library and a block together', () {
      expect(
        included('p.xc', 'DO (8000) NEXT\nDO (1000) NEXT\nPLEASE GIVE UP\n'),
        {'p.xc', 'system.xc', 'syslib.i'},
      );
    });
  });

  group('native library routines (R10, Q37)', () {
    Map<int, NativeLibraryCall> natives(String text) {
      final ir = lower(
        analyze(Source('p.xc', text)),
        options: const IrOptions(randomBug: false),
      );
      return {for (final c in findNativeLibraryCalls(ir).values) c.label: c};
    }

    test('INTERCAL routines and single PETITIONs have natives', () {
      final found = natives('DO (2200) NEXT\nDO (8000) NEXT\nPLEASE GIVE UP\n');
      expect(found.keys, containsAll([2000, 2200, 8000]));
      expect(found[2200]!.petition, isNull);
      expect(found[8000]!.petition, isNotNull);
      expect(found[2200]!.nexts.map((n) => n.$1), contains(2000));
    });

    test('every routine with a native version gets it', () {
      for (final label in libraryRoutines.keys) {
        final found = natives('DO ($label) NEXT\nPLEASE GIVE UP\n');
        expect(found.keys, contains(label), reason: '($label)');
      }
    });

    test('they watch what the INTERCAL touches that IGNORE can reach', () {
      final found = natives(
        'PLEASE IGNORE ,40 + .5\nDO (2200) NEXT\nDO GIVE UP\n',
      );
      expect(found[2200]!.watchedArrays.map((a) => '${a.ref}'), [',40']);
      expect(found[2200]!.watched.map((a) => '${a.ref}'), ['.5']);
    });

    test('they guard the statements an ABSTAIN can reach', () {
      final found = natives(
        'DO ABSTAIN FROM (2201)\nDO (2200) NEXT\nPLEASE GIVE UP\n',
      );
      expect(found[2200]!.abstainable, isNotEmpty);
    });

    test('a threaded program has none', () {
      final found = natives(
        '(1) DO (2200) NEXT\nDO COME FROM (1)\nPLEASE GIVE UP\n'
        'DO COME FROM (1)\nDO GIVE UP\n',
      );
      expect(found, isEmpty);
    });
  });
}
