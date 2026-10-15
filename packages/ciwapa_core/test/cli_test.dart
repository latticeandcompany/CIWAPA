import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

/// A backend whose toolchain either fails or writes a placeholder executable.
class FakeBackend implements Backend {
  FakeBackend({this.toolchainError});

  final String? toolchainError;

  @override
  String get name => 'ciwapa-fake';

  @override
  String get extension => 'txt';

  @override
  Map<String, String> emit(IrProgram program, EmitOptions options) => {
    'main.txt': program.dump(),
  };

  @override
  Future<void> compile(
    Directory dir,
    String output, {
    required bool optimize,
  }) async {
    if (toolchainError != null) throw ToolchainException(toolchainError!);
    File(output).writeAsStringSync('#!/bin/sh\n');
  }

  @override
  Future<List<(bool, String)>> doctor() async => [(true, 'fake')];
}

class Capture implements Stdout {
  final buffer = BytesBuilder();

  @override
  void add(List<int> data) => buffer.add(data);

  @override
  void write(Object? object) => buffer.add(utf8.encode('$object'));

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  String get text => utf8.decode(buffer.toBytes());
}

/// Runs the CLI and returns its exit status and stderr.
Future<(int, String)> cli(
  List<String> args,
  Backend backend, {
  Directory? systemTemp,
  Capture? out,
}) async {
  final err = Capture();
  final status = await IOOverrides.runZoned(
    () => runCli(args, backend),
    stderr: () => err,
    stdout: () => out ?? Capture(),
    getSystemTempDirectory: systemTemp == null ? null : () => systemTemp,
  );
  return (status, err.text);
}

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('cli-test-'));
  tearDown(() => temp.deleteSync(recursive: true));

  String source(String text) {
    final f = File('${temp.path}/prog.i')..writeAsStringSync(text);
    return f.path;
  }

  test('a missing source file is E777, reported against statement 1', () async {
    final (status, err) = await cli([
      'build',
      '${temp.path}/nope.i',
    ], FakeBackend());
    expect(status, 777 % 256);
    expect(err, IclError.of(777).format(1));
  });

  test('an executable that cannot be written is E888', () async {
    final (status, err) = await cli([
      'build',
      source('DO GIVE UP'),
      '-o',
      '${temp.path}/no/such/dir/prog',
    ], FakeBackend());
    expect(status, 888 % 256);
    expect(err, IclError.of(888).format(1));
  });

  test('a toolchain failure is E778, after the tool\'s own output', () async {
    final (status, err) = await cli([
      'build',
      source('DO GIVE UP'),
      '-o',
      '${temp.path}/prog',
    ], FakeBackend(toolchainError: 'clang: kaboom'));
    expect(status, 778 % 256);
    expect(err, 'clang: kaboom\n${IclError.of(778).format(1)}');
  });

  test('temp directories are removed even when the build fails', () async {
    final systemTemp = Directory('${temp.path}/tmp')..createSync();
    await cli(
      ['build', source('DO GIVE UP'), '-o', '${temp.path}/prog'],
      FakeBackend(toolchainError: 'no'),
      systemTemp: systemTemp,
    );
    expect(systemTemp.listSync(), isEmpty);
  });

  test('temp files that cannot be created are E888', () async {
    final (status, err) = await cli(
      ['build', source('DO GIVE UP'), '-o', '${temp.path}/prog'],
      FakeBackend(),
      systemTemp: Directory('${temp.path}/no/such/tmp'),
    );
    expect(status, 888 % 256);
    expect(err, IclError.of(888).format(1));
  });

  test('a failed build leaves an existing executable alone', () async {
    final existing = File('${temp.path}/prog')
      ..writeAsStringSync('old program');
    final (status, _) = await cli([
      'build',
      source('DO GIVE UP'),
      '-o',
      existing.path,
    ], FakeBackend(toolchainError: 'no'));
    expect(status, 778 % 256);
    expect(existing.readAsStringSync(), 'old program');
  });

  test('a failed build leaves no empty executable behind', () async {
    await cli([
      'build',
      source('DO GIVE UP'),
      '-o',
      '${temp.path}/new',
    ], FakeBackend(toolchainError: 'no'));
    expect(File('${temp.path}/new').existsSync(), isFalse);
  });

  test('--dump=ast prints each statement as parsed (§10.2, Q101)', () async {
    final out = Capture();
    final (status, _) = await cli(
      [
        'build',
        source('(5) PLEASE NOT %50 GIVE UP'),
        '--dump=ast',
        '-o',
        '${temp.path}/prog',
      ],
      FakeBackend(),
      out: out,
    );
    expect(status, 0);
    expect(out.text, '1 (5) PLEASE NOT %50 GiveUp\n');
  });

  test('--dump=ir prints the IR (§10.2, Q101)', () async {
    final out = Capture();
    final (status, _) = await cli(
      [
        'build',
        '--no-random-bug',
        source('PLEASE DO (2) NEXT\n(2) DO GIVE UP'),
        '--dump=ir',
        '-o',
        '${temp.path}/prog',
      ],
      FakeBackend(),
      out: out,
    );
    expect(status, 0);
    expect(out.text, '1 NEXT 2 next=2\n2 (2) GIVE UP next=3\n');
  });

  test(
    '--keep writes the generated source beside the executable (§10.2, Q101)',
    () async {
      final path = source('DO GIVE UP');
      await cli(['build', path, '-o', '${temp.path}/prog'], FakeBackend());
      expect(File('${temp.path}/prog.txt').existsSync(), isFalse);
      await cli([
        'build',
        '--keep',
        path,
        '-o',
        '${temp.path}/prog',
      ], FakeBackend());
      expect(
        File('${temp.path}/prog.txt').readAsStringSync(),
        startsWith('1 '),
      );
    },
  );

  test('--seed must be a whole number', () async {
    final (status, err) = await cli([
      'build',
      source('DO GIVE UP'),
      '--seed',
      'abc',
    ], FakeBackend());
    expect(status, 64);
    expect(err, contains('--seed'));
  });
}
