// Runs the golden conformance suite through one flavor's compiler.
//
//   dart run bin/conformance.dart --compiler <ciwapa-dart or ciwapa-llvm executable>
//       [--results results.json] [--jobs n] [name filters...]
//
// Each test is tests/<group>/<name>.i with optional siblings:
//   .in     stdin for the program
//   .args   program arguments, one per line
//   .flags  compiler flags, one per line (--no-random-bug is always passed)
//   .out    expected stdout (empty when missing)
//   .err    expected stderr (empty when missing)
//   .exit   expected exit status (0 when missing)
//   .timeout  seconds the program must still be running after; it is then killed, and only its
//             output so far is compared (for programs that loop forever by design)
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
  final tests =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.i') ||
                RegExp(r'\.[2-7]i$').hasMatch(f.path) ||
                f.path.endsWith('.bad'),
          )
          .map((f) => f.path)
          .where((p) => filters.isEmpty || filters.any(p.contains))
          .toList()
        ..sort();

  final failed = <String>[];
  var next = 0;
  Future<void> worker() async {
    while (next < tests.length) {
      final path = tests[next++];
      final name = _relative(path, root.path);
      final failure = await _check(compiler, path);
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
    File(
      results,
    ).writeAsStringSync(jsonEncode({'total': tests.length, 'failed': failed}));
  }
  exit(failed.isEmpty && tests.isNotEmpty ? 0 : 1);
}

String _relative(String path, String root) =>
    path.substring(root.length).replaceAll(r'\', '/');

String _stem(String path) => path.substring(0, path.lastIndexOf('.'));

List<String> _lines(File f) => f.existsSync()
    ? f.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList()
    : const [];

Future<String?> _check(String compiler, String path) async {
  final stem = _stem(path);
  final temp = Directory.systemTemp.createTempSync('ciwapa-conformance-');
  try {
    final exe =
        '${temp.path}${Platform.pathSeparator}program${Platform.isWindows ? '.exe' : ''}';
    final build = await _run(compiler, [
      'build',
      '--no-random-bug',
      ..._lines(File('$stem.flags')),
      path,
      '-o',
      exe,
    ], const []);
    final timeoutFile = File('$stem.timeout');
    final timeout = timeoutFile.existsSync()
        ? Duration(seconds: int.parse(timeoutFile.readAsStringSync().trim()))
        : null;
    final outcome = build.exitCode != 0
        ? build
        : await _run(
            exe,
            _lines(File('$stem.args')),
            File('$stem.in').existsSync()
                ? File('$stem.in').readAsBytesSync()
                : const [],
            timeout: timeout,
          );
    if (timeout != null && build.exitCode == 0 && !outcome.timedOut) {
      return 'expected the program to still be running after ${timeout.inSeconds}s, '
          'but it exited with ${outcome.exitCode}';
    }
    return _compare(stem, outcome);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

String? _compare(String stem, Outcome actual) {
  List<int> expected(String extension) {
    final f = File('$stem.$extension');
    return f.existsSync() ? f.readAsBytesSync() : const [];
  }

  final exitFile = File('$stem.exit');
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
}) async {
  final process = await Process.start(exe, args);
  final out = process.stdout.fold<List<int>>([], (a, b) => a..addAll(b));
  final err = process.stderr.fold<List<int>>([], (a, b) => a..addAll(b));
  process.stdin.add(stdin);
  await process.stdin.close().catchError((_) {});
  if (timeout != null) {
    final exited = await process.exitCode.timeout(timeout, onTimeout: () => -1);
    if (exited == -1) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      // The expected exit status of a program that never ends is "still running": 0 here.
      return Outcome(await out, await err, 0, timedOut: true);
    }
  }
  return Outcome(await out, await err, await process.exitCode);
}
