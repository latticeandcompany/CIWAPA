/// An LSP client for tests: it runs a [LanguageServer] in the same isolate, or talks to one in
/// another process, and speaks to it the way an editor would.
library;

import 'dart:async';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'src/extension.dart';
import 'src/rpc.dart';
import 'src/server.dart';

class TestClient {
  TestClient._(Stream<List<int>> fromServer, StreamSink<List<int>> toServer)
    : _connection = Connection(fromServer, toServer) {
    _connection.messages.listen(_receive);
  }

  /// A client for a server running here, around [frontend].
  factory TestClient(
    Frontend frontend, {
    String name = 'ciwapa-test',
    LanguageExtension extension = const LanguageExtension(),
  }) {
    final toServer = StreamController<List<int>>();
    final fromServer = StreamController<List<int>>();
    final client = TestClient._(fromServer.stream, toServer.sink);
    client.server = LanguageServer(
      frontend,
      name: name,
      input: toServer.stream,
      output: fromServer.sink,
      extension: extension,
    );
    client.exitCode = client.server!.serve();
    return client;
  }

  /// A client for the server that `<executable> <arguments>` starts, on its stdin and stdout.
  static Future<TestClient> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    process.stderr.drain<void>();
    return TestClient._(process.stdout, process.stdin)
      ..exitCode = process.exitCode;
  }

  final Connection _connection;
  LanguageServer? server;

  /// What the in-process server's [LanguageServer.serve] returns.
  late final Future<int> exitCode;

  var _nextId = 1;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final _notifications = <Map<String, Object?>>[];
  final _waiters =
      <
        (bool Function(Map<String, Object?>), Completer<Map<String, Object?>>)
      >[];

  /// Every notification so far, oldest first.
  List<Map<String, Object?>> get notifications =>
      List.unmodifiable(_notifications);

  void _receive(Map<String, Object?> message) {
    final id = message['id'];
    if (id is int && message.containsKey('method') == false) {
      _pending.remove(id)?.complete(message);
      return;
    }
    if (id != null) {
      // A request from the server: answer it with nothing.
      _connection.send({'id': id, 'result': null});
    }
    _notifications.add(message);
    for (final waiter in [..._waiters]) {
      if (waiter.$1(message)) {
        _waiters.remove(waiter);
        waiter.$2.complete(message);
      }
    }
  }

  /// The whole response to a request: its `result` or its `error`.
  Future<Map<String, Object?>> send(String method, [Object? params]) {
    final id = _nextId++;
    final completer = _pending[id] = Completer<Map<String, Object?>>();
    _connection.send({'id': id, 'method': method, 'params': ?params});
    return completer.future.timeout(const Duration(seconds: 30));
  }

  /// A request's result, failing the test on an error.
  Future<T> request<T>(String method, [Object? params]) async {
    final response = await send(method, params);
    if (response['error'] != null) {
      throw StateError('$method failed: ${response['error']}');
    }
    return response['result'] as T;
  }

  void notify(String method, [Object? params]) =>
      _connection.send({'method': method, 'params': ?params});

  /// The next notification that [test] accepts.
  Future<Map<String, Object?>> next(
    bool Function(Map<String, Object?> message) test,
  ) {
    final completer = Completer<Map<String, Object?>>();
    _waiters.add((test, completer));
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<Map<String, Object?>> initialize([Object? options]) async {
    final result = await request<Map<String, Object?>>('initialize', {
      'processId': null,
      'rootUri': null,
      'capabilities': <String, Object?>{},
      'initializationOptions': ?options,
    });
    notify('initialized', <String, Object?>{});
    return result;
  }

  /// Opens a document and returns the diagnostics the server publishes for it.
  Future<List<Map<String, Object?>>> open(
    String uri,
    String text, {
    int version = 1,
  }) {
    final published = diagnosticsFor(uri);
    notify('textDocument/didOpen', {
      'textDocument': {
        'uri': uri,
        'languageId': 'intercal',
        'version': version,
        'text': text,
      },
    });
    return published;
  }

  /// Replaces a document's text and returns its new diagnostics.
  Future<List<Map<String, Object?>>> change(
    String uri,
    String text, {
    required int version,
  }) {
    final published = diagnosticsFor(uri);
    notify('textDocument/didChange', {
      'textDocument': {'uri': uri, 'version': version},
      'contentChanges': [
        {'text': text},
      ],
    });
    return published;
  }

  /// The next diagnostics published for [uri].
  Future<List<Map<String, Object?>>> diagnosticsFor(String uri) async {
    final message = await next(
      (m) =>
          m['method'] == 'textDocument/publishDiagnostics' &&
          (m['params'] as Map)['uri'] == uri,
    );
    return ((message['params'] as Map)['diagnostics'] as List)
        .cast<Map<String, Object?>>();
  }

  /// Shuts the server down politely.
  Future<void> shutdown() async {
    await request<Object?>('shutdown');
    notify('exit');
  }
}

/// The codes of [diagnostics], such as `E182`, in order.
List<Object?> codesOf(List<Map<String, Object?>> diagnostics) => [
  for (final d in diagnostics) d['code'],
];

/// A decoded semantic token: where it is, and its type and modifiers by name.
typedef DecodedToken = ({
  int line,
  int character,
  int length,
  String type,
  Set<String> modifiers,
});

/// Decodes `semanticTokens/full`'s [result] with the server's [legend].
List<DecodedToken> decodeTokens(
  Map<String, Object?> result,
  Map<String, Object?> legend,
) {
  final data = (result['data'] as List).cast<int>();
  final types = (legend['tokenTypes'] as List).cast<String>();
  final modifiers = (legend['tokenModifiers'] as List).cast<String>();
  final tokens = <DecodedToken>[];
  var line = 0, character = 0;
  for (var i = 0; i < data.length; i += 5) {
    line += data[i];
    character = data[i] == 0 ? character + data[i + 1] : data[i + 1];
    tokens.add((
      line: line,
      character: character,
      length: data[i + 2],
      type: types[data[i + 3]],
      modifiers: {
        for (var m = 0; m < modifiers.length; m++)
          if (data[i + 4] & (1 << m) != 0) modifiers[m],
      },
    ));
  }
  return tokens;
}

/// The text of each of [tokens] in [text], with its type: what a highlighter would color.
List<(String, String)> coloredText(String text, List<DecodedToken> tokens) {
  final lines = text.split(RegExp(r'\r\n|\r|\n'));
  return [
    for (final t in tokens)
      (lines[t.line].substring(t.character, t.character + t.length), t.type),
  ];
}
