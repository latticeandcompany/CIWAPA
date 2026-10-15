import 'dart:ffi';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:runtime_c/runtime_c.dart';

import 'emitter.dart';

/// Where clang comes from, and how to call it.
class Toolchain {
  Toolchain(this.clang, this.triple, this.flags, this.description);

  final String clang;

  /// The exact target triple the emitted IR declares.
  final String triple;
  final List<String> flags;
  final String description;

  /// `CIWAPA_CLANG` wins; then the toolchain bundled next to this executable (clang + lld + a
  /// musl sysroot on Linux, llvm-mingw on Windows); then `clang` on the PATH, which on macOS is
  /// Apple clang from the Command Line Tools.
  static Toolchain find() {
    final exe = Platform.isWindows ? '.exe' : '';
    final override = Platform.environment['CIWAPA_CLANG'];
    if (override != null && override.isNotEmpty) {
      return Toolchain(
        override,
        _hostTriple(musl: false),
        const [],
        'clang from CIWAPA_CLANG',
      );
    }
    final root = File(Platform.resolvedExecutable).parent.parent.path;
    final sep = Platform.pathSeparator;
    final bundled = '$root${sep}toolchain${sep}bin${sep}clang$exe';
    if (File(bundled).existsSync()) {
      if (Platform.isLinux) {
        return Toolchain(bundled, _hostTriple(musl: true), [
          '--sysroot=$root${sep}toolchain${sep}sysroot',
          '-static',
          '-fuse-ld=lld',
          '-rtlib=compiler-rt',
          '-unwindlib=none',
        ], 'bundled clang + lld + musl');
      }
      return Toolchain(
        bundled,
        _hostTriple(musl: false),
        const [],
        'bundled llvm-mingw',
      );
    }
    return Toolchain(
      'clang$exe',
      _hostTriple(musl: false),
      const [],
      'clang from the PATH',
    );
  }

  static String _hostTriple({required bool musl}) => switch (Abi.current()) {
    Abi.linuxX64 => 'x86_64-unknown-linux-${musl ? 'musl' : 'gnu'}',
    Abi.linuxArm64 => 'aarch64-unknown-linux-${musl ? 'musl' : 'gnu'}',
    Abi.macosArm64 => 'arm64-apple-macosx11.0.0',
    Abi.windowsX64 => 'x86_64-w64-windows-gnu',
    Abi.windowsArm64 => 'aarch64-w64-windows-gnu',
    final abi => throw ToolchainException('$abi is not a supported platform'),
  };
}

/// Builds programs by compiling the emitted IR together with runtime.c.
class LlvmBackend implements Backend {
  LlvmBackend() : toolchain = Toolchain.find();

  final Toolchain toolchain;

  @override
  String get name => 'ciwapa-llvm';

  @override
  String get extension => 'll';

  @override
  Map<String, String> emit(IrProgram program, EmitOptions options) => {
    'main.ll': LlvmEmitter(program, options, toolchain.triple).emit(),
    'runtime.c': runtimeC,
  };

  @override
  Future<void> compile(
    Directory dir,
    String output, {
    required bool optimize,
  }) async {
    final result = await _run(toolchain.clang, [
      '--target=${toolchain.triple}',
      ...toolchain.flags,
      optimize ? '-O2' : '-O0',
      '-w',
      'main.ll',
      'runtime.c',
      '-o',
      File(output).absolute.path,
    ], workingDirectory: dir.path);
    if (result.exitCode != 0) {
      throw ToolchainException('${result.stdout}${result.stderr}');
    }
  }

  @override
  Future<List<(bool, String)>> doctor() async {
    final version = await _run(toolchain.clang, [
      '--version',
    ]).then<ProcessResult?>((r) => r).catchError((_) => null);
    if (version == null || version.exitCode != 0) {
      return [
        (false, 'cannot run ${toolchain.clang} (${toolchain.description})'),
        if (Platform.isMacOS)
          (
            false,
            'install the Command Line Tools with: xcode-select --install',
          ),
      ];
    }
    final checks = [
      (
        true,
        '${toolchain.description}: ${toolchain.clang} (${'${version.stdout}'.split('\n').first.trim()})',
      ),
    ];
    checks.add((true, 'target: ${toolchain.triple}'));
    final temp = Directory.systemTemp.createTempSync('ciwapa-doctor-');
    try {
      File('${temp.path}/main.ll').writeAsStringSync(
        'target triple = "${toolchain.triple}"\n'
        'define i32 @main() {\n  ret i32 0\n}\n',
      );
      File('${temp.path}/runtime.c').writeAsStringSync(runtimeC);
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
