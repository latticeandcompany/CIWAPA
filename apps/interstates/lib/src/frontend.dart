import 'package:args/args.dart';
import 'package:ciwapa_core/ciwapa_core.dart';

/// The `ioi-*` front end: plain EXTRACAL, or with `-s` ('States) the Interstates extensions
/// (R1, punchline 2).
class InterstatesFrontend implements Frontend {
  @override
  String get sourceDescription => 'file.xc';

  @override
  void addOptions(ArgParser parser) => parser.addFlag(
    'states',
    abbr: 's',
    negatable: false,
    help:
        "'States: turn on the Interstates extensions (binary .xc files only).",
  );

  @override
  Program analyze(
    Source source,
    ArgResults args, {
    required bool traditional,
    int? memoryLimit,
  }) {
    // The ioi-* CLIs compile EXTRACAL; with -s, binary EXTRACAL with C-INTERCAL-style extensions
    // on top (L35).
    final dialect = Source.dialectOf(source.path);
    final states = args.flag('states');
    if (dialect == null || !dialect.extracal || (states && dialect.base != 2)) {
      throw CompileError(998, 1);
    }
    if (states && traditional) throw CompileError(111, 1);
    return const CiwapaFrontend().analyze(
      source,
      args,
      traditional: traditional,
      memoryLimit: memoryLimit,
    );
  }

  @override
  IrProgram lower(Program program, ArgResults args, IrOptions options) =>
      const CiwapaFrontend().lower(program, args, options);
}
