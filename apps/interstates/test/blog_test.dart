// Step 10: the sample blog runs end to end in programs built by both flavors: the list (built by
// looping in INTERCAL over fragments), a post at /blog/post/:id, and the form that creates one
// with INTO DATABASE, all linked, so the link check and the Referer check both take part.
import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:interstates/interstates.dart';
import 'package:interstates/src/gross.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  for (final backend in [ioiDart(), ioiLlvm()]) {
    test('${backend.name}: list, create, view', () async {
      final temp = Directory.systemTemp.createTempSync('ioi-blog-');
      addTearDown(() => deleteSoon(temp));
      final exe = '${temp.path}/blog${Platform.isWindows ? '.exe' : ''}';
      expect(
        await runCli(
          [
            'build',
            '--no-random-bug',
            '-s',
            'examples/blog/blog.xc',
            '-o',
            exe,
          ],
          backend,
          frontend: InterstatesFrontend(),
        ),
        0,
      );
      final gross = await Gross.start(
        GrossConfig(
          program: exe,
          port: 0,
          staticDir: 'examples/blog/public',
          database: 'sqlite:${temp.path}/blog.db',
        ),
        log: (_) {},
      );
      addTearDown(gross.close);
      final site = 'http://127.0.0.1:${gross.port}';

      Future<(int, String, HttpHeaders)> go(
        String method,
        String path, {
        String? referer,
        String? form,
      }) async {
        final client = HttpClient();
        try {
          final request = await client.open(
            method,
            '127.0.0.1',
            gross.port,
            path,
          );
          request.followRedirects = false;
          if (referer != null) request.headers.set('Referer', '$site$referer');
          if (form != null) {
            request.headers.contentType = ContentType(
              'application',
              'x-www-form-urlencoded',
            );
            final bytes = utf8.encode(form);
            request.contentLength = bytes.length;
            request.add(bytes);
          }
          final response = await request.close();
          return (
            response.statusCode,
            await response.transform(utf8.decoder).join(),
            response.headers,
          );
        } finally {
          client.close(force: true);
        }
      }

      final (status, empty, _) = await go('GET', '/blog');
      expect(status, 200);
      expect(empty, contains('<ul class="posts">\n</ul>'));

      final (_, form, _) = await go('GET', '/blog/new', referer: '/blog');
      expect(form, contains('action="/blog/create"'));

      // The form only posts from its own page.
      expect(
        (await go('POST', '/blog/create', form: 'title=x&body=y')).$1,
        403,
      );

      final (created, _, headers) = await go(
        'POST',
        '/blog/create',
        referer: '/blog/new',
        form: 'title=Hello%2C+world&body=COME+FROM+%3Cthe+start%3E',
      );
      expect(created, 303);
      expect(headers.value('location'), '/blog');
      await go(
        'POST',
        '/blog/create',
        referer: '/blog/new',
        form: 'title=Caf%C3%A9+%E2%9C%93&body=Second',
      );

      final (_, list, _) = await go('GET', '/blog');
      expect(
        list,
        contains(
          '<li><a href="/blog/post/1">Hello, world</a></li>\n'
          '<li><a href="/blog/post/2">Café ✓</a></li>\n',
        ),
      );

      final (viewed, post, _) = await go(
        'GET',
        '/blog/post/1',
        referer: '/blog',
      );
      expect(viewed, 200);
      expect(
        post,
        contains('<h1>Hello, world</h1>\n<p>COME FROM &lt;the start&gt;</p>'),
      );

      // A post is only reachable from the list: not directly, and not from any other page, the
      // catch-all and the post itself included, though every route NEXTs to the same routine.
      expect((await go('GET', '/blog/post/1')).$1, 403);
      for (final page in ['/blog/new', '/nowhere', '/', '/blog/post/1']) {
        expect(
          (await go('GET', '/blog/post/1', referer: page)).$1,
          403,
          reason: page,
        );
      }

      // A post needs both fields, and a GET has neither.
      for (final (method, form) in [
        ('POST', 'title=Only+a+title'),
        ('POST', 'body=Only+a+body'),
        ('GET', null),
      ]) {
        final (status, page, _) = await go(
          method,
          '/blog/create',
          referer: '/blog/new',
          form: form,
        );
        expect(status, 400, reason: '$method $form');
        expect(page, contains('A post needs a title and a body'));
      }

      // Markup in a title stays text, in the list and in the post's <title>.
      await go(
        'POST',
        '/blog/create',
        referer: '/blog/new',
        form: 'title=%3Cb%3E%22x%22%3C%2Fb%3E&body=z',
      );
      final (_, escaped, _) = await go('GET', '/blog');
      expect(
        escaped,
        contains('<a href="/blog/post/3">&lt;b&gt;&quot;x&quot;&lt;/b&gt;</a>'),
      );
      expect(
        (await go('GET', '/blog/post/3', referer: '/blog')).$2,
        contains('<title>&lt;b&gt;&quot;x&quot;&lt;/b&gt; | The INTERCAL Blog'),
      );

      final (missing, page, _) = await go(
        'GET',
        '/blog/post/99',
        referer: '/blog',
      );
      expect(missing, 404);
      expect(page, contains('No such post'));

      final (redirected, _, to) = await go('GET', '/');
      expect(redirected, 303);
      expect(to.value('location'), '/blog');

      expect((await go('GET', '/blog.css')).$2, contains('font: 17px/1.5'));
    });
  }
}
