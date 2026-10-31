import 'package:ciwapa_core/ciwapa_core.dart';

import 'extension.dart';
import 'libraries.dart';
import 'library_docs.g.dart';
import 'model.dart';
import 'routines.dart';
import 'server.dart';
import 'text.dart';

const systemLibrary = LibraryBlock('syslib.i', 1000, 1999, syslibSource);

final _systemRoutines = parseRoutineTables(
  libraryTables['system library']!,
  'system library',
);
final _extracalRoutines = parseRoutineTables(
  libraryTables['EXTRACAL library']!,
  'EXTRACAL library',
);

/// An open document, and what the front end makes of it with the server's current settings.
class Document {
  Document(this.uri, String text, this.version, this.server)
    : text = EditorText(pathOf(uri), text);

  final String uri;
  final LanguageServer server;
  EditorText text;
  int version;
  Analysis? _analysis;
  SyntaxModel? _model;

  String get path => text.path;

  /// Whether the server's front end compiles this kind of file.
  bool get handled => server.frontend.handles(path);

  /// The front end's analysis, made on first use after each change. Full-text sync: the front end
  /// is fast enough to start over every time.
  Analysis get analysis => _analysis ??= server.frontend.analyzeAll(
    text.source,
    traditional: server.settings.traditional,
  );

  SyntaxModel get model => _model ??= SyntaxModel(analysis.program);

  /// The files the program depends on that aren't programs, such as templates (R10).
  List<Companion> get companions => _companions ??= server.extension
      .companionsOf(path, analysis.program, server.textOfPath);
  List<Companion>? _companions;

  /// The labels the file's own statements carry.
  Set<int> get definedLabels => {
    for (final s in model.statements) ?s.statement.label,
  };

  /// The labels of the library statements the compiler included (decisions T36, L9, L17): a
  /// block comes in when a NEXT asks for it and the file defines no label in its range.
  Set<int> get includedLabels {
    final program = analysis.program;
    return {
      for (final s in program.statements.skip(program.userStatements)) ?s.label,
    };
  }

  /// The library routine [label] names, when the compiler included the routine's library.
  RoutineDoc? libraryRoutine(int label) {
    if (!includedLabels.contains(label)) return null;
    return server.extension.routinesFor(path)[label] ??
        _systemRoutines[label] ??
        (analysis.program.extracal ? _extracalRoutines[label] : null);
  }

  /// Every library routine the file could call, by label: those of the libraries that come with
  /// files like this one, except for a library in whose range the file defines a label (T36).
  Map<int, RoutineDoc> get libraryRoutines {
    final program = analysis.program;
    if (program.base != 2) return const {};
    final own = definedLabels;
    final shut = [
      for (final block in server.knownLibraries)
        if (own.any((l) => l >= block.first && l <= block.last)) block,
    ];
    return {
      if (program.extracal) ..._extracalRoutines,
      ..._systemRoutines,
      ...server.extension.routinesFor(path),
    }..removeWhere(
      (label, _) => shut.any((b) => label >= b.first && label <= b.last),
    );
  }

  /// The library blocks the compiler included for this file.
  List<LibraryBlock> get includedLibraries {
    final program = analysis.program;
    final included = {
      for (final s in program.statements.skip(program.userStatements))
        s.source.path,
    };
    return [
      for (final block in server.knownLibraries)
        if (included.contains(block.name)) block,
    ];
  }

  /// The library document that defines [label] for this file: one the compiler included, as for
  /// [libraryRoutine].
  LibraryDocument? libraryOf(int label) {
    if (!includedLabels.contains(label)) return null;
    for (final block in includedLibraries) {
      if (label >= block.first && label <= block.last) {
        return server.library(block);
      }
    }
    return null;
  }

  void update(String newText, int newVersion) {
    text = EditorText(path, newText);
    version = newVersion;
    invalidate();
  }

  void invalidate() {
    _analysis = null;
    _model = null;
    _companions = null;
  }

  /// A companion's text changed, so what the extension says about it might have.
  void invalidateCompanions() => _companions = null;
}

/// The file path a `file:` URI names, in this platform's form. Other schemes keep their path,
/// which still ends in the file's extension.
String pathOf(String uri) {
  final parsed = Uri.parse(uri);
  if (parsed.scheme != 'file') return parsed.path;
  try {
    return parsed.toFilePath();
  } on UnsupportedError {
    return parsed.path;
  }
}
