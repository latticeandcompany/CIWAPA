import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    await client.initialize();
  });

  Future<String> toggle(
    String text,
    (int, int) start, [
    (int, int)? end,
  ]) async {
    const uri = 'file:///w/a.i';
    await client.open(uri, text);
    Map<String, int> at((int, int) p) => {'line': p.$1, 'character': p.$2};
    final edits = await client.request<List<Object?>>(
      'intercal/toggleComment',
      {
        'textDocument': {'uri': uri},
        'range': {'start': at(start), 'end': at(end ?? start)},
      },
    );
    return applyEdits(text, edits.cast<Map<String, Object?>>());
  }

  group('R9: comment toggling', () {
    test('a statement becomes PLEASE NOTE, label kept', () async {
      expect(
        await toggle('(10) DO .1 <- #1\nPLEASE GIVE UP\n', (0, 8)),
        '(10) PLEASE NOTE .1 <- #1\nPLEASE GIVE UP\n',
      );
      expect(
        await toggle('DO GIVE UP\nPLEASE DO .1 <- #1\n', (1, 0)),
        'DO GIVE UP\nPLEASE NOTE .1 <- #1\n',
      );
    });

    test('a statement over several lines changes at its head', () async {
      expect(
        await toggle('DO .1 <-\n    #1\nPLEASE GIVE UP\n', (1, 5)),
        'PLEASE NOTE .1 <-\n    #1\nPLEASE GIVE UP\n',
      );
    });

    test('PLEASE NOTE and DO NOTE go back to DO', () async {
      expect(
        await toggle('(3) PLEASE NOTE .1 <- #1\nDO GIVE UP\n', (0, 0)),
        '(3) DO .1 <- #1\nDO GIVE UP\n',
      );
      expect(await toggle('DO NOTE GIVE UP\n', (0, 3)), 'DO GIVE UP\n');
    });

    test('a selection comments every statement it touches, unless all are comments', () async {
      expect(
        await toggle(
          'DO .1 <- #1\nPLEASE NOTE X\nDO GIVE UP\n',
          (0, 2),
          (2, 1),
        ),
        'PLEASE NOTE .1 <- #1\nPLEASE NOTE X\nPLEASE NOTE GIVE UP\n',
      );
      expect(
        await toggle('PLEASE NOTE A\nDO NOTE B\n', (0, 0), (1, 3)),
        'DO A\nDO B\n',
      );
    });

    test('the commented statement never runs, so it is no error', () async {
      const uri = 'file:///w/b.i';
      final diagnostics = await client.open(
        uri,
        '(1) PLEASE NOTE THIS IS NOT CODE\nDO GIVE UP\nDO .1 <- #1\n',
      );
      expect(diagnostics.where((d) => d['severity'] == 1), isEmpty);
    });

    test('a cursor at the end of a line toggles its statement', () async {
      expect(
        await toggle('DO .1 <- #1\nDO GIVE UP\n', (0, 11)),
        'PLEASE NOTE .1 <- #1\nDO GIVE UP\n',
      );
      expect(
        await toggle('DO .1 <- #1\r\nDO GIVE UP\r\n', (0, 11)),
        'PLEASE NOTE .1 <- #1\r\nDO GIVE UP\r\n',
      );
    });

    test(
      'a selection ending at the start of a line leaves that line alone',
      () async {
        expect(
          await toggle(
            'DO .1 <- #1\nDO .2 <- #2\nDO GIVE UP\n',
            (0, 0),
            (2, 0),
          ),
          'PLEASE NOTE .1 <- #1\nPLEASE NOTE .2 <- #2\nDO GIVE UP\n',
        );
      },
    );

    test("DON'T goes there and back", () async {
      final commented = await toggle("DON'T GIVE UP\nDO GIVE UP\n", (0, 0));
      expect(commented, "PLEASE NOTE N'T GIVE UP\nDO GIVE UP\n");
      expect(await toggle(commented, (0, 0)), "DO N'T GIVE UP\nDO GIVE UP\n");
    });
  });
}
