import 'ast.dart';
import 'lexer.dart';
import 'source.dart';

class _Fail implements Exception {
  _Fail(this.at);

  /// Index of the first token that no valid statement can continue with.
  final int at;
}

/// Splits a token stream into statements and parses each body.
///
/// Statement boundaries follow C-INTERCAL 0.35's error recovery (decisions T8, T9): when a body
/// can't be parsed, or junk follows a complete one, the statement becomes undecodable and its text
/// runs up to the next `DO`, `PLEASE` or label token. Garbage before the first statement is a
/// statement of its own, with no identifier.
class Parser {
  Parser(
    this.source, {
    this.memoryLimit,
    bool wide = false,
    bool extensions = false,
  }) : _extensions = extensions,
       _tokens = Lexer(source, wide: wide, extensions: extensions).tokenize();

  final Source source;

  /// Test-only: parsing more statements than this fails as if memory ran out (decision L7).
  final int? memoryLimit;
  final List<Token> _tokens;

  /// Whether `ick`'s extensions parse (EXTRACAL, R3).
  final bool _extensions;
  int _pos = 0;
  bool _chain = false;

  Token get _tok => _tokens[_pos];

  List<Statement> parse() {
    final statements = <Statement>[];
    while (_tok.kind != TokenKind.end) {
      if (statements.length == memoryLimit) throw OutOfMemoryError();
      final first = _pos;
      final labelled =
          _tok.kind == TokenKind.label &&
          _tokens[_pos + 1].kind == TokenKind.identifier;
      if (!labelled && _tok.kind != TokenKind.identifier) {
        _recoverAtCommandStart(statements, first);
        continue;
      }
      final label = labelled ? _tokens[_pos++].value : null;
      final polite = _tokens[_pos].polite;
      final maybe = _tokens[_pos++].maybe;
      final not = _tok.kind == TokenKind.not;
      if (not) _pos++;
      final percent = _tok.kind == TokenKind.percent
          ? _tokens[_pos++].value
          : null;

      _chain = false;
      Body body;
      var onceAgain = OnceAgain.none;
      final bodyStart = _pos;
      Body? whileBody;
      try {
        body = _body();
        // `ick`'s `a WHILE b` (R3): b is another statement body.
        if (_tok.kind == TokenKind.whileKeyword) {
          _pos++;
          whileBody = _body();
        }
        // `ick`'s ONCE and AGAIN end a statement (R3).
        if (_tok.kind == TokenKind.once || _tok.kind == TokenKind.again) {
          onceAgain = _tokens[_pos++].kind == TokenKind.once
              ? OnceAgain.once
              : OnceAgain.again;
        }
      } on _Fail catch (fail) {
        _pos = bodyStart;
        final unknown = _extensions ? _tryUnknown() : null;
        if (unknown == null) _pos = _resync(fail.at);
        body = unknown ?? const Undecodable();
        // An unknown statement takes a ONCE or AGAIN; without a CREATE, the front end makes it
        // part of the comment again (L22).
        if (unknown != null &&
            (_tok.kind == TokenKind.once || _tok.kind == TokenKind.again)) {
          onceAgain = _tokens[_pos++].kind == TokenKind.once
              ? OnceAgain.once
              : OnceAgain.again;
        }
      }
      statements.add(
        Statement(
          source: source,
          start: _tokens[first].start,
          end: _tokens[_pos - 1].end,
          label: label,
          polite: polite,
          not: not,
          percent: percent,
          body: body,
          chain: _chain,
          onceAgain: onceAgain,
          maybe: maybe,
          whileBody: whileBody,
        ),
      );
    }
    return statements;
  }

  /// A command must start with an identifier, optionally after a label. When it doesn't, 0.35
  /// splatters the previous statement and lets it swallow everything up to the next statement start.
  void _recoverAtCommandStart(List<Statement> statements, int first) {
    final errorAt = _tok.kind == TokenKind.label ? _pos + 1 : _pos;
    _pos = _resync(errorAt);
    if (statements.isEmpty) {
      statements.add(
        Statement(
          source: source,
          start: _tokens[first].start,
          end: _tokens[_pos - 1].end,
          label: null,
          polite: false,
          not: false,
          percent: null,
          body: const Undecodable(),
        )..hasIdentifier = false,
      );
    } else {
      statements.last
        ..body = const Undecodable()
        ..end = _tokens[_pos - 1].end;
    }
  }

  /// The index of the next statement start at or after [at]: a `DO`/`PLEASE` token or a label.
  int _resync(int at) {
    var i = at;
    while (_tokens[i].kind != TokenKind.identifier &&
        _tokens[i].kind != TokenKind.label &&
        _tokens[i].kind != TokenKind.end) {
      i++;
    }
    return i;
  }

  Never _fail() => throw _Fail(_pos);

  /// `ick`'s just-in-case compilation (R3): the whole body as an [Unknown], or null.
  Unknown? _tryUnknown() {
    try {
      final start = _pos;
      _chain = false;
      final (signature, operands) = _template();
      final atEnd =
          _tok.kind == TokenKind.identifier ||
          _tok.kind == TokenKind.label ||
          _tok.kind == TokenKind.end ||
          _tok.kind == TokenKind.once ||
          _tok.kind == TokenKind.again;
      // An ungrouped chain, invalid in Mode 1, keeps the statement a comment.
      if (atEnd && !_chain) return Unknown(signature, operands);
      _pos = start;
    } on _Fail {
      // Not readable either.
    }
    _chain = false;
    return null;
  }

  /// Capital letters and operands, never two operands in a row, as in `ick`'s unknown statements.
  (String, List<Expr>) _template() {
    final signature = StringBuffer();
    final operands = <Expr>[];
    var afterOperand = false;
    while (true) {
      if (_isLetter(_tok)) {
        signature.writeCharCode(_tokens[_pos++].value);
        afterOperand = false;
      } else if (!afterOperand && _startsOperand(_tok.kind)) {
        // A grouped scalar or element is no longer one, in `ick`'s grammar.
        final grouped =
            _tok.kind == TokenKind.spark || _tok.kind == TokenKind.ears;
        final operand = _templateOperand();
        signature.write(switch (operand) {
          _ when grouped => '~',
          Scalar() => '.',
          Element() => ';',
          ArrayItem() => ',',
          _ => '~',
        });
        operands.add(operand);
        afterOperand = true;
      } else {
        break;
      }
    }
    if (signature.isEmpty) _fail();
    return (signature.toString(), operands);
  }

  /// A CREATE's template, whose operands are only examples of their kind.
  String _templateSignature() {
    final chain = _chain;
    final signature = _template().$1;
    _chain = chain;
    return signature;
  }

  Expr _templateOperand() {
    final kind = _arrayKinds[_tok.kind];
    if (kind != null &&
        _tokens[_pos + 1].kind == TokenKind.number &&
        _tokens[_pos + 2].kind != TokenKind.sub) {
      _pos += 2;
      return ArrayItem(VarRef(kind, _tokens[_pos - 1].value));
    }
    return _expr();
  }

  /// A capital letter that starts no keyword (`V` is always an operator).
  static bool _isLetter(Token t) =>
      t.kind == TokenKind.badChar &&
      t.end - t.start == 1 &&
      t.value >= 0x41 &&
      t.value <= 0x5A;

  static bool _startsOperand(TokenKind kind) =>
      _constantWidths.containsKey(kind) ||
      _scalarKinds.containsKey(kind) ||
      _arrayKinds.containsKey(kind) ||
      kind == TokenKind.spark ||
      kind == TokenKind.ears;

  /// A character that can name a created operator: an ASCII one `ick` lexes as nothing else (so
  /// not a capital letter, `_`, `\` or `|`), or an overstrike other than `ick`'s mingle `c^H|`.
  bool _isOperatorName(Token t) {
    if (!_extensions || t.kind != TokenKind.badChar) return false;
    final c = t.value;
    if (t.end - t.start == 3) {
      return c != 0x637C && (c >> 8) < 0x80 && (c & 0xFF) < 0x80;
    }
    return c < 0x80 &&
        c != 0x08 &&
        !_isLetter(t) &&
        c != 0x5F &&
        c != 0x5C &&
        c != 0x7C;
  }

  /// `ick`'s name for a created operator: `u` and the character in hex, or for an overstrike, `o`
  /// and the two characters.
  static String _operatorSignature(Token t) => t.value > 256
      ? 'o${(t.value >> 8).toRadixString(16)}x${(t.value & 0xFF).toRadixString(16)}'
      : 'u${t.value.toRadixString(16)}';

  void _expect(TokenKind kind) {
    if (_tok.kind != kind) _fail();
    _pos++;
  }

  int _number() {
    if (_tok.kind != TokenKind.number) _fail();
    return _tokens[_pos++].value;
  }

  static const _scalarKinds = {
    TokenKind.oneSpot: VarKind.spot,
    TokenKind.twoSpot: VarKind.twoSpot,
    TokenKind.doubleCateye: VarKind.doubleCateye,
  };
  static const _arrayKinds = {
    TokenKind.tail: VarKind.tail,
    TokenKind.hybrid: VarKind.hybrid,
    TokenKind.doubleHybrid: VarKind.doubleHybrid,
  };
  static const _constantWidths = {
    TokenKind.mesh: 16,
    TokenKind.fence: 32,
    TokenKind.stockade: 64,
  };

  Body _body() {
    final kind = _tok.kind;
    switch (kind) {
      case TokenKind.oneSpot || TokenKind.twoSpot || TokenKind.doubleCateye:
        final target = Scalar(_varRef());
        _expect(TokenKind.gets);
        return Calculate(target, _expr());
      case TokenKind.tail || TokenKind.hybrid || TokenKind.doubleHybrid:
        final array = _varRef();
        if (_tok.kind == TokenKind.sub) {
          _pos++;
          final target = Element(array, _subscripts());
          _expect(TokenKind.gets);
          return Calculate(target, _expr());
        }
        _expect(TokenKind.gets);
        final dimensions = [_expr()];
        while (_tok.kind == TokenKind.by) {
          _pos++;
          dimensions.add(_expr());
        }
        return Dimension(array, dimensions);
      case TokenKind.label:
        final label = _tokens[_pos++].value;
        _expect(TokenKind.next);
        return Next(label);
      case TokenKind.forget:
        _pos++;
        return Forget(_expr());
      case TokenKind.resume:
        _pos++;
        return Resume(_expr());
      case TokenKind.stash ||
          TokenKind.retrieve ||
          TokenKind.ignore ||
          TokenKind.remember:
        _pos++;
        final vars = [_varRef()];
        while (_tok.kind == TokenKind.intersection) {
          _pos++;
          vars.add(_varRef());
        }
        final op = switch (kind) {
          TokenKind.stash => ListOp.stash,
          TokenKind.retrieve => ListOp.retrieve,
          TokenKind.ignore => ListOp.ignore,
          _ => ListOp.remember,
        };
        return VarListBody(op, vars);
      case TokenKind.abstain:
        _pos++;
        // The Latin ABSTINERE comes before a separate FROM.
        if (_tok.kind == TokenKind.from) {
          _pos++;
          if (_tok.kind == TokenKind.label) {
            return AbstainBody(abstain: true, label: _tokens[_pos++].value);
          }
          return AbstainBody(abstain: true, gerunds: _gerunds());
        }
        // `ick`'s computed ABSTAIN adds the expression's value to the abstention count (R3).
        final count = _expr();
        _expect(TokenKind.from);
        if (_tok.kind == TokenKind.label) {
          return AbstainBody(
            abstain: true,
            label: _tokens[_pos++].value,
            count: count,
          );
        }
        return AbstainBody(abstain: true, gerunds: _gerunds(), count: count);
      case TokenKind.abstainFrom || TokenKind.reinstate:
        _pos++;
        final abstain = kind == TokenKind.abstainFrom;
        if (_tok.kind == TokenKind.label) {
          return AbstainBody(abstain: abstain, label: _tokens[_pos++].value);
        }
        return AbstainBody(abstain: abstain, gerunds: _gerunds());
      case TokenKind.writeIn || TokenKind.readOut:
        _pos++;
        final input = kind == TokenKind.writeIn;
        final signed = _tok.kind == TokenKind.signed;
        if (signed) _pos++;
        final items = [_ioItem(input: input)];
        while (_tok.kind == TokenKind.intersection) {
          _pos++;
          items.add(_ioItem(input: input));
        }
        return IoBody(input: input, items: items, signed: signed);
      case TokenKind.giveUp:
        _pos++;
        return const GiveUp();
      case TokenKind.tryAgain:
        _pos++;
        return const TryAgain();
      case TokenKind.goBack:
        _pos++;
        return const GoBack();
      case TokenKind.goAhead:
        _pos++;
        return const GoAhead();
      case TokenKind.createLabel:
        final label = _tokens[_pos++].value;
        if (_isOperatorName(_tok)) {
          return Create(_operatorSignature(_tokens[_pos++]), label: label);
        }
        return Create(_templateSignature(), label: label);
      case TokenKind.create:
        _pos++;
        // `ick`'s computed operator CREATE takes one operand (a group, but not a slat) as its
        // target; the template form takes a whole expression.
        final start = _pos;
        final operand = _operand();
        if (_isOperatorName(_tok) && !_startsOperand(_tokens[_pos + 1].kind)) {
          return Create(_operatorSignature(_tokens[_pos++]), target: operand);
        }
        _pos = start;
        final target = _expr();
        // A computed CREATE's template starts with a letter, so the target ends before it.
        if (!_isLetter(_tok)) _fail();
        return Create(_templateSignature(), target: target);
      case TokenKind.comeFrom || TokenKind.nextFrom:
        _pos++;
        final nexting = kind == TokenKind.nextFrom;
        if (_tok.kind == TokenKind.label) {
          return ComeFrom(_tokens[_pos++].value, nexting: nexting);
        }
        // `ick`'s computed and gerund forms (R3, L18).
        if (!_extensions) _fail();
        if (_tok.kind == TokenKind.gerund) {
          return GerundComeFrom(_gerunds(), nexting: nexting);
        }
        return ComputedComeFrom(_expr(), nexting: nexting);
      default:
        _fail();
    }
  }

  /// A `+` list of gerunds.
  List<Gerund> _gerunds() {
    if (_tok.kind != TokenKind.gerund) _fail();
    final gerunds = [_tokens[_pos++].gerund!];
    while (_tok.kind == TokenKind.intersection) {
      _pos++;
      if (_tok.kind != TokenKind.gerund) _fail();
      gerunds.add(_tokens[_pos++].gerund!);
    }
    return gerunds;
  }

  /// A variable or array name with no unary operator, as in STASH lists and assignment targets.
  VarRef _varRef() {
    final kind = _scalarKinds[_tok.kind] ?? _arrayKinds[_tok.kind];
    if (kind == null) _fail();
    _pos++;
    return VarRef(kind, _number());
  }

  /// I/O list items: scalars, array elements and whole arrays, plus constants for READ OUT.
  Expr _ioItem({required bool input}) {
    if (!input && _constantWidths.containsKey(_tok.kind)) {
      final width = _constantWidths[_tokens[_pos++].kind]!;
      return _constant(width);
    }
    final ref = _varRef();
    if (!ref.kind.isArray) return Scalar(ref);
    if (_tok.kind != TokenKind.sub) return ArrayItem(ref);
    _pos++;
    return Element(ref, _subscripts());
  }

  /// `operand (op operand)*`. Two or more operators without grouping is invalid (§3.4.3). At the
  /// top of an expression the statement still decodes, and raises E017 when it executes; inside a
  /// group it doesn't decode at all, as in 0.15's parser (decisions Q80, Q97, L4).
  Expr _expr({bool grouped = false}) {
    var left = _slat(_operand(), grouped);
    var operators = 0;
    while (left is! Slat &&
        (_tok.kind == TokenKind.mingle ||
            _tok.kind == TokenKind.select ||
            _createdOperatorNext())) {
      final token = _tokens[_pos++];
      final right = _slat(_operand(), grouped);
      left = switch (token.kind) {
        TokenKind.mingle => Binary(
          BinaryOp.mingle,
          left,
          right,
          ungrouped: operators > 0,
        ),
        TokenKind.select => Binary(
          BinaryOp.select,
          left,
          right,
          ungrouped: operators > 0,
        ),
        _ => CreatedOp(
          _operatorSignature(token),
          left,
          right,
          ungrouped: operators > 0,
        ),
      };
      operators++;
      if (right is Slat) break;
    }
    if (operators >= 2) {
      if (grouped) _fail();
      _chain = true;
    }
    return left;
  }

  /// A created operator with an operand after it: without one, as in `CREATE .5 x`, the operator
  /// isn't part of the expression.
  bool _createdOperatorNext() =>
      _isOperatorName(_tok) && _startsOperand(_tokens[_pos + 1].kind);

  /// `ick`'s slat (R3): a scalar, `/`, then the rest of the expression, which the scalar stands for
  /// from then on.
  Expr _slat(Expr operand, bool grouped) {
    if (operand is! Scalar || _tok.kind != TokenKind.slat) return operand;
    _pos++;
    return Slat(operand.ref, _expr(grouped: grouped));
  }

  UnaryOp? _unary() =>
      _tok.kind == TokenKind.unary ? _tokens[_pos++].unary : null;

  static Expr _apply(UnaryOp? op, Expr e) => op == null ? e : Unary(op, e);

  /// The number after a mesh, fence or stockade.
  Constant _constant(int width) {
    if (_tok.kind != TokenKind.number) _fail();
    final token = _tokens[_pos++];
    if (width == 16) return Constant(token.value);
    final bits = token.bits;
    return Constant(bits ?? 0, width: width, overflow: bits == null);
  }

  Expr _operand() {
    switch (_tok.kind) {
      case TokenKind.mesh || TokenKind.fence || TokenKind.stockade:
        final width = _constantWidths[_tokens[_pos++].kind]!;
        final op = _unary();
        return _apply(op, _constant(width));
      case TokenKind.oneSpot || TokenKind.twoSpot || TokenKind.doubleCateye:
        final kind = _scalarKinds[_tok.kind]!;
        _pos++;
        final op = _unary();
        return _apply(op, Scalar(VarRef(kind, _number())));
      case TokenKind.tail || TokenKind.hybrid || TokenKind.doubleHybrid:
        // A unary operator on an array name applies to the element (decision T4).
        final kind = _arrayKinds[_tok.kind]!;
        _pos++;
        final op = _unary();
        final array = VarRef(kind, _number());
        _expect(TokenKind.sub);
        return _apply(op, Element(array, _subscripts()));
      case TokenKind.spark || TokenKind.ears:
        // At the start of an operand a grouper opens a group; after a complete operand it closes
        // the current one (decision T1).
        final grouper = _tok.kind;
        _pos++;
        final op = _unary();
        final inner = _expr(grouped: true);
        if (_tok.kind != grouper) _fail();
        _pos++;
        return _apply(op, inner);
      default:
        _fail();
    }
  }

  /// Subscripts run until the first token that can't start one, so a binary operator ends the
  /// list (decision T2). A grouper after a subscript closes the enclosing group, so only the first
  /// subscript can be a group (decision T1).
  List<Expr> _subscripts() {
    final subscripts = <Expr>[];
    while (true) {
      final kind = _tok.kind;
      final opensGroup =
          (kind == TokenKind.spark || kind == TokenKind.ears) &&
          subscripts.isEmpty;
      final startsOperand =
          _constantWidths.containsKey(kind) ||
          _scalarKinds.containsKey(kind) ||
          _arrayKinds.containsKey(kind);
      if (!opensGroup && !startsOperand) break;
      subscripts.add(_operand());
    }
    if (subscripts.isEmpty) _fail();
    return subscripts;
  }
}
