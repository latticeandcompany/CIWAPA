import 'help.dart';
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
}
