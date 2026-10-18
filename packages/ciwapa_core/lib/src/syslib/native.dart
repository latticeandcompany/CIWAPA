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

/// Whether no native routine can stand in for its INTERCAL: a computed or gerund COME FROM could
/// take control from inside any routine, overloading could change what any variable in it means,
/// and with threads, each of its statements is a turn.
bool _noNatives(IrProgram program) =>
    program.overloading ||
    program.statements.any(
      (s) =>
          s.op is IrComputedComeFrom ||
          s.op is IrGerundComeFrom ||
          s.comeFroms.length > 1 ||
          s.preproc,
    );

/// A NEXT into a library routine that a runtime runs natively (R10, Q37): a routine that is just
/// `PETITION #n` and `RESUME #1` runs as its [petition]; the routines in [libraryRoutines] run as
/// the runtime's own version, on their documented [scalars] and [arrays]. It falls back to the
/// INTERCAL when the NEXT stack has fewer than [depth] free levels, when one of the [watched]
/// variables or [watchedArrays] is IGNOREd, or when one of the [abstainable] statements is
/// abstained. [nexts] lists each PETITION the INTERCAL uses, in program order, as its service and
/// the ordinal its errors name, so the native version reports them in the same place.
class NativeLibraryCall {
  const NativeLibraryCall({
    required this.label,
    required this.petition,
    required this.scalars,
    required this.arrays,
    required this.depth,
    required this.watched,
    required this.watchedArrays,
    required this.abstainable,
    required this.nexts,
  });

  final int label;
  final IrPetition? petition;
  final List<Slot> scalars;
  final List<Slot> arrays;
  final int depth;
  final List<Slot> watched;
  final List<Slot> watchedArrays;
  final List<int> abstainable;
  final List<(int, int)> nexts;
}

/// The library routines with native versions, and their documented variables. Their INTERCAL
/// never reaches deeper than [_libraryDepth] NEXT stack levels.
const libraryRoutines = <int, ({List<String> scalars, List<String> arrays})>{
  2100: (scalars: ['.1', ':1', '.3'], arrays: []),
  2110: (scalars: ['.1', ':1', '.3'], arrays: []),
  2200: (scalars: ['.1', '.3'], arrays: [',1']),
  2300: (scalars: ['.1', '.3'], arrays: [',1']),
  2310: (scalars: ['.1', '.3'], arrays: [',1']),
  3010: (scalars: [], arrays: [',1', ',2']),
  3020: (scalars: [':1', ':2'], arrays: [',1']),
  3030: (scalars: ['.1'], arrays: [',1', ',2']),
  3040: (scalars: [':1', '.1'], arrays: [',1', ',2']),
  3050: (scalars: [':1'], arrays: [',1']),
  3060: (scalars: [':1', '.1'], arrays: [',1']),
  3070: (scalars: [], arrays: [',1']),
  3080: (scalars: [], arrays: [',1']),
  4000: (scalars: ['::1', '::2', '::3'], arrays: []),
  4009: (scalars: ['::1', '::2', '::3', '::4'], arrays: []),
  4010: (scalars: ['::1', '::2', '::3'], arrays: []),
  4020: (scalars: [':1', ':2', '::1'], arrays: []),
  4030: (scalars: [':1', ':2', '::1'], arrays: []),
  4040: (scalars: ['::1', '::2', '::3'], arrays: []),
  4049: (scalars: ['::1', '::2', '::3', '::4'], arrays: []),
  4050: (scalars: ['::1', '::2', '::3'], arrays: []),
  4070: (scalars: ['::1', '::2', '::3'], arrays: []),
  4100: (scalars: ['.1', '.2', '.3'], arrays: []),
  4109: (scalars: ['.1', '.2', '.3', '.4'], arrays: []),
  4110: (scalars: ['.1', '.2', '.3'], arrays: []),
  4119: (scalars: ['.1', '.2', '.3', '.4'], arrays: []),
  4140: (scalars: ['.1', '.2', '.3'], arrays: []),
  4149: (scalars: ['.1', '.2', '.3', '.4'], arrays: []),
  4150: (scalars: ['.1', '.2', '.3'], arrays: []),
  4160: (scalars: ['.1', '.2', '.3'], arrays: []),
  4200: (scalars: [':1', ':2', ':3'], arrays: []),
  4209: (scalars: [':1', ':2', ':3', ':4'], arrays: []),
  4210: (scalars: [':1', ':2', ':3'], arrays: []),
  4219: (scalars: [':1', ':2', ':3', ':4'], arrays: []),
  4240: (scalars: [':1', ':2', ':3'], arrays: []),
  4249: (scalars: [':1', ':2', ':3', ':4'], arrays: []),
  4250: (scalars: [':1', ':2', ':3'], arrays: []),
  4260: (scalars: [':1', ':2', ':3'], arrays: []),
  4300: (scalars: ['::1', '::2', '::3'], arrays: []),
  4309: (scalars: ['::1', '::2', '::3', '::4'], arrays: []),
  4310: (scalars: ['::1', '::2', '::3'], arrays: []),
  4319: (scalars: ['::1', '::2', '::3', '::4'], arrays: []),
  4340: (scalars: ['::1', '::2', '::3'], arrays: []),
  4349: (scalars: ['::1', '::2', '::3', '::4'], arrays: []),
  4350: (scalars: ['::1', '::2', '::3'], arrays: []),
  4360: (scalars: ['::1', '::2', '::3'], arrays: []),
  4500: (scalars: [':1', ':2', ':3'], arrays: []),
  4509: (scalars: [':1', ':2', ':3', ':4'], arrays: []),
  4510: (scalars: [':1', ':2'], arrays: []),
  4520: (scalars: [':1', ':2', ':3'], arrays: []),
  4530: (scalars: [':1', ':2', ':3'], arrays: []),
  4600: (scalars: ['::1', '::2', '::3'], arrays: []),
  4609: (scalars: ['::1', '::2', '::3', '::4'], arrays: []),
  4610: (scalars: ['::1', '::2'], arrays: []),
  4620: (scalars: ['::1', '::2', '::3'], arrays: []),
  4630: (scalars: ['::1', '::2', '::3'], arrays: []),
  7000: (scalars: [':1', ':2', ':3'], arrays: []),
  7010: (scalars: [':1', ':2', ':3'], arrays: []),
  7020: (scalars: [':1', ':2', ':3'], arrays: []),
  7030: (scalars: [':1', ':2', ':3'], arrays: []),
  7040: (scalars: [':1', ':2', ':3'], arrays: []),
  7050: (scalars: [':1', ':2'], arrays: []),
  7060: (scalars: [':1', ':2'], arrays: []),
  7070: (scalars: [':1', ':2'], arrays: []),
  7080: (scalars: [':1'], arrays: [',1']),
  7090: (scalars: [':1', '.1'], arrays: [',1']),
  6020: (scalars: ['.1'], arrays: [',1']),
  6030: (scalars: [], arrays: [',1', ',2']),
  6040: (scalars: [], arrays: [',1']),
  6050: (scalars: ['.1', ':1', '.2'], arrays: [',1']),
  6120: (scalars: [':2'], arrays: [';1']),
  6130: (scalars: [], arrays: [';1', ';2']),
  6140: (scalars: [], arrays: [';1']),
  6150: (scalars: [':2', ':1', '.2'], arrays: [';1']),
};

const _libraryDepth = 40;

/// The native library calls in [program], keyed by the ordinal of the library entry they replace.
Map<int, NativeLibraryCall> findNativeLibraryCalls(IrProgram program) {
  if (program.statements.length == program.userStatements) return const {};
  if (_noNatives(program)) return const {};
  final slots = {
    for (final s in [...program.scalars, ...program.wideScalars]) s.ref: s,
  };
  final arraySlots = {for (final a in program.arrays) a.ref: a};
  final found = <int, NativeLibraryCall>{};
  for (final entry in program.statements.skip(program.userStatements)) {
    final label = entry.label;
    if (label == null) continue;
    final petition = entry.op;
    final routine = libraryRoutines[label];
    final List<int> ordinals;
    if (routine != null) {
      ordinals = (_reachable(program, entry.ordinal).toList()..sort());
    } else if (petition is IrPetition &&
        entry.ordinal < program.statements.length &&
        program.at(entry.ordinal + 1).op is IrResume &&
        (program.at(entry.ordinal + 1).op as IrResume).count is IrConst &&
        ((program.at(entry.ordinal + 1).op as IrResume).count as IrConst)
                .value ==
            1) {
      ordinals = [entry.ordinal, entry.ordinal + 1];
    } else {
      continue;
    }
    final touched = <Slot>{}, touchedArrays = <Slot>{};
    final abstainable = <int>[];
    final nexts = <(int, int)>[];
    var native = true;
    for (final ordinal in ordinals) {
      final s = program.at(ordinal);
      native &=
          ordinal > program.userStatements &&
          !s.bug &&
          s.comeFrom == null &&
          s.faults.isEmpty &&
          (s.percent == null || s.percent == 100);
      if (s.abstainable) abstainable.add(ordinal);
      final (scalars, arrays) = _variables(s.op);
      touched.addAll(scalars);
      touchedArrays.addAll(arrays);
      if (s.op case IrPetition(:final service)) nexts.add((service, s.next));
    }
    if (!native) continue;
    VarRef ref(String name) {
      final sigil = name.replaceAll(RegExp('[0-9]'), '');
      return VarRef(
        VarKind.values.firstWhere((k) => k.sigil == sigil),
        int.parse(name.substring(sigil.length)),
      );
    }

    final scalars = [
      for (final r in routine?.scalars ?? const []) slots[ref(r)],
    ];
    final arrays = [
      for (final r in routine?.arrays ?? const []) arraySlots[ref(r)],
    ];
    if (scalars.contains(null) || arrays.contains(null)) continue;
    found[entry.ordinal] = NativeLibraryCall(
      label: label,
      petition: routine == null ? petition as IrPetition : null,
      scalars: scalars.cast(),
      arrays: arrays.cast(),
      depth: routine == null ? 1 : _libraryDepth,
      watched: [...touched.intersection(program.ignorable)],
      watchedArrays: [...touchedArrays.intersection(program.ignorable)],
      abstainable: abstainable,
      nexts: nexts,
    );
  }
  return found;
}

/// The native calls in [program], keyed by the ordinal of the library entry they replace.
Map<int, NativeCall> findNativeCalls(IrProgram program) {
  if (program.statements.length == program.userStatements) return const {};
  if (_noNatives(program)) return const {};
  final slots = {for (final s in program.scalars) s.ref: s};

  final calls = <int, NativeCall>{};
  for (final entry in program.statements.skip(program.userStatements)) {
    final routine = _routines[entry.label];
    final depth = syslibDepth[entry.label];
    if (routine == null || depth == null) continue;
    final routineStatements = _reachable(program, entry.ordinal);
    final touched = <Slot>{};
    final abstainable = <int>[];
    var native = true;
    for (final ordinal in routineStatements) {
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
      native &= arrays.isEmpty;
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

/// The statements a run can reach: everything control can get to from the first statement. A
/// NEXT's return point counts, since a RESUME can land there, and so does anything a skipped
/// (abstained or `%`) RESUME or GIVE UP could fall into; the rest can never run. Running off the
/// user's last statement is E633, not a way into the library.
Set<int> reachable(IrProgram program) {
  final live = <int>{};
  final work = [if (program.statements.isNotEmpty) 1];
  void fallFrom(int ordinal) {
    if (ordinal != program.userStatements) work.add(ordinal + 1);
  }

  while (work.isNotEmpty) {
    final ordinal = work.removeLast();
    if (ordinal < 1 || ordinal > program.statements.length) continue;
    if (!live.add(ordinal)) continue;
    final s = program.at(ordinal);
    final skippable = s.abstainable || (s.percent != null && s.percent! < 100);
    switch (s.op) {
      case IrResume() || IrGiveUp():
        if (skippable) fallFrom(ordinal);
      case IrNext(:final target):
        work.add(target);
        fallFrom(ordinal);
      default:
        fallFrom(ordinal);
    }
    if (s.comeFrom case final c?) work.add(c);
  }
  return live;
}

/// The scalars [op] names, and whether it names any array.
(Set<Slot>, Set<Slot>) _variables(IrOp op) {
  final scalars = <Slot>{};
  final arrays = <Slot>{};
  void expr(IrExpr e) {
    switch (e) {
      case IrScalar(:final slot):
        scalars.add(slot);
      case IrElement(:final array, :final subscripts):
        arrays.add(array);
        subscripts.forEach(expr);
      case IrArrayItem(:final array):
        arrays.add(array);
      case IrMingle(:final left, :final right) ||
          IrSelect(:final left, :final right) ||
          IrCreatedOp(:final left, :final right):
        expr(left);
        expr(right);
      case IrUnary(:final operand):
        expr(operand);
      case IrSlat(:final slot):
        scalars.add(slot);
      case IrConst() || IrInput():
        break;
    }
  }

  switch (op) {
    case IrAssign(:final target, :final value):
      expr(target);
      expr(value);
    case IrDimension(:final array, :final dimensions):
      arrays.add(array);
      dimensions.forEach(expr);
    case IrForget(:final count) || IrResume(:final count):
      expr(count);
    case IrVarList(scalars: final named, arrays: final named2):
      scalars.addAll(named);
      arrays.addAll(named2);
    case IrWriteIn(:final items) || IrReadOut(:final items):
      items.forEach(expr);
    case IrPetition(scalars: final named, arrays: final named2):
      scalars.addAll(named);
      arrays.addAll(named2);
    default:
      break;
  }
  return (scalars, arrays);
}
