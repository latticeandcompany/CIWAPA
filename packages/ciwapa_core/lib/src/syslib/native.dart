import '../ast.dart';
import '../ir.dart';

/// A NEXT into the system library that the emitters may run as a native routine (decision Q37).
///
/// The native routine computes the result from [args] and stores it in [result], with `#1` in
/// [flag] for the routines that report overflow. Whenever it can't reproduce the INTERCAL
/// routine exactly, it falls back to it: on any overflow, when the NEXT stack lacks [depth] free
/// levels, when one of the [watched] variables is IGNOREd, or when one of the [abstainable]
/// statements is abstained.
class NativeCall {
  const NativeCall({
    required this.label,
    required this.args,
    required this.result,
    required this.flag,
    required this.depth,
    required this.watched,
    required this.abstainable,
  });

  final int label;
  final List<Slot> args;
  final Slot result;
  final Slot? flag;

  /// The most NEXT stack levels the INTERCAL routine uses, counting the call itself.
  final int depth;

  /// The variables the INTERCAL routine touches that some IGNORE in the program names.
  final List<Slot> watched;

  /// The ordinals of the INTERCAL routine's statements that some ABSTAIN or REINSTATE can reach.
  /// Nothing inside the library changes abstentions, so their state at the call decides.
  final List<int> abstainable;
}

typedef _Routine = ({List<String> args, String result, String? flag});

const Map<int, _Routine> _routines = {
  1000: (args: ['.1', '.2'], result: '.3', flag: null),
  1009: (args: ['.1', '.2'], result: '.3', flag: '.4'),
  1010: (args: ['.1', '.2'], result: '.3', flag: null),
  1020: (args: ['.1'], result: '.1', flag: null),
  1030: (args: ['.1', '.2'], result: '.3', flag: null),
  1039: (args: ['.1', '.2'], result: '.3', flag: '.4'),
  1040: (args: ['.1', '.2'], result: '.3', flag: null),
  1050: (args: [':1', '.1'], result: '.2', flag: null),
  1060: (args: ['.1', '.2'], result: '.3', flag: null),
  1070: (args: ['.1', '.2'], result: '.3', flag: null),
  1080: (args: ['.1', '.2'], result: '.3', flag: null),
  1500: (args: [':1', ':2'], result: ':3', flag: null),
  1509: (args: [':1', ':2'], result: ':3', flag: ':4'),
  1510: (args: [':1', ':2'], result: ':3', flag: null),
  1520: (args: ['.1', '.2'], result: ':1', flag: null),
  1525: (args: ['.3'], result: '.3', flag: null),
  1530: (args: ['.1', '.2'], result: ':1', flag: null),
  1540: (args: [':1', ':2'], result: ':3', flag: null),
  1549: (args: [':1', ':2'], result: ':3', flag: ':4'),
  1550: (args: [':1', ':2'], result: ':3', flag: null),
};

/// The native calls in [program], keyed by the ordinal of the library entry they replace.
Map<int, NativeCall> findNativeCalls(IrProgram program) {
  if (program.statements.length == program.userStatements) return const {};
  final slots = {for (final s in program.scalars) s.ref: s};

  final calls = <int, NativeCall>{};
  for (final entry in program.statements.skip(program.userStatements)) {
    final routine = _routines[entry.label];
    final depth = syslibDepth[entry.label];
    if (routine == null || depth == null) continue;
    final reachable = _reachable(program, entry.ordinal);
    final touched = <Slot>{};
    final abstainable = <int>[];
    var native = true;
    for (final ordinal in reachable) {
      final s = program.at(ordinal);
      native &=
          ordinal > program.userStatements &&
          !s.bug &&
          s.comeFrom == null &&
          s.op is! IrComeFrom &&
          (s.percent == null || s.percent == 100);
      if (s.abstainable) abstainable.add(ordinal);
      final (scalars, arrays) = _variables(s.op);
      touched.addAll(scalars);
      native &= !arrays;
    }
    final args = [for (final a in routine.args) slots[_ref(a)]];
    final result = slots[_ref(routine.result)];
    final flag = routine.flag == null ? null : slots[_ref(routine.flag!)];
    if (!native || args.contains(null) || result == null) continue;
    if (routine.flag != null && flag == null) continue;
    calls[entry.ordinal] = NativeCall(
      label: entry.label!,
      args: args.cast(),
      result: result,
      flag: flag,
      depth: depth,
      watched: [...touched.intersection(program.ignorable)],
      abstainable: abstainable..sort(),
    );
  }
  return calls;
}

/// The NEXT stack levels each library routine uses at most, counting the call into it, from the
/// table in `README.md`. The `depth-*` syslib tests pin them.
const Map<int, int> syslibDepth = {
  1000: 5,
  1009: 4,
  1010: 4,
  1020: 4,
  1030: 7,
  1039: 6,
  1040: 6,
  1050: 6,
  1060: 1,
  1070: 1,
  1080: 1,
  1500: 5,
  1509: 4,
  1510: 4,
  1520: 2,
  1525: 1,
  1530: 5,
  1540: 6,
  1549: 5,
  1550: 5,
};

VarRef _ref(String name) => VarRef(
  name[0] == '.' ? VarKind.spot : VarKind.twoSpot,
  int.parse(name.substring(1)),
);

/// Every statement control can reach from [entry] before the routine returns, following NEXT
/// targets and the statement after each NEXT. Computed RESUMEs make this an over-approximation.
Set<int> _reachable(IrProgram program, int entry) {
  final seen = <int>{};
  final work = [entry];
  while (work.isNotEmpty) {
    final ordinal = work.removeLast();
    if (ordinal < 1 || ordinal > program.statements.length) continue;
    if (!seen.add(ordinal)) continue;
    final s = program.at(ordinal);
    switch (s.op) {
      case IrResume() || IrGiveUp():
        if (s.percent != null || s.initiallyAbstained) work.add(ordinal + 1);
      case IrNext(:final target):
        work
          ..add(target)
          ..add(ordinal + 1);
      default:
        work.add(ordinal + 1);
    }
    if (s.comeFrom case final c?) work.add(c);
  }
  return seen;
}

/// The library statements a run can reach: everything control can get to from the user's NEXTs
/// into the library. Anything a skipped (abstained or `%`) RESUME or GIVE UP could fall into
/// counts, so the rest can never run.
Set<int> liveLibrary(IrProgram program) {
  final live = <int>{};
  final work = [
    for (final s in program.statements.take(program.userStatements))
      if (s.op case IrNext(:final target) when target > program.userStatements)
        target,
  ];
  while (work.isNotEmpty) {
    final ordinal = work.removeLast();
    if (ordinal > program.statements.length || !live.add(ordinal)) continue;
    final s = program.at(ordinal);
    final skippable = s.abstainable || (s.percent != null && s.percent! < 100);
    switch (s.op) {
      case IrResume() || IrGiveUp():
        if (skippable) work.add(ordinal + 1);
      case IrNext(:final target):
        work
          ..add(target)
          ..add(ordinal + 1);
      default:
        work.add(ordinal + 1);
    }
    if (s.comeFrom case final c?) work.add(c);
  }
  return live;
}

/// The scalars [op] names, and whether it names any array.
(Set<Slot>, bool) _variables(IrOp op) {
  final scalars = <Slot>{};
  var arrays = false;
  void expr(IrExpr e) {
    switch (e) {
      case IrScalar(:final slot):
        scalars.add(slot);
      case IrElement() || IrArrayItem():
        arrays = true;
      case IrMingle(:final left, :final right) ||
          IrSelect(:final left, :final right):
        expr(left);
        expr(right);
      case IrUnary(:final operand):
        expr(operand);
      case IrConst() || IrInput():
        break;
    }
  }

  switch (op) {
    case IrAssign(:final target, :final value):
      expr(target);
      expr(value);
    case IrDimension():
      arrays = true;
    case IrForget(:final count) || IrResume(:final count):
      expr(count);
    case IrVarList(scalars: final named, arrays: final named2):
      scalars.addAll(named);
      arrays |= named2.isNotEmpty;
    case IrWriteIn(:final items) || IrReadOut(:final items):
      items.forEach(expr);
    default:
      break;
  }
  return (scalars, arrays);
}
