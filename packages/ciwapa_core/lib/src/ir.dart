import 'dart:math';

import 'ast.dart';
import 'errors.dart';
import 'frontend.dart';
import 'lexer.dart';

/// The digits in a small (16-bit) word for each base (§6.6). Large words hold twice as many.
const smallDigits = {2: 16, 3: 10, 4: 8, 5: 6, 6: 6, 7: 5};

/// The largest small value in [base]: 65535 in binary, 59048 in ternary (§6.4, decision T40).
int smallMax(int base) => pow(base, smallDigits[base]!).toInt() - 1;

/// The largest large value in [base]: 4294967295 in binary.
int largeMax(int base) => pow(base, 2 * smallDigits[base]!).toInt() - 1;

/// The digit a base 3–7 logical operator prefers: AND 0, OR b-1, BUT (`@`) 1 and `N@` N (§6.6).
int preferredDigit(UnaryOp op, int base) => switch (op) {
  UnaryOp.and => 0,
  UnaryOp.or => base - 1,
  _ => op.whirlpoolDigit,
};

/// A statement-local error. It fires only when its statement executes (decisions Q80, Q81).
class Fault {
  const Fault(this.code);

  final int code;

  @override
  String toString() => 'E${code.toString().padLeft(3, '0')}';
}

/// A storage slot. Scalars and arrays are numbered separately, in order of first appearance.
class Slot {
  const Slot(this.index, this.ref);

  final int index;
  final VarRef ref;

  bool get large => ref.kind.width == 32;

  @override
  String toString() => '$ref';
}

sealed class IrExpr {
  const IrExpr();

  /// Whether the static type is large (32-bit in binary): the type of a mingle, of a `:` or `;`, or
  /// of a select with a large right operand (decisions Q77, Q79).
  bool get large;
}

class IrConst extends IrExpr {
  const IrConst(this.value, {this.large = false});

  final int value;

  @override
  final bool large;

  @override
  String toString() => '#$value';
}

class IrScalar extends IrExpr {
  const IrScalar(this.slot);

  final Slot slot;

  @override
  bool get large => slot.large;

  @override
  String toString() => '$slot';
}

class IrElement extends IrExpr {
  const IrElement(this.array, this.subscripts);

  final Slot array;
  final List<IrExpr> subscripts;

  @override
  bool get large => array.large;

  @override
  String toString() => '($array SUB ${subscripts.join(' ')})';
}

class IrMingle extends IrExpr {
  const IrMingle(this.left, this.right);

  final IrExpr left;
  final IrExpr right;

  @override
  bool get large => true;

  @override
  String toString() => '(\$ $left $right)';
}

class IrSelect extends IrExpr {
  const IrSelect(this.left, this.right);

  final IrExpr left;
  final IrExpr right;

  @override
  bool get large => right.large;

  @override
  String toString() => '(~ $left $right)';
}

class IrUnary extends IrExpr {
  const IrUnary(this.op, this.operand);

  final UnaryOp op;
  final IrExpr operand;

  @override
  bool get large => operand.large;

  @override
  String toString() => '${op.name}$operand';
}

/// The next number from input, as WRITE IN reads it (§4.4.12). The emitters use it to share the
/// assignment path; lowering never produces it.
class IrInput extends IrExpr {
  const IrInput();

  @override
  bool get large => true;

  @override
  String toString() => 'input';
}

/// A whole array in an I/O list (Turing Text, §5.2).
class IrArrayItem extends IrExpr {
  const IrArrayItem(this.array);

  final Slot array;

  @override
  bool get large => array.large;

  @override
  String toString() => '$array';
}

sealed class IrOp {
  const IrOp();
}

/// `target <- value`, where the target is an [IrScalar] or an [IrElement].
class IrAssign extends IrOp {
  const IrAssign(this.target, this.value);

  final IrExpr target;
  final IrExpr value;

  @override
  String toString() => '$target <- $value';
}

class IrDimension extends IrOp {
  const IrDimension(this.array, this.dimensions);

  final Slot array;
  final List<IrExpr> dimensions;

  @override
  String toString() => '$array <- ${dimensions.join(' BY ')}';
}

class IrNext extends IrOp {
  const IrNext(this.target);

  /// The target's ordinal, or 0 when the label is missing: the statement then carries an E129
  /// [Fault], and emitters must never jump here.
  final int target;

  @override
  String toString() => 'NEXT $target';
}

class IrForget extends IrOp {
  const IrForget(this.count);

  final IrExpr count;

  @override
  String toString() => 'FORGET $count';
}

class IrResume extends IrOp {
  const IrResume(this.count);

  final IrExpr count;

  @override
  String toString() => 'RESUME $count';
}

/// STASH, RETRIEVE, IGNORE or REMEMBER over scalar and array slots.
class IrVarList extends IrOp {
  const IrVarList(this.op, this.scalars, this.arrays);

  final ListOp op;
  final List<Slot> scalars;
  final List<Slot> arrays;

  @override
  String toString() =>
      '${op.name.toUpperCase()} ${[...scalars, ...arrays].join('+')}';
}

/// ABSTAIN or REINSTATE, by label or by gerund. Either way the targets are known statically: a
/// label names one statement and a gerund names every statement of its type (decision T21).
class IrAbstain extends IrOp {
  const IrAbstain({
    required this.abstain,
    required this.targets,
    this.gerunds = const {},
  });

  final bool abstain;

  /// Ordinals whose abstention flag this statement sets or clears.
  final List<int> targets;

  /// The gerunds named, for the gerund form; [targets] are then every statement with one of them.
  final Set<Gerund> gerunds;

  @override
  String toString() => '${abstain ? 'ABSTAIN' : 'REINSTATE'} $targets';
}

class IrWriteIn extends IrOp {
  const IrWriteIn(this.items);

  final List<IrExpr> items;

  @override
  String toString() => 'WRITE IN ${items.join('+')}';
}

class IrReadOut extends IrOp {
  const IrReadOut(this.items);

  final List<IrExpr> items;

  @override
  String toString() => 'READ OUT ${items.join('+')}';
}

class IrGiveUp extends IrOp {
  const IrGiveUp();

  @override
  String toString() => 'GIVE UP';
}

/// A COME FROM does nothing when reached; its jumps live on its target's [IrStatement.comeFrom].
class IrComeFrom extends IrOp {
  const IrComeFrom();

  @override
  String toString() => 'COME FROM';
}

/// An undecodable statement: E000 with [text] as the message (decision T10).
class IrUndecodable extends IrOp {
  const IrUndecodable(this.text);

  final String text;

  @override
  String toString() => 'E000';
}

class IrStatement {
  IrStatement({
    required this.ordinal,
    required this.label,
    required this.op,
    required this.gerund,
    required this.initiallyAbstained,
    required this.percent,
    required this.faults,
  });

  final int ordinal;
  final int? label;
  final IrOp op;

  /// The gerund that abstains this statement, if any (decision T21).
  final Gerund? gerund;

  /// Set by NOT (§4.3).
  final bool initiallyAbstained;

  /// The `%` chance, or null when there is none or it's invalid (above 100, which is a [Fault]).
  final int? percent;

  /// Statement-local errors, in source order. The first one fires when the statement executes.
  final List<Fault> faults;

  /// The ordinal printed on line 3 of an error raised here (decision T33).
  late int next;

  /// The ordinal of the COME FROM aimed at this statement.
  int? comeFrom;

  /// Whether anything can ever set this statement's abstention flag.
  bool abstainable = false;

  /// Whether a random compiler bug was planted here (decision T23).
  bool bug = false;

  bool get isGiveUp => op is IrGiveUp;

  String dump() {
    final parts = [
      '$ordinal',
      if (label != null) '($label)',
      if (initiallyAbstained) 'NOT',
      if (percent != null) '%$percent',
      '$op',
      if (faults.isNotEmpty) 'faults=$faults',
      'next=$next',
      if (comeFrom != null) 'comeFrom=$comeFrom',
      if (abstainable) 'abstainable',
      if (bug) 'E774',
    ];
    return parts.join(' ');
  }
}

class IrProgram {
  IrProgram(
    this.base,
    this.statements,
    this.scalars,
    this.arrays,
    this.userStatements,
  );

  final int base;
  final List<IrStatement> statements;
  final List<Slot> scalars;
  final List<Slot> arrays;

  /// How many statements are the user's; any after them are the system library's (§7.3).
  final int userStatements;

  /// The variables and arrays some IGNORE names. Nothing else can ever be ignored.
  late final Set<Slot> ignorable = {
    for (final s in statements)
      if (s.op case IrVarList(
        op: ListOp.ignore,
        :final scalars,
        :final arrays,
      )) ...[
        ...scalars,
        ...arrays,
      ],
  };

  int get smallLimit => smallMax(base);
  int get largeLimit => largeMax(base);

  IrStatement at(int ordinal) => statements[ordinal - 1];

  String dump() => statements.map((s) => s.dump()).join('\n');
}

class IrOptions {
  const IrOptions({this.randomBug = true, this.seed});

  /// Whether to plant E774 bugs (`--no-random-bug` turns this off, decision T23).
  final bool randomBug;

  /// Seeds the bug placement (`--seed`). Defaults to the clock.
  final int? seed;
}

/// Lowers a checked [Program] to the IR both emitters consume.
IrProgram lower(Program program, {IrOptions options = const IrOptions()}) =>
    _Lowering(program).build(options);

class _Lowering {
  _Lowering(this.program);

  final Program program;
  final _scalars = <VarRef, Slot>{};
  final _arrays = <VarRef, Slot>{};
  final _labels = <int, int>{};
  late List<Fault> _faults;

  IrProgram build(IrOptions options) {
    final statements = program.statements;
    for (final (i, s) in statements.indexed) {
      final label = s.label;
      if (label != null && isValidLabel(label)) {
        _labels.putIfAbsent(label, () => i + 1);
      }
    }

    final ir = <IrStatement>[];
    for (final (i, s) in statements.indexed) {
      _faults = [];
      if (s.label != null && !isValidLabel(s.label!)) {
        _faults.add(const Fault(197));
      }
      final percent = s.percent;
      if (percent != null && percent > 100) _faults.add(const Fault(17));
      final op = _op(s);
      ir.add(
        IrStatement(
          ordinal: i + 1,
          label: s.label,
          op: op,
          gerund: s.body.gerund,
          initiallyAbstained: s.not,
          percent: percent != null && percent <= 100 ? percent : null,
          faults: _faults,
        ),
      );
    }

    for (final s in ir) {
      if (s.op case IrComeFrom()) {
        final target =
            _labels[(statements[s.ordinal - 1].body as ComeFrom).label]!;
        ir[target - 1].comeFrom = s.ordinal;
      }
    }
    for (final s in ir) {
      final op = s.op;
      s.next = op is IrNext && op.target != 0
          ? op.target
          : s.comeFrom ?? s.ordinal + 1;
      s.abstainable = s.initiallyAbstained;
    }
    for (final s in ir) {
      if (s.op case IrAbstain(abstain: true, :final targets)) {
        for (final t in targets) {
          ir[t - 1].abstainable = true;
        }
      }
    }

    if (options.randomBug) {
      final random = Random(
        options.seed ?? DateTime.now().microsecondsSinceEpoch,
      );
      for (final s in ir) {
        s.bug = random.nextInt(128) == 0;
      }
    }

    return IrProgram(
      program.base,
      ir,
      _scalars.values.toList(),
      _arrays.values.toList(),
      program.userStatements,
    );
  }

  IrOp _op(Statement s) {
    final body = s.body;
    return switch (body) {
      Calculate(:final target, :final value) => IrAssign(
        _expr(target),
        _expr(value),
      ),
      Dimension(:final array, :final dimensions) => IrDimension(_array(array), [
        for (final d in dimensions) _expr(d),
      ]),
      Next(:final label) => _next(label),
      Forget(:final count) => IrForget(_expr(count)),
      Resume(:final count) => IrResume(_expr(count)),
      VarListBody(:final op, :final vars) => IrVarList(
        op,
        [
          for (final v in vars)
            if (!v.kind.isArray) _scalar(v),
        ],
        [
          for (final v in vars)
            if (v.kind.isArray) _array(v),
        ],
      ),
      AbstainBody() => _abstain(body),
      IoBody(input: true, :final items) => IrWriteIn([
        for (final i in items) _expr(i),
      ]),
      IoBody(input: false, :final items) => IrReadOut([
        for (final i in items) _expr(i),
      ]),
      GiveUp() => const IrGiveUp(),
      ComeFrom() => const IrComeFrom(),
      Undecodable() => IrUndecodable(_text(s)),
    };
  }

  String _text(Statement s) {
    final source = s.source;
    final first = source.lineOf(s.start);
    final last = source.lineOf(s.end > s.start ? s.end - 1 : s.start);
    return undecodableText([
      for (var l = first; l <= last; l++) source.line(l),
    ]);
  }

  IrOp _next(int label) {
    final target = _labels[label];
    if (target == null) {
      _faults.add(const Fault(129));
      return const IrNext(0);
    }
    return IrNext(target);
  }

  IrOp _abstain(AbstainBody body) {
    final label = body.label;
    if (label != null) {
      final target = _labels[label];
      if (target == null) {
        _faults.add(const Fault(139));
        return IrAbstain(abstain: body.abstain, targets: const []);
      }
      // REINSTATE of a GIVE UP by label does nothing, so DON'T GIVE UP stays a no-op (§4.4.10).
      final giveUp = program.statements[target - 1].body is GiveUp;
      return IrAbstain(
        abstain: body.abstain,
        targets: !body.abstain && giveUp ? const [] : [target],
      );
    }
    final gerunds = body.gerunds.toSet();
    return IrAbstain(
      abstain: body.abstain,
      targets: [
        for (final (i, s) in program.statements.indexed)
          if (gerunds.contains(s.body.gerund)) i + 1,
      ],
      gerunds: gerunds.whereType<Gerund>().toSet(),
    );
  }

  Slot _slot(Map<VarRef, Slot> slots, VarRef ref) {
    if (ref.number < 1 || ref.number > 65535) _faults.add(const Fault(200));
    return slots.putIfAbsent(ref, () => Slot(slots.length, ref));
  }

  Slot _scalar(VarRef ref) => _slot(_scalars, ref);

  Slot _array(VarRef ref) => _slot(_arrays, ref);

  IrExpr _expr(Expr e) => switch (e) {
    Constant(:final value) => _constant(value),
    Scalar(:final ref) => IrScalar(_scalar(ref)),
    Element(:final array, :final subscripts) => IrElement(_array(array), [
      for (final s in subscripts) _expr(s),
    ]),
    ArrayItem(:final array) => IrArrayItem(_array(array)),
    Unary(:final op, :final operand) => IrUnary(op, _expr(operand)),
    Binary() => _binary(e),
  };

  /// Lowers left to right, so an ungrouped chain's E017 lands at its second operator, after the
  /// faults of the operands before it.
  IrExpr _binary(Binary e) {
    final left = _expr(e.left);
    if (e.ungrouped) _faults.add(const Fault(17));
    final right = _expr(e.right);
    if (e.op == BinaryOp.mingle) {
      // A mingle of two constants that fit is a constant; one that doesn't fit stays, for E533.
      final max = smallMax(program.base);
      if (left case IrConst(value: final l) when l <= max) {
        if (right case IrConst(value: final r) when r <= max) {
          return IrConst(_mingle(l, r), large: true);
        }
      }
      return IrMingle(left, right);
    }
    return IrSelect(left, right);
  }

  /// Interleaves the digits of [left] and [right], left supplying the high digit of each pair
  /// (§3.4.1, §6.5.1).
  int _mingle(int left, int right) {
    final base = program.base;
    var result = 0, place = 1;
    for (var i = 0; i < smallDigits[base]!; i++) {
      result += place * (right % base);
      right ~/= base;
      place *= base;
      result += place * (left % base);
      left ~/= base;
      place *= base;
    }
    return result;
  }

  IrExpr _constant(int value) {
    if (value > smallMax(program.base)) _faults.add(const Fault(17));
    return IrConst(value);
  }
}
