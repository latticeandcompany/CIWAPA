import 'dart:io';

import 'package:args/args.dart';

import 'errors.dart';
import 'frontend.dart';
import 'ir.dart';
import 'source.dart';

/// Compile-time options that reach the generated program.
class EmitOptions {
  const EmitOptions({
    required this.clockface,
    required this.optimize,
    required this.sourceName,
  });

  /// `--clockface`: IIII instead of IV (§10.2, decision T30).
  final bool clockface;

  /// False with `--no-opt` (§10.2, decision Q101).
  final bool optimize;

  /// The source file's name, for the generated file's header.
  final String sourceName;
}

/// A toolchain step failed. The CLI reports it as E778, after the tool's own output.
class ToolchainException implements Exception {
  ToolchainException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a flavor contributes: code generation, and the toolchain that turns the code into an
/// executable.
abstract interface class Backend {
  /// The command name, `ciwapa-dart` or `ciwapa-llvm`.
  String get name;

  /// The generated main file's extension, without the dot.
  String get extension;

  /// The generated files, by name. The first entry is the main file.
  Map<String, String> emit(IrProgram program, EmitOptions options);

  /// Builds the files in [dir] into the executable [output].
  Future<void> compile(Directory dir, String output, {required bool optimize});

  /// Describes the toolchain this flavor will use and whether it works, one line per check.
  Future<List<(bool, String)>> doctor();
}

/// Runs the `build`, `run` and `doctor` commands (decisions Q100, Q101) and returns the exit status.
Future<int> runCli(List<String> arguments, Backend backend) async {
  final parser = _parser();
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(
      '${backend.name}: ${e.message}\n\n${_usage(backend, parser)}',
    );
    return 64;
  }
  final command = args.rest.isEmpty ? null : args.rest.first;
  if (args.flag('help') || command == null) {
    stdout.writeln(_usage(backend, parser));
    return command == null && !args.flag('help') ? 64 : 0;
  }
  switch (command) {
    case 'doctor':
      return _doctor(backend);
    case 'build' || 'run':
      if (args.rest.length < 2) {
        stderr.writeln(
          '${backend.name} $command: which file?\n\n${_usage(backend, parser)}',
        );
        return 64;
      }
      try {
        return await _build(backend, args, command == 'run');
      } on _Exit catch (e) {
        return e.status;
      }
    default:
      stderr.writeln(
        '${backend.name}: unknown command "$command"\n\n${_usage(backend, parser)}',
      );
      return 64;
  }
}

ArgParser _parser() => ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Print this usage information.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    valueHelp: 'path',
    help: 'Where `build` writes the executable.',
  )
  ..addFlag(
    'traditional',
    negatable: false,
    help: 'INTERCAL-72 only: COME FROM and other bases are E111 (ick -t).',
  )
  ..addFlag(
    'no-random-bug',
    negatable: false,
    help: 'Never plant the E774 random compiler bug (ick -b).',
  )
  ..addFlag(
    'clockface',
    negatable: false,
    help: 'Print IIII instead of IV (ick -C).',
  )
  ..addOption('seed', valueHelp: 'n', help: 'Seed where E774 bugs are planted.')
  ..addFlag(
    'keep',
    negatable: false,
    help: 'Keep the generated source next to the executable (ick -c).',
  )
  ..addOption(
    'dump',
    allowed: ['ast', 'ir'],
    help: 'Print the parse or the IR to stdout (ick -d).',
  )
  ..addFlag(
    'no-opt',
    negatable: false,
    help: 'Turn off optimization, which is on by default.',
  );

String _usage(Backend backend, ArgParser parser) =>
    '''
Usage:
  ${backend.name} build <file.i> [-o <executable>] [options]
  ${backend.name} run <file.i> [options] [-- <program arguments>]
  ${backend.name} doctor

Options:
${parser.usage}''';

Future<int> _doctor(Backend backend) async {
  final checks = await backend.doctor();
  for (final (ok, line) in checks) {
    stdout.writeln('${ok ? 'ok     ' : 'PROBLEM'} $line');
  }
  return checks.every((c) => c.$1) ? 0 : 1;
}

/// Unwinds to [runCli] with an exit status, so that every `finally` (and its temp-dir cleanup) runs.
class _Exit implements Exception {
  _Exit(this.status);

  final int status;
}

Never _fail(IclError error, int statement, {String? detail}) {
  if (detail != null && detail.isNotEmpty) {
    stderr.write(detail.endsWith('\n') ? detail : '$detail\n');
  }
  stderr.write(error.format(statement));
  throw _Exit(error.exitStatus);
}

Future<int> _build(Backend backend, ArgResults args, bool run) async {
  final path = args.rest[1];
  final programArgs = run ? args.rest.skip(2).toList() : const <String>[];
  if (!run && args.rest.length > 2) {
    stderr.writeln(
      '${backend.name} build: unexpected arguments: ${args.rest.skip(2).join(' ')}',
    );
    return 64;
  }
  final seed = args.option('seed');
  if (seed != null && int.tryParse(seed) == null) {
    stderr.writeln('${backend.name}: --seed needs a whole number, not "$seed"');
    return 64;
  }
  final file = File(path);
  final List<int> bytes;
  try {
    bytes = file.readAsBytesSync();
  } on FileSystemException {
    _fail(IclError.of(777), 1);
  }

  final IrProgram ir;
  try {
    final program = analyze(
      Source.fromBytes(path, bytes),
      traditional: args.flag('traditional'),
    );
    if (args.option('dump') == 'ast') stdout.write(_dumpAst(program));
    ir = lower(
      program,
      options: IrOptions(
        randomBug: !args.flag('no-random-bug'),
        seed: seed == null ? null : int.tryParse(seed),
      ),
    );
    if (args.option('dump') == 'ir') stdout.writeln(ir.dump());
  } on CompileError catch (e) {
    _fail(e.error, e.statement);
  }

  final name = file.uri.pathSegments.last;
  final stem = name.substring(0, name.lastIndexOf('.'));
  final exe = Platform.isWindows ? '.exe' : '';
  final options = EmitOptions(
    clockface: args.flag('clockface'),
    optimize: !args.flag('no-opt'),
    sourceName: name,
  );
  final Map<String, String> files;
  try {
    files = backend.emit(ir, options);
  } on ToolchainException catch (e) {
    _fail(IclError.of(778), 1, detail: e.message);
  }

  final Directory temp;
  try {
    temp = Directory.systemTemp.createTempSync('ciwapa-');
  } on FileSystemException {
    _fail(IclError.of(888), 1);
  }
  try {
    final output = run
        ? '${temp.path}${Platform.pathSeparator}$stem$exe'
        : _executableName(args.option('output') ?? stem);
    try {
      for (final MapEntry(:key, :value) in files.entries) {
        File('${temp.path}${Platform.pathSeparator}$key')
            .writeAsStringSync(value);
      }
      if (args.flag('keep')) {
        final kept = run ? stem : _withoutExe(output);
        File('$kept.${backend.extension}')
            .writeAsStringSync(files.values.first);
      }
    } on FileSystemException {
      _fail(IclError.of(888), 1);
    }
    // The output has to be writable before the toolchain runs; otherwise it would fail as E778.
    // An existing file is only opened for appending, so a failed build never empties it.
    final outputFile = File(output);
    final placeholder = !outputFile.existsSync();
    try {
      outputFile.openSync(mode: FileMode.append).closeSync();
    } on FileSystemException {
      _fail(IclError.of(888), 1);
    }
    try {
      await backend.compile(temp, output, optimize: options.optimize);
    } on ToolchainException catch (e) {
      if (placeholder) outputFile.deleteSync();
      _fail(IclError.of(778), 1, detail: e.message);
    }
    if (outputFile.lengthSync() == 0) {
      outputFile.deleteSync();
      _fail(IclError.of(888), 1);
    }
    if (!run) return 0;
    final process = await Process.start(
      output,
      programArgs,
      mode: ProcessStartMode.inheritStdio,
    );
    // Ctrl-C reaches the program; ignoring it here lets the temp dir be cleaned up afterwards.
    final interrupts = ProcessSignal.sigint.watch().listen((_) {});
    try {
      return await process.exitCode;
    } finally {
      await interrupts.cancel();
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// On Windows an executable gets `.exe` unless it already has an extension, as clang's MinGW
/// driver would do anyway; both flavors then write the same file.
String _executableName(String path) {
  if (!Platform.isWindows) return path;
  final name = path.split(RegExp(r'[\\/]')).last;
  return name.contains('.') ? path : '$path.exe';
}

String _withoutExe(String path) =>
    path.endsWith('.exe') ? path.substring(0, path.length - 4) : path;

String _dumpAst(Program program) {
  final buffer = StringBuffer();
  for (final (i, s) in program.statements.indexed) {
    buffer.writeln(
      [
        '${i + 1}',
        if (s.label != null) '(${s.label})',
        s.polite ? 'PLEASE' : 'DO',
        if (s.not) 'NOT',
        if (s.percent != null) '%${s.percent}',
        s.body.runtimeType,
      ].join(' '),
    );
  }
  return buffer.toString();
}
