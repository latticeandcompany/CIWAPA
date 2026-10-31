// Regenerates lib/src/library_docs.g.dart from the system library's and EXTRACAL's READMEs: their
// headings and tables, which the server's hovers read (R4).
//   dart run tool/embed_docs.dart
import 'dart:io';

import 'package:ciwapa_lsp/ciwapa_lsp.dart';

String generate() => generateLibraryTables({
  'system library': File('../ciwapa_core/lib/src/syslib/README.md')
      .readAsStringSync(),
  'EXTRACAL library': File('../ciwapa_core/lib/extracal/README.md')
      .readAsStringSync(),
}, 'tool/embed_docs.dart');

void main() =>
    File('lib/src/library_docs.g.dart').writeAsStringSync(generate());
