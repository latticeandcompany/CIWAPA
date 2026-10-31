import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';
import 'package:ciwapa_lsp/ciwapa_lsp.dart';

Future<void> main(List<String> args) async =>
    exit(await runCli(args, LlvmBackend(), languageServer: runLanguageServer));
