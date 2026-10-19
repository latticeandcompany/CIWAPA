// The Interstates host that ioi-dart copies next to every -s program, as ioi_host.dart (with this
// import pointing at the runtime.dart beside it). host.c is its twin; the Interstates suite keeps
// the two identical in behavior.
import 'dart:convert';
import 'dart:ffi';
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
  IoiHost({
    this.routes = const [],
    this.templates = const [],
    this.sqliteLibrary,
  });

  final List<IoiRoute> routes;
  final List<List<IoiPiece>> templates;

  /// The built-in SQLite adapter's library, for a program that uses a database.
  final String? sqliteLibrary;
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
      case 16200 || 16210 || 16600 || 16610 || 16620 || 16630 || 16640:
        _database(service, scalars, arrays, values, next);
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

  // ---- ActiveCassette (R7, Q95, Q99, Q119, Q145) ------------------------------------------

  Pointer<_Adapter>? _adapter;
  var _db = nullptr.cast<Void>();

  /// Table and column names, by number from 1, read from the database when first needed.
  List<String>? _tables;
  final _columns = <int, List<String>>{};

  /// What (16210) reports: rows the last read matched, or the last write changed.
  var _lastCount = 0;

  /// Writes ActiveCassette's reason to stderr, then raises [code].
  Never _cassetteFail(int code, String? reason, int next) {
    stderr.add(utf8.encode('ActiveCassette: ${reason ?? 'no reason given'}\n'));
    ickFatal(code, next);
  }

  String? _adapterError(Pointer<Void> db) {
    final p = _adapter!.ref.error
        .asFunction<Pointer<Uint8> Function(Pointer<Void>)>()(db);
    return p == nullptr ? null : _fromC(p);
  }

  void _forgetSchema() {
    _tables = null;
    _columns.clear();
  }

  Pointer<_Adapter> _loadAdapter(String scheme, int next) {
    if (scheme.length > 64) {
      _cassetteFail(825, "the DATABASE_URL's scheme is too long", next);
    }
    final name =
        'IOI_ADAPTER_${String.fromCharCodes([for (final c in scheme.codeUnits) c >= 0x61 && c <= 0x7A ? c - 32 : c])}';
    final path = _env[name];
    if (path == null) {
      _cassetteFail(
        825,
        'no adapter for $scheme: set $name to its library',
        next,
      );
    }
    try {
      return DynamicLibrary.open(path).lookupFunction<
        Pointer<_Adapter> Function(),
        Pointer<_Adapter> Function()
      >('ioi_adapter_entry')();
    } on ArgumentError {
      _cassetteFail(
        825,
        "the adapter's library can't be loaded, or has no ioi_adapter_entry",
        next,
      );
    }
  }

  /// Connects to DATABASE_URL (sqlite:./app.db when it isn't set), the first time a program
  /// needs to.
  void _cassette(int next) {
    if (_db != nullptr) return;
    final url = _env['DATABASE_URL'] ?? 'sqlite:./app.db';
    final colon = url.indexOf(':');
    if (colon <= 0) _cassetteFail(825, 'the DATABASE_URL has no scheme', next);
    final scheme = url.substring(0, colon);
    Pointer<_Adapter>? adapter;
    if (scheme == 'sqlite') {
      try {
        adapter = sqliteLibrary == null
            ? null
            : DynamicLibrary.open(sqliteLibrary!).lookupFunction<
                Pointer<_Adapter> Function(),
                Pointer<_Adapter> Function()
              >('ioi_sqlite_adapter')();
      } on ArgumentError {
        adapter = null;
      }
      if (adapter == null) {
        _cassetteFail(825, 'this program has no SQLite', next);
      }
    } else {
      adapter = _loadAdapter(scheme, next);
    }
    if (adapter.ref.version != 1) {
      _cassetteFail(825, 'the adapter is not version 1', next);
    }
    _adapter = adapter;
    final text = _toC(utf8.encode(url));
    _db = adapter.ref.connect
        .asFunction<Pointer<Void> Function(Pointer<Uint8>)>()(text);
    _free(text.cast());
    if (_db == nullptr) _cassetteFail(825, _adapterError(nullptr), next);
  }

  /// A column's value as a string: its digits for an integer, its text decoded, and nothing for
  /// NULL.
  static String _valueString(_Value v) => switch (v.kind) {
    1 => '${v.integer}',
    2 => decodeUtf8(v.text.asTypedList(v.length)),
    _ => '',
  };

  int _next(Pointer<Void> rows) =>
      _adapter!.ref.next.asFunction<int Function(Pointer<Void>)>()(rows);

  int _width(Pointer<Void> rows) =>
      _adapter!.ref.width.asFunction<int Function(Pointer<Void>)>()(rows);

  void _finish(Pointer<Void> rows) =>
      _adapter!.ref.finish.asFunction<void Function(Pointer<Void>)>()(rows);

  String _column(Pointer<Void> rows, int i) {
    final out = _malloc(sizeOf<_Value>()).cast<_Value>();
    _adapter!.ref.column
        .asFunction<void Function(Pointer<Void>, int, Pointer<_Value>)>()(
      rows,
      i,
      out,
    );
    final value = _valueString(out.ref);
    _free(out.cast());
    return value;
  }

  /// Every row's first column, from rows the adapter gave (or E826).
  List<String> _firstColumns(Pointer<Void> rows, int next) {
    if (rows == nullptr) _cassetteFail(826, _adapterError(_db), next);
    final out = <String>[];
    int status;
    while ((status = _next(rows)) == 1) {
      out.add(_width(rows) > 0 ? _column(rows, 0) : '');
    }
    _finish(rows);
    if (status < 0) _cassetteFail(826, _adapterError(_db), next);
    return out;
  }

  List<String> _knownTables(int next) => _tables ??= _firstColumns(
    _adapter!.ref.tables.asFunction<Pointer<Void> Function(Pointer<Void>)>()(
      _db,
    ),
    next,
  );

  /// Table [t] (from 1): E824 past the end of the schema.
  String _tableName(int t, int next) {
    final tables = _knownTables(next);
    if (t < 1 || t > tables.length) _cassetteFail(824, 'no such table', next);
    return tables[t - 1];
  }

  /// Column [c] (from 1) of table [t]: E824 past the end of the table.
  String _columnName(int t, int c, int next) {
    final table = _tableName(t, next);
    final columns = _columns[t] ??= () {
      final name = _toC(utf8.encode(table));
      final rows = _adapter!.ref.columns
          .asFunction<
            Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>)
          >()(_db, name);
      _free(name.cast());
      return _firstColumns(rows, next);
    }();
    if (c < 1 || c > columns.length) _cassetteFail(824, 'no such column', next);
    return columns[c - 1];
  }

  static String _identifier(String name) => '"${name.replaceAll('"', '""')}"';

  /// An item's value as a parameter (services.dart's ItemKind): a number (as text past 2^63 - 1),
  /// a tail array's string, or a `;4400` or `;49221` element's. Reads its two values at [at].
  Object _item(List<int> arrays, List<int> values, List<int> at, int next) {
    final kind = values[at[0]++], value = values[at[0]++];
    return switch (kind) {
      0 => value >= 0 ? value : BigInt.from(value).toUnsigned(64).toString(),
      1 => ickString(arrays[value], next),
      2 => _param(value, next),
      _ => _arg(value, next),
    };
  }

  /// ` WHERE "a" = ? AND "b" = ?` for a HAVING list at [at]: its count, then (column, item) pairs.
  void _having(
    StringBuffer sql,
    List<Object> params,
    int t,
    List<int> arrays,
    List<int> values,
    List<int> at,
    int next,
  ) {
    final pairs = values[at[0]++];
    for (var i = 0; i < pairs; i++) {
      sql
        ..write(i == 0 ? ' WHERE ' : ' AND ')
        ..write(_identifier(_columnName(t, values[at[0]++], next)))
        ..write(' = ?');
      params.add(_item(arrays, values, at, next));
    }
  }

  /// Runs [sql] with [params] (ints and strings), and returns its rows.
  Pointer<Void> _query(String sql, List<Object> params, int next) {
    final text = _toC(utf8.encode(sql));
    final array = _malloc(
      sizeOf<_Value>() * (params.isEmpty ? 1 : params.length),
    ).cast<_Value>();
    final owned = <Pointer<Uint8>>[];
    for (final (i, p) in params.indexed) {
      final v = array[i];
      if (p is int) {
        v
          ..kind = 1
          ..integer = p
          ..text = nullptr
          ..length = 0;
      } else {
        final bytes = utf8.encode(p as String);
        final copy = _toC(bytes);
        owned.add(copy);
        v
          ..kind = 2
          ..integer = 0
          ..text = copy
          ..length = bytes.length;
      }
    }
    final rows = _adapter!.ref.query
        .asFunction<
          Pointer<Void> Function(
            Pointer<Void>,
            Pointer<Uint8>,
            Pointer<_Value>,
            int,
          )
        >()(_db, text, array, params.length);
    for (final p in owned) {
      _free(p.cast());
    }
    _free(array.cast());
    _free(text.cast());
    if (rows == nullptr) _cassetteFail(826, _adapterError(_db), next);
    return rows;
  }

  int _changes() =>
      _adapter!.ref.changes.asFunction<int Function(Pointer<Void>)>()(_db);

  /// Runs a statement that returns no rows, and counts what it changed.
  void _execute(StringBuffer sql, List<Object> params, int next) {
    final rows = _query(sql.toString(), params, next);
    int status;
    while ((status = _next(rows)) == 1) {}
    _finish(rows);
    if (status < 0) _cassetteFail(826, _adapterError(_db), next);
    _lastCount = _changes();
  }

  /// Runs a query, leaving row [row]'s columns (from 1) in `;49221` (which it empties first) and
  /// how many rows there were in [_lastCount]; a statement with no columns counts its changes.
  void _queryIntoArgs(
    StringBuffer sql,
    List<Object> params,
    int row,
    int next,
  ) {
    final rows = _query(sql.toString(), params, next);
    _args.clear();
    var count = 0;
    int status;
    final width = _width(rows);
    while ((status = _next(rows)) == 1) {
      if (++count != row) continue;
      for (var i = 0; i < width; i++) {
        _setArg(i + 1, _column(rows, i), next);
      }
    }
    _finish(rows);
    if (status < 0) _cassetteFail(826, _adapterError(_db), next);
    _lastCount = width > 0 ? count : _changes();
  }

  /// The column list of a read or write at [at]: [t, columns, c...]; a read without columns gets
  /// them all.
  void _columnList(
    StringBuffer sql,
    int t,
    List<int> values,
    List<int> at,
    bool star,
    int next,
  ) {
    final count = values[at[0]++];
    if (count == 0 && star) sql.write('*');
    for (var i = 0; i < count; i++) {
      if (i > 0) sql.write(', ');
      sql.write(_identifier(_columnName(t, values[at[0]++], next)));
    }
  }

  void _database(
    int service,
    List<int> scalars,
    List<int> arrays,
    List<int> values,
    int next,
  ) {
    _cassette(next);
    final sql = StringBuffer();
    final params = <Object>[];
    final at = [0];
    switch (service) {
      case 16600:
        final t = values[at[0]++];
        final table = _tableName(t, next);
        sql.write('SELECT ');
        _columnList(sql, t, values, at, true, next);
        sql
          ..write(' FROM ')
          ..write(_identifier(table));
        final row = values[at[0]++];
        _having(sql, params, t, arrays, values, at, next);
        _queryIntoArgs(sql, params, row, next);
      case 16610:
        final t = values[at[0]++];
        final table = _tableName(t, next);
        final count = values[at[0]];
        sql.write('INSERT INTO ${_identifier(table)} (');
        _columnList(sql, t, values, at, false, next);
        sql.write(') VALUES (');
        for (var i = 0; i < count; i++) {
          sql.write(i == 0 ? '?' : ', ?');
          params.add(_item(arrays, values, at, next));
        }
        sql.write(')');
        _execute(sql, params, next);
      case 16620:
        final t = values[at[0]++];
        final table = _tableName(t, next);
        final count = values[at[0]];
        final first = at[0] + 1;
        sql.write('UPDATE ${_identifier(table)} SET ');
        at[0] = first + count;
        for (var i = 0; i < count; i++) {
          if (i > 0) sql.write(', ');
          sql
            ..write(_identifier(_columnName(t, values[first + i], next)))
            ..write(' = ?');
          params.add(_item(arrays, values, at, next));
        }
        _having(sql, params, t, arrays, values, at, next);
        _execute(sql, params, next);
      case 16630:
        final t = values[at[0]++];
        sql.write('DELETE FROM ${_identifier(_tableName(t, next))}');
        _having(sql, params, t, arrays, values, at, next);
        _execute(sql, params, next);
      case 16640:
        final tables = _knownTables(next);
        for (final table in tables) {
          _execute(StringBuffer('DROP TABLE ${_identifier(table)}'), [], next);
        }
        _forgetSchema();
        _lastCount = tables.length;
      case 16200:
        sql.write(ickString(arrays[0], next));
        final count = ickScalar(scalars[0]);
        for (var i = 1; i <= count; i++) {
          params.add(_arg(i, next));
        }
        _queryIntoArgs(sql, params, ickScalar(scalars[1]), next);
        _forgetSchema();
        ickSetScalar(scalars[0], _lastCount);
      default:
        ickSetScalar(scalars[0], _lastCount);
    }
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

// ---- ActiveCassette's adapter interface, ioi_adapter.h ------------------------------------------

final class _Value extends Struct {
  @Int32()
  external int kind;

  @Int64()
  external int integer;

  external Pointer<Uint8> text;

  @Size()
  external int length;
}

final class _Adapter extends Struct {
  @Uint32()
  external int version;

  external Pointer<NativeFunction<Pointer<Void> Function(Pointer<Uint8>)>>
  connect;
  external Pointer<NativeFunction<Pointer<Uint8> Function(Pointer<Void>)>>
  error;
  external Pointer<NativeFunction<Void Function(Pointer<Void>)>> disconnect;
  external Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>)>>
  tables;
  external Pointer<
    NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>)>
  >
  columns;
  external Pointer<
    NativeFunction<
      Pointer<Void> Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Pointer<_Value>,
        Size,
      )
    >
  >
  query;
  external Pointer<NativeFunction<Int Function(Pointer<Void>)>> next;
  external Pointer<NativeFunction<Size Function(Pointer<Void>)>> width;
  external Pointer<
    NativeFunction<Void Function(Pointer<Void>, Size, Pointer<_Value>)>
  >
  column;
  external Pointer<NativeFunction<Void Function(Pointer<Void>)>> finish;
  external Pointer<NativeFunction<Int64 Function(Pointer<Void>)>> changes;
}

/// The C library's own allocator, for the strings and arrays passed to an adapter.
final _libc = Platform.isWindows
    ? DynamicLibrary.open('ucrtbase.dll')
    : DynamicLibrary.process();
final _malloc = _libc
    .lookupFunction<Pointer<Void> Function(Size), Pointer<Void> Function(int)>(
      'malloc',
    );
final _free = _libc
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'free',
    );

/// [bytes] as a NUL-terminated C string, which the caller frees.
Pointer<Uint8> _toC(List<int> bytes) {
  final p = _malloc(bytes.length + 1).cast<Uint8>();
  p.asTypedList(bytes.length + 1)
    ..setAll(0, bytes)
    ..[bytes.length] = 0;
  return p;
}

/// A NUL-terminated UTF-8 C string.
String _fromC(Pointer<Uint8> p) {
  var n = 0;
  while (p[n] != 0) {
    n++;
  }
  return decodeUtf8(p.asTypedList(n));
}
