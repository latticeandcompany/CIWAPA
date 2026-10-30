import 'dart:io';

import 'package:args/args.dart';

import 'analysis.dart';
import 'errors.dart';
import 'frontend.dart';
import 'frontend.dart' as core show analyze;
import 'ir.dart';
import 'ir.dart' as core show lower;
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

/// How a CLI turns a source file into IR. [CiwapaFrontend] is CIWAPA's own; a compiler built on
/// CIWAPA can add options and language of its own on top.
abstract interface class Frontend {
  /// What the usage message calls a source file.
  String get sourceDescription;

  /// Adds this front end's options to the CLI's.
  void addOptions(ArgParser parser);

  /// Why the options can't be used together, or null when they can. The CLI prints it and exits 64.
  String? checkOptions(ArgResults args);

  /// Parses [source] and runs the whole-program checks, throwing [CompileError] on failure.
  Program analyze(
    Source source,
    ArgResults args, {
    required bool traditional,
    int? memoryLimit,
  });

  /// Lowers a checked [program] to the IR the backend emits.
  IrProgram lower(Program program, ArgResults args, IrOptions options);

  /// Whether an editor should send this front end [path], by its extension.
  bool handles(String path);

  /// Every error in [source], for an editor (R2), with the settings an editor passes. The random
  /// bug is never planted.
  Analysis analyzeAll(Source source, {required bool traditional});
}

/// CIWAPA's own front end: Mode 1 and EXTRACAL, picked by the file extension.
class CiwapaFrontend implements Frontend {
  const CiwapaFrontend();

  @override
  String get sourceDescription => 'file.i or file.xc';

  @override
  void addOptions(ArgParser parser) {}

  @override
  String? checkOptions(ArgResults args) => null;

  @override
  Program analyze(
    Source source,
    ArgResults args, {
    required bool traditional,
    int? memoryLimit,
  }) =>
      core.analyze(source, traditional: traditional, memoryLimit: memoryLimit);

  @override
  IrProgram lower(Program program, ArgResults args, IrOptions options) =>
      core.lower(program, options: options);

  @override
  bool handles(String path) => Source.dialectOf(path) != null;

  @override
  Analysis analyzeAll(Source source, {required bool traditional}) =>
      collectErrors(
        (onError) =>
            core.analyze(source, traditional: traditional, onError: onError),
        (program, options) => core.lower(program, options: options),
      );
}

/// Runs the `build`, `run`, `doctor` and `lsp` commands (decisions Q100, Q101, Q151) and returns
/// the exit status. The language server comes from the binary, since CIWAPA's core doesn't hold it.
Future<int> runCli(
  List<String> arguments,
  Backend backend, {
  Frontend frontend = const CiwapaFrontend(),
  Future<int> Function(Frontend frontend, String name)? languageServer,
}) async {
  final parser = _parser();
  frontend.addOptions(parser);
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(
      '${backend.name}: ${e.message}\n\n${_usage(backend, frontend, parser)}',
    );
    return 64;
  }
  final problem = frontend.checkOptions(args);
  if (problem != null) {
    stderr.writeln('${backend.name}: $problem');
    return 64;
  }
  final command = args.rest.isEmpty ? null : args.rest.first;
  if (args.flag('help') || command == null) {
    stdout.writeln(_usage(backend, frontend, parser));
    return command == null && !args.flag('help') ? 64 : 0;
  }
  switch (command) {
    case 'doctor':
      return _doctor(backend);
    case 'lsp' when languageServer != null:
      return languageServer(frontend, backend.name);
    case 'build' || 'run':
      if (args.rest.length < 2) {
        stderr.writeln(
          '${backend.name} $command: which file?\n\n${_usage(backend, frontend, parser)}',
        );
        return 64;
      }
      try {
        return await _build(backend, frontend, args, command == 'run');
      } on _Exit catch (e) {
        return e.status;
      }
    default:
      stderr.writeln(
        '${backend.name}: unknown command "$command"\n\n${_usage(backend, frontend, parser)}',
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

String _usage(Backend backend, Frontend frontend, ArgParser parser) =>
    '''
Usage:
  ${backend.name} build <${frontend.sourceDescription}> [-o <executable>] [options]
  ${backend.name} run <${frontend.sourceDescription}> [options] [-- <program arguments>]
  ${backend.name} doctor
  ${backend.name} lsp                 the language server, on stdin and stdout

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

Future<int> _build(
  Backend backend,
  Frontend frontend,
  ArgResults args,
  bool run,
) async {
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

  // Test-only (decision L7): never set outside tests, it fakes running out of memory.
  final memoryLimit = int.tryParse(
    Platform.environment['CIWAPA_TEST_MEMORY_LIMIT'] ?? '',
  );
  final Program program;
  final IrProgram ir;
  try {
    try {
      program = frontend.analyze(
        Source.fromBytes(path, bytes),
        args,
        traditional: args.flag('traditional'),
        memoryLimit: memoryLimit,
      );
    } on OutOfMemoryError {
      _fail(IclError.of(666), 1);
    }
    if (args.option('dump') == 'ast') stdout.write(_dumpAst(program));
    try {
      ir = frontend.lower(
        program,
        args,
        IrOptions(
          randomBug: !args.flag('no-random-bug'),
          seed: seed == null ? null : int.tryParse(seed),
          memoryLimit: memoryLimit,
          forceEngine: Platform.environment['CIWAPA_TEST_ENGINE'] == '1',
        ),
      );
    } on OutOfMemoryError {
      _fail(IclError.of(333), 1);
    }
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
  } on OutOfMemoryError {
    // Generating code is where a huge program needs the most memory (decision L12).
    _fail(IclError.of(666), 1);
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
    // A device such as /dev/null is never "empty"; only a regular file can be left unwritten.
    if (FileSystemEntity.isFileSync(output) && outputFile.lengthSync() == 0) {
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
