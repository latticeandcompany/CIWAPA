// A host, as a language built on CIWAPA's adds one: where the program starts, services of its own
// (with computed values), and a prologue before the first byte of output.
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';
import 'package:test/test.dart';

const toyHost = r'''
#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint32_t (*start)(void);
  int (*petition)(uint32_t, const uint32_t *, uint32_t, const uint32_t *, uint32_t, const uint64_t *,
                  uint32_t, uint32_t);
  void (*prologue)(void);
} ick_host;

void ick_set_scalar(uint32_t key, uint64_t value);
void ick_output(const char *bytes, size_t length);

static uint32_t start(void) { return 2; }

static int petition(uint32_t service, const uint32_t *scalars, uint32_t scalar_count,
                    const uint32_t *arrays, uint32_t array_count, const uint64_t *values,
                    uint32_t value_count, uint32_t next) {
  (void)scalar_count, (void)arrays, (void)array_count, (void)value_count, (void)next;
  if (service == 7) ick_set_scalar(scalars[0], 9);
  if (service == 8) ick_set_scalar(0, values[0] + values[1]);
  return service == 7 || service == 8;
}

static void prologue(void) { ick_output("HEAD\n", 5); }

static const ick_host toy = {start, petition, prologue};

const ick_host *ick_create_host(void) { return &toy; }
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
    final backend = LlvmBackend(sources: const ['host.c']);
    final files = {
      ...backend.emit(
        ir,
        const EmitOptions(clockface: false, optimize: true, sourceName: 't.xc'),
      ),
      'host.c': toyHost,
    };
    for (final MapEntry(:key, :value) in files.entries) {
      File('${temp.path}/$key').writeAsStringSync(value);
    }
    final exe = '${temp.path}/t${Platform.isWindows ? '.exe' : ''}';
    await backend.compile(temp, exe, optimize: true);
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

  test('a host call works on the control engine too', () async {
    final result = await run(
      'DO .2 <- #4\nDO .2 <- #5\nDO GIVE UP\nPLEASE READ OUT .2\nDO GIVE UP\n',
      hostCall: 3,
      engine: true,
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
