import 'package:args/args.dart';
import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_core/ciwapa_core.dart' as core show analyze, lower;

import 'errors.dart';
import 'routes.dart';
import 'templates.dart';
import 'runtime_sources.g.dart';
import 'services.dart';
import 'syntax.dart';

/// The `ioi-*` front end: Interstates programs are `.ioi` files, and anything else is plain EXTRACAL
/// (R1, Q154, L35).
class InterstatesFrontend implements Frontend {
  @override
  String get sourceDescription => 'file.ioi or file.xc';

  /// `-s` is gone, but it is still recognized, so that using it says what to do instead.
  @override
  void addOptions(ArgParser parser) =>
      parser.addFlag('states', abbr: 's', negatable: false, hide: true);

  @override
  String? checkOptions(ArgResults args) {
    if (!args.flag('states')) return null;
    final path = args.rest.length > 1 ? args.rest[1] : null;
    const gone = '-s is gone: Interstates programs are .ioi files now.';
    if (path != null && interstatesBase(path) != null) {
      return '$gone Build $path without -s.';
    }
    final xc = path == null ? null : RegExp(r'\.(2?)xc$').firstMatch(path);
    final rename = xc != null
        ? 'Rename $path to ${path!.substring(0, xc.start)}.${xc.group(1)}ioi'
        : 'Rename the program to end in .ioi';
    return '$gone $rename and build it without -s.';
  }

  @override
  Program analyze(
    Source source,
    ArgResults args, {
    required bool traditional,
    int? memoryLimit,
  }) {
    final base = interstatesBase(source.path);
    if (base != null) {
      // Interstates is built on the binary library blocks and string machinery (L35).
      if (base != 2) throw CompileError(998, 1);
      if (traditional) throw CompileError(111, 1);
      return analyzeInterstates(source, memoryLimit: memoryLimit);
    }
    final dialect = Source.dialectOf(source.path);
    if (dialect == null || !dialect.extracal) throw CompileError(998, 1);
    return const CiwapaFrontend().analyze(
      source,
      args,
      traditional: traditional,
      memoryLimit: memoryLimit,
    );
  }

  @override
  IrProgram lower(Program program, ArgResults args, IrOptions options) =>
      _lower(program, options);

  /// `.ioi` files, and everything CIWAPA's own front end takes (R3, Q167).
  @override
  bool handles(String path) =>
      interstatesBase(path) != null || const CiwapaFrontend().handles(path);

  /// A `.ioi` file as the `ioi-*` CLIs see it, and any other file as `ciwapa-*` does (R3).
  @override
  Analysis analyzeAll(Source source, {required bool traditional}) {
    final base = interstatesBase(source.path);
    if (base == null) {
      return const CiwapaFrontend().analyzeAll(
        source,
        traditional: traditional,
      );
    }
    return collectErrors(
      (onError) {
        if (base != 2) {
          onError(CompileError(998, 1));
          return Program(source, base, const [], 0, extracal: true);
        }
        if (traditional) onError(CompileError(111, 1));
        return analyzeInterstates(source, onError: onError);
      },
      _lower,
      faultOf: _faultOf,
    );
  }

  /// E822 and the like are statements that raise an Interstates error when they run, the way
  /// CIWAPA's statement-local errors do.
  static IclError? _faultOf(Statement s) => switch (s.body) {
    HostCall(service: HostService.fault, values: [Constant(:final value)]) =>
      interstatesError(value),
    _ => null,
  };

  IrProgram _lower(Program program, IrOptions options) {
    final routes = _routes[program];
    if (routes == null) {
      return core.lower(program, options: options);
    }
    final ir = core.lower(
      program,
      options: options,
      entries: routes.entries,
      services: libraryServices,
      host: true,
      errors: interstatesErrors,
      extension: InterstatesProgram(routes, _templates[program] ?? const []),
    );
    allowReferers(routes, ir);
    return ir;
  }
}

/// The base a `.ioi` or `.2ioi`–`.7ioi` path names, or null for any other path.
int? interstatesBase(String path) {
  final match = RegExp(r'\.([2-7]?)ioi$').firstMatch(path);
  if (match == null) return null;
  final digit = match.group(1)!;
  return digit.isEmpty ? 2 : int.parse(digit);
}

/// Parses an Interstates program and runs CIWAPA's whole-program checks, then its own, throwing the
/// first error, or with [onError], passing every one there and carrying on (R2).
Program analyzeInterstates(
  Source source, {
  int? memoryLimit,
  void Function(CompileError error)? onError,
}) {
  late InterstatesParser parser;
  final program = core.analyze(
    source,
    memoryLimit: memoryLimit,
    onError: onError,
    dialect: const Dialect(2, extracal: true),
    parser: (source, {required wide, required extensions}) =>
        parser = InterstatesParser(source, memoryLimit: memoryLimit),
    libraries: interstatesBlocks,
  );
  void report(CompileError error) {
    final placed = error.placed(program.statements, source);
    if (onError == null) throw placed;
    onError(placed);
  }

  // A WHILE's body becomes a statement of its own, which gets its data here.
  for (final s in program.statements.take(program.userStatements)) {
    s.data ??= parser.dataOf(s.body);
  }
  for (final (i, s)
      in program.statements.take(program.userStatements).indexed) {
    if (s.data case DatabaseWrite(:final columns, :final items)
        when columns != items) {
      report(interstatesCompileError(827, i + 1));
    }
    // ;4400 and ;49221 hold strings, which only the Interstates statements can move (R5).
    if (s.body is! HostCall && _usesStrings(s.body)) {
      s.body = InterstatesParser.fault(822, s.body.gerund);
    }
  }
  try {
    _routes[program] = routeTable(program);
  } on CompileError catch (e) {
    report(e);
  }
  final templates = <Template>[];
  for (final (i, s)
      in program.statements.take(program.userStatements).indexed) {
    if (s.data case TemplateUse(:final count, :final path)) {
      final Template template;
      try {
        template = compileTemplate(program.source, path, count, i + 1);
      } on CompileError catch (e) {
        report(e);
        continue;
      }
      s.body = HostCall(
        HostService.render,
        values: [Constant(templates.length), ...template.values],
        gerund: Gerund.readingOut,
      );
      templates.add(template);
    }
  }
  _templates[program] = templates;
  return program;
}

/// The library blocks `.ioi` programs get. ActiveCassette is apart, so that only programs that NEXT
/// to it link SQLite.
const interstatesBlocks = [
  LibraryBlock('interstates.xc', 16001, 16199, interstatesLibrary),
  LibraryBlock('activecassette.xc', 16200, 16999, activecassetteLibrary),
];

final _templates = Expando<List<Template>>();

/// What the front end found in each program, for its lowering.
final _routes = Expando<RouteTable>();

/// What the ioi-* backends need about a program beyond its IR.
class InterstatesProgram {
  InterstatesProgram(this.routes, this.templates);

  final RouteTable routes;
  final List<Template> templates;
}

bool _usesStrings(Body body) => switch (body) {
  Dimension(:final array) when isStringArray(array) => true,
  VarListBody(:final vars) => vars.any(isStringArray),
  _ => expressionsOf(body).any(mentionsStrings),
};
