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
  Parser(this.source) : _tokens = Lexer(source).tokenize();

  final Source source;
  final List<Token> _tokens;
  int _pos = 0;
  bool _chain = false;

  Token get _tok => _tokens[_pos];

  List<Statement> parse() {
    final statements = <Statement>[];
    while (_tok.kind != TokenKind.end) {
      final first = _pos;
      final labelled =
          _tok.kind == TokenKind.label &&
          _tokens[_pos + 1].kind == TokenKind.identifier;
      if (!labelled && _tok.kind != TokenKind.identifier) {
        _recoverAtCommandStart(statements, first);
        continue;
      }
      final label = labelled ? _tokens[_pos++].value : null;
      final polite = _tokens[_pos++].polite;
      final not = _tok.kind == TokenKind.not;
      if (not) _pos++;
      final percent = _tok.kind == TokenKind.percent
          ? _tokens[_pos++].value
          : null;

      _chain = false;
      Body body;
      try {
        body = _body();
      } on _Fail catch (fail) {
        _pos = _resync(fail.at);
        body = const Undecodable();
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
  };
  static const _arrayKinds = {
    TokenKind.tail: VarKind.tail,
    TokenKind.hybrid: VarKind.hybrid,
  };

  Body _body() {
    final kind = _tok.kind;
    switch (kind) {
      case TokenKind.oneSpot || TokenKind.twoSpot:
        final target = Scalar(_varRef());
        _expect(TokenKind.gets);
        return Calculate(target, _expr());
      case TokenKind.tail || TokenKind.hybrid:
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
      case TokenKind.abstainFrom || TokenKind.reinstate:
        _pos++;
        final abstain = kind == TokenKind.abstainFrom;
        if (_tok.kind == TokenKind.label) {
          return AbstainBody(abstain: abstain, label: _tokens[_pos++].value);
        }
        if (_tok.kind != TokenKind.gerund) _fail();
        final gerunds = [_tokens[_pos++].gerund!];
        while (_tok.kind == TokenKind.intersection) {
          _pos++;
          if (_tok.kind != TokenKind.gerund) _fail();
          gerunds.add(_tokens[_pos++].gerund!);
        }
        return AbstainBody(abstain: abstain, gerunds: gerunds);
      case TokenKind.writeIn || TokenKind.readOut:
        _pos++;
        final input = kind == TokenKind.writeIn;
        final items = [_ioItem(input: input)];
        while (_tok.kind == TokenKind.intersection) {
          _pos++;
          items.add(_ioItem(input: input));
        }
        return IoBody(input: input, items: items);
      case TokenKind.giveUp:
        _pos++;
        return const GiveUp();
      case TokenKind.comeFrom:
        _pos++;
        if (_tok.kind != TokenKind.label) _fail();
        return ComeFrom(_tokens[_pos++].value);
      default:
        _fail();
    }
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
    if (!input && _tok.kind == TokenKind.mesh) {
      _pos++;
      return Constant(_number());
    }
    final ref = _varRef();
    if (!ref.kind.isArray) return Scalar(ref);
    if (_tok.kind != TokenKind.sub) return ArrayItem(ref);
    _pos++;
    return Element(ref, _subscripts());
  }

  /// `operand (op operand)*`. Two or more operators without grouping is invalid (§3.4.3); the
  /// statement still decodes, and raises E017 when it executes (decisions Q80, Q97).
  Expr _expr() {
    var left = _operand();
    var operators = 0;
    while (_tok.kind == TokenKind.mingle || _tok.kind == TokenKind.select) {
      final op = _tok.kind == TokenKind.mingle
          ? BinaryOp.mingle
          : BinaryOp.select;
      _pos++;
      left = Binary(op, left, _operand(), ungrouped: operators > 0);
      operators++;
    }
    if (operators >= 2) _chain = true;
    return left;
  }

  UnaryOp? _unary() =>
      _tok.kind == TokenKind.unary ? _tokens[_pos++].unary : null;

  static Expr _apply(UnaryOp? op, Expr e) => op == null ? e : Unary(op, e);

  Expr _operand() {
    switch (_tok.kind) {
      case TokenKind.mesh:
        _pos++;
        final op = _unary();
        return _apply(op, Constant(_number()));
      case TokenKind.oneSpot || TokenKind.twoSpot:
        final kind = _scalarKinds[_tok.kind]!;
        _pos++;
        final op = _unary();
        return _apply(op, Scalar(VarRef(kind, _number())));
      case TokenKind.tail || TokenKind.hybrid:
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
        final inner = _expr();
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
          kind == TokenKind.mesh ||
          _scalarKinds.containsKey(kind) ||
          _arrayKinds.containsKey(kind);
      if (!opensGroup && !startsOperand) break;
      subscripts.add(_operand());
    }
    if (subscripts.isEmpty) _fail();
    return subscripts;
  }
}
