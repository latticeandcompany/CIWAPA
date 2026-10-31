import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    await client.initialize();
  });

  /// Opens [text], applies the quick fix for [code], and returns the new text and its codes; null
  /// when there is no fix.
  Future<(String, List<Object?>)?> fix(
    String text,
    String code, {
    String uri = 'file:///w/a.i',
  }) async {
    final diagnostics = await client.open(uri, text);
    final diagnostic = diagnostics.firstWhere((d) => d['code'] == code);
    final actions = await client.request<List<Object?>>(
      'textDocument/codeAction',
      {
        'textDocument': {'uri': uri},
        'range': diagnostic['range'],
        'context': {
          'diagnostics': [diagnostic],
        },
      },
    );
    if (actions.isEmpty) return null;
    final action = actions.single as Map<String, Object?>;
    expect(action['kind'], 'quickfix');
    final edits = (((action['edit'] as Map)['changes'] as Map)[uri] as List)
        .cast<Map<String, Object?>>();
    final fixed = applyEdits(text, edits);
    return (fixed, codesOf(await client.change(uri, fixed, version: 2)));
  }

  List<int> politeLines(String text) => [
    for (final (i, line) in text.split('\n').indexed)
      if (line.startsWith('PLEASE')) i,
  ];

  group('R8: the politeness quick fixes', () {
    test('E079 adds just enough PLEASEs, spread through the file', () async {
      final text = [
        for (var i = 0; i < 10; i++) 'DO .1 <- #$i',
        "DON'T GIVE UP",
      ].join('\n');
      final (fixed, codes) = (await fix(text, 'E079'))!;
      expect(codes, isEmpty);
      expect(politeLines(fixed), [1, 5, 9]);
      expect(fixed, contains('PLEASE DO .1 <- #1\n'));
    });

    test('E099 takes just enough off, spread through the file', () async {
      final text = [
        for (var i = 0; i < 6; i++) 'PLEASE .1 <- #$i',
        "PLEASE DON'T GIVE UP",
      ].join('\n');
      final (fixed, codes) = (await fix(text, 'E099'))!;
      expect(codes, isEmpty);
      expect(politeLines(fixed), [1, 5]);
      expect(fixed, endsWith("DON'T GIVE UP"));
    });

    test('a file with no statement it may change gets no fix', () async {
      expect(
        await fix(
          'FAC GIVE UP\nFAC GIVE UP\nFAC GIVE UP\n',
          'E079',
          uri: 'file:///w/a.xc',
        ),
        isNull,
      );
      expect(
        await fix(
          'PLACET GIVE UP\nPLACET GIVE UP\nPLACET GIVE UP\n',
          'E099',
          uri: 'file:///w/b.xc',
        ),
        isNull,
      );
    });
  });
}
