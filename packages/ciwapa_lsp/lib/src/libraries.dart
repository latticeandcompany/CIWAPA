import 'package:ciwapa_core/ciwapa_core.dart';

import 'text.dart';

/// A library's source, served read-only as `ciwapa-lib:/<name>` (R6, Q165): the editor fetches its
/// text with `intercal/librarySource`, so nothing is written to disk.
class LibraryDocument {
  LibraryDocument(this.name, String source) : text = EditorText(name, source) {
    final extensions = name.endsWith('.xc');
    final parser = Parser(
      text.source,
      wide: extensions,
      extensions: extensions,
    );
    final statements = parser.parse();
    final tokens = parser.tokens;
    for (final s in statements) {
      final label = s.label;
      if (label == null) continue;
      final token = tokens.firstWhere((t) => t.start == s.start);
      labels.putIfAbsent(label, () => Span(token.start, token.end));
    }
  }

  static const scheme = 'ciwapa-lib';

  final String name;
  final EditorText text;

  /// Where each label is defined.
  final labels = <int, Span>{};

  String get uri => '$scheme:/$name';
}
