// Runs the golden conformance suite through one flavor's compiler.
//
//   dart run bin/conformance.dart --compiler <ciwapa-dart or ciwapa-llvm executable>
//       [--results results.json] [--jobs n] [name filters...]
//
// Each test is tests/<group>/<name>.i (or .2i–.7i, .xc, .2xc–.7xc, or .bad for a bad extension)
// with optional siblings:
//   .in     stdin for the program
//   .args   program arguments, one per line
//   .flags  compiler flags, one per line (--no-random-bug is always passed)
//   .env    KEY=VALUE environment variables, one per line, for the build and the run
//   .out    expected stdout (empty when missing)
//   .err    expected stderr (empty when missing)
//   .exit   expected exit status (0 when missing)
//   .timeout  seconds the program must still be running after; it is then killed and its
//             output so far is compared. Only for programs that loop forever by design and print
//             nothing, since how much a looping program prints in N seconds varies.
// Any other program that runs longer than a minute fails as timed out.
//
// Every Mode 1 test also runs a second time as EXTRACAL, copied to <name>.xc (or .2xc–.7xc), and
// must give the same results: the superset rule (R1). Where EXTRACAL deliberately differs, the
// test has .xc.out, .xc.err or .xc.exit files, and the EXTRACAL run is compared with those instead
// (each missing one counts as empty, or 0).
// When the build fails, its own stdout, stderr and exit status are what gets compared, so
// compile-time errors are tested the same way as run-time ones.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';

class Outcome {
  Outcome(this.stdout, this.stderr, this.exitCode, {this.timedOut = false});

  final List<int> stdout;
  final List<int> stderr;
  final int exitCode;
  final bool timedOut;
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('compiler', mandatory: true)
    ..addOption('results')
    ..addOption('jobs', defaultsTo: '${Platform.numberOfProcessors}');
  final args = parser.parse(arguments);
  final compiler = File(args.option('compiler')!).absolute.path;
  final root = Directory.fromUri(
    (await Isolate.resolvePackageUri(Uri.parse('package:conformance/')))!
        .resolve('../tests/'),
  );
  final filters = args.rest;
  final sources =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .where(
            (p) =>
                _mode1.hasMatch(p) ||
                _extracal.hasMatch(p) ||
                p.endsWith('.bad'),
          )
          .where((p) => filters.isEmpty || filters.any(p.contains))
          .toList()
        ..sort();
  final tests = [
    for (final path in sources) ...[
      (path: path, superset: false),
      if (_mode1.hasMatch(path)) (path: path, superset: true),
    ],
  ];
  final supersetCount = tests.where((t) => t.superset).length;

  final failed = <String>[];
  var next = 0;
  Future<void> worker() async {
    while (next < tests.length) {
      final (:path, :superset) = tests[next++];
      final name =
          '${superset ? 'superset:' : ''}${_relative(path, root.path)}';
      final failure = await _check(compiler, path, superset: superset);
      if (failure == null) {
        stdout.writeln('pass  $name');
      } else {
        failed.add(name);
        stdout.writeln(
          'FAIL  $name\n${failure.split('\n').map((l) => '      $l').join('\n')}',
        );
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < int.parse(args.option('jobs')!); i++) worker(),
  ]);
  failed.sort();
  stdout.writeln('\n${tests.length - failed.length}/${tests.length} passed');
  final results = args.option('results');
  if (results != null) {
    File(results).writeAsStringSync(
      jsonEncode({
        'total': tests.length,
        'superset': supersetCount,
        'failed': failed,
      }),
    );
  }
  exit(failed.isEmpty && tests.isNotEmpty ? 0 : 1);
}

const _defaultTimeout = Duration(minutes: 1);

final _mode1 = RegExp(r'\.[2-7]?i$');
final _extracal = RegExp(r'\.[2-7]?xc$');

String _relative(String path, String root) =>
    path.substring(root.length).replaceAll(r'\', '/');

String _stem(String path) => path.substring(0, path.lastIndexOf('.'));

List<String> _lines(File f) => f.existsSync()
    ? f.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList()
    : const [];

Future<String?> _check(
  String compiler,
  String path, {
  required bool superset,
}) async {
  final stem = _stem(path);
  final temp = Directory.systemTemp.createTempSync('ciwapa-conformance-');
  try {
    if (superset) {
      final name = File(path).uri.pathSegments.last;
      final copy =
          '${temp.path}${Platform.pathSeparator}${name.substring(0, name.length - 1)}xc';
      File(path).copySync(copy);
      path = copy;
    }
    final exe =
        '${temp.path}${Platform.pathSeparator}program${Platform.isWindows ? '.exe' : ''}';
    final environment = <String, String>{};
    for (final line in _lines(File('$stem.env'))) {
      final equals = line.indexOf('=');
      if (equals < 1) return '$stem.env: expected KEY=VALUE, got "$line"';
      environment[line.substring(0, equals)] = line.substring(equals + 1);
    }
    final build = await _run(
      compiler,
      [
        'build',
        '--no-random-bug',
        ..._lines(File('$stem.flags')),
        path,
        '-o',
        exe,
      ],
      const [],
      environment: environment,
    );
    final timeoutFile = File('$stem.timeout');
    final mustLoop = timeoutFile.existsSync();
    final timeout = mustLoop
        ? Duration(seconds: int.parse(timeoutFile.readAsStringSync().trim()))
        : _defaultTimeout;
    final outcome = build.exitCode != 0
        ? build
        : await _run(
            exe,
            _lines(File('$stem.args')),
            File('$stem.in').existsSync()
                ? File('$stem.in').readAsBytesSync()
                : const [],
            timeout: timeout,
            environment: environment,
          );
    if (build.exitCode == 0 && mustLoop && !outcome.timedOut) {
      return 'expected the program to still be running after ${timeout.inSeconds}s, '
          'but it exited with ${outcome.exitCode}';
    }
    if (build.exitCode == 0 && !mustLoop && outcome.timedOut) {
      return 'timed out after ${timeout.inSeconds}s';
    }
    return _compare(stem, outcome, superset: superset);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

String? _compare(String stem, Outcome actual, {required bool superset}) {
  final differs =
      superset &&
      ['out', 'err', 'exit'].any((e) => File('$stem.xc.$e').existsSync());
  final prefix = differs ? '$stem.xc' : stem;
  List<int> expected(String extension) {
    final f = File('$prefix.$extension');
    return f.existsSync() ? f.readAsBytesSync() : const [];
  }

  final exitFile = File('$prefix.exit');
  final expectedExit = exitFile.existsSync()
      ? int.parse(exitFile.readAsStringSync().trim())
      : 0;
  final problems = [
    if (!_same(expected('out'), actual.stdout))
      _diff('stdout', expected('out'), actual.stdout),
    if (!_same(expected('err'), actual.stderr))
      _diff('stderr', expected('err'), actual.stderr),
    if (expectedExit != actual.exitCode)
      'exit status: expected $expectedExit, got ${actual.exitCode}',
  ];
  return problems.isEmpty ? null : problems.join('\n');
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _diff(String what, List<int> expected, List<int> actual) {
  String show(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.length > 2000 ? '${text.substring(0, 2000)}…' : text;
  }

  return '$what differs\n--- expected\n${show(expected)}\n--- actual\n${show(actual)}';
}

Future<Outcome> _run(
  String exe,
  List<String> args,
  List<int> stdin, {
  Duration? timeout,
  Map<String, String> environment = const {},
}) async {
  final process = await Process.start(exe, args, environment: environment);
  final out = process.stdout.fold<List<int>>([], (a, b) => a..addAll(b));
  final err = process.stderr.fold<List<int>>([], (a, b) => a..addAll(b));
  process.stdin.add(stdin);
  await process.stdin.close().catchError((_) {});
  if (timeout != null) {
    final exited = await process.exitCode
        .then<int?>((code) => code)
        .timeout(timeout, onTimeout: () => null);
    if (exited == null) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      // The expected exit status of a program that never ends is "still running": 0 here.
      return Outcome(await out, await err, 0, timedOut: true);
    }
  }
  return Outcome(await out, await err, await process.exitCode);
}
