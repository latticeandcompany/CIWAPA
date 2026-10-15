import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'emitter.dart';
import 'runtime_source.g.dart';

/// Builds programs with `dart compile exe`, using the bundled Dart SDK when there is one.
class DartBackend implements Backend {
  @override
  String get name => 'ciwapa-dart';

  @override
  String get extension => 'dart';

  @override
  Map<String, String> emit(IrProgram program, EmitOptions options) => {
    'main.dart': DartEmitter(program, options).emit(),
    'runtime.dart': runtimeSource,
  };

  /// `CIWAPA_DART` wins; then the SDK bundled next to this executable; then the `dart` running
  /// this compiler (under `dart run`); then `dart` on the PATH.
  static String findDart() {
    final override = Platform.environment['CIWAPA_DART'];
    if (override != null && override.isNotEmpty) return override;
    final dartExe = Platform.isWindows ? 'dart.exe' : 'dart';
    final self = File(Platform.resolvedExecutable);
    final bundled = File(
      [
        self.parent.parent.path,
        'dart-sdk',
        'bin',
        dartExe,
      ].join(Platform.pathSeparator),
    );
    if (bundled.existsSync()) return bundled.path;
    if (self.uri.pathSegments.last == dartExe) return self.path;
    return dartExe;
  }

  @override
  Future<void> compile(
    Directory dir,
    String output, {
    required bool optimize,
  }) async {
    final result = await _run(findDart(), [
      '--suppress-analytics',
      'compile',
      'exe',
      'main.dart',
      '-o',
      File(output).absolute.path,
    ], workingDirectory: dir.path);
    if (result.exitCode != 0) {
      throw ToolchainException('${result.stdout}${result.stderr}');
    }
  }

  @override
  Future<List<(bool, String)>> doctor() async {
    final dart = findDart();
    final checks = <(bool, String)>[];
    final version = await _run(dart, ['--version']);
    if (version.exitCode != 0) {
      return [(false, 'cannot run the Dart SDK at $dart')];
    }
    checks.add((
      true,
      'Dart SDK: $dart (${'${version.stdout}${version.stderr}'.trim()})',
    ));
    final temp = Directory.systemTemp.createTempSync('ciwapa-doctor-');
    try {
      final stray = _strayPubspec(temp);
      checks.add(
        stray == null
            ? (true, 'no pubspec.yaml above ${temp.parent.path}')
            : (false, '$stray would make `dart compile exe` run `pub get`'),
      );
      File('${temp.path}/main.dart')
          .writeAsStringSync("void main() => print('ok');");
      try {
        await compile(
          temp,
          '${temp.path}/hello${Platform.isWindows ? '.exe' : ''}',
          optimize: true,
        );
        checks.add((true, 'compiled a test program'));
      } on ToolchainException catch (e) {
        checks.add((false, 'could not compile a test program:\n$e'));
      }
    } finally {
      temp.deleteSync(recursive: true);
    }
    return checks;
  }

  static String? _strayPubspec(Directory start) {
    for (
      var dir = start.absolute;
      dir.parent.path != dir.path;
      dir = dir.parent
    ) {
      final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
      if (pubspec.existsSync()) return pubspec.path;
    }
    return null;
  }

  static Future<ProcessResult> _run(
    String exe,
    List<String> args, {
    String? workingDirectory,
  }) async {
    try {
      return await Process.run(exe, args, workingDirectory: workingDirectory);
    } on ProcessException catch (e) {
      throw ToolchainException('cannot run $exe: ${e.message}');
    }
  }
}
