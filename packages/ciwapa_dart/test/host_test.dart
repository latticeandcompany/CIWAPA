// A host, as a language built on CIWAPA's adds one: where the program starts, services of its own
// (with computed values), and a prologue before the first byte of output.
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_dart/ciwapa_dart.dart';
import 'package:test/test.dart';

const toyHost = r'''
import 'runtime.dart';

class Toy extends IckHost {
  @override
  int start() => 2;

  @override
  bool petition(int service, List<int> scalars, List<int> arrays, List<int> values, int next) {
    if (service == 7) ickSetScalar(scalars[0], 9);
    if (service == 8) ickSetScalar(0, values[0] + values[1]);
    return service == 7 || service == 8;
  }

  @override
  void prologue() => ickOutput('HEAD\n'.codeUnits);
}

IckHost createHost() => Toy();
''';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('host-'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Builds [text] with the toy host, its statement [hostCall] made a host call to service 8
  /// storing .2 + #3 in the first scalar (.2, the first one named), and runs it.
  Future<ProcessResult> run(
    String text, {
    int? hostCall,
    bool engine = false,
  }) async {
    final program = analyze(Source('t.xc', text));
    if (hostCall != null) {
      program.statements[hostCall - 1].body = const HostCall(
        8,
        values: [Scalar(VarRef(VarKind.spot, 2)), Constant(3)],
      );
    }
    final ir = lower(
      program,
      options: IrOptions(randomBug: false, forceEngine: engine),
      entries: const [2],
      services: const {
        7: (scalars: ['.1'], arrays: []),
      },
      host: true,
    );
    final files = {
      ...DartBackend().emit(
        ir,
        const EmitOptions(clockface: false, optimize: true, sourceName: 't.xc'),
      ),
      'host.dart': toyHost,
    };
    for (final MapEntry(:key, :value) in files.entries) {
      File('${temp.path}/$key').writeAsStringSync(value);
    }
    final exe = '${temp.path}/t${Platform.isWindows ? '.exe' : ''}';
    await DartBackend().compile(temp, exe, optimize: true);
    return Process.run(exe, const []);
  }

  test(
    'the host picks the start, runs its services and writes a prologue',
    () async {
      final result = await run(
        'DO READ OUT #1\nDO PETITION #7\nPLEASE READ OUT .1\nDO GIVE UP\n',
      );
      expect(result.stdout, 'HEAD\n  \nIX\n');
      expect(result.exitCode, 0);
    },
  );

  test('a host call passes its values, evaluated when it runs', () async {
    final result = await run(
      'DO .2 <- #4\nDO .2 <- #5\nDO GIVE UP\nPLEASE READ OUT .2\nDO GIVE UP\n',
      hostCall: 3,
    );
    expect(result.stdout, 'HEAD\n    \nVIII\n');
  });

  test('the control engine starts where the host says too', () async {
    final result = await run(
      'DO READ OUT #1\nDO PETITION #7\nPLEASE READ OUT .1\nDO GIVE UP\n',
      engine: true,
    );
    expect(result.stdout, 'HEAD\n  \nIX\n');
  });

  test('the prologue comes at a normal exit even with no output', () async {
    final result = await run('DO GIVE UP\nDO GIVE UP\n');
    expect(result.stdout, 'HEAD\n');
  });
}
