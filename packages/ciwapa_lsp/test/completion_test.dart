import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    await client.initialize();
  });

  /// The labels completion offers at the end of [text]'s last line.
  Future<List<Map<String, Object?>>> completeAtEnd(
    String uri,
    String text,
  ) async {
    await client.open(uri, text);
    final lines = text.split('\n');
    return (await client.request<List<Object?>>('textDocument/completion', {
      'textDocument': {'uri': uri},
      'position': {'line': lines.length - 1, 'character': lines.last.length},
    })).cast<Map<String, Object?>>();
  }

  List<Object?> labels(List<Map<String, Object?>> items) => [
    for (final i in items) i['label'],
  ];

  group('R8: completion', () {
    test('statement keywords after an identifier, by dialect', () async {
      final plain = labels(
        await completeAtEnd('file:///w/a.i', 'DO GIVE UP\nPLEASE DO '),
      );
      expect(plain, containsAll(['GIVE UP', 'COME FROM', 'ABSTAIN FROM']));
      expect(plain, isNot(contains('NEXT FROM')));
      final extracal = labels(
        await completeAtEnd('file:///w/a.xc', "DO GIVE UP\n(4) DON'T NE"),
      );
      expect(extracal, containsAll(['NEXT FROM', 'TRY AGAIN', 'GO BACK']));
      expect(
        labels(await completeAtEnd('file:///w/b.xc', 'PLEASE %50 ')),
        contains('GIVE UP'),
      );
    });

    test(
      'labels inside ( ), the file\'s and the libraries\', with docs',
      () async {
        final items = await completeAtEnd(
          'file:///w/a.xc',
          '(10) DO .1 <- #1\n(20) PLEASE GIVE UP\nDO (',
        );
        expect(labels(items).take(2), ['10', '20']);
        final routine = items.firstWhere((i) => i['label'] == '1000');
        expect(routine['detail'], 'system library');
        expect(
          (routine['documentation'] as Map)['value'],
          startsWith('**(1000)**, in the system library'),
        );
        expect(labels(items), contains('1020'));
        final extracal = items.where((i) => '${i['label']}'.startsWith('2'));
        expect(extracal, isNotEmpty);
        // An INTERCAL file doesn't get EXTRACAL's library.
        final plain = await completeAtEnd('file:///w/b.i', 'DO (1');
        expect(plain.where((i) => '${i['label']}'.startsWith('2')), isEmpty);
      },
    );

    test('gerunds after ABSTAIN FROM and REINSTATE', () async {
      final items = await completeAtEnd(
        'file:///w/a.i',
        'DO ABSTAIN FROM CALCULATING + NEX',
      );
      expect(labels(items), containsAll(['CALCULATING', 'NEXTING']));
      expect(labels(items), isNot(contains('NEXTING FROM')));
      expect(
        (items.first['documentation'] as Map)['value'],
        startsWith('**CALCULATING**: a gerund.'),
      );
      expect(
        labels(await completeAtEnd('file:///w/b.xc', 'PLEASE REINSTATE ')),
        contains('COMMENTING'),
      );
    });

    test('nothing in the middle of an expression', () async {
      expect(await completeAtEnd('file:///w/a.i', 'DO .1 <- #1'), isEmpty);
    });
  });
}
