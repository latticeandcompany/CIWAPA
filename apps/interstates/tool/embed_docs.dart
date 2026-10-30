// Regenerates lib/src/library_docs.g.dart from this app's README: the tables of the library
// blocks, which the language server's hovers read (R4).
//   dart run tool/embed_docs.dart
import 'dart:io';

import 'package:ciwapa_lsp/ciwapa_lsp.dart';

String generate() => generateLibraryTables({
  'Interstates library': File('README.md').readAsStringSync(),
}, 'tool/embed_docs.dart');

void main() =>
    File('lib/src/library_docs.g.dart').writeAsStringSync(generate());
