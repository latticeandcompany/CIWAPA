// TEMPORARY (goal 2's cleanup removes it): times the front end plus each flavor's code emission
// for every program given, best of 5, and prints one JSON line per program (Q33).
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';

void main(List<String> paths) {
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    final options = EmitOptions(
      clockface: false,
      optimize: true,
      sourceName: path,
    );
    int best(String Function(IrProgram) emit) {
      var fastest = 1 << 62;
      for (var i = 0; i < 5; i++) {
        final watch = Stopwatch()..start();
        try {
          final ir = lower(analyze(Source.fromBytes(path, bytes)));
          emit(ir);
        } on CompileError {
          // Still a full front-end pass; the program is just rejected.
        }
        fastest = watch.elapsedMicroseconds < fastest
            ? watch.elapsedMicroseconds
            : fastest;
      }
      return fastest;
    }

    stdout.writeln(
      jsonEncode({
        'program': path,
        'llvm_us': best(
          (ir) => LlvmEmitter(ir, options, 'aarch64-unknown-linux-musl').emit(),
        ),
        'dart_us': best((ir) => DartEmitter(ir, options).emit()),
      }),
    );
  }
}
