import 'dart:async';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'diagnostics.dart';
import 'document.dart';
import 'extension.dart';
import 'hover.dart';
import 'rpc.dart';
import 'semantic_tokens.dart';
import 'text.dart';

/// The compiler flags an editor passes to the server, from its settings (Q160). The server never
/// plants the random bug, so `--no-random-bug` is always on (R3).
class Settings {
  const Settings({this.traditional = false, this.clockface = false});

  /// Reads `{traditional, clockface}`, or the same under an `intercal` key; anything else is false.
  factory Settings.fromJson(Object? json) {
    if (json case {'intercal': final Object? nested}) {
      return Settings.fromJson(nested);
    }
    return Settings(
      traditional: json is Map && json['traditional'] == true,
      clockface: json is Map && json['clockface'] == true,
    );
  }

  final bool traditional;

  /// IIII instead of IV. It changes what programs print, never what the compiler says about them.
  final bool clockface;
}

typedef Handler = FutureOr<Object?> Function(Map<String, Object?> params);

/// The INTERCAL language server: the CLI's [frontend] behind LSP on a [Connection] (R3).
class LanguageServer {
  LanguageServer(
    this.frontend, {
    required this.name,
    required Stream<List<int>> input,
    required StreamSink<List<int>> output,
    this.extension = const LanguageExtension(),
  }) : connection = Connection(input, output);

  final Frontend frontend;
  final LanguageExtension extension;

  /// The CLI it runs in, such as `ciwapa-llvm`, which it reports as its name.
  final String name;
  final Connection connection;

  var settings = const Settings();
  final documents = <String, Document>{};
  var _initialized = false;
  var _shuttingDown = false;
  final _exit = Completer<int>();

  late final Map<String, Handler> _requests = {
    'initialize': _initialize,
    'shutdown': (_) {
      _shuttingDown = true;
      return null;
    },
    'textDocument/hover': (params) => _withDocument(
      params,
      (document) => hover(document, Position.fromJson(params['position'])),
    ),
    'textDocument/semanticTokens/full': (params) =>
        _withDocument(params, semanticTokens),
  };

  /// Runs [handler] on the open, handled document [params] names; null for any other.
  Object? _withDocument(
    Map<String, Object?> params,
    Object? Function(Document document) handler,
  ) {
    final document = documentOf(params);
    if (document == null || !document.handled) return null;
    return handler(document);
  }

  late final Map<String, void Function(Map<String, Object?> params)>
  _notifications = {
    'initialized': (_) {},
    'exit': (_) => _finish(_shuttingDown ? 0 : 1),
    'textDocument/didOpen': _didOpen,
    'textDocument/didChange': _didChange,
    'textDocument/didClose': _didClose,
    'workspace/didChangeConfiguration': (params) {
      settings = Settings.fromJson(params['settings']);
      for (final document in documents.values) {
        document.invalidate();
        _publish(document);
      }
    },
  };

  /// Serves until the client sends `exit` or closes the connection, and returns the exit status:
  /// 0 after a `shutdown`, 1 otherwise.
  Future<int> serve() async {
    final subscription = connection.messages.listen(
      _handle,
      onDone: () => _finish(_shuttingDown ? 0 : 1),
    );
    final status = await _exit.future;
    await subscription.cancel();
    await connection.close();
    return status;
  }

  void _finish(int status) {
    if (!_exit.isCompleted) _exit.complete(status);
  }

  Future<void> _handle(Map<String, Object?> message) async {
    final method = message['method'];
    final id = message['id'];
    final params = switch (message['params']) {
      final Map<String, Object?> p => p,
      _ => const <String, Object?>{},
    };
    if (method is! String) return;
    if (id == null) {
      if (!_initialized && method != 'exit') return;
      try {
        _notifications[method]?.call(params);
      } on Object catch (e, stack) {
        _log(method, e, stack);
      }
      return;
    }
    try {
      if (!_initialized && method != 'initialize') {
        throw const ResponseError(
          ResponseError.serverNotInitialized,
          'initialize comes first',
        );
      }
      if (_shuttingDown) {
        throw const ResponseError(
          ResponseError.invalidRequest,
          'the server is shutting down',
        );
      }
      final handler = _requests[method];
      if (handler == null) {
        throw ResponseError(ResponseError.methodNotFound, 'no $method here');
      }
      connection.send({'id': id, 'result': await handler(params)});
    } on ResponseError catch (e) {
      connection.send({'id': id, 'error': e.toJson()});
    } on FormatException catch (e) {
      connection.send({
        'id': id,
        'error': ResponseError(ResponseError.invalidParams, e.message).toJson(),
      });
    } on Object catch (e, stack) {
      _log(method, e, stack);
      connection.send({
        'id': id,
        'error': ResponseError(
          ResponseError.internalError,
          '$method failed: $e',
        ).toJson(),
      });
    }
  }

  /// A failure the server survives, for the editor's server log: one broken document mustn't take
  /// the others down, or have the editor restart the server until it gives up.
  void _log(String method, Object error, StackTrace stack) {
    final trace = error is StackOverflowError ? '' : '\n$stack';
    stderr.writeln('$name lsp: $method failed: $error$trace');
  }

  Object? _initialize(Map<String, Object?> params) {
    _initialized = true;
    settings = Settings.fromJson(params['initializationOptions']);
    return {
      'capabilities': {
        'positionEncoding': 'utf-16',
        'textDocumentSync': {'openClose': true, 'change': 1},
        'hoverProvider': true,
        'semanticTokensProvider': {'legend': legend, 'full': true},
      },
      'serverInfo': {'name': name, 'version': ciwapaVersion},
    };
  }

  /// The open document [params] names, or null when it isn't open.
  Document? documentOf(Map<String, Object?> params) =>
      switch (params['textDocument']) {
        {'uri': final String uri} => documents[uri],
        _ => null,
      };

  void _didOpen(Map<String, Object?> params) {
    if (params['textDocument'] case {
      'uri': final String uri,
      'text': final String text,
      'version': final int version,
    }) {
      final document = documents[uri] = Document(uri, text, version, this);
      _publish(document);
    }
  }

  void _didChange(Map<String, Object?> params) {
    final document = documentOf(params);
    final changes = params['contentChanges'];
    if (document == null || changes is! List || changes.isEmpty) return;
    // Full sync (change: 1): the last change is the whole text.
    if (changes.last case {'text': final String text}) {
      final version = switch (params['textDocument']) {
        {'version': final int v} => v,
        _ => document.version + 1,
      };
      document.update(text, version);
      _publish(document);
    }
  }

  void _didClose(Map<String, Object?> params) {
    final document = documentOf(params);
    if (document == null) return;
    documents.remove(document.uri);
    connection.send({
      'method': 'textDocument/publishDiagnostics',
      'params': {'uri': document.uri, 'diagnostics': const []},
    });
  }

  void _publish(Document document) {
    if (!document.handled) return;
    connection.send({
      'method': 'textDocument/publishDiagnostics',
      'params': {
        'uri': document.uri,
        'version': document.version,
        'diagnostics': diagnosticsOf(document),
      },
    });
  }
}

/// Runs the server on stdin and stdout, for the CLIs' `lsp` command.
Future<int> runLanguageServer(
  Frontend frontend,
  String name, {
  LanguageExtension extension = const LanguageExtension(),
}) => LanguageServer(
  frontend,
  name: name,
  input: stdin,
  output: stdout,
  extension: extension,
).serve();
