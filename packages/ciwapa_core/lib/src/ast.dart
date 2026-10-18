import 'lexer.dart';
import 'source.dart';

/// The scalar and array kinds, with their sigils (§3.1, §3.3): Mode 1's two of each, plus
/// EXTRACAL's 64-bit double cateye and double hybrid (R4, Q123).
enum VarKind {
  spot('.', 16),
  twoSpot(':', 32),
  tail(',', 16),
  hybrid(';', 32),
  doubleCateye('::', 64),
  doubleHybrid(';;', 64);

  const VarKind(this.sigil, this.width);

  final String sigil;

  /// 16 for the small types and 32 for the large ones, whatever the base, and 64 for EXTRACAL's.
  final int width;

  bool get isArray => this == tail || this == hybrid || this == doubleHybrid;
}

/// A variable or array name as written. [number] may be 0 or above 65535: that is an E200 when
/// its statement executes (decisions Q80, Q81), not a parse error.
class VarRef {
  const VarRef(this.kind, this.number);

  final VarKind kind;
  final int number;

  @override
  bool operator ==(Object other) =>
      other is VarRef && other.kind == kind && other.number == number;

  @override
  int get hashCode => Object.hash(kind, number);

  @override
  String toString() => '${kind.sigil}$number';
}

sealed class Expr {
  const Expr();
}

/// `#n`, or EXTRACAL's `##n` (32 bits) and `####n` (64 bits) (R4, Q123). [value] may exceed the
/// constant's range: that is an E017 when its statement executes.
class Constant extends Expr {
  const Constant(this.value, {this.width = 16, this.overflow = false});

  /// For `#n`, the number saturated as [Lexer.numberCap] does. For the wide constants, its 64 bits
  /// (negative from 2^63 up, as a Dart int).
  final int value;

  /// 16 for `#`, 32 for `##` and 64 for `####`.
  final int width;

  /// The number is above 2^64 - 1, so [value] means nothing.
  final bool overflow;

  @override
  String toString() =>
      '${switch (width) {
        16 => '#',
        32 => '##',
        _ => '####',
      }}${overflow ? '∞' : BigInt.from(value).toUnsigned(64)}';
}

class Scalar extends Expr {
  const Scalar(this.ref);

  final VarRef ref;

  @override
  String toString() => '$ref';
}

class Element extends Expr {
  const Element(this.array, this.subscripts);

  final VarRef array;
  final List<Expr> subscripts;

  @override
  String toString() => '($array SUB ${subscripts.join(' ')})';
}

class Unary extends Expr {
  const Unary(this.op, this.operand);

  final UnaryOp op;
  final Expr operand;

  @override
  String toString() => '${op.name}($operand)';
}

enum BinaryOp { mingle, select }

class Binary extends Expr {
  const Binary(this.op, this.left, this.right, {this.ungrouped = false});

  final BinaryOp op;
  final Expr left;
  final Expr right;

  /// This operator is the second or later in an ungrouped chain such as `#1¢#2~#3`, which is
  /// invalid (§3.4.3): E017 when the statement executes (decision Q97).
  final bool ungrouped;

  @override
  String toString() => '(${op == BinaryOp.mingle ? r'$' : '~'} $left $right)';
}

sealed class Body {
  const Body();

  /// The gerund that ABSTAIN and REINSTATE use for this kind of statement (decision T21), if any.
  Gerund? get gerund;
}

/// `lvalue <- expr`, where the target is a [Scalar] or an [Element].
class Calculate extends Body {
  const Calculate(this.target, this.value);

  final Expr target;
  final Expr value;

  @override
  Gerund get gerund => Gerund.calculating;
}

/// `array <- expr BY expr …`
class Dimension extends Body {
  const Dimension(this.array, this.dimensions);

  final VarRef array;
  final List<Expr> dimensions;

  @override
  Gerund get gerund => Gerund.calculating;
}

class Next extends Body {
  const Next(this.label);

  final int label;

  @override
  Gerund get gerund => Gerund.nexting;
}

class Forget extends Body {
  const Forget(this.count);

  final Expr count;

  @override
  Gerund get gerund => Gerund.forgetting;
}

class Resume extends Body {
  const Resume(this.count);

  final Expr count;

  @override
  Gerund get gerund => Gerund.resuming;
}

enum ListOp { stash, retrieve, ignore, remember }

/// STASH, RETRIEVE, IGNORE and REMEMBER: each takes a `+` list of variables and whole arrays.
class VarListBody extends Body {
  const VarListBody(this.op, this.vars);

  final ListOp op;
  final List<VarRef> vars;

  @override
  Gerund get gerund => switch (op) {
    ListOp.stash => Gerund.stashing,
    ListOp.retrieve => Gerund.retrieving,
    ListOp.ignore => Gerund.ignoring,
    ListOp.remember => Gerund.remembering,
  };
}

/// ABSTAIN FROM / REINSTATE, by label or by gerund list (never both, decision T20).
class AbstainBody extends Body {
  const AbstainBody({
    required this.abstain,
    this.label,
    this.gerunds = const [],
  });

  /// True for ABSTAIN FROM, false for REINSTATE.
  final bool abstain;
  final int? label;
  final List<Gerund> gerunds;

  @override
  Gerund get gerund => abstain ? Gerund.abstaining : Gerund.reinstating;
}

/// WRITE IN (items are [Scalar], [Element] or a whole-array [ArrayItem]) and READ OUT (which also
/// accepts [Constant]).
class IoBody extends Body {
  const IoBody({required this.input, required this.items, this.signed = false});

  final bool input;
  final List<Expr> items;

  /// `WRITE IN SIGNED` or `READ OUT SIGNED` (R6, Q124).
  final bool signed;

  @override
  Gerund get gerund => input ? Gerund.writingIn : Gerund.readingOut;
}

/// A whole array in an I/O list: Turing Text character I/O (§5.2).
class ArrayItem extends Expr {
  const ArrayItem(this.array);

  final VarRef array;

  @override
  String toString() => '$array';
}

class GiveUp extends Body {
  const GiveUp();

  @override
  Gerund? get gerund => null;
}

/// COME FROM, or EXTRACAL's NEXT FROM, which also pushes a NEXT stack entry (R3).
class ComeFrom extends Body {
  const ComeFrom(this.label, {this.nexting = false});

  final int label;
  final bool nexting;

  @override
  Gerund get gerund => nexting ? Gerund.nextingFrom : Gerund.comingFrom;
}

/// A statement the compiler can't decode (§4.5). It raises E000 if it executes.
class Undecodable extends Body {
  const Undecodable();

  @override
  Gerund? get gerund => null;
}

/// One statement as parsed: its qualifiers, its body and where its text lies in the source.
class Statement {
  Statement({
    required this.source,
    required this.start,
    required this.end,
    required this.label,
    required this.polite,
    required this.not,
    required this.percent,
    required this.body,
    this.chain = false,
  });

  /// The file the statement comes from: the user's program or the system library.
  final Source source;

  /// Rune offsets of the statement's text: from its label or identifier up to the next statement.
  final int start;
  int end;

  final int? label;

  /// Whether the identifier includes PLEASE (§10.4, decisions T11, T35).
  final bool polite;
  final bool not;
  final int? percent;
  Body body;

  /// The parser saw two or more ungrouped binary operators in a row.
  final bool chain;

  /// An ungrouped chain of binary operators: E017 when the statement executes (decision Q97).
  /// A statement that later turns out to be undecodable raises E000 instead (decision T9).
  bool get ungroupedChain => chain && body is! Undecodable;

  /// Whether the statement has an identifier at all. Garbage before the first statement doesn't.
  bool hasIdentifier = true;
}
