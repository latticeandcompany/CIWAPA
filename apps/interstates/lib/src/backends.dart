import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';

import 'host_data.dart';
import 'runtime_sources.g.dart';
import 'services.dart';

/// `ioi-dart`: CIWAPA's Dart flavor, with the Interstates host beside `-s` programs.
Backend ioiDart() => IoiBackend(
  'ioi-dart',
  DartBackend(),
  (program) => DartBackend(),
  (program) => {
    'ioi_host.dart': ioiHostDart,
    'host.dart': dartHost(program, sqliteLibrary: _sqliteLibrary(program)),
  },
);

/// `ioi-llvm`: CIWAPA's LLVM flavor, with the Interstates host compiled into `-s` programs, and
/// ActiveCassette's SQLite into those that use a database.
Backend ioiLlvm() {
  final triple = Toolchain.find().triple;
  return IoiBackend(
    'ioi-llvm',
    LlvmBackend(),
    (program) => switch (_activeCassette(program, triple)) {
      null => LlvmBackend(sources: const ['host.c']),
      (object: final object?, sqlite: _) => LlvmBackend(
        sources: const ['host.c'],
        flags: [object],
      ),
      (object: _, sqlite: final sqlite) => LlvmBackend(
        sources: const ['host.c', 'activecassette.c'],
        flags: [
          '-I$sqlite',
          '-DSQLITE_OMIT_LOAD_EXTENSION',
          '-DSQLITE_THREADSAFE=0',
        ],
      ),
    },
    (program) => {
      'host.c': ioiHostC + cHostData(program),
      if (_activeCassette(program, triple) case (object: null, sqlite: _)) ...{
        'activecassette.c': activecassetteC,
        'sqlite_adapter.c': sqliteAdapterC,
        'ioi_adapter.h': ioiAdapterHeader,
      },
    },
  );
}

/// Where ActiveCassette's SQLite comes from: `IOI_LIB`, or the `lib` folder beside the compiler
/// (in a release archive). tool/activecassette.sh makes its contents.
String get _libraryFolder {
  final sep = Platform.pathSeparator;
  final override = Platform.environment['IOI_LIB'];
  if (override != null && override.isNotEmpty) {
    return Directory(override).absolute.path;
  }
  return '${File(Platform.resolvedExecutable).parent.parent.path}${sep}lib';
}

bool _usesDatabase(IrProgram program) => program.statements.any(
  (s) =>
      s.op is IrPetition &&
      databaseServices.contains((s.op as IrPetition).service),
);

/// For an ioi-dart program that uses a database, the SQLite library it loads.
String? _sqliteLibrary(IrProgram program) {
  if (!_usesDatabase(program)) return null;
  final name = Platform.isWindows
      ? 'ioi_sqlite.dll'
      : Platform.isMacOS
      ? 'libioi_sqlite.dylib'
      : 'libioi_sqlite.so';
  final file = File('$_libraryFolder${Platform.pathSeparator}$name');
  if (!file.existsSync()) throw _noSqlite;
  return file.path;
}

/// For an ioi-llvm program that uses a database, ActiveCassette's object for [triple], or failing
/// that the folder with SQLite's amalgamation to compile it from; null for one that doesn't.
({String? object, String sqlite})? _activeCassette(
  IrProgram program,
  String triple,
) {
  if (!_usesDatabase(program)) return null;
  final sep = Platform.pathSeparator;
  final object = File('$_libraryFolder${sep}activecassette-$triple.o');
  if (object.existsSync()) return (object: object.path, sqlite: '');
  final sqlite = '$_libraryFolder${sep}sqlite';
  if (File('$sqlite${sep}sqlite3.c').existsSync()) {
    return (object: null, sqlite: sqlite);
  }
  throw _noSqlite;
}

final _noSqlite = ToolchainException(
  'ActiveCassette needs SQLite: set IOI_LIB to a folder that '
  'apps/interstates/tool/activecassette.sh made, or use a release archive',
);

/// One of CIWAPA's backends, under the name of an `ioi-*` CLI: [plain] builds programs without
/// `-s`, and [hosted] the backend for a `-s` one, with the [hostFiles] beside the generated code.
class IoiBackend implements Backend {
  IoiBackend(this.name, this.plain, this.hosted, this.hostFiles);

  @override
  final String name;

  final Backend plain;
  final Backend Function(IrProgram program) hosted;
  final Map<String, String> Function(IrProgram program) hostFiles;

  /// The backend for the program [emit] last generated, which [compile] then builds with.
  Backend? _current;

  @override
  String get extension => plain.extension;

  @override
  Map<String, String> emit(IrProgram program, EmitOptions options) {
    if (!program.host) {
      _current = plain;
      return plain.emit(program, options);
    }
    final backend = _current = hosted(program);
    return {...backend.emit(program, options), ...hostFiles(program)};
  }

  @override
  Future<void> compile(
    Directory dir,
    String output, {
    required bool optimize,
  }) => (_current ?? plain).compile(dir, output, optimize: optimize);

  @override
  Future<List<(bool, String)>> doctor() => plain.doctor();
}
