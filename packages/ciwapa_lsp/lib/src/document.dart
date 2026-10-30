import 'package:ciwapa_core/ciwapa_core.dart';

import 'library_docs.g.dart';
import 'model.dart';
import 'routines.dart';
import 'server.dart';
import 'text.dart';

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

  /// The labels the file's own statements carry.
  Set<int> get definedLabels => {
    for (final s in model.statements) ?s.statement.label,
  };

  /// The library routine [label] names, when the file doesn't define it and its library comes
  /// with files like this one: the system library with every binary file, EXTRACAL's with
  /// EXTRACAL files, and those of the language built on CIWAPA's (decisions T36, L9, L17).
  RoutineDoc? libraryRoutine(int label) {
    final program = analysis.program;
    if (program.base != 2 || definedLabels.contains(label)) return null;
    return server.extension.routinesFor(path)[label] ??
        _systemRoutines[label] ??
        (program.extracal ? _extracalRoutines[label] : null);
  }

  void update(String newText, int newVersion) {
    text = EditorText(path, newText);
    version = newVersion;
    invalidate();
  }

  void invalidate() {
    _analysis = null;
    _model = null;
  }
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
