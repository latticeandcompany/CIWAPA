import 'package:ciwapa_core/ciwapa_core.dart';

import 'help.dart';
import 'model.dart';
import 'routines.dart';

/// What a compiler built on CIWAPA's adds to the language server beyond its `Frontend`: the words
/// for its own errors and library routines, written in Dart like the server's own (R4). The
/// server never learns which compiler it is serving.
class LanguageExtension {
  const LanguageExtension();

  /// Help for its own errors, by code.
  Map<int, ErrorHelp> get errorHelp => const {};

  /// Its own library routines, by label, for files of [path]'s kind.
  Map<int, RoutineDoc> routinesFor(String path) => const {};

  /// Hover text for a label no routine documents, such as an entry point the compiler provides.
  String? labelHelp(String path, int label) => null;

  /// Its own library blocks, which its front end includes as EXTRACAL's are included.
  List<LibraryBlock> get libraries => const [];

  /// Where go to definition takes a label the file doesn't define, such as an entry point; null
  /// to leave it to the libraries.
  List<Span>? definitionsOf(String path, int label, SyntaxModel model) => null;

  /// The words that start its own statements, for completion after an identifier in files of
  /// [path]'s kind.
  List<String> keywordsFor(String path) => const [];
}
