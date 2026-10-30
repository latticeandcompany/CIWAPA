import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// JSON-RPC 2.0 messages framed the LSP way: `Content-Length: n` and a blank line, then n bytes
/// of UTF-8 JSON (Q169: hand-rolled, with no dependencies).
class Connection {
  Connection(Stream<List<int>> input, this._output) {
    _subscription = input.listen(
      _receive,
      onDone: () => _messages.close(),
      onError: _messages.addError,
    );
  }

  final StreamSink<List<int>> _output;
  late final StreamSubscription<List<int>> _subscription;
  final _messages = StreamController<Map<String, Object?>>();
  var _buffer = Uint8List(0);

  /// Every message the other side sends, in order. A frame that isn't a JSON object is dropped.
  Stream<Map<String, Object?>> get messages => _messages.stream;

  void send(Map<String, Object?> message) {
    final body = utf8.encode(jsonEncode({'jsonrpc': '2.0', ...message}));
    _output.add(ascii.encode('Content-Length: ${body.length}\r\n\r\n'));
    _output.add(body);
  }

  Future<void> close() async {
    await _subscription.cancel();
    // stdout may still hold the last response when the process exits.
    if (_output case final IOSink sink) await sink.flush();
    if (!_messages.isClosed) await _messages.close();
  }

  void _receive(List<int> chunk) {
    _buffer = Uint8List.fromList([..._buffer, ...chunk]);
    while (true) {
      final headerEnd = _indexOfBlankLine(_buffer);
      if (headerEnd < 0) return;
      final headers = ascii.decode(
        _buffer.sublist(0, headerEnd),
        allowInvalid: true,
      );
      final length = RegExp(
        r'^Content-Length:\s*(\d+)\s*$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(headers);
      final bodyStart = headerEnd + 4;
      if (length == null) {
        // Not a frame we can read: skip its headers and hope the next one is.
        _buffer = _buffer.sublist(bodyStart);
        continue;
      }
      final bodyEnd = bodyStart + int.parse(length.group(1)!);
      if (_buffer.length < bodyEnd) return;
      final body = utf8.decode(
        _buffer.sublist(bodyStart, bodyEnd),
        allowMalformed: true,
      );
      _buffer = _buffer.sublist(bodyEnd);
      final Object? message;
      try {
        message = jsonDecode(body);
      } on FormatException {
        continue;
      }
      if (message is Map<String, Object?>) _messages.add(message);
    }
  }

  static int _indexOfBlankLine(Uint8List bytes) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }
}

/// An error a request handler throws to answer with a JSON-RPC error.
class ResponseError implements Exception {
  const ResponseError(this.code, this.message);

  static const parseError = -32700;
  static const invalidRequest = -32600;
  static const methodNotFound = -32601;
  static const invalidParams = -32602;
  static const serverNotInitialized = -32002;
  static const requestFailed = -32803;

  final int code;
  final String message;

  Map<String, Object?> toJson() => {'code': code, 'message': message};
}
