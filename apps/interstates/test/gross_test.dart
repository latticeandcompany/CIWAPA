import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:interstates/interstates.dart';
import 'package:interstates/src/gross.dart';
import 'package:test/test.dart';

import '../bin/gross.dart' show grossArguments, grossConfig;
import 'support.dart';

/// A response as the test sees it.
class Got {
  Got(this.status, this.headers, this.body);

  final int status;
  final HttpHeaders headers;
  final String body;
}

Future<Got> request(
  int port,
  String path, {
  String method = 'GET',
  String? body,
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final req = await client.open(method, '127.0.0.1', port, path);
    req.followRedirects = false;
    headers.forEach(req.headers.set);
    if (body != null) {
      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    final res = await req.close();
    return Got(
      res.statusCode,
      res.headers,
      await res.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

/// The method and the query parameter `name` in the body, one per line.
final echo = program([
  '(16001) NEXT',
  ...writeLine,
  ...string(',1', 'name'),
  '(16040) NEXT',
  ...copy21,
  ...writeLine,
  'GIVE UP',
]);

/// ,1 becomes a copy of ,2, by way of ;49221.
const copy21 = [';49221 SUB #1 <- ,2', ',1 <- ;49221 SUB #1'];

void main() {
  group('gross\'s options (R2, Q120, Q144)', () {
    late Directory dir;
    late String hello;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('gross-options-');
      hello = (File('${dir.path}/hello')..writeAsStringSync('')).path;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('punchline 1: it listens on port 10585 of 127.0.0.1 by default', () {
      final config = grossConfig(grossArguments().parse([hello]));
      expect(config.port, 10585);
      expect(config.bind, '127.0.0.1');
      expect(config.staticDir, isNull);
      expect(config.database, isNull);
      expect(config.timeout, const Duration(seconds: 30));
    });

    test('each option sets what it says', () {
      final config = grossConfig(
        grossArguments().parse([
          '--port',
          '8080',
          '--bind',
          '0.0.0.0',
          '--static',
          dir.path,
          '--database',
          'sqlite:./blog.db',
          '--timeout',
          '5',
          hello,
        ]),
      );
      expect(config.port, 8080);
      expect(config.bind, '0.0.0.0');
      expect(config.staticDir, dir.path);
      expect(config.database, 'sqlite:./blog.db');
      expect(config.timeout, const Duration(seconds: 5));
    });

    test('--static has to name a folder', () {
      expect(
        () => grossConfig(
          grossArguments().parse(['--static', '/no/such/folder', hello]),
        ),
        throwsFormatException,
      );
    });

    test('the program has to exist', () {
      expect(
        () => grossConfig(grossArguments().parse(['${dir.path}/hellp'])),
        throwsFormatException,
      );
    });
  });

  for (final backend in [ioiDart(), ioiLlvm()]) {
    group('gross with ${backend.name}', () {
      late Directory temp;
      late List<String> log;
      final servers = <Gross>[];
      setUp(() {
        temp = Directory.systemTemp.createTempSync('gross-');
        log = [];
      });
      tearDown(() async {
        for (final s in servers) {
          await s.close();
        }
        servers.clear();
        temp.deleteSync(recursive: true);
      });

      Future<Gross> serve(
        String source, {
        bool states = true,
        String? staticDir,
        String? database,
        Duration timeout = const Duration(seconds: 30),
        Map<String, String>? environment,
      }) async {
        final exe = await build(backend, temp, source, states: states);
        final gross = await Gross.start(
          GrossConfig(
            program: exe,
            port: 0,
            staticDir: staticDir,
            database: database,
            timeout: timeout,
            environment: environment,
          ),
          log: log.add,
        );
        servers.add(gross);
        return gross;
      }

      test('R2: each request runs the program, CGI-style', () async {
        final gross = await serve(echo);
        final got = await request(gross.port, '/anything?name=Ada+Lovelace');
        expect(got.status, 200);
        expect(got.headers.contentType?.mimeType, 'text/html');
        expect(got.body, 'GET\nAda Lovelace\n');
        final again = await request(gross.port, '/', method: 'POST');
        expect(again.body, 'POST\n\n');
      });

      test('R2: every run starts fresh', () async {
        final gross = await serve(
          program(['.2 <- #0', 'READ OUT .1', '.1 <- #7', 'GIVE UP']),
        );
        for (var i = 0; i < 2; i++) {
          expect((await request(gross.port, '/')).body, '_\n\n');
        }
      });

      test('R2: the CGI/1.1 variables, and nothing of gross\'s own that looks like them', () async {
        final names = [
          'GATEWAY_INTERFACE',
          'SERVER_PROTOCOL',
          'SERVER_NAME',
          'SERVER_PORT',
          'REQUEST_URI',
          'PATH_INFO',
          'QUERY_STRING',
          'REMOTE_ADDR',
          'REMOTE_HOST',
          'HTTP_X_TEST',
          'HTTP_COOKIE',
          'HTTP_PROXY',
        ];
        final gross = await serve(
          program([
            for (final n in names) ...[
              ...string(',1', n),
              '(8020) NEXT',
              'READ OUT .1',
              ...copy21,
              ...writeLine,
            ],
            'GIVE UP',
          ]),
          environment: {
            ...Platform.environment,
            'HTTP_PROXY': 'http://evil.example',
            'REQUEST_METHOD': 'FAKE',
          },
        );
        final socket = await Socket.connect('127.0.0.1', gross.port);
        socket.write(
          'GET /a%20b/c?x=1 HTTP/1.1\r\nHost: example.test:8080\r\nX-Test: one\r\n'
          'X-Test: two\r\nCookie: a=1\r\nCookie: b=2\r\n\r\n',
        );
        final reply = await utf8.decoder.bind(socket).join();
        final body = reply.substring(reply.indexOf('\r\n\r\n') + 4);
        final values = [
          for (final (i, line) in body.split('\n').indexed)
            if (i % 3 == 2) line,
        ];
        expect(values, [
          'CGI/1.1',
          'HTTP/1.1',
          'example.test',
          '${gross.port}',
          '/a%20b/c?x=1',
          '/a b/c',
          'x=1',
          '127.0.0.1',
          '127.0.0.1',
          'one, two',
          'a=1; b=2',
          // HTTP_PROXY isn't set, so ,2 still holds the cookies.
          'a=1; b=2',
        ]);
        expect(body, endsWith('  \nII\na=1; b=2\n'));
      });

      test(
        'R2: without --database, the inherited DATABASE_URL reaches each run',
        () async {
          final gross = await serve(
            program([
              ...string(',1', 'DATABASE_URL'),
              '(8020) NEXT',
              ...copy21,
              '.1 <- #1',
              '(2310) NEXT',
              'GIVE UP',
            ]),
            environment: {
              ...Platform.environment,
              'DATABASE_URL': 'sqlite:./inherited.db',
            },
          );
          expect(
            (await request(gross.port, '/')).body,
            'sqlite:./inherited.db\n',
          );
        },
      );

      test('R2: the body reaches stdin', () async {
        final gross = await serve(
          program([
            ...string(',1', 'title'),
            '(16050) NEXT',
            ...copy21,
            ...writeLine,
            'GIVE UP',
          ]),
        );
        final got = await request(
          gross.port,
          '/new',
          method: 'POST',
          body: 'title=Hello%2C+gross',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        );
        expect(got.body, 'Hello, gross\n');
      });

      test('R2: the status and headers come from the program', () async {
        final gross = await serve(
          program([
            '.1 <- #418',
            '(16100) NEXT',
            ...string(',1', 'X-Pot'),
            ...string(',2', 'teapot'),
            '(16110) NEXT',
            'GIVE UP',
          ]),
        );
        final got = await request(gross.port, '/');
        expect(got.status, 418);
        expect(got.headers.value('x-pot'), 'teapot');
        expect(got.headers.value('connection'), 'close');
        expect(got.headers.contentLength, 0);
      });

      test('R4: a redirect is a 303 with its Location', () async {
        final gross = await serve(
          program([...string(',1', '/there'), '(16130) NEXT', 'GIVE UP']),
        );
        final got = await request(gross.port, '/');
        expect(got.status, 303);
        expect(got.headers.value('location'), '/there');
      });

      test('R2: --database reaches each run as DATABASE_URL', () async {
        final gross = await serve(
          program([
            ...string(',1', 'DATABASE_URL'),
            '(8020) NEXT',
            ...copy21,
            '.1 <- #1',
            '(2310) NEXT',
            'GIVE UP',
          ]),
          database: 'sqlite:./elsewhere.db',
        );
        expect(
          (await request(gross.port, '/')).body,
          'sqlite:./elsewhere.db\n',
        );
      });

      test('R2: --static serves its files, and nothing outside them', () async {
        final files = Directory('${temp.path}/public')..createSync();
        File('${files.path}/style.css').writeAsStringSync('body {}');
        Directory('${files.path}/css').createSync();
        File('${files.path}/css/site.css').writeAsStringSync('p {}');
        File('${temp.path}/secret.txt').writeAsStringSync('hidden');
        final gross = await serve(echo, staticDir: files.path);
        final css = await request(gross.port, '/style.css');
        expect(css.status, 200);
        expect(css.headers.contentType?.mimeType, 'text/css');
        expect(css.body, 'body {}');
        expect((await request(gross.port, '/css/site.css')).body, 'p {}');
        // Anything else is the program's: a missing file, a folder, or a way out of the folder.
        for (final path in [
          '/missing.css',
          '/css',
          '/../secret.txt',
          '/%2e%2e/secret.txt',
          '/..%5Csecret.txt',
          '/..\\secret.txt',
          '/C:%5Csecret.txt',
          '/NUL.css',
          '/con',
          '/style.css%00.png',
        ]) {
          final socket = await Socket.connect('127.0.0.1', gross.port);
          socket.write('GET $path HTTP/1.1\r\n\r\n');
          final reply = await utf8.decoder.bind(socket).join();
          expect(reply, endsWith('\r\n\r\nGET\n\n'), reason: path);
        }
      });

      test('R2: logs go to stderr, the program\'s stderr included', () async {
        final gross = await serve(
          program([
            '.1 <- #2',
            ...string(',1', 'complaint'),
            '(2310) NEXT',
            'GIVE UP',
          ]),
        );
        await request(gross.port, '/log?x=1');
        // The request's line is written once the response has gone, so it may come a little later.
        final line = RegExp(
          r'^127\.0\.0\.1:\d+ "GET /log\?x=1 HTTP/1\.1" 200 \d+ms$',
        );
        for (var i = 0; i < 100 && !log.any(line.hasMatch); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(log, contains(matches(line)));
        expect(log, contains(endsWith(': complaint')));
      });

      test('an ICL error inside the program is a 500 ICL page', () async {
        final gross = await serve(
          program(['.1 <- #1', '.2 <- ;49221 SUB #1', 'GIVE UP']),
        );
        final got = await request(gross.port, '/');
        expect(got.status, 500);
        expect(got.headers.contentType?.mimeType, 'text/html');
        expect(
          got.body,
          contains(
            '<pre>ICL822I STRINGS AND NUMBERS DO NOT MIX.\n'
            '        A STRING WALKED INTO AN EXPRESSION. THE EXPRESSION DID NOT LAUGH.\n'
            '\tON THE WAY TO STATEMENT 3\n'
            '        CORRECT SOURCE AND RESUBMIT\n</pre>',
          ),
        );
      });

      test('an error after part of the body is written replaces it', () async {
        final gross = await serve(
          program([
            '.1 <- #3',
            'READ OUT .1',
            'READ OUT .1',
            '.2 <- ;4400 SUB #1',
          ]),
        );
        final got = await request(gross.port, '/');
        expect(got.status, 500);
        expect(got.body, isNot(contains('III')));
        expect(got.body, contains('ICL822I'));
      });

      test('E000 escapes the statement it quotes', () async {
        final gross = await serve(
          program(['.1 <- #1', 'SAY <b>bold</b> & "so on"', 'GIVE UP']),
        );
        final got = await request(gross.port, '/');
        expect(got.status, 500);
        expect(
          got.body,
          contains('ICL000I DO SAY &lt;b&gt;bold&lt;/b&gt; &amp; "so on"'),
        );
      });

      test(
        'Q144: a program that runs past --timeout is a 504 ICL page',
        () async {
          final gross = await serve(
            program(['.1 <- #1', 'COME FROM (6)', '.2 <- #2', 'L(6) .1 <- #1']),
            timeout: const Duration(seconds: 1),
          );
          final got = await request(gross.port, '/');
          expect(got.status, 504);
          expect(
            got.body,
            contains('ICL504I THE PROGRAM DID NOT GIVE UP IN TIME.'),
          );
        },
      );

      test(
        'a program that doesn\'t answer in CGI is a 500 page (E829)',
        () async {
          final gross = await serve(
            program(['.1 <- #1', 'READ OUT .1', 'GIVE UP']),
            states: false,
          );
          final got = await request(gross.port, '/');
          expect(got.status, 500);
          expect(
            got.body,
            contains('ICL829I THE PROGRAM DID NOT ANSWER IN CGI.'),
          );
        },
      );

      test('HEAD gets the headers and no body', () async {
        final gross = await serve(echo);
        final got = await request(gross.port, '/', method: 'HEAD');
        expect(got.status, 200);
        expect(got.body, '');
        expect(got.headers.contentLength, 'HEAD\n\n'.length);
      });

      test(
        'a chunked body gets a 411: only Content-Length bodies are read',
        () async {
          final gross = await serve(echo);
          final socket = await Socket.connect('127.0.0.1', gross.port);
          socket.write(
            'POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n',
          );
          final reply = await utf8.decoder.bind(socket).join();
          expect(reply, startsWith('HTTP/1.1 411 Length Required\r\n'));
        },
      );

      test(
        'a chunked body streamed after its head still sees the 411',
        () async {
          final gross = await serve(echo);
          final socket = await Socket.connect('127.0.0.1', gross.port);
          final reply = utf8.decoder.bind(socket).join();
          // gross stops reading once it has refused, so the rest of the body may fail to send.
          unawaited(socket.done.catchError((_) {}));
          socket.add(
            utf8.encode(
              'POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n'
              '${'400\r\n${'x' * 1024}\r\n' * 64}',
            ),
          );
          await socket.flush().catchError((_) {});
          expect(await reply, startsWith('HTTP/1.1 411 Length Required\r\n'));
        },
      );

      test(
        'a request that stops arriving gets a 408 after --timeout',
        () async {
          final gross = await serve(echo, timeout: const Duration(seconds: 1));
          final socket = await Socket.connect('127.0.0.1', gross.port);
          socket.write('GET / HTTP/1.1\r\n');
          final reply = await utf8.decoder
              .bind(socket)
              .join()
              .timeout(const Duration(seconds: 10));
          expect(reply, startsWith('HTTP/1.1 408 Request Timeout\r\n'));
        },
      );

      test('a body over the limit is a 413, a head over 64 KiB a 431, and other HTTP a 400', () async {
        final gross = await serve(echo);
        for (final (head, status) in [
          (
            'POST / HTTP/1.1\r\nContent-Length: ${Gross.bodyLimit + 1}\r\n\r\n',
            '413',
          ),
          ('GET / HTTP/1.1\r\nX-Big: ${'x' * 70000}\r\n\r\n', '431'),
          ('GET / HTTP/2.0\r\n\r\n', '400'),
          ('GET http://example.test/ HTTP/1.1\r\n\r\n', '400'),
        ]) {
          final socket = await Socket.connect('127.0.0.1', gross.port);
          socket.write(head);
          final reply = await utf8.decoder.bind(socket).join();
          expect(reply, startsWith('HTTP/1.1 $status '), reason: status);
        }
      });

      test('Expect: 100-continue gets its interim answer', () async {
        final gross = await serve(
          program([
            ...string(',1', 'a'),
            '(16050) NEXT',
            ...copy21,
            ...writeLine,
            'GIVE UP',
          ]),
        );
        final socket = await Socket.connect('127.0.0.1', gross.port);
        final replies = StreamIterator(utf8.decoder.bind(socket));
        socket.write(
          'POST / HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\n'
          'Content-Length: 3\r\nExpect: 100-continue\r\n\r\n',
        );
        await socket.flush();
        expect(await replies.moveNext(), isTrue);
        expect(replies.current, startsWith('HTTP/1.1 100 Continue\r\n\r\n'));
        socket.write('a=b');
        var rest = replies.current;
        while (await replies.moveNext()) {
          rest += replies.current;
        }
        expect(rest, endsWith('\r\n\r\nb\n'));
      });

      test('headers about the connection don\'t pass through', () async {
        final gross = await serve(
          program([
            ...string(',1', 'Transfer-Encoding'),
            ...string(',2', 'chunked'),
            '(16110) NEXT',
            ...string(',1', 'body'),
            ...writeLine,
            'GIVE UP',
          ]),
        );
        final got = await request(gross.port, '/');
        expect(got.headers.value('transfer-encoding'), isNull);
        expect(got.body, 'body\n');
      });

      test('a request that isn\'t HTTP gets a 400', () async {
        final gross = await serve(echo);
        final socket = await Socket.connect('127.0.0.1', gross.port);
        socket.write('NONSENSE\r\n\r\n');
        final reply = await utf8.decoder.bind(socket).join();
        expect(reply, startsWith('HTTP/1.1 400 Bad Request\r\n'));
      });
    });
  }

  group('reading a run', () {
    const e822 =
        'ICL822I STRINGS AND NUMBERS DO NOT MIX.\n'
        '        A STRING WALKED INTO AN EXPRESSION. THE EXPRESSION DID NOT LAUGH.\n'
        '\tON THE WAY TO STATEMENT 3\n'
        '        CORRECT SOURCE AND RESUBMIT\n';

    test('the ICL error is the one stderr ends with, whatever came before', () {
      expect(iclError('ICL440I hi\n$e822', 822 % 256), (
        822,
        3,
        'STRINGS AND NUMBERS DO NOT MIX.',
      ));
    });

    test('an E000\'s statement runs on in tab-led lines', () {
      const text = 'DO SAY\n\tTWO LINES';
      expect(
        iclError(
          'ICL000I $text\n        JOKE\n\tON THE WAY TO STATEMENT 2\n        CORRECT SOURCE AND RESUBMIT\n',
          0,
        ),
        (0, 2, text),
      );
    });

    test('an error the exit status disagrees with is just text', () {
      expect(iclError(e822, 0), isNull);
    });

    test('a CGI response keeps its reason, and refuses malformed headers', () {
      final ok = cgiResponse(
        utf8.encode('Status: 429 Too Many Requests\nX-A: b\n\nbody'),
      )!;
      expect(
        (ok.status, ok.reason, utf8.decode(ok.body)),
        (429, 'Too Many Requests', 'body'),
      );
      expect(ok.headers, [('X-A', 'b')]);
      for (final bad in [
        'X A: b\n\n',
        'X-A: b\rc\n\n',
        'Status: 99\n\n',
        'X-A: b\n',
        'nonsense\n\n',
      ]) {
        expect(cgiResponse(utf8.encode(bad)), isNull, reason: bad);
      }
      expect(cgiResponse(utf8.encode('Location: /x\r\n\r\n'))!.status, 302);
    });
  });

  test('punchline 1: the gross command serves on http://127.0.0.1:10585, logging to stderr', () async {
    final temp = Directory.systemTemp.createTempSync('gross-cli-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final exe = await build(ioiDart(), temp, echo);
    final gross = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/gross.dart',
      exe,
    ]);
    addTearDown(gross.kill);
    final seen = <String>[];
    final more = StreamController<void>.broadcast();
    gross.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (l) {
        seen.add(l);
        more.add(null);
      },
    );
    Future<String> line(bool Function(String) test) async {
      while (!seen.any(test)) {
        await more.stream.first.timeout(const Duration(minutes: 2));
      }
      return seen.firstWhere(test);
    }

    expect(
      await line((l) => l.startsWith('gross:')),
      'gross: serving $exe on http://127.0.0.1:10585',
    );
    expect((await request(10585, '/?name=gross')).body, 'GET\ngross\n');
    expect(
      await line((l) => l.contains('"GET /?name=gross HTTP/1.1" 200')),
      startsWith('127.0.0.1:'),
    );
  });
}
