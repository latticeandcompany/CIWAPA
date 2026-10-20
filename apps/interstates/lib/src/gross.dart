import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'errors.dart';

/// How `gross` runs (R2, Q120, Q144).
class GrossConfig {
  const GrossConfig({
    required this.program,
    this.port = defaultPort,
    this.bind = '127.0.0.1',
    this.staticDir,
    this.database,
    this.timeout = const Duration(seconds: 30),
    this.environment,
  });

  /// Punchline 1: the General READ OUT Server System listens on 10585.
  static const defaultPort = 10585;

  final String program;
  final int port;
  final String bind;

  /// `--static`: files are served from here, and only when it is given.
  final String? staticDir;

  /// `--database`: the ActiveCassette connection each run gets as DATABASE_URL.
  final String? database;

  /// How long a request may take to arrive, and how long its run may take.
  final Duration timeout;

  /// The environment the program's runs start from; gross's own by default.
  final Map<String, String>? environment;
}

/// The General READ OUT Server System: an HTTP/1.1 server that runs a CGI program once per
/// request (R2). It speaks the same HTTP/1.1 as EXTRACAL's Network block: one request per
/// connection, bodies by `Content-Length`, and `Connection: close` on every response (L39).
class Gross {
  Gross._(this.config, this._server, this._program, this._log);

  final GrossConfig config;
  final ServerSocket _server;
  final String _program;
  final void Function(String line) _log;

  /// The runs going on, which closing gross stops.
  final _running = <Process>{};

  /// The most a request body or a run's output may be.
  static const bodyLimit = 16 * 1024 * 1024, outputLimit = 64 * 1024 * 1024;

  /// The port it listens on, which is the configured one unless that was 0.
  int get port => _server.port;

  /// Starts listening. [log] gets one line per request and anything the program writes to
  /// stderr; by default it goes to stderr.
  static Future<Gross> start(
    GrossConfig config, {
    void Function(String line)? log,
  }) async {
    final server = await ServerSocket.bind(config.bind, config.port);
    final gross = Gross._(
      config,
      server,
      executable(config.program),
      log ?? stderr.writeln,
    );
    server.listen(gross._serve);
    return gross;
  }

  /// Stops listening, and stops every run still going.
  Future<void> close() async {
    await _server.close();
    for (final p in _running) {
      p.kill(ProcessSignal.sigkill);
    }
  }

  /// The program to run, as an absolute path; on Windows `.exe` may be left off.
  static String executable(String program) {
    final file = File(program);
    if (!file.existsSync() &&
        Platform.isWindows &&
        File('$program.exe').existsSync()) {
      return File('$program.exe').absolute.path;
    }
    return file.absolute.path;
  }

  Future<void> _serve(Socket socket) async {
    final started = Stopwatch()..start();
    final peer = '${socket.remoteAddress.address}:${socket.remotePort}';
    var line = '-';
    var status = 0;
    final input = StreamIterator(socket);
    try {
      final HttpRequest request;
      try {
        request = await HttpRequest.read(socket, input).timeout(config.timeout);
      } on TimeoutException {
        status = 408;
        await _write(socket, _plain(408, reasonPhrase(408)), head: false);
        return;
      } on HttpRefusal catch (e) {
        status = e.status;
        await _write(
          socket,
          _plain(e.status, reasonPhrase(e.status)),
          head: false,
        );
        return;
      }
      line = '${request.method} ${request.target} ${request.version}';
      final response =
          await _static(request) ??
          await _run(request, socket.remoteAddress, socket.remotePort);
      status = response.status;
      await _write(socket, response, head: request.method == 'HEAD');
    } on SocketException {
      // The client went away.
    } on Object catch (e) {
      _log('gross: $e');
    } finally {
      await _hangUp(socket, input);
      _log(
        _printable(
          '$peer "$line" ${status == 0 ? '-' : status} ${started.elapsedMilliseconds}ms',
        ),
      );
    }
  }

  /// Ends a connection gently: stops writing, then reads and drops what the client still sends
  /// for up to a second, so that the answer isn't lost to a reset, and only then lets go.
  static Future<void> _hangUp(
    Socket socket,
    StreamIterator<Uint8List> input,
  ) async {
    try {
      unawaited(socket.close().catchError((_) => null));
      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (await input.moveNext().timeout(
        deadline.difference(DateTime.now()),
        onTimeout: () => false,
      )) {}
    } on Object {
      // The client is already gone.
    } finally {
      unawaited(input.cancel());
      socket.destroy();
    }
  }

  /// A file under `--static` that the path names, if there is one (R2: no folder is served
  /// unless the flag names it).
  Future<HttpResponse?> _static(HttpRequest request) async {
    final dir = config.staticDir;
    if (dir == null || (request.method != 'GET' && request.method != 'HEAD')) {
      return null;
    }
    final segments = request.path
        .split('/')
        .skip(1)
        .map(_percentDecode)
        .toList();
    final unsafe = segments.any(
      (s) =>
          s.isEmpty ||
          s == '.' ||
          s == '..' ||
          s.contains(RegExp(r'[/\\:\x00]')) ||
          _windowsDevice.hasMatch(s),
    );
    if (unsafe) return null;
    final path = [dir, ...segments].join(Platform.pathSeparator);
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
      return null;
    }
    try {
      return HttpResponse(200, [
        ('Content-Type', _contentType(path)),
      ], await File(path).readAsBytes());
    } on FileSystemException {
      return null;
    }
  }

  /// Windows' reserved device names, which name a device in every folder.
  static final _windowsDevice = RegExp(
    r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
    caseSensitive: false,
  );

  Future<HttpResponse> _run(
    HttpRequest request,
    InternetAddress remote,
    int remotePort,
  ) async {
    final Process process;
    try {
      process = await Process.start(
        _program,
        const [],
        environment: _environment(request, remote, remotePort),
        includeParentEnvironment: false,
      );
    } on ProcessException catch (e) {
      _log('gross: cannot run ${config.program}: ${e.message}');
      return _page(829, 1);
    }
    _running.add(process);
    var overflowed = false;
    var size = 0;
    Future<BytesBuilder> collect(Stream<List<int>> stream) =>
        stream.fold(BytesBuilder(), (b, d) {
          size += d.length;
          if (size > outputLimit) {
            overflowed = true;
            process.kill(ProcessSignal.sigkill);
            return b;
          }
          return b..add(d);
        });
    final out = collect(process.stdout);
    final err = collect(process.stderr);
    process.stdin.add(request.body);
    unawaited(process.stdin.close().catchError((_) {}));
    final exited = await process.exitCode
        .then<int?>((c) => c)
        .timeout(
          config.timeout,
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return null;
          },
        );
    final errors = utf8.decode((await err).takeBytes(), allowMalformed: true);
    final output = (await out).takeBytes();
    await process.exitCode;
    _running.remove(process);
    for (final l in const LineSplitter().convert(errors)) {
      _log(_printable('${config.program}: $l'));
    }
    if (exited == null) return _page(504, 1);
    if (overflowed || exited < 0) return _page(829, 1);
    if (iclError(errors, exited) case (
      final code,
      final statement,
      final text,
    )) {
      return _page(code, statement, text: text);
    }
    return cgiResponse(output) ?? _page(829, 1);
  }

  /// The CGI/1.1 variables for [request], over the environment gross was started with, less
  /// anything that would look like part of the request.
  Map<String, String> _environment(
    HttpRequest request,
    InternetAddress remote,
    int remotePort,
  ) {
    final env = {
      for (final MapEntry(:key, :value)
          in (config.environment ?? Platform.environment).entries)
        if (!key.toUpperCase().startsWith('HTTP_') &&
            !_cgiVariables.contains(key.toUpperCase()))
          key: value,
    };
    final host = request.header('host') ?? '${config.bind}:$port';
    env.addAll({
      'GATEWAY_INTERFACE': 'CGI/1.1',
      'SERVER_SOFTWARE': 'gross',
      'SERVER_PROTOCOL': request.version,
      'SERVER_NAME': host.replaceFirst(RegExp(r':\d+$'), ''),
      'SERVER_PORT': '$port',
      'REQUEST_METHOD': request.method,
      'REQUEST_URI': request.target,
      'SCRIPT_NAME': '',
      'PATH_INFO': _percentDecode(request.path),
      'QUERY_STRING': request.query,
      'REMOTE_ADDR': remote.address,
      'REMOTE_HOST': remote.address,
      'REMOTE_PORT': '$remotePort',
      if (request.body.isNotEmpty || request.header('content-length') != null)
        'CONTENT_LENGTH': '${request.body.length}',
      'CONTENT_TYPE': ?request.header('content-type'),
      'DATABASE_URL': ?config.database,
    });
    for (final (name, value) in request.headers) {
      final key = name.toUpperCase().replaceAll('-', '_');
      if (key == 'CONTENT_TYPE' || key == 'CONTENT_LENGTH') continue;
      if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(key)) continue;
      final previous = env['HTTP_$key'];
      env['HTTP_$key'] = previous == null
          ? value
          : '$previous${key == 'COOKIE' ? '; ' : ', '}$value';
    }
    return env;
  }

  static const _cgiVariables = {
    'GATEWAY_INTERFACE',
    'SERVER_SOFTWARE',
    'SERVER_PROTOCOL',
    'SERVER_NAME',
    'SERVER_PORT',
    'REQUEST_METHOD',
    'REQUEST_URI',
    'SCRIPT_NAME',
    'PATH_INFO',
    'QUERY_STRING',
    'REMOTE_ADDR',
    'REMOTE_HOST',
    'REMOTE_PORT',
    'CONTENT_LENGTH',
    'CONTENT_TYPE',
  };

  Future<void> _write(
    Socket socket,
    HttpResponse response, {
    required bool head,
  }) async {
    final out = StringBuffer(
      'HTTP/1.1 ${response.status} ${response.reason ?? reasonPhrase(response.status)}\r\n',
    );
    for (final (name, value) in response.headers) {
      if (_hopByHop.contains(name.toLowerCase())) continue;
      out.write('$name: $value\r\n');
    }
    out
      ..write('Content-Length: ${response.body.length}\r\n')
      ..write('Connection: close\r\n\r\n');
    socket.add(utf8.encode(out.toString()));
    if (!head) socket.add(response.body);
    await socket.flush();
  }

  /// Headers about this one connection, which gross sets itself or leaves out.
  static const _hopByHop = {
    'connection',
    'content-length',
    'keep-alive',
    'proxy-connection',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };
}

/// [line] with its control characters escaped, so it can't move the operator's cursor.
String _printable(String line) => line.replaceAllMapped(
  RegExp(r'[\x00-\x1f\x7f]'),
  (m) => '\\x${m[0]!.codeUnitAt(0).toRadixString(16).padLeft(2, '0')}',
);

/// An ICL-style error page (Design & Behavior): the four lines of the error, as the program
/// would have printed them. E403 is 403 Forbidden, E440 404 Not Found and E504 504 Gateway
/// Timeout; any other ICL error is the program's own fault, 500.
HttpResponse _page(int code, int statement, {String? text}) {
  final error = _error(code);
  final message = error.format(statement, message: text);
  final status = switch (code) {
    403 => 403,
    440 => 404,
    504 => 504,
    _ => 500,
  };
  final title = 'ICL${code.toString().padLeft(3, '0')}I';
  final html =
      '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$title</title>
<style>
body { margin: 0; padding: 2rem; background: #fff8e7; color: #1a1a1a; font: 16px/1.4 "Courier New", monospace; }
pre { white-space: pre-wrap; border-top: 3px double #1a1a1a; border-bottom: 3px double #1a1a1a; padding: 1rem 0; }
</style>
</head>
<body>
<pre>${const HtmlEscape(HtmlEscapeMode.element).convert(message)}</pre>
</body>
</html>
''';
  return HttpResponse(status, [
    ('Content-Type', 'text/html; charset=utf-8'),
  ], utf8.encode(html));
}

/// One of CIWAPA's errors, or one of Interstates' own.
IclError _error(int code) =>
    IclError.all.where((e) => e.code == code).firstOrNull ??
    interstatesErrors.firstWhere(
      (e) => e.code == code,
      orElse: () => IclError(code, '', ''),
    );

/// The ICL error a run ended with, as (code, statement, official text), or null: the four lines
/// at the very end of its stderr, from the start of a line (E000's text runs on in lines that start
/// with a tab), and an exit status that agrees with the code (T34).
(int, int, String)? iclError(String stderr, int exitCode) {
  final match = RegExp(
    r'(?:^|\n)ICL(\d{3})I ([^\n]*(?:\n\t[^\n]*)*?)\n {8}[^\n]*\n\tON THE WAY TO STATEMENT (\d+)\n {8}CORRECT SOURCE AND RESUBMIT\n?$',
  ).firstMatch(stderr);
  if (match == null) return null;
  final code = int.parse(match.group(1)!);
  if (code % 256 != exitCode) return null;
  return (code, int.parse(match.group(3)!), match.group(2)!);
}

/// A CGI response turned into an HTTP one: its `Status` (and reason), or 302 for a bare
/// `Location`, or 200; its other headers; and its body. Null if it isn't one: no empty line ends
/// its headers, a line isn't `name: value` with a token for a name and no CR or NUL in the
/// value, or the status isn't three digits from 100 to 599.
HttpResponse? cgiResponse(List<int> output) {
  var status = 200;
  String? reason;
  var located = false, statused = false;
  final headers = <(String, String)>[];
  var at = 0;
  while (true) {
    final end = output.indexOf(0x0A, at);
    if (end < 0) return null;
    var lineEnd = end;
    if (lineEnd > at && output[lineEnd - 1] == 0x0D) lineEnd--;
    final line = utf8.decode(output.sublist(at, lineEnd), allowMalformed: true);
    at = end + 1;
    if (line.isEmpty) break;
    final colon = line.indexOf(':');
    if (colon <= 0) return null;
    final name = line.substring(0, colon);
    final value = line.substring(colon + 1).trim();
    if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(name) ||
        value.contains(RegExp('[\r\x00]'))) {
      return null;
    }
    if (name.toLowerCase() == 'status') {
      final m = RegExp(r'^([1-5][0-9]{2})(?: (.*))?$').firstMatch(value);
      if (m == null) return null;
      status = int.parse(m.group(1)!);
      reason = m.group(2);
      statused = true;
    } else {
      if (name.toLowerCase() == 'location') located = true;
      headers.add((name, value));
    }
  }
  if (located && !statused) status = 302;
  return HttpResponse(status, headers, output.sublist(at), reason: reason);
}

class HttpResponse {
  HttpResponse(this.status, this.headers, this.body, {this.reason});

  final int status;
  final List<(String, String)> headers;
  final List<int> body;

  /// The program's own reason phrase, if it gave one.
  final String? reason;
}

HttpResponse _plain(int status, String text) => HttpResponse(status, [
  ('Content-Type', 'text/plain; charset=utf-8'),
], utf8.encode('$text\n'));

/// A request gross won't read, and the status it answers instead (L39).
class HttpRefusal implements Exception {
  HttpRefusal(this.status);

  final int status;
}

/// One HTTP/1.1 request, read as EXTRACAL's (9200) reads one: empty lines skipped, then the
/// request line and headers, then a `Content-Length` body.
class HttpRequest {
  HttpRequest(this.method, this.target, this.version, this.headers, this.body);

  final String method;

  /// The request target as sent: the path and any query.
  final String target;
  final String version;
  final List<(String, String)> headers;
  final Uint8List body;

  String get path {
    final question = target.indexOf('?');
    return question < 0 ? target : target.substring(0, question);
  }

  String get query {
    final question = target.indexOf('?');
    return question < 0 ? '' : target.substring(question + 1);
  }

  String? header(String name) {
    for (final (n, v) in headers) {
      if (n.toLowerCase() == name) return v;
    }
    return null;
  }

  static const _headLimit = 64 * 1024;

  /// The request on [socket]. Refuses one with [HttpRefusal]: 400 for one that isn't HTTP/1.0 or
  /// 1.1 in origin form (or that stops short), 431 for a head over 64 KiB, 411 for a body sent with
  /// a transfer encoding, and 413 for a body over [Gross.bodyLimit]. It answers
  /// `Expect: 100-continue` before reading the body.
  static Future<HttpRequest> read(
    Socket socket,
    StreamIterator<Uint8List> chunks,
  ) async {
    final buffer = BytesBuilder(copy: false);
    var bytes = Uint8List(0);
    var headEnd = -1;
    {
      while (headEnd < 0) {
        if (!await chunks.moveNext()) throw HttpRefusal(400);
        buffer.add(chunks.current);
        bytes = buffer.toBytes();
        // Empty lines before the request line are skipped.
        var start = 0;
        while (start < bytes.length &&
            (bytes[start] == 0x0D || bytes[start] == 0x0A)) {
          start++;
        }
        headEnd = _blankLine(bytes, start);
        if (headEnd < 0 && bytes.length > _headLimit) throw HttpRefusal(431);
      }
      if (headEnd > _headLimit) throw HttpRefusal(431);
      final head = utf8.decode(bytes.sublist(0, headEnd), allowMalformed: true);
      final lines = head
          .split('\n')
          .map((l) => l.endsWith('\r') ? l.substring(0, l.length - 1) : l)
          .skipWhile((l) => l.isEmpty)
          .toList();
      final parts = lines.first.split(' ');
      if (parts.length != 3 ||
          !parts[1].startsWith('/') ||
          !RegExp(r'^HTTP/1\.[01]$').hasMatch(parts[2])) {
        throw HttpRefusal(400);
      }
      final headers = <(String, String)>[];
      for (final line in lines.skip(1)) {
        if (line.isEmpty) continue;
        final colon = line.indexOf(':');
        if (colon <= 0) throw HttpRefusal(400);
        headers.add((
          line.substring(0, colon).trim(),
          line.substring(colon + 1).trim(),
        ));
      }
      final request = HttpRequest(
        parts[0],
        parts[1],
        parts[2],
        headers,
        Uint8List(0),
      );
      // Like EXTRACAL's Network block, gross reads only Content-Length bodies.
      final encoding = request.header('transfer-encoding');
      if (encoding != null && encoding.toLowerCase() != 'identity') {
        throw HttpRefusal(411);
      }
      final lengthText = request.header('content-length');
      final length = lengthText == null
          ? 0
          : (RegExp(r'^[0-9]{1,18}$').hasMatch(lengthText)
                ? int.parse(lengthText)
                : null);
      if (length == null) throw HttpRefusal(400);
      if (length > Gross.bodyLimit) throw HttpRefusal(413);
      final bodyStart = bytes[headEnd + 1] == 0x0D ? headEnd + 3 : headEnd + 2;
      final body = BytesBuilder(copy: false)..add(bytes.sublist(bodyStart));
      if (body.length < length &&
          request.header('expect')?.toLowerCase() == '100-continue') {
        socket.add(utf8.encode('HTTP/1.1 100 Continue\r\n\r\n'));
        await socket.flush();
      }
      while (body.length < length) {
        if (!await chunks.moveNext()) throw HttpRefusal(400);
        body.add(chunks.current);
      }
      return HttpRequest(
        request.method,
        request.target,
        request.version,
        headers,
        Uint8List.sublistView(body.toBytes(), 0, length),
      );
    }
  }

  /// Where the empty line that ends the headers starts (its first CR or LF), from [start], or -1.
  static int _blankLine(Uint8List bytes, int start) {
    for (var i = start; i + 1 < bytes.length; i++) {
      if (bytes[i] != 0x0A) continue;
      if (bytes[i + 1] == 0x0A) return i;
      if (i + 2 < bytes.length &&
          bytes[i + 1] == 0x0D &&
          bytes[i + 2] == 0x0A) {
        return i;
      }
    }
    return -1;
  }
}

/// `%XX` decoded, with the bytes read as UTF-8.
String _percentDecode(String text) {
  final bytes = <int>[];
  for (var i = 0; i < text.length; i++) {
    final hex = i + 2 < text.length ? text.substring(i + 1, i + 3) : '';
    if (text[i] == '%' && RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(hex)) {
      bytes.add(int.parse(hex, radix: 16));
      i += 2;
    } else {
      bytes.addAll(utf8.encode(text[i]));
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _contentType(String path) {
  final dot = path.lastIndexOf('.');
  final extension = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'html' || 'htm' => 'text/html; charset=utf-8',
    'css' => 'text/css; charset=utf-8',
    'js' || 'mjs' => 'text/javascript; charset=utf-8',
    'json' => 'application/json',
    'txt' => 'text/plain; charset=utf-8',
    'svg' => 'image/svg+xml',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'ico' => 'image/x-icon',
    'woff' => 'font/woff',
    'woff2' => 'font/woff2',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

String reasonPhrase(int status) => switch (status) {
  100 => 'Continue',
  200 => 'OK',
  201 => 'Created',
  204 => 'No Content',
  301 => 'Moved Permanently',
  302 => 'Found',
  303 => 'See Other',
  304 => 'Not Modified',
  307 => 'Temporary Redirect',
  308 => 'Permanent Redirect',
  400 => 'Bad Request',
  401 => 'Unauthorized',
  403 => 'Forbidden',
  404 => 'Not Found',
  405 => 'Method Not Allowed',
  408 => 'Request Timeout',
  409 => 'Conflict',
  410 => 'Gone',
  411 => 'Length Required',
  413 => 'Content Too Large',
  418 => "I'm a teapot",
  422 => 'Unprocessable Content',
  431 => 'Request Header Fields Too Large',
  500 => 'Internal Server Error',
  501 => 'Not Implemented',
  503 => 'Service Unavailable',
  504 => 'Gateway Timeout',
  _ => 'Unknown',
};
