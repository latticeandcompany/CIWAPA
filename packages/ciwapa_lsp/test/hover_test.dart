import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    await client.initialize();
  });

  /// The hover's markdown at [line]:[character] of the document [uri], or null.
  Future<String?> hoverAt(String uri, int line, int character) async {
    final result = await client.request<Map<String, Object?>?>(
      'textDocument/hover',
      {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character},
      },
    );
    return (result?['contents'] as Map?)?['value'] as String?;
  }

  group('R4: error hovers', () {
    test(
      'show the ICL line and the joke as printed, the meaning and the fix',
      () async {
        await client.open(
          'file:///w/a.i',
          '(1) DO .1 <- #1\n(1) PLEASE DO .2 <- #2\nDO GIVE UP\n',
        );
        final text = await hoverAt('file:///w/a.i', 1, 1);
        expect(
          text,
          startsWith(
            '```text\n'
            'ICL182I A LINE LABEL HAS BEEN MULTIPLY DEFINED.\n'
            '        TWO STATEMENTS ANSWERED TO THE SAME NAME. BOTH ARE EMBARRASSED.\n'
            '```\n'
            'Two or more statements share a label',
          ),
        );
        expect(
          text,
          contains('**What to do:** Give each statement its own label.'),
        );
      },
    );

    test('work for statement-local errors, and past non-ASCII text', () async {
      await client.open(
        'file:///w/a.i',
        'DO NOTE ¢🎉\nPLEASE .1 <- #70000\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.i', 1, 13),
        contains('ICL017I AN EXPRESSION CONTAINS'),
      );
    });
  });

  group('R4: undecodable statements', () {
    const text =
        'DO NOTE THIS IS A COMMENT\nPLEASE NOTE THIS ONE NEVER RUNS\nDO .1 <- #1\nDO GIVE UP\n';

    test('get an Information hint, never a warning or an error', () async {
      final diagnostics = await client.open('file:///w/a.i', text);
      expect(
        [for (final d in diagnostics) (d['code'], d['severity'])],
        [('E000', 3), ('E000', 3)],
      );
      expect(diagnostics[1]['message'], contains('abstained'));
    });

    test('hover with the ICL000I line E000 would print', () async {
      await client.open('file:///w/a.i', text);
      expect(
        await hoverAt('file:///w/a.i', 0, 10),
        startsWith(
          '```text\nICL000I DO NOTE THIS IS A COMMENT\n        THAT WAS NOT A STATEMENT.',
        ),
      );
    });
  });

  group('R4: what things are', () {
    test('operators, sigils, identifiers and gerunds', () async {
      const text =
          'PLEASE .1 <- #1\$#2\n'
          'DO :2 <- ,3 SUB #1 ~ ;4 SUB #2\n'
          'DO .5 <- .&1\n'
          'DO .6 <- .V1\n'
          'DO .7 <- .?1\n'
          'PLEASE ABSTAIN FROM CALCULATING\n'
          'DO NOT GIVE UP\n'
          'DO %50 GIVE UP\n';
      await client.open('file:///w/a.i', text);
      final expected = {
        (0, 15): '**Mingle**',
        (1, 19): '**Select**',
        (2, 10): '**AND**',
        (3, 10): '**OR**',
        (4, 10): '**XOR**',
        (0, 8): '**Spot**',
        (1, 3): '**Two-spot**',
        (1, 9): '**Tail**',
        (1, 21): '**Hybrid**',
        (0, 13): '**Mesh**',
        (0, 2): '**Statement identifier.**',
        (5, 25): '**CALCULATING**',
        (6, 4): '**NOT**',
        (7, 4): '**%n**',
        (1, 7): '**Gets**',
      };
      for (final MapEntry(key: (line, character), value: start)
          in expected.entries) {
        expect(
          await hoverAt('file:///w/a.i', line, character),
          startsWith(start),
          reason: start,
        );
      }
    });

    test('TriINTERCAL\'s operators and EXTRACAL\'s sigils', () async {
      await client.open(
        'file:///w/a.3i',
        'PLEASE .1 <- .^2\nDO .3 <- .@2\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.3i', 0, 14),
        startsWith('**Sharkfin**'),
      );
      expect(
        await hoverAt('file:///w/a.3i', 1, 10),
        startsWith('**Whirlpool**'),
      );
      await client.open(
        'file:///w/a.xc',
        'PLEASE ::1 <- ####5\nDO ;;2 <- ##3\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.xc', 0, 8),
        startsWith('**Double cateye**'),
      );
      expect(
        await hoverAt('file:///w/a.xc', 0, 15),
        startsWith('**Stockade**'),
      );
      expect(
        await hoverAt('file:///w/a.xc', 1, 4),
        startsWith('**Double hybrid**'),
      );
      expect(await hoverAt('file:///w/a.xc', 1, 11), startsWith('**Fence**'));
    });
  });

  group('R4: library labels say what goes in and what comes out', () {
    test('the system library\'s, in every binary file', () async {
      await client.open('file:///w/a.i', 'PLEASE DO (1000) NEXT\nDO GIVE UP\n');
      final text = await hoverAt('file:///w/a.i', 0, 12);
      expect(text, startsWith('**(1000)**, in the system library'));
      expect(text, contains('- **In:** .1 .2'));
      expect(text, contains('- **Out:** .3 = .1 + .2'));
    });

    test('EXTRACAL\'s, in EXTRACAL files only', () async {
      const text = 'PLEASE DO (2000) NEXT\nDO GIVE UP\n';
      await client.open('file:///w/a.xc', text);
      expect(
        await hoverAt('file:///w/a.xc', 0, 12),
        allOf(
          startsWith('**(2000)**, in the EXTRACAL library: I/O'),
          contains('- **Out:** .2 = the next byte; .3'),
        ),
      );
      await client.open('file:///w/a.i', text);
      expect(
        await hoverAt('file:///w/a.i', 0, 12),
        contains('no statement has this label'),
      );
    });

    test(
      'a label the file defines itself is the file\'s, not the library\'s',
      () async {
        await client.open(
          'file:///w/a.i',
          'PLEASE DO (1000) NEXT\n(1000) DO GIVE UP\n',
        );
        expect(
          await hoverAt('file:///w/a.i', 0, 12),
          '**(1000)**: statement 2, on line 2.',
        );
      },
    );

    test('there is no library in bases 3 to 7', () async {
      await client.open(
        'file:///w/a.3i',
        'PLEASE DO (1000) NEXT\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.3i', 0, 12),
        contains('no statement has this label'),
      );
    });

    test('a file with any label of a library\'s range doesn\'t get that library (T36)', () async {
      await client.open(
        'file:///w/a.i',
        '(1500) DO .1 <- #1\nPLEASE DO (1000) NEXT\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.i', 1, 12),
        allOf(contains('ICL129I'), isNot(contains('in the system library'))),
      );
    });
  });

  group('R4, R5: labels the model must not lose', () {
    test('a WHILE keeps its own label', () async {
      await client.open(
        'file:///w/a.xc',
        '(1000) DO .1 <- #1 WHILE .2 <- #2\nPLEASE DO (1000) NEXT\nDO GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.xc', 1, 12),
        allOf(startsWith('**(1000)**: statement 10, on line 1.')),
      );
    });

    test('CREATE (n) names a label', () async {
      await client.open(
        'file:///w/a.xc',
        '(100) DO .1 <- #1\nDO CREATE (100) FOO .1\nPLEASE GIVE UP\n',
      );
      expect(
        await hoverAt('file:///w/a.xc', 1, 12),
        '**(100)**: statement 1, on line 1.',
      );
    });
  });
}
