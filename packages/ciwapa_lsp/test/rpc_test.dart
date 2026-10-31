import 'dart:async';
import 'dart:convert';

import 'package:ciwapa_lsp/ciwapa_lsp.dart';
import 'package:test/test.dart';

List<int> frame(String json) {
  final body = utf8.encode(json);
  return [...ascii.encode('Content-Length: ${body.length}\r\n\r\n'), ...body];
}

void main() {
  test('frames split anywhere, or several in one chunk, all arrive', () async {
    final input = StreamController<List<int>>();
    final connection = Connection(
      input.stream,
      StreamController<List<int>>().sink,
    );
    final bytes = [
      ...frame('{"id":1,"method":"a"}'),
      ...frame('{"method":"b","params":{"text":"¢ and 🎉"}}'),
      ...frame('not json'),
      ...frame('[1]'),
      ...frame('{"method":"c"}'),
    ];
    for (var i = 0; i < bytes.length; i += 7) {
      input.add(bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7));
    }
    await input.close();
    final messages = await connection.messages.toList();
    expect([for (final m in messages) m['method']], ['a', 'b', 'c']);
    expect((messages[1]['params'] as Map)['text'], '¢ and 🎉');
  });

  test('sent messages carry their length in bytes, not characters', () async {
    final output = StreamController<List<int>>();
    final bytesFuture = output.stream.toList();
    final connection = Connection(const Stream.empty(), output.sink);
    connection.send({'method': 'x', 'params': '¢'});
    await output.close();
    final bytes = (await bytesFuture).expand((c) => c).toList();
    final text = utf8.decode(bytes);
    final body = text.substring(text.indexOf('\r\n\r\n') + 4);
    expect(
      text,
      startsWith('Content-Length: ${utf8.encode(body).length}\r\n\r\n'),
    );
    expect(jsonDecode(body), {'jsonrpc': '2.0', 'method': 'x', 'params': '¢'});
  });

  test(
    'a frame it can\'t read is skipped, and the next one still arrives',
    () async {
      final input = StreamController<List<int>>();
      final connection = Connection(
        input.stream,
        StreamController<List<int>>().sink,
      );
      input
        ..add(ascii.encode('X-Nonsense: 1\r\n\r\n{"method":"lost"}'))
        ..add(ascii.encode('Content-Length: 99999999999999999999999\r\n\r\n'))
        ..add(frame('{"method":"a"}'))
        ..add(frame('{"method":"b"}'));
      await input.close();
      final messages = await connection.messages.toList();
      expect([for (final m in messages) m['method']], ['a', 'b']);
    },
  );

  test('a frame that isn\'t JSON gets a parse error', () async {
    final input = StreamController<List<int>>();
    final output = StreamController<List<int>>();
    final replies = Connection(
      output.stream,
      StreamController<List<int>>().sink,
    ).messages;
    final connection = Connection(input.stream, output.sink);
    input.add(frame('{"id":1,'));
    final reply = await replies.first;
    expect(reply['id'], isNull);
    expect((reply['error'] as Map)['code'], -32700);
    await input.close();
    await connection.close();
  });
}
