import 'ast.dart' show OnceAgain;
import 'ir.dart';

/// Statement kinds in the control engine's table. Both runtimes define the same numbers.
enum EngineKind {
  plain,
  next,
  forget,
  resume,
  giveUp,
  abstain,
  reinstate,
  comeFrom,
  nextFrom,
  undecodable,
  computedComeFrom,
  computedNextFrom,
  gerundComeFrom,
  gerundNextFrom,
  computedAbstain,
  tryAgain,
  create,
  computedCreate,
  unknown,
  goBack,
  goAhead,
}

/// The fields of one statement's row, in order.
enum EngineField {
  kind,
  label,
  gerund,
  flags,
  percent,
  onceAgain,
  fault,
  next,
  target,
  listStart,
  listLength,
  comeFromStart,
  comeFromLength,
  signature,
}

const engineInitiallyAbstained = 1,
    engineBug = 2,
    engineMaybe = 4,
    enginePreproc = 8,
    engineWeaveOn = 16,
    engineWeaveOff = 32;

/// What EXTRACAL's control engine needs to know about a program (R3): a row of [EngineField]s per
/// statement (row 0 is unused, so a row's index is its ordinal), the lists the rows point into,
/// and the text of each undecodable or unknown statement.
class EngineTable {
  EngineTable(IrProgram program) {
    rows.addAll(List.filled(EngineField.values.length, 0));
    for (final s in program.statements) {
      final row = List.filled(EngineField.values.length, 0);
      void set(EngineField field, int value) => row[field.index] = value;
      final (kind, targets) = switch (s.op) {
        IrNext() => (EngineKind.next, const <int>[]),
        IrForget() => (EngineKind.forget, const <int>[]),
        IrResume() => (EngineKind.resume, const <int>[]),
        IrGiveUp() => (EngineKind.giveUp, const <int>[]),
        IrTryAgain() => (EngineKind.tryAgain, const <int>[]),
        IrAbstain(count: _?, :final targets) => (
          EngineKind.computedAbstain,
          targets,
        ),
        IrAbstain(abstain: true, :final targets) => (
          EngineKind.abstain,
          targets,
        ),
        IrAbstain(:final targets) => (EngineKind.reinstate, targets),
        IrComeFrom(nexting: true) => (EngineKind.nextFrom, const <int>[]),
        IrComeFrom() => (EngineKind.comeFrom, const <int>[]),
        IrUndecodable() => (EngineKind.undecodable, const <int>[]),
        IrCreate(target: _?) => (EngineKind.computedCreate, const <int>[]),
        IrCreate() => (EngineKind.create, const <int>[]),
        IrUnknown() => (EngineKind.unknown, const <int>[]),
        IrGoBack() => (EngineKind.goBack, const <int>[]),
        IrGoAhead() => (EngineKind.goAhead, const <int>[]),
        IrComputedComeFrom(nexting: true) => (
          EngineKind.computedNextFrom,
          const <int>[],
        ),
        IrComputedComeFrom() => (EngineKind.computedComeFrom, const <int>[]),
        IrGerundComeFrom(nexting: true, :final gerunds) => (
          EngineKind.gerundNextFrom,
          [for (final g in gerunds) g.index + 1],
        ),
        IrGerundComeFrom(:final gerunds) => (
          EngineKind.gerundComeFrom,
          [for (final g in gerunds) g.index + 1],
        ),
        _ => (EngineKind.plain, const <int>[]),
      };
      set(EngineField.kind, kind.index);
      final label = s.label;
      set(
        EngineField.label,
        label != null && label >= 1 && !s.preproc ? label : 0,
      );
      set(EngineField.gerund, s.gerund == null ? 0 : s.gerund!.index + 1);
      set(
        EngineField.flags,
        (s.initiallyAbstained ? engineInitiallyAbstained : 0) |
            (s.bug ? engineBug : 0) |
            (s.maybe ? engineMaybe : 0) |
            (s.preproc ? enginePreproc : 0) |
            (s.weave > 0 ? engineWeaveOn : 0) |
            (s.weave < 0 ? engineWeaveOff : 0),
      );
      set(EngineField.percent, s.percent ?? 100);
      // What reaching the statement does to its abstention, after `ick`'s swap of ONCE and AGAIN
      // on an initially abstained statement: 1 abstains it, 2 reinstates it.
      set(EngineField.onceAgain, switch ((s.onceAgain, s.initiallyAbstained)) {
        (OnceAgain.none, _) => 0,
        (OnceAgain.once, false) || (OnceAgain.again, true) => 1,
        _ => 2,
      });
      set(EngineField.fault, s.faults.isEmpty ? 0 : s.faults.first.code);
      set(EngineField.next, s.next);
      switch (s.op) {
        case IrNext(:final target) || IrCreate(label: final target):
          set(EngineField.target, target);
        case IrUnknown(:final signature, :final text):
          set(EngineField.signature, signature);
          texts[s.ordinal] = text;
        default:
      }
      if (s.op case IrCreate(:final signature)) {
        set(EngineField.signature, signature);
      }
      set(EngineField.listStart, lists.length);
      set(EngineField.listLength, targets.length);
      lists.addAll(targets);
      set(EngineField.comeFromStart, lists.length);
      set(EngineField.comeFromLength, s.comeFroms.length);
      lists.addAll(s.comeFroms);
      if (s.op case IrUndecodable(:final text)) texts[s.ordinal] = text;
      rows.addAll(row);
    }
  }

  final rows = <int>[];
  final lists = <int>[];
  final texts = <int, String>{};
}
