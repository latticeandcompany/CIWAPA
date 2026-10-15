import 'dart:io';
import 'dart:typed_data';

import 'package:ciwapa_dart/runtime/runtime.dart';
import 'package:test/test.dart';

import '../tool/embed_runtime.dart';

void main() {
  setUpAll(
    () => ickInit(
      const [],
      base: 2,
      clockface: false,
      arrayCount: 0,
      values: Uint32List(0),
      ignored: Uint8List(0),
      messages: const {},
    ),
  );

  test('§3.4.1 mingle goldens', () {
    expect(ickMingle(65535, 0, 0), 2863311530);
    expect(ickMingle(0, 65535, 0), 1431655765);
    expect(ickMingle(255, 255, 0), 65535);
    expect(ickMingle(0, 256, 0), 65536);
  });

  test('§3.4.1 select goldens', () {
    expect(ickSelect(179, 201), 9);
    expect(ickSelect(201, 179), 17);
    expect(ickSelect(179, 179), 31);
    expect(ickSelect(201, 201), 15);
  });

  test('§3.4.2 unary goldens', () {
    expect(ickAnd16(77), 4);
    expect(ickOr16(77), 32879);
    expect(ickXor16(77), 32875);
  });

  test('32-bit unary operators rotate through bit 31', () {
    expect(ickXor32(1), 0x80000001);
    expect(ickOr32(0x80000000), 0xC0000000);
    expect(ickAnd32(0xFFFFFFFF), 0xFFFFFFFF);
  });

  test('§3.4.3 grouping goldens', () {
    expect(ickSelect(ickMingle(165, 203, 0), 358), 15);
    expect(ickMingle(165, ickSelect(203, 358), 0), 34915);
  });

  test('the embedded copy matches runtime.dart', () {
    expect(
      File('lib/src/runtime_source.g.dart').readAsStringSync(),
      embed(File('lib/runtime/runtime.dart').readAsStringSync()),
      reason: 'run `dart run tool/embed_runtime.dart`',
    );
  });
}
