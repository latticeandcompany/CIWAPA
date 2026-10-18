import 'source.dart';

enum TokenKind {
  number,
  oneSpot,
  twoSpot,
  tail,
  hybrid,
  doubleCateye,
  doubleHybrid,
  mesh,
  fence,
  stockade,
  mingle,
  select,
  slat,
  unary,
  spark,
  ears,
  label,
  identifier,
  not,
  percent,
  sub,
  by,
  gets,
  next,
  forget,
  resume,
  stash,
  retrieve,
  ignore,
  remember,
  abstainFrom,
  abstain,
  from,
  reinstate,
  readOut,
  writeIn,
  comeFrom,
  nextFrom,
  giveUp,
  tryAgain,
  create,
  createLabel,
  goBack,
  goAhead,
  gerund,
  signed,
  once,
  again,
  intersection,
  badChar,
  end,
}

enum UnaryOp {
  and,
  or,
  xor,
  sharkfin,
  whirlpool,
  whirlpool2,
  whirlpool3,
  whirlpool4,
  whirlpool5;

  int get whirlpoolDigit => index - whirlpool.index + 1;
}

enum Gerund {
  calculating,
  nexting,
  forgetting,
  resuming,
  stashing,
  retrieving,
  ignoring,
  remembering,
  abstaining,
  reinstating,
  readingOut,
  writingIn,
  comingFrom,
  nextingFrom,
  tryingAgain,
  creating,
  commenting,
  goingBack,
  goingAhead,
}

class Token {
  Token(
    this.kind,
    this.start,
    this.end, {
    this.value = 0,
    this.polite = false,
    this.maybe = false,
    this.unary,
    this.gerund,
    this.bits,
  });

  final TokenKind kind;

  /// Offsets into [Source.runes]; [end] is exclusive.
  final int start;
  final int end;

  /// The number of a [TokenKind.number], [TokenKind.label], [TokenKind.percent] or
  /// [TokenKind.createLabel], saturated at [Lexer.numberCap] so that absurdly long digit strings
  /// stay "too big". A [TokenKind.badChar]'s character, or for an overstrike, its two characters
  /// as `ick` numbers them: the smaller one times 256 plus the larger.
  final int value;

  /// Whether an [TokenKind.identifier] includes PLEASE.
  final bool polite;

  /// Whether an [TokenKind.identifier] is `ick`'s MAYBE (R3).
  final bool maybe;

  final UnaryOp? unary;
  final Gerund? gerund;

  /// A [TokenKind.number]'s exact value as 64 bits (negative from 2^63 up, as a Dart int), or
  /// null when it is above 2^64 - 1.
  final int? bits;

  @override
  String toString() => '$kind@$start';
}

/// A longest-match tokenizer in the style of C-INTERCAL 0.15's flex scanner: any character that
/// starts no token becomes a [TokenKind.badChar], which is how a statement identifier is found even
/// in the middle of a word (§4.5, decision T8).
class Lexer {
  Lexer(this.source, {this.wide = false, this.extensions = false})
    : _text = source.runes;

  static const numberCap = 1 << 40;

  static final _bitsMax = (BigInt.one << 64) - BigInt.one;

  final Source source;

  /// Whether EXTRACAL's 64-bit sigils and SIGNED are tokens (R4, R6). They are only in binary
  /// EXTRACAL; in Mode 1, and in EXTRACAL's bases 3–7 (L17), they are the separate characters.
  final bool wide;

  /// Whether the keywords of `ick`'s extensions are tokens (R3): in EXTRACAL, in every base.
  final bool extensions;
  final List<int> _text;
  late final _activePatterns = [
    ..._patterns,
    if (wide) ..._widePatterns,
    if (extensions) ..._extensionPatterns,
  ];

  List<Token> tokenize() {
    final tokens = <Token>[];
    var i = 0;
    while (true) {
      i = _skipSpace(i);
      if (i >= _text.length) {
        tokens.add(Token(TokenKind.end, i, i));
        return tokens;
      }
      final token = _longest(i);
      tokens.addAll(token);
      i = token.last.end;
    }
  }

  int _skipSpace(int i) {
    while (i < _text.length && _isSpace(_text[i])) {
      i++;
    }
    return i;
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A;

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  /// Returns the token (or, for the wow, the two tokens) that starts at [i].
  List<Token> _longest(int i) {
    final c = _text[i];
    final candidates = <Token>[
      ..._fixed(i),
      if (_isDigit(c)) _number(i),
      if (c >= 0x32 && c <= 0x35) ?_digitWhirlpool(i),
      if (c == 0x28) ?_label(i),
      if (c == 0x25) ?_percent(i),
    ];
    if (c == 0x21) {
      // The wow `!` is a spark followed by a spot (§3.4.3, decision T3).
      return [Token(TokenKind.spark, i, i), Token(TokenKind.oneSpot, i, i + 1)];
    }
    if (candidates.isEmpty) {
      return [Token(TokenKind.badChar, i, i + 1, value: c)];
    }
    var best = candidates.first;
    for (final t in candidates.skip(1)) {
      if (t.end > best.end) best = t;
    }
    return [best];
  }

  Iterable<Token> _fixed(int i) sync* {
    for (final (pattern, make) in _activePatterns) {
      final end = _match(pattern, i);
      if (end != null) yield make(i, end);
    }
    if (extensions) {
      for (final word in const ['CREATE', 'CONFICE']) {
        final end = _match(word, i);
        if (end != null) {
          yield _labelAfter(i, end) ?? Token(TokenKind.create, i, end);
        }
      }
      if (_overstrike(i) case final token?) yield token;
    }
  }

  /// `ick`'s CREATE with a label is one token (`CREATE{W}\({W}{D}\)`).
  Token? _labelAfter(int i, int end) {
    final j = _skipSpace(end);
    if (j >= _text.length || _text[j] != 0x28) return null;
    final label = _label(j);
    if (label == null) return null;
    return Token(TokenKind.createLabel, i, label.end, value: label.value);
  }

  /// `ick`'s `.\^H.`: two characters overstruck with a backspace, which names a created operator
  /// unless the overstrike is a built-in one (longer matches win, and the built-ins come first).
  Token? _overstrike(int i) {
    if (i + 2 >= _text.length || _text[i + 1] != 0x08) return null;
    final a = _text[i], b = _text[i + 2];
    if (a == 0x0A || b == 0x0A) return null;
    final value = a > b ? a + b * 256 : a * 256 + b;
    return Token(TokenKind.badChar, i, i + 3, value: value);
  }

  /// Matches [pattern] at [i], where a space in the pattern stands for optional whitespace
  /// (flex's `{W}`), and returns the end offset.
  int? _match(String pattern, int i) {
    var j = i;
    for (final p in pattern.runes) {
      if (p == 0x20) {
        j = _skipSpace(j);
      } else if (j < _text.length && _text[j] == p) {
        j++;
      } else {
        return null;
      }
    }
    return j;
  }

  /// `[0-9][ \t\n0-9]*`: spaces inside a number join its digits (§4.1, decision T5).
  Token _number(int i) {
    var j = i;
    var value = 0;
    var lastDigitEnd = i;
    while (j < _text.length && (_isDigit(_text[j]) || _isSpace(_text[j]))) {
      if (_isDigit(_text[j])) {
        value = value * 10 + (_text[j] - 0x30);
        if (value > numberCap) value = numberCap;
        lastDigitEnd = j + 1;
      }
      j++;
    }
    return Token(
      TokenKind.number,
      i,
      lastDigitEnd,
      value: value,
      bits: value < numberCap ? value : _exactBits(i, lastDigitEnd),
    );
  }

  /// The digits between [start] and [end] as 64 bits, or null above 2^64 - 1.
  int? _exactBits(int start, int end) {
    var exact = BigInt.zero;
    for (var k = start; k < end; k++) {
      if (!_isDigit(_text[k])) continue;
      exact = exact * BigInt.from(10) + BigInt.from(_text[k] - 0x30);
      if (exact > _bitsMax) return null;
    }
    return exact.toSigned(64).toInt();
  }

  /// `[2-5]{W}@`: a numbered whirlpool such as `2@` (§6.6).
  Token? _digitWhirlpool(int i) {
    final j = _skipSpace(i + 1);
    if (j < _text.length && _text[j] == 0x40) {
      final op = UnaryOp.values[UnaryOp.whirlpool.index + _text[i] - 0x31];
      return Token(TokenKind.unary, i, j + 1, unary: op);
    }
    return null;
  }

  /// `\({W}[0-9][ \t\n0-9]*\)`
  Token? _label(int i) {
    final j = _skipSpace(i + 1);
    if (j >= _text.length || !_isDigit(_text[j])) return null;
    var k = j;
    while (k < _text.length && (_isDigit(_text[k]) || _isSpace(_text[k]))) {
      k++;
    }
    if (k >= _text.length || _text[k] != 0x29) return null;
    return Token(TokenKind.label, i, k + 1, value: _number(j).value);
  }

  /// `\%{W}[0-9][ \t\n0-9]*`
  Token? _percent(int i) {
    final j = _skipSpace(i + 1);
    if (j >= _text.length || !_isDigit(_text[j])) return null;
    final n = _number(j);
    return Token(TokenKind.percent, i, n.end, value: n.value);
  }

  static Token Function(int, int) _kind(TokenKind kind) =>
      (start, end) => Token(kind, start, end);

  static Token Function(int, int) _op(UnaryOp op) =>
      (start, end) => Token(TokenKind.unary, start, end, unary: op);

  static Token Function(int, int) _gerund(Gerund g) =>
      (start, end) => Token(TokenKind.gerund, start, end, gerund: g);

  static Token Function(int, int) _identifier({
    required bool polite,
    bool maybe = false,
  }) =>
      (start, end) =>
          Token(TokenKind.identifier, start, end, polite: polite, maybe: maybe);

  static final _patterns = <(String, Token Function(int, int))>[
    ('.', _kind(TokenKind.oneSpot)),
    (':', _kind(TokenKind.twoSpot)),
    (',', _kind(TokenKind.tail)),
    (';', _kind(TokenKind.hybrid)),
    ('#', _kind(TokenKind.mesh)),
    (r'$', _kind(TokenKind.mingle)),
    ('¢', _kind(TokenKind.mingle)),
    ('c\b/', _kind(TokenKind.mingle)),
    ('~', _kind(TokenKind.select)),
    ('&', _op(UnaryOp.and)),
    ('V', _op(UnaryOp.or)),
    ('?', _op(UnaryOp.xor)),
    ('V\b-', _op(UnaryOp.xor)),
    ('-\bV', _op(UnaryOp.xor)),
    ('^', _op(UnaryOp.sharkfin)),
    ('@', _op(UnaryOp.whirlpool)),
    ("'", _kind(TokenKind.spark)),
    ('"', _kind(TokenKind.ears)),
    ('DO', _identifier(polite: false)),
    ('PLEASE', _identifier(polite: true)),
    ('DO PLEASE', _identifier(polite: true)),
    ('PLEASE DO', _identifier(polite: true)),
    ('NOT', _kind(TokenKind.not)),
    ("N'T", _kind(TokenKind.not)),
    ('SUB', _kind(TokenKind.sub)),
    ('BY', _kind(TokenKind.by)),
    ('<-', _kind(TokenKind.gets)),
    ('CALCULATING', _gerund(Gerund.calculating)),
    ('NEXT', _kind(TokenKind.next)),
    ('NEXTING', _gerund(Gerund.nexting)),
    ('FORGET', _kind(TokenKind.forget)),
    ('FORGETTING', _gerund(Gerund.forgetting)),
    ('RESUME', _kind(TokenKind.resume)),
    ('RESUMING', _gerund(Gerund.resuming)),
    ('STASH', _kind(TokenKind.stash)),
    ('STASHING', _gerund(Gerund.stashing)),
    ('RETRIEVE', _kind(TokenKind.retrieve)),
    ('RETRIEVING', _gerund(Gerund.retrieving)),
    ('IGNORE', _kind(TokenKind.ignore)),
    ('IGNORING', _gerund(Gerund.ignoring)),
    ('REMEMBER', _kind(TokenKind.remember)),
    ('REMEMBERING', _gerund(Gerund.remembering)),
    ('ABSTAIN FROM', _kind(TokenKind.abstainFrom)),
    ('ABSTAINING', _gerund(Gerund.abstaining)),
    ('REINSTATE', _kind(TokenKind.reinstate)),
    ('REINSTATING', _gerund(Gerund.reinstating)),
    ('READ OUT', _kind(TokenKind.readOut)),
    ('READING OUT', _gerund(Gerund.readingOut)),
    ('WRITE IN', _kind(TokenKind.writeIn)),
    ('WRITING IN', _gerund(Gerund.writingIn)),
    ('COME FROM', _kind(TokenKind.comeFrom)),
    ('COMING FROM', _gerund(Gerund.comingFrom)),
    ('GIVE UP', _kind(TokenKind.giveUp)),
    ('+', _kind(TokenKind.intersection)),
  ];

  static final _extensionPatterns = <(String, Token Function(int, int))>[
    ('NEXT FROM', _kind(TokenKind.nextFrom)),
    ('ABSTAIN', _kind(TokenKind.abstain)),
    ('FROM', _kind(TokenKind.from)),
    ('/', _kind(TokenKind.slat)),
    ('ONCE', _kind(TokenKind.once)),
    ('TRY AGAIN', _kind(TokenKind.tryAgain)),
    ('TRYING AGAIN', _gerund(Gerund.tryingAgain)),
    ('AGAIN', _kind(TokenKind.again)),
    ('NEXTING FROM', _gerund(Gerund.nextingFrom)),
    // `ick`'s Latin keywords (R3 item 12).
    ('FAC', _identifier(polite: false)),
    ('PLACET', _identifier(polite: true)),
    ('PLACET FACERE', _identifier(polite: true)),
    ('NON', _kind(TokenKind.not)),
    ('QUONDAM', _kind(TokenKind.once)),
    ('ITERUM', _kind(TokenKind.again)),
    ('MULTIPLICATUS A', _kind(TokenKind.by)),
    ('CALCULANDUM', _gerund(Gerund.calculating)),
    ('DEINDE', _kind(TokenKind.next)),
    ('PROXIMANDUM', _gerund(Gerund.nexting)),
    ('ALIENERE', _kind(TokenKind.forget)),
    ('ALIENENDUM', _gerund(Gerund.forgetting)),
    ('RECOLERE', _kind(TokenKind.resume)),
    ('RECOLERENDUM', _gerund(Gerund.resuming)),
    ('EXUERE', _kind(TokenKind.stash)),
    ('EXUENDUM', _gerund(Gerund.stashing)),
    ('INUERE', _kind(TokenKind.retrieve)),
    ('INUENDUM', _gerund(Gerund.retrieving)),
    ('DISSIMULARE', _kind(TokenKind.ignore)),
    ('DISSIMULANDUM', _gerund(Gerund.ignoring)),
    ('MEMINISSE', _kind(TokenKind.remember)),
    ('MEMINISSENDUM', _gerund(Gerund.remembering)),
    ('ABSTINERE', _kind(TokenKind.abstain)),
    ('ABSTINENDUM', _gerund(Gerund.abstaining)),
    ('REINSTARE', _kind(TokenKind.reinstate)),
    ('REINSTATANDUM', _gerund(Gerund.reinstating)),
    ('LEGERE EX', _kind(TokenKind.readOut)),
    ('LEGENDUM', _gerund(Gerund.readingOut)),
    ('SCRIBERE IN', _kind(TokenKind.writeIn)),
    ('SCRIBENDUM', _gerund(Gerund.writingIn)),
    ('ADVENIRE DE', _kind(TokenKind.comeFrom)),
    ('ADVENENDUM', _gerund(Gerund.comingFrom)),
    ('DEINDERE A', _kind(TokenKind.nextFrom)),
    ('DEINDENDUM', _gerund(Gerund.nextingFrom)),
    ('CONCEDERE', _kind(TokenKind.giveUp)),
    ('DESPERARE', _kind(TokenKind.giveUp)),
    ('CONOR ITERUM', _kind(TokenKind.tryAgain)),
    // CREATE and CONFICE are in [_fixed], because with a label they are one token.
    ('CREATING', _gerund(Gerund.creating)),
    ('CREATION', _gerund(Gerund.creating)),
    ('CONFICENDUM', _gerund(Gerund.creating)),
    ('COMMENT', _gerund(Gerund.commenting)),
    ('COMMENTS', _gerund(Gerund.commenting)),
    ('COMMENTING', _gerund(Gerund.commenting)),
    ('COMMEMERO', _gerund(Gerund.commenting)),
    // Backtracking (R3 item 7).
    ('MAYBE', _identifier(polite: false, maybe: true)),
    ('MAYBE DO', _identifier(polite: false, maybe: true)),
    ('MAYBE PLEASE', _identifier(polite: true, maybe: true)),
    ('MAYBE PLEASE DO', _identifier(polite: true, maybe: true)),
    ('GO BACK', _kind(TokenKind.goBack)),
    ('REDIRE', _kind(TokenKind.goBack)),
    ('GO AHEAD', _kind(TokenKind.goAhead)),
    ('GRASSOR', _kind(TokenKind.goAhead)),
    ('GOING BACK', _gerund(Gerund.goingBack)),
    ('REDENDUM', _gerund(Gerund.goingBack)),
    ('GOING AHEAD', _gerund(Gerund.goingAhead)),
  ];

  static final _widePatterns = <(String, Token Function(int, int))>[
    ('::', _kind(TokenKind.doubleCateye)),
    (';;', _kind(TokenKind.doubleHybrid)),
    ('##', _kind(TokenKind.fence)),
    ('####', _kind(TokenKind.stockade)),
    ('SIGNED', _kind(TokenKind.signed)),
  ];
}
