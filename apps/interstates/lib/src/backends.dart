import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';

import 'host_data.dart';
import 'runtime_sources.g.dart';

/// `ioi-dart`: CIWAPA's Dart flavor, with the Interstates host beside `-s` programs.
Backend ioiDart() => IoiBackend(
  'ioi-dart',
  DartBackend(),
  DartBackend(),
  (program) => {'ioi_host.dart': ioiHostDart, 'host.dart': dartHost(program)},
);

/// `ioi-llvm`: CIWAPA's LLVM flavor, with the Interstates host compiled into `-s` programs.
Backend ioiLlvm() => IoiBackend(
  'ioi-llvm',
  LlvmBackend(),
  LlvmBackend(sources: const ['host.c']),
  (program) => {'host.c': ioiHostC + cHostData(program)},
);

/// One of CIWAPA's backends, under the name of an `ioi-*` CLI: [plain] builds programs without
/// `-s`, and [hosted] builds `-s` ones, with the [hostFiles] beside the generated code.
class IoiBackend implements Backend {
  IoiBackend(this.name, this.plain, this.hosted, this.hostFiles);

  @override
  final String name;

  final Backend plain;
  final Backend hosted;
  final Map<String, String> Function(IrProgram program) hostFiles;

  /// Whether the program [emit] last generated has a host, which [compile] then builds.
  var _host = false;

  @override
  String get extension => plain.extension;

  @override
  Map<String, String> emit(IrProgram program, EmitOptions options) {
    _host = program.host;
    if (!_host) return plain.emit(program, options);
    return {...hosted.emit(program, options), ...hostFiles(program)};
  }

  @override
  Future<void> compile(
    Directory dir,
    String output, {
    required bool optimize,
  }) => (_host ? hosted : plain).compile(dir, output, optimize: optimize);

  @override
  Future<List<(bool, String)>> doctor() => plain.doctor();
}
