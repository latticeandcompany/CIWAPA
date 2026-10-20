import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:interstates/src/gross.dart';

/// `gross [--port 10585] [--bind 127.0.0.1] [--static <dir>] [--database <url>] [--timeout 30]
/// ./program` (R2, Q120, Q144).
Future<void> main(List<String> arguments) async {
  final parser = grossArguments();
  final GrossConfig config;
  try {
    config = grossConfig(parser.parse(arguments));
  } on FormatException catch (e) {
    stderr.writeln('gross: ${e.message}\n\n${grossUsage(parser)}');
    exit(64);
  } on _Help {
    stdout.writeln(grossUsage(parser));
    exit(0);
  }
  final Gross gross;
  try {
    gross = await Gross.start(config);
  } on SocketException catch (e) {
    stderr.writeln(
      'gross: cannot listen on ${config.bind}:${config.port}: ${e.message}',
    );
    exit(1);
  }
  stderr.writeln(
    'gross: serving ${config.program} on http://${config.bind}:${gross.port}',
  );
  await ProcessSignal.sigint.watch().first;
  await gross.close();
  exit(0);
}

class _Help implements Exception {}

ArgParser grossArguments() => ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Print this usage information.',
  )
  ..addOption(
    'port',
    defaultsTo: '${GrossConfig.defaultPort}',
    help: 'The port to listen on.',
  )
  ..addOption(
    'bind',
    defaultsTo: '127.0.0.1',
    help: 'The address to listen on.',
  )
  ..addOption(
    'static',
    valueHelp: 'dir',
    help: 'Serve the files in this folder, before running the program.',
  )
  ..addOption(
    'database',
    valueHelp: 'url',
    help: 'The ActiveCassette connection, given to each run as DATABASE_URL.',
  )
  ..addOption(
    'timeout',
    defaultsTo: '30',
    help: 'Seconds a request may run before it gets a 504.',
  );

String grossUsage(ArgParser parser) => '''
Usage: gross [options] ./program

The General READ OUT Server System runs the program once per request, CGI-style.

${parser.usage}''';

GrossConfig grossConfig(ArgResults args) {
  if (args.flag('help')) throw _Help();
  if (args.rest.length != 1) {
    throw const FormatException('which program?');
  }
  final port = int.tryParse(args.option('port')!);
  if (port == null || port < 0 || port > 65535) {
    throw FormatException(
      '--port needs a number from 0 to 65535, not "${args.option('port')}"',
    );
  }
  final timeout = int.tryParse(args.option('timeout')!);
  if (timeout == null || timeout < 1) {
    throw FormatException(
      '--timeout needs a whole number of seconds, not "${args.option('timeout')}"',
    );
  }
  final staticDir = args.option('static');
  if (staticDir != null && !Directory(staticDir).existsSync()) {
    throw FormatException(
      '--static needs a folder, and "$staticDir" isn\'t one',
    );
  }
  final program = args.rest.single;
  if (!File(Gross.executable(program)).existsSync()) {
    throw FormatException('there is no program at "$program"');
  }
  return GrossConfig(
    program: program,
    port: port,
    bind: args.option('bind')!,
    staticDir: staticDir,
    database: args.option('database'),
    timeout: Duration(seconds: timeout),
  );
}
