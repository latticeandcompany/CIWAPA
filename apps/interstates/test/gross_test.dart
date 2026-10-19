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
    test('punchline 1: it listens on port 10585 of 127.0.0.1 by default', () {
      final config = grossConfig(grossArguments().parse(['./hello']));
      expect(config.port, 10585);
      expect(config.bind, '127.0.0.1');
      expect(config.staticDir, isNull);
      expect(config.database, isNull);
      expect(config.timeout, const Duration(seconds: 30));
    });

    test('each option sets what it says', () {
      final dir = Directory.systemTemp.createTempSync('gross-static-');
      addTearDown(() => dir.deleteSync(recursive: true));
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
          './blog',
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
          grossArguments().parse(['--static', '/no/such/folder', './p']),
        ),
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
      }) async {
        final exe = await build(backend, temp, source, states: states);
        final gross = await Gross.start(
          GrossConfig(
            program: exe,
            port: 0,
            staticDir: staticDir,
            database: database,
            timeout: timeout,
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
        // Fresh every time: nothing carries over from the last run.
        final again = await request(gross.port, '/', method: 'POST');
        expect(again.body, 'POST\n\n');
      });

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
        ]) {
          expect(
            (await request(gross.port, path)).body,
            'GET\n\n',
            reason: path,
          );
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
        expect(
          log,
          contains(
            matches(r'^127\.0\.0\.1:\d+ "GET /log\?x=1 HTTP/1\.1" 200 \d+ms$'),
          ),
        );
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

      test('a request that isn\'t HTTP gets a 400', () async {
        final gross = await serve(echo);
        final socket = await Socket.connect('127.0.0.1', gross.port);
        socket.write('NONSENSE\r\n\r\n');
        final reply = await utf8.decoder.bind(socket).join();
        expect(reply, startsWith('HTTP/1.1 400 Bad Request\r\n'));
      });
    });
  }

  test(
    'punchline 1: the gross command serves on http://127.0.0.1:10585',
    () async {
      final temp = Directory.systemTemp.createTempSync('gross-cli-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final exe = await build(ioiDart(), temp, echo);
      final gross = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/gross.dart',
        exe,
      ]);
      addTearDown(gross.kill);
      final lines = gross.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final ready = await lines
          .firstWhere((l) => l.startsWith('gross:'))
          .timeout(const Duration(minutes: 2));
      expect(ready, 'gross: serving $exe on http://127.0.0.1:10585');
      expect((await request(10585, '/?name=gross')).body, 'GET\ngross\n');
    },
  );
}
