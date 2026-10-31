import 'package:ciwapa_core/ciwapa_core.dart';

import 'help.dart';
import 'model.dart';
import 'routines.dart';

/// A file a program depends on that isn't a program, such as a template it renders, and what the
/// extension finds in it. Its places are rune offsets in [text].
class Companion {
  const Companion(
    this.path,
    this.reference, {
    this.text,
    this.diagnostics = const [],
    this.hovers = const [],
  });

  /// The file, as a path like the program's own.
  final String path;

  /// Where the program names it, for go to definition.
  final Span reference;

  /// The text it was checked as, or null when it can't be read.
  final String? text;

  final List<CompanionDiagnostic> diagnostics;
  final List<CompanionHover> hovers;
}

/// An error in a companion file, with a word about which program found it.
typedef CompanionDiagnostic = ({CompileError error, Span span, String? note});

typedef CompanionHover = ({Span span, String markdown});

/// An inlay hint the extension adds to a program: after rune offset [offset].
typedef ExtensionHint = ({int offset, String label, String? tooltip});

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

  /// The companion files [program], at [path], depends on. [textOf] is the text of a file the
  /// editor has open, by path, which wins over what is on disk.
  List<Companion> companionsOf(
    String path,
    Program program,
    String? Function(String path) textOf,
  ) => const [];

  /// Inlay hints of its own for a file of [path]'s kind.
  List<ExtensionHint> inlayHintsFor(String path, SyntaxModel model) => const [];
}
