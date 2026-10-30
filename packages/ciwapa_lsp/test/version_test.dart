import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'R3, Q179: the version the server reports is the compilers\' version',
    () {
      for (final package in [
        'ciwapa_core',
        'ciwapa_dart',
        'ciwapa_llvm',
        'ciwapa_lsp',
      ]) {
        final pubspec = File('../$package/pubspec.yaml').readAsStringSync();
        expect(
          RegExp(
            r'^version: *(\S+)',
            multiLine: true,
          ).firstMatch(pubspec)!.group(1),
          ciwapaVersion,
          reason: package,
        );
      }
    },
  );
}
