import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_llvm/ciwapa_llvm.dart';
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
      test('R1: a .xc is plain EXTRACAL', () async {
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

      for (final name in ['states.ioi', 'states.2ioi']) {
        test('R1, Q154: a $name is an Interstates program', () async {
          final (status, err) = await build(
            backend,
            name,
            'DO COME FROM (16000)\nDO .1 <- #3\nPLEASE READ OUT .1\nDO GIVE UP\n',
            [],
          );
          expect(err, '');
          expect(status, 0);
          final run = await Process.run(exe('prog'), const []);
          expect(
            run.stdout,
            'Status: 200 OK\nContent-Type: text/html; charset=utf-8\n\n'
            '   \nIII\n',
          );
        });
      }

      test('R1, Q141: a .ioi tolerates prose first and a bare GIVE UP, and '
          'the same text as a .xc does not', () async {
        const text =
            'This is prose.\nDO COME FROM (16000)\nDO .1 <- #3\nPLEASE READ OUT .1\nGIVE UP\n';
        final (ioiStatus, ioiErr) = await build(backend, 'p.ioi', text, []);
        expect(ioiErr, '');
        expect(ioiStatus, 0);
        // As plain EXTRACAL the prose is an undecodable statement, and the COME FROM (16000) has
        // no label to come from.
        final (xcStatus, xcErr) = await build(backend, 'p.xc', text, []);
        expect(xcErr, IclError.of(444).format(2));
        expect(xcStatus, 444 % 256);
      });

      test('R1, L35: other extensions are E998, Mode 1 included', () async {
        for (final name in [
          'p.i',
          'p.3i',
          'p.html',
          'p.3ioi',
          'p.4ioi',
          'p.5ioi',
          'p.6ioi',
          'p.7ioi',
        ]) {
          final (status, err) = await build(backend, name, 'DO GIVE UP\n', []);
          expect(err, IclError.of(998).format(1), reason: name);
          expect(status, 998 % 256, reason: name);
        }
      });

      test('R1, L35: EXTRACAL in bases 3-7 still builds', () async {
        final (status, err) = await build(
          backend,
          'p.3xc',
          'DO .1 <- #2\nPLEASE READ OUT .1\nDO GIVE UP\n',
          [],
        );
        expect(err, '');
        expect(status, 0);
      });

      test('R1, L35: a .ioi uses C-INTERCAL extensions, so --traditional '
          'rejects it (E111)', () async {
        final (status, err) = await build(
          backend,
          'states.ioi',
          'DO GIVE UP\n',
          ['--traditional'],
        );
        expect(err, IclError.of(111).format(1));
        expect(status, 111);
      });

      for (final flag in ['-s', '--states']) {
        test('R1: $flag is gone, and says to rename the file', () async {
          final (status, err) = await build(
            backend,
            'site.xc',
            'DO GIVE UP\n',
            [flag],
          );
          expect(
            err,
            '${backend.name}: -s is gone: Interstates programs are .ioi files now. '
            'Rename ${temp.path}/site.xc to ${temp.path}/site.ioi and build it without -s.\n',
          );
          expect(status, 64);
          expect(File(exe('prog')).existsSync(), isFalse);
        });
      }
    });
  }

  test('R1: ciwapa-* has never heard of .ioi (E998)', () async {
    final source = File('${temp.path}/site.ioi')
      ..writeAsStringSync('DO GIVE UP\n');
    final err = _Capture();
    final status = await IOOverrides.runZoned(
      () => runCli(['build', source.path, '-o', exe('prog')], LlvmBackend()),
      stderr: () => err,
      stdout: () => _Capture(),
    );
    expect(err.text, IclError.of(998).format(1));
    expect(status, 998 % 256);
  });

  test('the usage names .ioi files and no longer mentions -s', () async {
    final out = _Capture();
    await IOOverrides.runZoned(
      () => runCli(['--help'], ioiLlvm(), frontend: InterstatesFrontend()),
      stdout: () => out,
    );
    expect(out.text, contains('ioi-llvm build <file.ioi or file.xc>'));
    expect(out.text, isNot(contains('--states')));
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
