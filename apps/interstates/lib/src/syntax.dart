import 'package:ciwapa_core/ciwapa_core.dart';

import 'services.dart';

/// The array of route parameters and the array of template arguments, whose elements are whole
/// strings (R5, punchline 5).
const params = VarRef(VarKind.hybrid, 4400);
const args = VarRef(VarKind.hybrid, 49221);

bool isStringArray(VarRef ref) => ref == params || ref == args;

/// A `WITH ROUTE` COME FROM, or with no [pattern] the bare `COME FROM (16000)` catch-all (R3).
class RouteDecl {
  const RouteDecl(this.label, this.pattern);

  final int label;
  final String? pattern;
}

/// `READ OUT #count WITH TEMPLATE "path"` (R6).
class TemplateUse {
  const TemplateUse(this.count, this.path);

  final int count;
  final String path;
}

/// An `INTO DATABASE` that names [columns] columns and gives [items] values (R7).
class DatabaseWrite {
  const DatabaseWrite(this.columns, this.items);

  final int columns;
  final int items;
}

/// The words `.ioi` files add, and its string literals: `"…"` right after `WITH ROUTE` or
/// `WITH TEMPLATE`, up to the next `"` on the same line (R5). Anywhere else `"` stays rabbit ears.
final interstatesDialect = LexerDialect(
  words: const [
    'WITH ROUTE',
    'WITH TEMPLATE',
    'FROM DATABASE',
    'INTO DATABASE',
    'FORGET DATABASE',
    'AMNESIA',
    'HAVING',
  ],
  scan: (text, offset, before) {
    if (text[offset] != 0x22 || before.isEmpty) return null;
    final last = before.last;
    if (last.kind != TokenKind.dialect ||
        (last.tag != 'WITH ROUTE' && last.tag != 'WITH TEMPLATE')) {
      return null;
    }
    for (var end = offset + 1; end < text.length; end++) {
      if (text[end] == 0x0A) return null;
      if (text[end] == 0x22) {
        return Token(
          TokenKind.dialect,
          offset,
          end + 1,
          tag: 'string',
          text: String.fromCharCodes(text, offset + 1, end),
        );
      }
    }
    return null;
  },
);

/// EXTRACAL with the Interstates extensions, for `.ioi` files. Its own statements become [HostCall]s, or for a
/// route a [Nothing], and what the rest of the compiler needs to know about them is the
/// statement's [Statement.data].
class InterstatesParser extends Parser {
  InterstatesParser(super.source, {super.memoryLimit})
    : super(
        wide: true,
        extensions: true,
        dialect: interstatesDialect,
        // The site's hello world starts with a NOTE and ends with a bare GIVE UP (Q141).
        leadingComment: true,
        bareGiveUp: true,
      );

  final _data = Map<Body, Object>.identity();

  /// Whether the statement being parsed uses a string where a number belongs.
  var _misuse = false;

  @override
  List<Statement> parse() {
    final statements = super.parse();
    for (final s in statements) {
      s.data = _data[s.body];
    }
    return statements;
  }

  Body _record(Body body, Object data) {
    _data[body] = data;
    return body;
  }

  /// The data the parser recorded for [body], which outlives a WHILE's expansion of it.
  Object? dataOf(Body body) => _data[body];

  @override
  Body body() {
    _misuse = false;
    final body = _body();
    return _misuse ? fault(822, body.gerund) : body;
  }

  /// Notes a string in [e], which is in a number's place.
  Expr _number(Expr e) {
    if (mentionsStrings(e)) _misuse = true;
    return e;
  }

  Body _body() {
    final t = current;
    if (t.kind == TokenKind.dialect) {
      take();
      return switch (t.tag) {
        'INTO DATABASE' => _into(),
        'FORGET DATABASE' => HostCall(
          HostService.delete,
          values: [..._table(named: false), ..._having().values],
          arrays: _arrays,
          gerund: Gerund.forgetting,
        ),
        'AMNESIA' => HostCall(HostService.amnesia),
        _ => reject(),
      };
    }
    if (_stringArrayAhead() case final array?) {
      // The route parameters can't be changed.
      if (lookAhead(2).kind == TokenKind.sub) {
        final store = _storeArg();
        return array == args ? store : fault(822, Gerund.calculating);
      }
      if (lookAhead(2).kind == TokenKind.gets) {
        final read = _wholeArgs();
        return array == args ? read : fault(822, Gerund.calculating);
      }
    }
    final body = super.body();
    // `,a <- ;4400 SUB e`: in plain INTERCAL a DIMENSION, here a copy (R5).
    if (body
        case Dimension(
          array: VarRef(kind: VarKind.tail) && final target,
          dimensions: [Element(:final array, subscripts: [final index])],
        )
        when isStringArray(array)) {
      return HostCall(
        array == params ? HostService.paramToArray : HostService.argToArray,
        values: [_number(index)],
        arrays: [target],
        gerund: Gerund.calculating,
      );
    }
    return body;
  }

  /// A statement that raises Interstates error [code] when it runs. It keeps the [gerund] of the
  /// statement it replaces, so abstaining that kind of statement skips it, as Q80's faults are.
  static Body fault(int code, [Gerund? gerund]) =>
      HostCall(HostService.fault, values: [Constant(code)], gerund: gerund);

  @override
  Body extendBody(Body body) {
    final tag = current.kind == TokenKind.dialect ? current.tag : null;
    if (tag == 'WITH ROUTE') {
      if (body is! ComeFrom || body.nexting) reject();
      take();
      return _record(Nothing(), RouteDecl(body.label, _string()));
    }
    if (tag == 'WITH TEMPLATE') {
      if (body case IoBody(
        input: false,
        signed: false,
        baudot: false,
        items: [Constant(width: 16, :final value)],
      )) {
        take();
        return _record(
          HostCall(HostService.render, gerund: Gerund.readingOut),
          TemplateUse(value, _string()),
        );
      }
      reject();
    }
    // `(16000)` is the implicit entry label: a COME FROM it is a route, never a trap door (R3).
    if (body case ComeFrom(label: 16000, nexting: false)) {
      return _record(Nothing(), const RouteDecl(16000, null));
    }
    return body;
  }

  String _string() {
    final t = current;
    if (t.kind != TokenKind.dialect || t.tag != 'string') reject();
    take();
    return t.text!;
  }

  /// The string array named at the current token, if one is.
  VarRef? _stringArrayAhead() {
    if (current.kind != TokenKind.hybrid) return null;
    final number = lookAhead(1);
    if (number.kind != TokenKind.number) return null;
    final ref = VarRef(VarKind.hybrid, number.value);
    return isStringArray(ref) ? ref : null;
  }

  /// `;49221 SUB e <- source`, where the source is a tail array or another string element.
  Body _storeArg() {
    take();
    take();
    take();
    final index = subscriptList();
    _expect(TokenKind.gets);
    index.forEach(_number);
    if (index.length != 1) {
      _item();
      return fault(822, Gerund.calculating);
    }
    final source = _item();
    return switch (source.kind) {
      ItemKind.array => HostCall(
        HostService.arrayToArg,
        values: [index.single],
        arrays: [source.array!],
        gerund: Gerund.calculating,
      ),
      ItemKind.param || ItemKind.arg => HostCall(
        source.kind == ItemKind.param
            ? HostService.paramToArg
            : HostService.argToArg,
        values: [index.single, source.value!],
        gerund: Gerund.calculating,
      ),
      _ => fault(822, Gerund.calculating),
    };
  }

  /// `;49221 <- 'FROM DATABASE …'`, the only thing the whole array can be given.
  Body _wholeArgs() {
    take();
    take();
    take();
    final grouper = current.kind;
    final read =
        (grouper == TokenKind.spark || grouper == TokenKind.ears) &&
        lookAhead(1).kind == TokenKind.dialect &&
        lookAhead(1).tag == 'FROM DATABASE';
    if (!read) {
      expression();
      while (current.kind == TokenKind.by) {
        take();
        expression();
      }
      return fault(822, Gerund.calculating);
    }
    take();
    take();
    final columns = _table();
    _expect(grouper);
    Expr row = const Constant(1);
    if (current.kind == TokenKind.sub) {
      take();
      row = _number(expression());
    }
    final having = _having();
    return HostCall(
      HostService.read,
      values: [...columns, row, ...having.values],
      arrays: _arrays,
      gerund: Gerund.calculating,
    );
  }

  /// `INTO DATABASE #t~#c$… <- item + item [HAVING …]` (Q145).
  Body _into() {
    final columns = _table();
    _expect(TokenKind.gets);
    final items = [_item()];
    while (current.kind == TokenKind.intersection) {
      take();
      items.add(_item());
    }
    final having = _having();
    final count = columns.length - 2;
    final call = HostCall(
      having.pairs == 0 ? HostService.insert : HostService.update,
      values: [
        ...columns,
        for (final i in items) ...i.encode(_arrays),
        if (having.pairs > 0) ...having.values,
      ],
      arrays: _arrays,
      gerund: Gerund.calculating,
    );
    return _record(call, DatabaseWrite(count, items.length));
  }

  /// The arrays the statement's items name, in the order their values index them.
  var _arrays = <VarRef>[];

  /// `#t~#c$#c…` as values: the table, the number of columns, then the columns. A FORGET DATABASE
  /// names only `#t` ([named] false), and gets just the table. Starts the statement's [_arrays].
  List<Expr> _table({bool named = true}) {
    _arrays = [];
    final table = _constantNumber();
    if (!named) return [table];
    if (current.kind != TokenKind.select) return [table, const Constant(0)];
    take();
    final columns = [_constantNumber()];
    while (current.kind == TokenKind.mingle) {
      take();
      columns.add(_constantNumber());
    }
    return [table, Constant(columns.length), ...columns];
  }

  /// `HAVING #c item + #c item …` as values: the number of pairs, then each column and item.
  ({int pairs, List<Expr> values}) _having() {
    final having = current.kind == TokenKind.dialect && current.tag == 'HAVING';
    if (!having) return (pairs: 0, values: [const Constant(0)]);
    take();
    final values = <Expr>[];
    var pairs = 0;
    do {
      if (pairs > 0) take();
      values
        ..add(_constantNumber())
        ..addAll(_item().encode(_arrays));
      pairs++;
    } while (current.kind == TokenKind.intersection);
    return (pairs: pairs, values: [Constant(pairs), ...values]);
  }

  /// `#n`, the way a table or column is named.
  Expr _constantNumber() {
    if (current.kind != TokenKind.mesh) reject();
    take();
    return constant(16);
  }

  void _expect(TokenKind kind) {
    if (current.kind != kind) reject();
    take();
  }

  /// A value: a whole tail array or a string element (strings), or any other expression (a
  /// number). A number that uses a string anywhere is a misuse.
  _Item _item() {
    if (current.kind == TokenKind.tail &&
        lookAhead(1).kind == TokenKind.number &&
        lookAhead(2).kind != TokenKind.sub) {
      take();
      return _Item.array(VarRef(VarKind.tail, take().value));
    }
    final e = expression();
    if (e case Element(:final array, subscripts: [final index])
        when isStringArray(array)) {
      return _Item(
        array == params ? ItemKind.param : ItemKind.arg,
        _number(index),
      );
    }
    return _Item(ItemKind.number, _number(e));
  }
}

class _Item {
  _Item(this.kind, this.value) : array = null;

  _Item.array(VarRef this.array) : kind = ItemKind.array, value = null;

  final int kind;
  final Expr? value;
  final VarRef? array;

  /// Its kind and value, adding a tail array to [arrays].
  List<Expr> encode(List<VarRef> arrays) {
    if (array case final a?) {
      arrays.add(a);
      return [const Constant(ItemKind.array), Constant(arrays.length - 1)];
    }
    return [Constant(kind), value!];
  }
}

/// Whether [e] uses `;4400` or `;49221` anywhere.
bool mentionsStrings(Expr e) => switch (e) {
  Element(:final array, :final subscripts) =>
    isStringArray(array) || subscripts.any(mentionsStrings),
  ArrayItem(:final array) => isStringArray(array),
  Unary(:final operand) => mentionsStrings(operand),
  Binary(:final left, :final right) || CreatedOp(:final left, :final right) =>
    mentionsStrings(left) || mentionsStrings(right),
  Slat(:final expr) => mentionsStrings(expr),
  Constant() || Scalar() => false,
};
