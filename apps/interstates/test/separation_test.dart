import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('R1, R3: nothing under packages/ names Interstates or .ioi files, '
      'ciwapa_lsp included', () {
    final naming = [
      for (final f in Directory('../../packages').listSync(recursive: true))
        if (f is File &&
            !f.path.contains('${Platform.pathSeparator}.dart_tool') &&
            RegExp(
              r'interstates|ioi[-_]|\.[2-7]?ioi\b',
              caseSensitive: false,
            ).hasMatch(String.fromCharCodes(f.readAsBytesSync())))
          f.path,
    ];
    expect(naming, isEmpty);
  });
}
