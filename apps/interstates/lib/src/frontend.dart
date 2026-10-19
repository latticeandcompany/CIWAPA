import 'package:args/args.dart';
import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_core/ciwapa_core.dart' as core show analyze, lower;

import 'errors.dart';
import 'routes.dart';
import 'runtime_sources.g.dart';
import 'services.dart';
import 'syntax.dart';

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
    if (!states) {
      return const CiwapaFrontend().analyze(
        source,
        args,
        traditional: traditional,
        memoryLimit: memoryLimit,
      );
    }
    return analyzeInterstates(source, memoryLimit: memoryLimit);
  }

  @override
  IrProgram lower(Program program, ArgResults args, IrOptions options) {
    if (!args.flag('states')) {
      return const CiwapaFrontend().lower(program, args, options);
    }
    final routes = _routes[program] ?? RouteTable(const []);
    final ir = core.lower(
      program,
      options: options,
      entries: routes.entries,
      services: libraryServices,
      host: true,
      errors: interstatesErrors,
      extension: InterstatesProgram(routes),
    );
    allowReferers(routes, ir);
    return ir;
  }
}

/// Parses an Interstates program and runs CIWAPA's whole-program checks, then its own.
Program analyzeInterstates(Source source, {int? memoryLimit}) {
  late InterstatesParser parser;
  final program = core.analyze(
    source,
    memoryLimit: memoryLimit,
    parser: (source, {required wide, required extensions}) =>
        parser = InterstatesParser(source, memoryLimit: memoryLimit),
    libraries: const [
      LibraryBlock('interstates.xc', 16001, 16999, interstatesLibrary),
    ],
  );
  // A WHILE's body becomes a statement of its own, which gets its data here.
  for (final s in program.statements.take(program.userStatements)) {
    s.data ??= parser.dataOf(s.body);
  }
  for (final (i, s)
      in program.statements.take(program.userStatements).indexed) {
    if (s.data case DatabaseWrite(:final columns, :final items)
        when columns != items) {
      throw interstatesCompileError(827, i + 1);
    }
    // ;4400 and ;49221 hold strings, which only the Interstates statements can move (R5).
    if (s.body is! HostCall && _usesStrings(s.body)) {
      s.body = InterstatesParser.fault(822, s.body.gerund);
    }
  }
  _routes[program] = routeTable(program);
  return program;
}

/// What the front end found in each program, for its lowering.
final _routes = Expando<RouteTable>();

/// What the ioi-* backends need about a program beyond its IR.
class InterstatesProgram {
  InterstatesProgram(this.routes);

  final RouteTable routes;
}

bool _usesStrings(Body body) => switch (body) {
  Dimension(:final array) when isStringArray(array) => true,
  VarListBody(:final vars) => vars.any(isStringArray),
  _ => expressionsOf(body).any(mentionsStrings),
};
