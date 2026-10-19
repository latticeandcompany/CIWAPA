import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:interstates/interstates.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('ioi-cli-'));
  tearDown(() => temp.deleteSync(recursive: true));

  String exe(String name) =>
      '${temp.path}/$name${Platform.isWindows ? '.exe' : ''}';

  /// Builds [program] as [name] with [flags] and returns the CLI's exit status and stderr.
  Future<(int, String)> build(
    Backend backend,
    String name,
    String program,
    List<String> flags,
  ) async {
    final source = File('${temp.path}/$name')..writeAsStringSync(program);
    final err = _Capture();
    final status = await IOOverrides.runZoned(
      () => runCli(
        ['build', '--no-random-bug', ...flags, source.path, '-o', exe('prog')],
        backend,
        frontend: InterstatesFrontend(),
      ),
      stderr: () => err,
      stdout: () => _Capture(),
    );
    return (status, err.text);
  }

  for (final backend in [ioiDart(), ioiLlvm()]) {
    group(backend.name, () {
      test('R1: without -s it compiles plain EXTRACAL', () async {
        final (status, err) = await build(
          backend,
          'plain.xc',
          'DO ::1 <- ####5000000000\nPLEASE READ OUT ::1\nDO GIVE UP\n',
          [],
        );
        expect(err, '');
        expect(status, 0);
        final run = await Process.run(exe('prog'), const []);
        expect(run.stdout, '_\nv\n');
      });

      test('punchline 2: -s builds a .xc program', () async {
        final (status, err) = await build(
          backend,
          'states.xc',
          'DO .1 <- #3\nPLEASE READ OUT .1\nDO GIVE UP\n',
          ['-s'],
        );
        expect(err, '');
        expect(status, 0);
        final run = await Process.run(exe('prog'), const []);
        expect(run.stdout, '   \nIII\n');
      });

      test('R1: -s takes only binary .xc files (E998)', () async {
        for (final name in ['states.i', 'states.3xc']) {
          final (status, err) = await build(backend, name, 'DO GIVE UP\n', [
            '-s',
          ]);
          expect(err, IclError.of(998).format(1));
          expect(status, 998 % 256);
        }
      });

      test('R1: -s is a C-INTERCAL extension, so --traditional rejects it '
          '(E111)', () async {
        final (status, err) = await build(
          backend,
          'states.xc',
          'DO GIVE UP\n',
          ['-s', '--traditional'],
        );
        expect(err, IclError.of(111).format(1));
        expect(status, 111);
      });
    });
  }

  test('the usage names -s and the ioi-* command', () async {
    final out = _Capture();
    await IOOverrides.runZoned(
      () => runCli(['--help'], ioiLlvm(), frontend: InterstatesFrontend()),
      stdout: () => out,
    );
    expect(out.text, contains('ioi-llvm build <file.xc>'));
    expect(out.text, contains("-s, --states           'States: turn on"));
  });
}

class _Capture implements Stdout {
  final _buffer = BytesBuilder();

  @override
  void add(List<int> data) => _buffer.add(data);

  @override
  void write(Object? object) => _buffer.add(utf8.encode('$object'));

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  String get text => utf8.decode(_buffer.toBytes());
}
