// TEMPORARY (goal 2's cleanup removes it): triages tools/oracle/differential's results. Each
// difference from an ick oracle gets the Divergences entry (or decision) that explains it, by the
// rules below or by tools/oracle/reasons.json. Writes tools/oracle/triage.json when every
// difference is explained; otherwise lists the ones that aren't and exits 1.
// Usage: tools/in-docker dart run tools/oracle/triage.dart
import 'dart:convert';
import 'dart:io';

const work = '.cache/oracle/programs';
const oracles = ['ick035', 'ick015'];
const flavors = ['llvm', 'dart'];

/// The §7.2 entry points; pit programs that NEXT to any other 1xxx label rely on ick's library.
const documented = {
  1000, 1009, 1010, 1020, 1030, 1039, 1040, 1050, 1060, 1070, 1080, //
  1500, 1509, 1510, 1520, 1525, 1530, 1540, 1549, 1550, 1900, 1910,
};

String? read(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync().trim() : null;
}

List<int>? bytes(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsBytesSync() : null;
}

bool same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The ICL code of a run-time error in an exit ("0:ICL000" gives "ICL000"), or null.
String? runtimeCode(String exit) =>
    exit.startsWith('compile') || !exit.contains(':')
    ? null
    : exit.split(':')[1];

String? rule(
  String name,
  String source,
  String oracle,
  String ickExit,
  String ourExit,
  List<int> ickOut,
  List<int> ourOut,
) {
  if (name.contains('_syslib_')) return 'Q35, Q38 (clean-room library)';
  if (name.startsWith('pit_')) {
    final defined = RegExp(
      r'^\s*\((\d+)\)',
      multiLine: true,
    ).allMatches(source).map((m) => int.parse(m[1]!)).toSet();
    final called = RegExp(r'\(\s*(1\d\d\d)\s*\)\s*NEXT')
        .allMatches(source)
        .map((m) => int.parse(m[1]!));
    if (called.any((l) => !documented.contains(l) && !defined.contains(l))) {
      return 'Q35, Q38 (ick-internal library labels)';
    }
  }
  if (oracle == 'ick015' &&
      ickExit == 'compile:ICL017' &&
      runtimeCode(ourExit) == 'ICL000') {
    return 'T9';
  }
  if (RegExp(r'%\s*(0|1\s*0\s*0)\b').hasMatch(source) &&
      ickExit == 'compile:ICL017') {
    return 'T13';
  }
  if (RegExp(r'^compile:ICL(017|200|197|129|139)$').hasMatch(ickExit) &&
      !ourExit.startsWith('compile') &&
      runtimeCode(ourExit) != 'ICL000') {
    return 'Q80/Q81';
  }
  if (oracle == 'ick035' &&
      ickExit == '129:ICL129' &&
      ourExit == '121:ICL633' &&
      same(ickOut, ourOut)) {
    return '§9.2 (running off the end is E633)';
  }
  if (ickExit == '124' && ourExit == '124') {
    final n = ickOut.length < ourOut.length ? ickOut.length : ourOut.length;
    if (n > 0 && same(ickOut.sublist(0, n), ourOut.sublist(0, n))) {
      return 'not a difference: never stops, same output up to the timeout';
    }
  }
  if (oracle == 'ick015' && ickExit.startsWith('127')) {
    return 'not a difference: 0.15 generates C that does not compile';
  }
  return null;
}

void main() {
  final reasons = (jsonDecode(
    File('tools/oracle/reasons.json').readAsStringSync(),
  ) as Map).cast<String, String>();
  final names = File('$work/list').readAsLinesSync().where((l) => l.isNotEmpty);
  final triaged = <Map<String, String>>[];
  final untriaged = <String>[];
  final used = <String>{};
  final parity = <String>[];
  for (final name in names) {
    final source = latin1.decode(File('$work/$name').readAsBytesSync());
    final llvmOut = bytes('$work/$name.out.llvm');
    final dartOut = bytes('$work/$name.out.dart');
    if (llvmOut != null &&
        dartOut != null &&
        (!same(llvmOut, dartOut) ||
            read('$work/$name.exit.llvm') != read('$work/$name.exit.dart'))) {
      parity.add(name);
    }
    for (final oracle in oracles) {
      for (final flavor in flavors) {
        final ickOut = bytes('$work/$name.out.$oracle')!;
        final ourOut = bytes('$work/$name.out.$flavor');
        if (ourOut == null) continue;
        final ickExit = read('$work/$name.exit.$oracle')!;
        final ourExit = read('$work/$name.exit.$flavor')!;
        if (same(ickOut, ourOut) && ickExit == ourExit) continue;
        final key = reasons.containsKey('$name|$oracle')
            ? '$name|$oracle'
            : name;
        if (reasons.containsKey(key)) used.add(key);
        final reason =
            reasons[key] ??
            rule(name, source, oracle, ickExit, ourExit, ickOut, ourOut);
        if (reason == null) {
          untriaged.add('$oracle $flavor $name: ick $ickExit, ours $ourExit');
          continue;
        }
        triaged.add({
          'program': name,
          'oracle': oracle,
          'flavor': flavor,
          'ick_exit': ickExit,
          'ciwapa_exit': ourExit,
          'status': reason.startsWith('not a difference')
              ? 'not a difference'
              : 'divergence',
          'reason': reason,
        });
      }
    }
  }
  stdout.writeln(
    '${names.length} programs, ${triaged.length} triaged, ${untriaged.length} untriaged',
  );
  stdout.writeln(
    'llvm and dart disagree on: ${parity.isEmpty ? 'nothing' : parity.join(', ')}',
  );
  // The flavors must agree, apart from programs whose `%` rolls come from the clock (T22).
  for (final name in parity) {
    if (reasons[name] != 'T22') untriaged.add('llvm and dart differ on $name');
  }
  for (final key in reasons.keys.where((k) => !used.contains(k))) {
    untriaged.add('reasons.json: $key explains no difference');
  }
  if (untriaged.isNotEmpty) {
    untriaged.forEach(stdout.writeln);
    exit(1);
  }
  File('tools/oracle/triage.json').writeAsStringSync(
    '${const JsonEncoder.withIndent(' ').convert({
      'programs': names.length,
      'oracles': {'ick035': 'C-INTERCAL 0.35', 'ick015': 'C-INTERCAL 0.15'},
      'differences': triaged,
    })}\n',
  );
  stdout.writeln('wrote tools/oracle/triage.json');
}
