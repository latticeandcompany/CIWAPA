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

  /// Every message the other side sends, in order. A frame that isn't JSON is answered with a
  /// parse error; one that is JSON but not an object is dropped.
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
    _buffer =
        (BytesBuilder(copy: false)
              ..add(_buffer)
              ..add(chunk))
            .takeBytes();
    while (true) {
      final headerEnd = _indexOf(_blankLine, _buffer);
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
      final bodyLength = length == null ? null : int.tryParse(length[1]!);
      if (bodyLength == null) {
        // Not a frame we can read: start again at the next Content-Length.
        final next = _indexOf(_contentLength, _buffer, from: 1);
        _buffer = next < 0 ? Uint8List(0) : _buffer.sublist(next);
        continue;
      }
      final bodyStart = headerEnd + _blankLine.length;
      final bodyEnd = bodyStart + bodyLength;
      if (_buffer.length < bodyEnd) return;
      final body = utf8.decode(
        _buffer.sublist(bodyStart, bodyEnd),
        allowMalformed: true,
      );
      _buffer = _buffer.sublist(bodyEnd);
      final Object? message;
      try {
        message = jsonDecode(body);
      } on FormatException catch (e) {
        send({
          'id': null,
          'error': ResponseError(ResponseError.parseError, e.message).toJson(),
        });
        continue;
      }
      if (message is Map<String, Object?>) _messages.add(message);
    }
  }

  static final _blankLine = ascii.encode('\r\n\r\n');
  static final _contentLength = ascii.encode('Content-Length:');

  static int _indexOf(List<int> pattern, Uint8List bytes, {int from = 0}) {
    outer:
    for (var i = from; i + pattern.length <= bytes.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) continue outer;
      }
      return i;
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
  static const internalError = -32603;
  static const requestFailed = -32803;

  final int code;
  final String message;

  Map<String, Object?> toJson() => {'code': code, 'message': message};
}
