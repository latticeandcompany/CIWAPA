// R7, Q146: an adapter loads through the C ABI, in programs built by both flavors, and AMNESIA
// drops its tables through it. It needs IOI_LIB (from tool/activecassette.sh) and a C compiler
// (CC, or clang).
import 'dart:io';

import 'package:interstates/interstates.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Directory temp;
  late String library;
  late String nullLibrary;

  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('ioi-adapter-');
    final lib = Platform.environment['IOI_LIB'];
    if (lib == null) fail('the adapter tests need IOI_LIB');
    library =
        '${temp.path}/${Platform.isWindows
            ? 'loud.dll'
            : Platform.isMacOS
            ? 'libloud.dylib'
            : 'libloud.so'}';
    final result = await Process.run(Platform.environment['CC'] ?? 'clang', [
      if (Platform.isMacOS) '-dynamiclib' else '-shared',
      if (!Platform.isWindows && !Platform.isMacOS) '-fPIC',
      '-O1',
      '-w',
      '-DSQLITE_OMIT_LOAD_EXTENSION',
      '-DSQLITE_THREADSAFE=0',
      '-I$lib/sqlite',
      '-Iruntime',
      'test/adapter/loud_adapter.c',
      '-o',
      library,
    ]);
    if (result.exitCode != 0) fail('${result.stdout}${result.stderr}');
    nullLibrary = library.replaceFirst('loud', 'null');
    final nothing = File('${temp.path}/null_adapter.c')
      ..writeAsStringSync(
        '#include "ioi_adapter.h"\n'
        '${Platform.isWindows ? '__declspec(dllexport) ' : ''}'
        'const ioi_adapter *ioi_adapter_entry(void) { return 0; }\n',
      );
    final built = await Process.run(Platform.environment['CC'] ?? 'clang', [
      if (Platform.isMacOS) '-dynamiclib' else '-shared',
      if (!Platform.isWindows && !Platform.isMacOS) '-fPIC',
      '-w',
      '-Iruntime',
      nothing.path,
      '-o',
      nullLibrary,
    ]);
    if (built.exitCode != 0) fail('${built.stdout}${built.stderr}');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  final source = program([
    'COME FROM (16000)',
    ...string(',1', 'CREATE TABLE notes (body TEXT)'),
    ':1 <- #0',
    ':2 <- #1',
    '(16200) NEXT',
    ...string(',1', 'remember me'),
    'INTO DATABASE #1~#1 <- ,1',
    ";49221 <- 'FROM DATABASE #1~#1' HAVING #1 ,1",
    ',1 <- ;49221 SUB #1',
    ...writeLine,
    'AMNESIA',
    '(16210) NEXT',
    'READ OUT :1',
    'GIVE UP',
  ]);

  for (final backend in [ioiDart(), ioiLlvm()]) {
    test('${backend.name}: a user adapter, and AMNESIA through it', () async {
      final dir = Directory('${temp.path}/${backend.name}')..createSync();
      final exe = await build(backend, dir, source);
      final run = await Process.run(
        exe,
        const [],
        workingDirectory: dir.path,
        environment: {
          'DATABASE_URL': 'loud:./notes.db',
          'IOI_ADAPTER_LOUD': library,
        },
      );
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect(
        run.stdout,
        'Status: 200 OK\nContent-Type: text/html; charset=utf-8\n\nremember me\n \nI\n',
      );
      // A DLL's stderr is in text mode on Windows, so its lines end in \r\n.
      expect(
        (run.stderr as String)
            .split(RegExp(r'\r?\n'))
            .where((l) => l.isNotEmpty),
        [
          'loud: connect ./notes.db',
          'loud: CREATE TABLE notes (body TEXT) (0 parameters)',
          'loud: INSERT INTO "notes" ("body") VALUES (?) (1 parameters)',
          'loud: SELECT "body" FROM "notes" WHERE "body" = ? (1 parameters)',
          'loud: DROP TABLE "notes" (0 parameters)',
        ],
      );
    });
  }

  for (final backend in [ioiDart(), ioiLlvm()]) {
    final amnesia = program(['COME FROM (16000)', 'AMNESIA', 'GIVE UP']);

    Future<ProcessResult> run(
      String name,
      Map<String, String> environment,
    ) async {
      final dir = Directory('${temp.path}/${backend.name}-$name')..createSync();
      final exe = await build(backend, dir, amnesia);
      return Process.run(
        exe,
        const [],
        workingDirectory: dir.path,
        environment: environment,
      );
    }

    test('${backend.name}: a file that isn\'t a database is E825', () async {
      final dir = Directory('${temp.path}/${backend.name}-text')..createSync();
      File('${dir.path}/notes.txt').writeAsStringSync('not a database\n' * 100);
      final exe = await build(backend, dir, amnesia);
      final result = await Process.run(
        exe,
        const [],
        workingDirectory: dir.path,
        environment: {'DATABASE_URL': 'sqlite:./notes.txt'},
      );
      expect(result.stderr, contains('ICL825I'));
      expect(result.stderr, contains('ActiveCassette: file is not a database'));
    });

    test(
      '${backend.name}: an adapter whose entry gives NULL is E825',
      () async {
        final result = await run('null', {
          'DATABASE_URL': 'null:x',
          'IOI_ADAPTER_NULL': nullLibrary,
        });
        expect(result.stderr, contains('ICL825I'));
        expect(result.stderr, contains('the adapter is not version 1'));
      },
    );
  }
}
