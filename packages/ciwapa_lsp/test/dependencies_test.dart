import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'R3, Q169: ciwapa_lsp depends on CIWAPA\'s core alone, and tests with test',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      List<String> section(String name) {
        final match = RegExp(
          '^$name:\\n((?:  .*\\n)*)',
          multiLine: true,
        ).firstMatch(pubspec);
        return [
          for (final line in (match?.group(1) ?? '').split('\n'))
            if (line.trim().isNotEmpty) line.trim().split(':').first,
        ];
      }

      expect(section('dependencies'), ['ciwapa_core']);
      expect(section('dev_dependencies'), ['test']);
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        for (final import in RegExp(
          r"^import '([^']+)'",
          multiLine: true,
        ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!)) {
          expect(
            import.startsWith('dart:') ||
                import.startsWith('package:ciwapa_core/') ||
                !import.contains(':'),
            isTrue,
            reason: '${file.path} imports $import',
          );
        }
      }
    },
  );
}
