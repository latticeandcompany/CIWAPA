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
        library: File('runtime/interstates.xc').readAsStringSync(),
      ),
      reason: 'run `dart run tool/embed_runtime.dart`',
    );
  });
}
