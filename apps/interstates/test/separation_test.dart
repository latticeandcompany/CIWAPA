import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('R1: nothing under packages/ names Interstates', () {
    final naming = [
      for (final f in Directory('../../packages').listSync(recursive: true))
        if (f is File &&
            !f.path.contains('${Platform.pathSeparator}.dart_tool') &&
            RegExp(
              'interstates|ioi-',
              caseSensitive: false,
            ).hasMatch(String.fromCharCodes(f.readAsBytesSync())))
          f.path,
    ];
    expect(naming, isEmpty);
  });
}
