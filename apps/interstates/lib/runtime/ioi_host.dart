// The Interstates host that ioi-dart copies next to every -s program, as ioi_host.dart (with this
// import pointing at the runtime.dart beside it). host.c is its twin; the Interstates suite keeps
// the two identical in behavior.
import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_dart/runtime/runtime.dart';

/// A route, as the compiler ordered them, most specific first and the catch-all last (R3).
class IoiRoute {
  const IoiRoute(this.entry, this.segments, this.allowed);

  /// The ordinal of its `WITH ROUTE` COME FROM, where the program starts for it.
  final int entry;

  /// Its pattern's segments, with null for a `:param`; null for the catch-all.
  final List<String?>? segments;

  /// For a restricted route, the routes (by index) whose pages may link to it; null for a public
  /// one.
  final List<int>? allowed;
}

/// One piece of a compiled template (R6): text as it is (kind 0), template argument [index]
/// (1), the route parameter (2) or template argument (3) a value names, or a value as a numeral
/// (4).
class IoiPiece {
  const IoiPiece(this.kind, this.text, this.index, this.raw, this.attribute);

  final int kind;
  final String text;
  final int index;

  /// Triple grumpies: a string isn't HTML-escaped.
  final bool raw;

  /// Inside an attribute's value, where a numeral's overlines can't be markup.
  final bool attribute;
}

/// A request, read the CGI/1.1 way from the environment and stdin, and the response the program
/// builds for it (R2, R4).
class IoiHost extends IckHost {
  IoiHost({this.routes = const [], this.templates = const []});

  final List<IoiRoute> routes;
  final List<List<IoiPiece>> templates;
  final Map<String, String> _env = Platform.environment;

  /// The route parameters, `;4400`, and the template arguments, `;49221` (R5).
  final _params = <String>[];
  final _args = <int, String>{};

  var _status = 200;
  final _headers = <(String, String)>[];
  var _sent = false;
  List<int>? _body;

  @override
  bool petition(
    int service,
    List<int> scalars,
    List<int> arrays,
    List<int> values,
    int next,
  ) {
    switch (service) {
      case 16001:
        ickSetString(arrays[0], _env['REQUEST_METHOD'] ?? '');
      case 16010:
        ickSetString(arrays[0], _env['QUERY_STRING'] ?? '');
      case 16020:
        _found(scalars[0], arrays[1], _header(ickString(arrays[0], next)));
      case 16030:
        _found(scalars[0], arrays[1], _cookie(ickString(arrays[0], next)));
      case 16040:
        _found(
          scalars[0],
          arrays[1],
          _field(
            utf8.encode(_env['QUERY_STRING'] ?? ''),
            ickString(arrays[0], next),
          ),
        );
      case 16050:
        _found(
          scalars[0],
          arrays[1],
          _field(_form(), ickString(arrays[0], next)),
        );
      case 16060:
        ickSetString(arrays[0], String.fromCharCodes(_requestBody()));
      case 16100:
        _unsent(next);
        _status = ickScalar(scalars[0]);
      case 16110:
        _unsent(next);
        final name = ickString(arrays[0], next);
        final value = ickString(arrays[1], next);
        if (!_isToken(name) || !_isFieldValue(value)) ickFatal(828, next);
        _headers.add((name, value));
      case 16120:
        _unsent(next);
        final name = ickString(arrays[0], next);
        final value = ickString(arrays[1], next);
        if (!_isToken(name) || !value.codeUnits.every(_isCookieOctet)) {
          ickFatal(828, next);
        }
        _headers.add(('Set-Cookie', '$name=$value; Path=/'));
      case 16130:
        _unsent(next);
        final location = ickString(arrays[0], next);
        if (!_isFieldValue(location)) ickFatal(828, next);
        _status = 303;
        _headers.add(('Location', location));
      case 16510:
        ickSetString(arrays[0], _param(values[0], next));
      case 16511:
        ickSetString(arrays[0], _arg(values[0], next));
      case 16512:
        _setArg(values[0], ickString(arrays[0], next), next);
      case 16513:
        _setArg(values[0], _param(values[1], next), next);
      case 16514:
        _setArg(values[0], _arg(values[1], next), next);
      case 16520:
        ickFatal(values[0], next);
      case 16500:
        _render(templates[values[0]], values, next);
      default:
        return false;
    }
    return true;
  }

  /// Where the request's route starts the program (R3, Q113, Q114): no route is E440 (a 404
  /// page), and a restricted route whose `Referer` isn't a page that may link to it is E403.
  @override
  int start() {
    final matched = _match(_requestPath());
    if (matched == null) ickFatal(440, 1);
    final (index, values) = matched;
    final route = routes[index];
    if (route.allowed case final allowed?) {
      final referer = _refererPath();
      final from = referer == null ? null : _match(referer)?.$1;
      if (from == null || !allowed.contains(from)) ickFatal(403, route.entry);
    }
    _params.addAll(values);
    return route.entry;
  }

  /// The route [segments] lead to, and its parameters' values.
  (int, List<String>)? _match(List<String>? segments) {
    if (segments == null) return null;
    for (final (i, route) in routes.indexed) {
      final pattern = route.segments;
      if (pattern == null) return (i, const []);
      if (pattern.length != segments.length) continue;
      final values = <String>[];
      var fits = true;
      for (var j = 0; j < pattern.length && fits; j++) {
        if (pattern[j] == null) {
          values.add(segments[j]);
        } else {
          fits = pattern[j] == segments[j];
        }
      }
      if (fits) return (i, values);
    }
    return null;
  }

  /// The request's path segments, decoded: from REQUEST_URI as sent, so that `%2F` stays inside
  /// its segment, or failing that from PATH_INFO.
  List<String>? _requestPath() {
    if (_env['REQUEST_URI'] case final uri?) {
      return _segments(
        uri.replaceFirst(RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]*'), ''),
      );
    }
    final info = _env['PATH_INFO'] ?? '';
    return (info.isEmpty ? '/' : info).substring(1).split('/');
  }

  /// The `Referer`'s path, when it is a page of this same host.
  List<String>? _refererPath() {
    final referer = _env['HTTP_REFERER'];
    final host = _env['HTTP_HOST'];
    if (referer == null || host == null) return null;
    final m = RegExp(
      r'^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]*)(.*)$',
      dotAll: true,
    ).firstMatch(referer);
    if (m == null || _asciiLower(m.group(1)!) != _asciiLower(host)) return null;
    final path = m.group(2)!;
    return _segments(path.isEmpty || !path.startsWith('/') ? '/$path' : path);
  }

  static String _asciiLower(String s) => String.fromCharCodes([
    for (final c in s.codeUnits) c >= 0x41 && c <= 0x5A ? c + 32 : c,
  ]);

  /// A raw path's segments, up to any `?` or `#`, each percent-decoded; null unless it starts
  /// with `/`.
  static List<String>? _segments(String raw) {
    final end = raw.indexOf(RegExp('[?#]'));
    final path = end < 0 ? raw : raw.substring(0, end);
    if (!path.startsWith('/')) return null;
    return [
      for (final s in path.substring(1).split('/')) urlDecode(utf8.encode(s)),
    ];
  }

  /// `READ OUT #n WITH TEMPLATE` (R6): the template's pieces, with values from [values] (after
  /// the template's number), written all at once.
  void _render(List<IoiPiece> pieces, List<int> values, int next) {
    final out = <int>[];
    var v = 1;
    for (final p in pieces) {
      switch (p.kind) {
        case 0:
          out.addAll(utf8.encode(p.text));
        case 1:
          out.addAll(_html(_args[p.index] ?? '', raw: p.raw));
        case 2:
          out.addAll(_html(_param(values[v++], next), raw: p.raw));
        case 3:
          out.addAll(_html(_arg(values[v++], next), raw: p.raw));
        default:
          out.addAll(utf8.encode(_numeral(values[v++], p.attribute)));
      }
    }
    ickOutput(out);
  }

  /// [s] as UTF-8, escaped for HTML unless [raw].
  static List<int> _html(String s, {required bool raw}) => utf8.encode(
    raw
        ? s
        : s
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;')
              .replaceAll('"', '&quot;')
              .replaceAll("'", '&#39;'),
  );

  /// A number as READ OUT's butchered Roman numeral. A letter under READ OUT's bar row (×1000)
  /// gets `text-decoration: overline`, and one under its top row (×10^12, for 64-bit values) a
  /// `border-top` line above that; in an attribute's value, where markup can't go, they are
  /// combining characters instead, U+0305 and U+033F. Zero is an overlined no-break space. In wimp
  /// mode it is plain decimal.
  static String _numeral(int value, bool attribute) {
    final rows = ickNumeralLines(value);
    if (rows.length == 1) return rows.single;
    final letters = rows.last;
    final top = rows.length == 3 ? rows[0] : '';
    final bars = rows[rows.length - 2];
    final width = [
      letters.length,
      top.length,
      bars.length,
    ].reduce((a, b) => a > b ? a : b);
    final out = StringBuffer();
    var run = StringBuffer();
    var runStyle = -1;
    void flush() {
      if (run.isEmpty) return;
      out.write(switch (runStyle) {
        0 => '$run',
        1 => '<span style="text-decoration: overline">$run</span>',
        2 => '<span style="border-top: 1px solid">$run</span>',
        _ =>
          '<span style="border-top: 1px solid"><span style="text-decoration: overline">$run</span></span>',
      });
      run = StringBuffer();
    }

    for (var c = 0; c < width; c++) {
      final letter = c < letters.length ? letters[c] : '\u00A0';
      final barred = c < bars.length && bars[c] == '_';
      final topped = c < top.length && top[c] == '_';
      if (attribute) {
        out.write(letter);
        if (barred) out.write('\u0305');
        if (topped) out.write('\u033F');
        continue;
      }
      final style = (topped ? 2 : 0) + (barred ? 1 : 0);
      if (style != runStyle) flush();
      runStyle = style;
      run.write(letter);
    }
    flush();
    return out.toString();
  }

  /// The CGI response's headers, before the first byte of its body (R2).
  @override
  void prologue() {
    _sent = true;
    final head = StringBuffer('Status: $_status ${_reason(_status)}\n');
    if (!_headers.any((h) => _asciiLower(h.$1) == 'content-type')) {
      head.write('Content-Type: text/html; charset=utf-8\n');
    }
    for (final (name, value) in _headers) {
      head.write('$name: $value\n');
    }
    head.write('\n');
    ickOutput(utf8.encode(head.toString()));
  }

  /// The status and headers can't change once the body has started (E823).
  void _unsent(int next) {
    if (_sent) ickFatal(823, next);
  }

  /// A header name is an HTTP token (RFC 9110).
  static bool _isToken(String s) =>
      s.isNotEmpty && RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(s);

  /// A header value has no control characters but tabs, so it can't split the response.
  static bool _isFieldValue(String s) =>
      !s.codeUnits.any((c) => (c < 0x20 && c != 0x09) || c == 0x7F);

  /// RFC 6265's cookie-octet: ASCII with no controls, spaces, `"`, `,`, `;` or `\`, so a value
  /// can't add attributes to its cookie.
  static bool _isCookieOctet(int c) =>
      c == 0x21 ||
      (c >= 0x23 && c <= 0x2B) ||
      (c >= 0x2D && c <= 0x3A) ||
      (c >= 0x3C && c <= 0x5B) ||
      (c >= 0x5D && c <= 0x7E);

  /// Stores a lookup's result: [value] in the array [into] and status #1, or #2 when there is none.
  void _found(int status, int into, String? value) {
    if (value != null) ickSetString(into, value);
    ickSetScalar(status, value == null ? 2 : 1);
  }

  /// A request header, as CGI passes it: `HTTP_` and the name in capitals with `-` as `_`, except
  /// the two it passes without the prefix. A name that isn't ASCII letters, digits, `-` and `_`
  /// finds nothing.
  String? _header(String name) {
    if (name.isEmpty ||
        name.length > 256 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(name)) {
      return null;
    }
    final key = _asciiUpper(name).replaceAll('-', '_');
    return _env[key == 'CONTENT_TYPE' || key == 'CONTENT_LENGTH'
        ? key
        : 'HTTP_$key'];
  }

  static String _asciiUpper(String s) => String.fromCharCodes([
    for (final c in s.codeUnits) c >= 0x61 && c <= 0x7A ? c - 32 : c,
  ]);

  /// [s] without spaces and tabs at either end.
  static String _trimmed(String s) =>
      s.replaceAll(RegExp(r'^[ \t]+|[ \t]+$'), '');

  String? _cookie(String name) {
    for (final pair in (_env['HTTP_COOKIE'] ?? '').split(';')) {
      final equals = pair.indexOf('=');
      if (equals >= 0 && _trimmed(pair.substring(0, equals)) == name) {
        return _trimmed(pair.substring(equals + 1));
      }
    }
    return null;
  }

  /// The first [name] in an `application/x-www-form-urlencoded` list of bytes, decoded.
  static String? _field(List<int> encoded, String name) {
    var start = 0;
    for (var i = 0; i <= encoded.length; i++) {
      if (i < encoded.length && encoded[i] != 0x26) continue;
      var equals = start;
      while (equals < i && encoded[equals] != 0x3D) {
        equals++;
      }
      if (urlDecode(encoded.sublist(start, equals), plus: true) == name) {
        return equals < i
            ? urlDecode(encoded.sublist(equals + 1, i), plus: true)
            : '';
      }
      start = i + 1;
    }
    return null;
  }

  /// `%XX` is a byte and, with [plus], `+` a space; then the bytes are decoded as [decodeUtf8]
  /// does.
  static String urlDecode(List<int> bytes, {bool plus = false}) {
    final out = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      final high = i + 2 < bytes.length ? _hexDigit(bytes[i + 1]) : -1;
      final low = i + 2 < bytes.length ? _hexDigit(bytes[i + 2]) : -1;
      if (b == 0x2B && plus) {
        out.add(0x20);
      } else if (b == 0x25 && high >= 0 && low >= 0) {
        out.add(high * 16 + low);
        i += 2;
      } else {
        out.add(b);
      }
    }
    return decodeUtf8(out);
  }

  static int _hexDigit(int c) => switch (c) {
    >= 0x30 && <= 0x39 => c - 0x30,
    >= 0x61 && <= 0x66 => c - 0x61 + 10,
    >= 0x41 && <= 0x46 => c - 0x41 + 10,
    _ => -1,
  };

  /// The body of a form post, or nothing for any other kind of body.
  List<int> _form() {
    final type = _asciiLower(_env['CONTENT_TYPE'] ?? '');
    if (!type.startsWith('application/x-www-form-urlencoded')) return const [];
    return _requestBody();
  }

  /// The request body, read once from stdin: CONTENT_LENGTH bytes, or up to the end of input.
  List<int> _requestBody() {
    if (_body case final body?) return body;
    final lengthText = _env['CONTENT_LENGTH'] ?? '';
    final length = RegExp(r'^[0-9]{1,18}$').hasMatch(lengthText)
        ? int.parse(lengthText)
        : null;
    final body = <int>[];
    while (length == null || body.length < length) {
      final b = ickReadByte();
      if (b < 0) break;
      body.add(b);
    }
    return _body = body;
  }

  /// `;4400 SUB n`: a parameter the route doesn't have is E241.
  String _param(int n, int next) {
    if (n < 1 || n > _params.length) ickFatal(241, next);
    return _params[n - 1];
  }

  /// `;49221 SUB n`: one never stored is the empty string.
  String _arg(int n, int next) {
    if (n < 1 || n > 0xFFFFFFFF) ickFatal(241, next);
    return _args[n] ?? '';
  }

  void _setArg(int n, String value, int next) {
    if (n < 1 || n > 0xFFFFFFFF) ickFatal(241, next);
    _args[n] = value;
  }

  static String _reason(int status) => switch (status) {
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
    409 => 'Conflict',
    410 => 'Gone',
    418 => "I'm a teapot",
    422 => 'Unprocessable Content',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    503 => 'Service Unavailable',
    _ => 'Unknown',
  };
}

/// UTF-8 bytes as a string: a lead byte that starts no sequence, or whose continuation bytes run
/// out or are interrupted, is U+FFFD and uses up only itself; a complete sequence that is
/// overlong, a surrogate or above U+10FFFF is U+FFFD and uses up all its bytes (the Strings
/// block's rules, as host.c's str_decode).
String decodeUtf8(List<int> bytes) {
  final units = <int>[];
  var i = 0;
  while (i < bytes.length) {
    final lead = bytes[i];
    if (lead < 0x80) {
      units.add(lead);
      i++;
      continue;
    }
    var need = 0, minimum = 0, value = 0;
    if (lead >> 5 == 6) {
      (need, minimum, value) = (1, 0x80, lead & 0x1F);
    } else if (lead >> 4 == 14) {
      (need, minimum, value) = (2, 0x800, lead & 0x0F);
    } else if (lead >> 3 == 30) {
      (need, minimum, value) = (3, 0x10000, lead & 0x07);
    }
    var got = 0;
    while (got < need &&
        i + got + 1 < bytes.length &&
        bytes[i + got + 1] >> 6 == 2) {
      value = value << 6 | (bytes[i + got + 1] & 0x3F);
      got++;
    }
    if (need == 0 || got < need) {
      units.add(0xFFFD);
      i++;
      continue;
    }
    i += need + 1;
    if (value < minimum || value > 0x10FFFF || value >> 11 == 27) {
      units.add(0xFFFD);
    } else if (value >= 0x10000) {
      units
        ..add(0xD800 | ((value - 0x10000) >> 10))
        ..add(0xDC00 | ((value - 0x10000) & 0x3FF));
    } else {
      units.add(value);
    }
  }
  return String.fromCharCodes(units);
}
