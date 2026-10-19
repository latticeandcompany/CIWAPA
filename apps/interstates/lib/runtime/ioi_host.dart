// The Interstates host that ioi-dart copies next to every -s program, as ioi_host.dart (with this
// import pointing at the runtime.dart beside it). host.c is its twin; the Interstates suite keeps
// the two identical in behavior.
import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_dart/runtime/runtime.dart';

/// A request, read the CGI/1.1 way from the environment and stdin, and the response the program
/// builds for it (R2, R4).
class IoiHost extends IckHost {
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
          _field(_env['QUERY_STRING'] ?? '', ickString(arrays[0], next)),
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
        _headers.add(
          _checked(
            ickString(arrays[0], next),
            ickString(arrays[1], next),
            next,
          ),
        );
      case 16120:
        _unsent(next);
        final (name, value) = _checked(
          ickString(arrays[0], next),
          ickString(arrays[1], next),
          next,
        );
        _headers.add(('Set-Cookie', '$name=$value; Path=/'));
      case 16130:
        _unsent(next);
        _status = 303;
        _headers.add(_checked('Location', ickString(arrays[0], next), next));
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
      default:
        return false;
    }
    return true;
  }

  /// The CGI response's headers, before the first byte of its body (R2).
  @override
  void prologue() {
    _sent = true;
    final head = StringBuffer('Status: $_status ${_reason(_status)}\n');
    if (!_headers.any((h) => h.$1.toLowerCase() == 'content-type')) {
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

  /// A header line break would split the response (E828).
  (String, String) _checked(String name, String value, int next) {
    if ('$name$value'.contains(RegExp('[\r\n]'))) ickFatal(828, next);
    return (name, value);
  }

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

  /// The first [name] in a `application/x-www-form-urlencoded` list, decoded.
  static String? _field(String encoded, String name) {
    for (final pair in encoded.split('&')) {
      final equals = pair.indexOf('=');
      final key = equals < 0 ? pair : pair.substring(0, equals);
      if (_decode(key) == name) {
        return equals < 0 ? '' : _decode(pair.substring(equals + 1));
      }
    }
    return null;
  }

  /// Form decoding: `+` is a space and `%XX` a byte, the other characters stand for their UTF-8,
  /// and the bytes are decoded as [decodeUtf8] does.
  static String _decode(String text) {
    final bytes = <int>[];
    final units = text.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final c = units[i];
      final high = i + 2 < units.length ? _hexDigit(units[i + 1]) : -1;
      final low = i + 2 < units.length ? _hexDigit(units[i + 2]) : -1;
      if (c == 0x2B) {
        bytes.add(0x20);
      } else if (c == 0x25 && high >= 0 && low >= 0) {
        bytes.add(high * 16 + low);
        i += 2;
      } else {
        final pair =
            c >= 0xD800 &&
            c <= 0xDBFF &&
            i + 1 < units.length &&
            units[i + 1] >= 0xDC00 &&
            units[i + 1] <= 0xDFFF;
        bytes.addAll(
          utf8.encode(String.fromCharCodes(units, i, i + (pair ? 2 : 1))),
        );
        if (pair) i++;
      }
    }
    return decodeUtf8(bytes);
  }

  static int _hexDigit(int c) => switch (c) {
    >= 0x30 && <= 0x39 => c - 0x30,
    >= 0x61 && <= 0x66 => c - 0x61 + 10,
    >= 0x41 && <= 0x46 => c - 0x41 + 10,
    _ => -1,
  };

  /// The body of a form post, one unit per byte, or nothing for any other kind of body.
  String _form() {
    final type = _env['CONTENT_TYPE'] ?? '';
    const form = 'application/x-www-form-urlencoded';
    final lowered = String.fromCharCodes([
      for (final c in type.codeUnits) c >= 0x41 && c <= 0x5A ? c + 32 : c,
    ]);
    if (!lowered.startsWith(form)) return '';
    return String.fromCharCodes(_requestBody());
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
