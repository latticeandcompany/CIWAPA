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

/// A binary select by a constant [mask], as the runs of 1-bits in the mask: in each, `width` bits
/// of the value from bit `from` land at bit `to` of the result, packed toward the low end in order
/// (§3.4.1). Emitters turn a constant-mask select into one shift and mask per run. A 64-bit mask
/// ([bits] 64) is a Dart int's 64 bits.
List<({int from, int width, int to})> selectRuns(int mask, {int bits = 32}) {
  final runs = <({int from, int width, int to})>[];
  var to = 0;
  for (var bit = 0; bit < bits;) {
    if ((mask >>> bit) & 1 == 0) {
      bit++;
      continue;
    }
    var width = 0;
    while (bit + width < bits && (mask >>> (bit + width)) & 1 == 1) {
      width++;
    }
    runs.add((from: bit, width: width, to: to));
    to += width;
    bit += width;
  }
  return runs;
}

/// A binary select by a constant [mask] as Hacker's Delight's compress (§7-4): mask the value,
/// then in each step shift its `moving` bits right by `shift`. At most five steps, so emitters use
/// it in place of [selectRuns] for masks with more runs than that, like 0x55555555.
List<({int moving, int shift})> compressSteps(int mask) {
  final steps = <({int moving, int shift})>[];
  var zerosRight = ~mask << 1 & 0xFFFFFFFF;
  for (var shift = 1; shift < 32; shift <<= 1) {
    // The bits with an odd number of mask zeros to their right: the ones moving this step.
    var odd = zerosRight ^ zerosRight << 1;
    odd ^= odd << 2;
    odd ^= odd << 4;
    odd ^= odd << 8;
    odd = (odd ^ odd << 16) & 0xFFFFFFFF;
    final moving = odd & mask;
    if (moving != 0) steps.add((moving: moving, shift: shift));
    mask = (mask ^ moving) | moving >> shift;
    zerosRight &= ~odd;
  }
  return steps;
}

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

/// A storage slot. Scalars and arrays are numbered separately, in order of first appearance, and
/// EXTRACAL's 64-bit ones (`::`, `;;`) separately again.
class Slot {
  const Slot(this.index, this.ref);

  final int index;
  final VarRef ref;

  /// 16, 32 or 64.
  int get width => ref.kind.width;

  bool get large => width != 16;

  bool get wide => width == 64;

  @override
  String toString() => '$ref';
}

sealed class IrExpr {
  const IrExpr();

  /// The static type's width: 16 or 32 in Mode 1 (32 for a mingle, a `:` or `;`, or a select with
  /// a large right operand, decisions Q77, Q79), or 64 for EXTRACAL's 64-bit types (R4). In
  /// EXTRACAL a mingle's width depends on its operands' values (R5), so it and what is built on it
  /// can be [runtimeWidth]: 32, 64 or a 128-bit ephemeral value, known only when it runs.
  int get width;

  static const runtimeWidth = 0;

  /// Whether the static type is large (32-bit in binary, or wider).
  bool get large => width != 16;

  /// The width of the value an emitter holds for this expression: a value of [runtimeWidth] is
  /// held as 64 bits once it is known not to be ephemeral.
  int get valueWidth => width == runtimeWidth ? 64 : width;
}

class IrConst extends IrExpr {
  const IrConst(this.value, {this.width = 16});

  /// A 64-bit constant's 64 bits, negative from 2^63 up.
  final int value;

  @override
  final int width;

  @override
  String toString() => '#${BigInt.from(value).toUnsigned(64)}';
}

class IrScalar extends IrExpr {
  const IrScalar(this.slot);

  final Slot slot;

  @override
  int get width => slot.width;

  @override
  String toString() => '$slot';
}

class IrElement extends IrExpr {
  const IrElement(this.array, this.subscripts);

  final Slot array;
  final List<IrExpr> subscripts;

  @override
  int get width => array.width;

  @override
  String toString() => '($array SUB ${subscripts.join(' ')})';
}

class IrMingle extends IrExpr {
  const IrMingle(this.left, this.right, {this.width = 32});

  final IrExpr left;
  final IrExpr right;

  /// 32, or in binary EXTRACAL [IrExpr.runtimeWidth] unless both operands are known to fit in
  /// 16 bits (R5).
  @override
  final int width;

  @override
  String toString() => '(\$ $left $right)';
}

class IrSelect extends IrExpr {
  const IrSelect(this.left, this.right);

  final IrExpr left;
  final IrExpr right;

  @override
  int get width => right.width;

  @override
  String toString() => '(~ $left $right)';
}

class IrUnary extends IrExpr {
  const IrUnary(this.op, this.operand);

  final UnaryOp op;
  final IrExpr operand;

  @override
  int get width => operand.width;

  @override
  String toString() => '${op.name}$operand';
}

/// The next number from input, as WRITE IN reads it (§4.4.12), for a target of [width] bits. The
/// emitters use it to share the assignment path; lowering never produces it. A [signed] input
/// already has its target's width (R6).
class IrInput extends IrExpr {
  const IrInput({this.width = 32, this.signed = false});

  @override
  final int width;

  final bool signed;

  @override
  String toString() => 'input';
}

/// A whole array in an I/O list (Turing Text, §5.2).
class IrArrayItem extends IrExpr {
  const IrArrayItem(this.array);

  final Slot array;

  @override
  int get width => array.width;

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
    this.count,
  });

  final bool abstain;

  /// For `ick`'s computed ABSTAIN, the amount added to each target's abstention count (R3). Only
  /// the control engine runs it.
  final IrExpr? count;

  /// Ordinals whose abstention flag this statement sets or clears.
  final List<int> targets;

  /// The gerunds named, for the gerund form; [targets] are then every statement with one of them.
  final Set<Gerund> gerunds;

  @override
  String toString() => '${abstain ? 'ABSTAIN' : 'REINSTATE'} $targets';
}

class IrWriteIn extends IrOp {
  const IrWriteIn(this.items, {this.signed = false});

  final List<IrExpr> items;

  /// `WRITE IN SIGNED` (R6, Q124): numbers may start with MINUS and are stored in two's complement.
  final bool signed;

  @override
  String toString() => 'WRITE IN ${signed ? 'SIGNED ' : ''}${items.join('+')}';
}

class IrReadOut extends IrOp {
  const IrReadOut(this.items, {this.signed = false});

  final List<IrExpr> items;

  /// `READ OUT SIGNED` (R6, Q124): each number is read as two's complement at its width.
  final bool signed;

  @override
  String toString() => 'READ OUT ${signed ? 'SIGNED ' : ''}${items.join('+')}';
}

class IrGiveUp extends IrOp {
  const IrGiveUp();

  @override
  String toString() => 'GIVE UP';
}

/// A COME FROM does nothing when reached; its jumps live on its target's [IrStatement.comeFrom].
/// EXTRACAL's NEXT FROM is one that also pushes a NEXT stack entry (R3).
class IrComeFrom extends IrOp {
  const IrComeFrom({this.nexting = false});

  final bool nexting;

  @override
  String toString() => nexting ? 'NEXT FROM' : 'COME FROM';
}

/// `ick`'s computed COME FROM or NEXT FROM (R3): it takes control after a labelled statement whose
/// label equals [label]'s value. Only the control engine runs it.
class IrComputedComeFrom extends IrOp {
  const IrComputedComeFrom(this.label, {this.nexting = false});

  final IrExpr label;
  final bool nexting;

  @override
  String toString() => '${nexting ? 'NEXT' : 'COME'} FROM $label';
}

/// `ick`'s COME FROM or NEXT FROM a gerund list (R3, L18): it takes control after any statement
/// with one of [gerunds]. Only the control engine runs it.
class IrGerundComeFrom extends IrOp {
  const IrGerundComeFrom(this.gerunds, {this.nexting = false});

  final Set<Gerund> gerunds;
  final bool nexting;

  @override
  String toString() =>
      '${nexting ? 'NEXT' : 'COME'} FROM ${[for (final g in gerunds) g.name].join('+')}';
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
    this.onceAgain = OnceAgain.none,
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

  /// `ick`'s ONCE or AGAIN, as written (R3). Only the control engine runs it.
  final OnceAgain onceAgain;

  /// The ordinal printed on line 3 of an error raised here (decision T33).
  late int next;

  /// The ordinal of the COME FROM aimed at this statement.
  int? comeFrom;

  /// Every COME FROM and NEXT FROM aimed at this statement by label, in program order. Mode 1
  /// allows one (E555); EXTRACAL's control engine handles more.
  final comeFroms = <int>[];

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
    this.userStatements, {
    required this.extracal,
    this.wideScalars = const [],
    this.wideArrays = const [],
    this.engine = false,
  });

  final int base;

  /// Whether the program runs on EXTRACAL's control engine, which every program using one of
  /// `ick`'s control extensions needs (R3). Each statement's body is still compiled.
  final bool engine;

  /// Whether the program is EXTRACAL rather than Mode 1.
  final bool extracal;
  final List<IrStatement> statements;

  /// The 16- and 32-bit scalars and arrays.
  final List<Slot> scalars;
  final List<Slot> arrays;

  /// EXTRACAL's 64-bit scalars and arrays (R4), numbered apart from the others.
  final List<Slot> wideScalars;
  final List<Slot> wideArrays;

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
  const IrOptions({
    this.randomBug = true,
    this.seed,
    this.memoryLimit,
    this.forceEngine = false,
  });

  /// Test-only: runs every EXTRACAL program on the control engine, so the superset suite checks the
  /// engine against all of Mode 1.
  final bool forceEngine;

  /// Test-only: laying out more variables than this fails as if memory ran out (decision L7).
  final int? memoryLimit;

  /// Whether to plant E774 bugs (`--no-random-bug` turns this off, decision T23).
  final bool randomBug;

  /// Seeds the bug placement (`--seed`). Defaults to the clock.
  final int? seed;
}

/// Lowers a checked [Program] to the IR both emitters consume.
IrProgram lower(Program program, {IrOptions options = const IrOptions()}) =>
    _Lowering(program, options.memoryLimit).build(options);

class _Lowering {
  _Lowering(this.program, this.memoryLimit);

  final Program program;
  final int? memoryLimit;
  final _scalars = <VarRef, Slot>{};
  final _arrays = <VarRef, Slot>{};
  final _wideScalars = <VarRef, Slot>{};
  final _wideArrays = <VarRef, Slot>{};
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
          onceAgain: s.onceAgain,
        ),
      );
    }

    for (final s in ir) {
      if (s.op case IrComeFrom()) {
        final target =
            _labels[(statements[s.ordinal - 1].body as ComeFrom).label]!;
        ir[target - 1].comeFrom ??= s.ordinal;
        ir[target - 1].comeFroms.add(s.ordinal);
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
      extracal: program.extracal,
      wideScalars: _wideScalars.values.toList(),
      wideArrays: _wideArrays.values.toList(),
      engine:
          program.extracal &&
          (options.forceEngine ||
              ir.any(
                (s) => _needsEngine(s.op) || s.onceAgain != OnceAgain.none,
              )),
    );
  }

  /// The `ick` control extensions, which only the control engine runs (R3).
  static bool _needsEngine(IrOp op) => switch (op) {
    IrComeFrom(nexting: true) ||
    IrComputedComeFrom() ||
    IrGerundComeFrom() ||
    IrAbstain(count: _?) => true,
    _ => false,
  };

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
      IoBody(input: true, :final items, :final signed) => IrWriteIn([
        for (final i in items) _expr(i),
      ], signed: signed),
      IoBody(input: false, :final items, :final signed) => IrReadOut([
        for (final i in items) _expr(i),
      ], signed: signed),
      GiveUp() => const IrGiveUp(),
      ComeFrom(:final nexting) => IrComeFrom(nexting: nexting),
      ComputedComeFrom(:final label, :final nexting) => IrComputedComeFrom(
        _expr(label),
        nexting: nexting,
      ),
      GerundComeFrom(:final gerunds, :final nexting) => IrGerundComeFrom(
        gerunds.toSet(),
        nexting: nexting,
      ),
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
    final count = body.count == null ? null : _expr(body.count!);
    final label = body.label;
    if (label != null) {
      final target = _labels[label];
      if (target == null) {
        _faults.add(const Fault(139));
        return IrAbstain(
          abstain: body.abstain,
          targets: const [],
          count: count,
        );
      }
      // REINSTATE of a GIVE UP by label does nothing, so DON'T GIVE UP stays a no-op (§4.4.10).
      final giveUp = program.statements[target - 1].body is GiveUp;
      return IrAbstain(
        abstain: body.abstain,
        targets: !body.abstain && giveUp ? const [] : [target],
        count: count,
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
      count: count,
    );
  }

  Slot _slot(Map<VarRef, Slot> slots, VarRef ref) {
    if (ref.number < 1 || ref.number > 65535) _faults.add(const Fault(200));
    return slots.putIfAbsent(ref, () {
      final laidOut =
          _scalars.length +
          _arrays.length +
          _wideScalars.length +
          _wideArrays.length;
      if (laidOut == memoryLimit) throw OutOfMemoryError();
      return Slot(slots.length, ref);
    });
  }

  Slot _scalar(VarRef ref) =>
      _slot(ref.kind.width == 64 ? _wideScalars : _scalars, ref);

  Slot _array(VarRef ref) =>
      _slot(ref.kind.width == 64 ? _wideArrays : _arrays, ref);

  IrExpr _expr(Expr e) => switch (e) {
    Constant() => _constant(e),
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
      if (left case IrConst(value: final l) when l >= 0 && l <= max) {
        if (right case IrConst(value: final r) when r >= 0 && r <= max) {
          return IrConst(_mingle(l, r), width: 32);
        }
      }
      // In binary EXTRACAL a mingle widens by value (R5), unless both operands surely fit in 16 bits.
      final widens =
          program.extracal &&
          program.base == 2 &&
          !(_fitsSmall(left) && _fitsSmall(right));
      return IrMingle(left, right, width: widens ? IrExpr.runtimeWidth : 32);
    }
    return IrSelect(left, right);
  }

  static bool _fitsSmall(IrExpr e) =>
      e.width == 16 || (e is IrConst && e.value >= 0 && e.value <= 0xFFFF);

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

  /// A constant above its sigil's range is E017: `#` holds a small value in the base (§3.2), `##`
  /// 32 bits and `####` 64 bits (R4).
  IrExpr _constant(Constant c) {
    final tooBig = switch (c.width) {
      16 => c.value > smallMax(program.base),
      32 => c.value < 0 || c.value > 0xFFFFFFFF,
      _ => c.overflow,
    };
    if (tooBig) _faults.add(const Fault(17));
    return IrConst(c.value, width: c.width);
  }
}
