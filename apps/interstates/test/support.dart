import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:interstates/interstates.dart';

/// A program from statements without their identifiers: about a quarter of them get PLEASE,
/// always within politeness's 1/5 to 1/3. `L(n) rest` is `rest` with label (n).
String program(List<String> lines) {
  final n = lines.length;
  final k = (n / 4).round().clamp(1, n);
  final polite = {for (var j = 0; j < k; j++) j * n ~/ k};
  return [
    for (final (i, line) in lines.indexed)
      line.startsWith('L(')
          ? '${line.substring(1, line.indexOf(') ') + 2)}'
                '${polite.contains(i) ? 'PLEASE' : 'DO'} ${line.substring(line.indexOf(') ') + 2)}'
          : '${polite.contains(i) ? 'PLEASE' : 'DO'} $line',
  ].join('\n');
}

/// The statements that make tail array [array] hold [text].
List<String> string(String array, String text) => [
  '$array <- #${text.codeUnits.length}',
  for (final (i, u) in text.codeUnits.indexed) '$array SUB #${i + 1} <- #$u',
];

/// Writes ,1 and a line feed to the response body.
const writeLine = ['.1 <- #1', '(2310) NEXT'];

/// Builds [source] (a whole program) as [name] in [dir] with [backend], and returns the
/// executable. [states] adds -s.
Future<String> build(
  Backend backend,
  Directory dir,
  String source, {
  String name = 'p',
  bool states = true,
}) async {
  final file = File('${dir.path}/$name.xc')..writeAsStringSync('$source\n');
  final exe = '${dir.path}/$name${Platform.isWindows ? '.exe' : ''}';
  final status = await runCli(
    ['build', '--no-random-bug', if (states) '-s', file.path, '-o', exe],
    backend,
    frontend: InterstatesFrontend(),
  );
  if (status != 0) throw StateError('$name.xc did not build ($status)');
  return exe;
}
