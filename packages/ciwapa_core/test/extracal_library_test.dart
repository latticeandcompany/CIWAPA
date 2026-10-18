import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_core/src/extracal/blocks.dart';
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
      expect(included('p.xc', '${callsSystem}(8999) DO GIVE UP\n'), {'p.xc'});
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
}
