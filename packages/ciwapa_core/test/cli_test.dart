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

class _Capture implements Stdout {
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
Future<(int, String)> cli(List<String> args, Backend backend) async {
  final err = _Capture();
  final status = await IOOverrides.runZoned(
    () => runCli(args, backend),
    stderr: () => err,
    stdout: () => _Capture(),
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
    final before = Directory.systemTemp
        .listSync()
        .where((e) => e.path.contains('ciwapa-'))
        .length;
    await cli([
      'build',
      source('DO GIVE UP'),
      '-o',
      '${temp.path}/prog',
    ], FakeBackend(toolchainError: 'no'));
    final after = Directory.systemTemp
        .listSync()
        .where((e) => e.path.contains('ciwapa-'))
        .length;
    expect(after, before);
  });

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
