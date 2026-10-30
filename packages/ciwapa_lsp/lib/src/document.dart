import 'package:ciwapa_core/ciwapa_core.dart';

import 'server.dart';
import 'text.dart';

/// An open document, and what the front end makes of it with the server's current settings.
class Document {
  Document(this.uri, String text, this.version, this.server)
    : text = EditorText(pathOf(uri), text);

  final String uri;
  final LanguageServer server;
  EditorText text;
  int version;
  Analysis? _analysis;

  String get path => text.path;

  /// Whether the server's front end compiles this kind of file.
  bool get handled => server.frontend.handles(path);

  /// The front end's analysis, made on first use after each change. Full-text sync: the front end
  /// is fast enough to start over every time.
  Analysis get analysis => _analysis ??= server.frontend.analyzeAll(
    text.source,
    traditional: server.settings.traditional,
  );

  void update(String newText, int newVersion) {
    text = EditorText(path, newText);
    version = newVersion;
    invalidate();
  }

  void invalidate() => _analysis = null;
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
