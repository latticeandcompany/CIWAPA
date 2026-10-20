import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:interstates/interstates.dart';

Future<void> main(List<String> args) async =>
    exit(await runCli(args, ioiLlvm(), frontend: InterstatesFrontend()));
