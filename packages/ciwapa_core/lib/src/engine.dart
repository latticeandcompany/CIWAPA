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
}

const engineInitiallyAbstained = 1, engineBug = 2;

/// What EXTRACAL's control engine needs to know about a program (R3): a row of [EngineField]s per
/// statement (row 0 is unused, so a row's index is its ordinal), the lists the rows point into,
/// and the text of each undecodable statement.
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
        IrAbstain(abstain: true, :final targets) => (
          EngineKind.abstain,
          targets,
        ),
        IrAbstain(:final targets) => (EngineKind.reinstate, targets),
        IrComeFrom(nexting: true) => (EngineKind.nextFrom, const <int>[]),
        IrComeFrom() => (EngineKind.comeFrom, const <int>[]),
        IrUndecodable(:final text) => (EngineKind.undecodable, const <int>[]),
        _ => (EngineKind.plain, const <int>[]),
      };
      set(EngineField.kind, kind.index);
      final label = s.label;
      set(EngineField.label, label != null && label >= 1 ? label : 0);
      set(EngineField.gerund, s.gerund == null ? 0 : s.gerund!.index + 1);
      set(
        EngineField.flags,
        (s.initiallyAbstained ? engineInitiallyAbstained : 0) |
            (s.bug ? engineBug : 0),
      );
      set(EngineField.percent, s.percent ?? 100);
      set(EngineField.fault, s.faults.isEmpty ? 0 : s.faults.first.code);
      set(EngineField.next, s.next);
      if (s.op case IrNext(:final target)) set(EngineField.target, target);
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
