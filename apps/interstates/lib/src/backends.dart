import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';

/// `ioi-dart`: CIWAPA's Dart flavor under its Interstates name.
Backend ioiDart() => IoiBackend('ioi-dart', DartBackend());

/// `ioi-llvm`: CIWAPA's LLVM flavor under its Interstates name.
Backend ioiLlvm() => IoiBackend('ioi-llvm', LlvmBackend());

/// One of CIWAPA's backends, under the name of an `ioi-*` CLI.
class IoiBackend implements Backend {
  IoiBackend(this.name, this.ciwapa);

  @override
  final String name;

  final Backend ciwapa;

  @override
  String get extension => ciwapa.extension;

  @override
  Map<String, String> emit(IrProgram program, EmitOptions options) =>
      ciwapa.emit(program, options);

  @override
  Future<void> compile(
    Directory dir,
    String output, {
    required bool optimize,
  }) => ciwapa.compile(dir, output, optimize: optimize);

  @override
  Future<List<(bool, String)>> doctor() => ciwapa.doctor();
}
