import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:ciwapa_lsp/ciwapa_lsp.dart';

Future<void> main(List<String> args) async =>
    exit(await runCli(args, DartBackend(), languageServer: runLanguageServer));
