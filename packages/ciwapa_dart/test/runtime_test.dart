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
      arrayCount: 1,
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

  test(
    '§5.2, T31: after the end of input, the next character reads as itself + 1',
    () {
      final input = [0x41, -1, 0x42].iterator;
      ickReadByte = () => input.moveNext() ? input.current : -1;
      ickDimension(0, [3], 0);
      ickTuringIn(0, 0);
      expect(ickArrayData(0), [65, 256, 67]);
    },
  );

  test('§5.2, T31: Turing Text output is flushed at a newline', () {
    final sink = <List<int>>[];
    ickWriteBytes = sink.add;
    ickDimension(0, [2], 0);
    // 0x82 and 0x50 are "A" and "\n" with their bits reversed.
    ickArrayData(0)
      ..[0] = (0 - 0x82) & 0xFF
      ..[1] = (0x82 - 0x50) & 0xFF;
    ickTuringOut(0, 0);
    expect(sink, [
      [0x41, 0x0A],
    ]);
  });

  test('the embedded copy matches runtime.dart', () {
    expect(
      File('lib/src/runtime_source.g.dart').readAsStringSync(),
      embed(File('lib/runtime/runtime.dart').readAsStringSync()),
      reason: 'run `dart run tool/embed_runtime.dart`',
    );
  });
}
