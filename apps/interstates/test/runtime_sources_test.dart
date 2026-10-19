import 'dart:io';

import 'package:test/test.dart';

import '../tool/embed_runtime.dart';

void main() {
  test('runtime_sources.g.dart is up to date', () {
    expect(
      File('lib/src/runtime_sources.g.dart').readAsStringSync(),
      embed(
        hostDart: File('lib/runtime/ioi_host.dart').readAsStringSync(),
        hostC: File('runtime/host.c').readAsStringSync(),
        adapterHeader: File('runtime/ioi_adapter.h').readAsStringSync(),
        sqliteAdapter: File('runtime/sqlite_adapter.c').readAsStringSync(),
        activecassette: File('runtime/activecassette.c').readAsStringSync(),
        library: File('runtime/interstates.xc').readAsStringSync(),
        databaseLibrary: File('runtime/activecassette.xc').readAsStringSync(),
      ),
      reason: 'run `dart run tool/embed_runtime.dart`',
    );
  });

  test('host.c declares runtime.c\'s ick_host exactly', () {
    String struct(String path) {
      final text = File(path).readAsStringSync();
      final body = RegExp(r'typedef struct \{([^}]*)\} ick_host;')
          .firstMatch(text)!
          .group(1)!;
      return body
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    expect(
      struct('runtime/host.c'),
      struct('../../packages/runtime_c/runtime.c'),
    );
  });
}
