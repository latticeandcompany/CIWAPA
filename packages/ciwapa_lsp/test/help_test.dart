import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/src/help.dart';
import 'package:test/test.dart';

import '../tool/embed_docs.dart' as embed;

void main() {
  test('R4: every one of CIWAPA\'s errors has a description and a fix', () {
    for (final error in IclError.all) {
      final help = errorHelp[error.code];
      expect(help, isNotNull, reason: 'E${error.code}');
      expect(help!.description, isNotEmpty);
      expect(help.fix, isNotEmpty);
    }
    expect(errorHelp.keys.toSet(), {for (final e in IclError.all) e.code});
  });

  test('R4: the embedded library tables match the libraries\' READMEs', () {
    expect(
      embed.generate(),
      File('lib/src/library_docs.g.dart').readAsStringSync(),
      reason: 'run dart run tool/embed_docs.dart',
    );
  });
}
