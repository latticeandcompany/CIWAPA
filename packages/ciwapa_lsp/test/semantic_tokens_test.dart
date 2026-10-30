import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/test_client.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  late Map<String, Object?> legend;
  setUp(() async {
    client = TestClient(const CiwapaFrontend());
    final init = await client.initialize();
    legend =
        ((init['capabilities'] as Map)['semanticTokensProvider']
                as Map)['legend']
            as Map<String, Object?>;
  });

  Future<List<DecodedToken>> tokensOf(String uri, String text) async {
    await client.open(uri, text);
    final result = await client.request<Map<String, Object?>>(
      'textDocument/semanticTokens/full',
      {
        'textDocument': {'uri': uri},
      },
    );
    return decodeTokens(result, legend);
  }

  test('R5: INTERCAL gets every kind its words have', () async {
    const text =
        '(1) DO .1 <- #1\$#2\n'
        'PLEASE DO (1) NEXT\n'
        'DO ABSTAIN FROM CALCULATING\n'
        'DO NOTE A COMMENT\n'
        'PLEASE GIVE UP\n';
    final tokens = await tokensOf('file:///w/a.i', text);
    expect(coloredText(text, tokens), [
      ('(1)', 'function'),
      ('DO', 'modifier'),
      ('.1', 'variable'),
      ('<-', 'operator'),
      ('#1', 'number'),
      (r'$', 'operator'),
      ('#2', 'number'),
      ('PLEASE DO', 'modifier'),
      ('(1)', 'function'),
      ('NEXT', 'keyword'),
      ('DO', 'modifier'),
      ('ABSTAIN FROM', 'keyword'),
      ('CALCULATING', 'enumMember'),
      ('DO', 'modifier'),
      ('NOTE A COMMENT', 'comment'),
      ('PLEASE', 'modifier'),
      ('GIVE UP', 'keyword'),
    ]);
    expect(tokens.first.modifiers, {'declaration'});
    expect(tokens[2].modifiers, {'spot'});
    expect(tokens[8].modifiers, isEmpty);
  });

  test('R5: EXTRACAL\'s words are marked, and so are library labels', () async {
    const text =
        'PLEASE ::1 <- ####5\n'
        'DO (2000) NEXT\n'
        'DO NEXT FROM (2000)\n'
        'DO GIVE UP\n';
    final tokens = await tokensOf('file:///w/a.xc', text);
    final colored = coloredText(text, tokens);
    expect(
      colored,
      containsAll([
        ('::1', 'variable'),
        ('####5', 'number'),
        ('NEXT FROM', 'keyword'),
      ]),
    );
    expect(tokens[colored.indexOf(('::1', 'variable'))].modifiers, {
      'extension',
      'doubleCateye',
    });
    expect(tokens[colored.indexOf(('NEXT FROM', 'keyword'))].modifiers, {
      'extension',
    });
    expect(tokens[colored.indexOf(('(2000)', 'function'))].modifiers, {
      'defaultLibrary',
    });
  });

  test('R5: undecodable statements are comments, line by line, and so is garbage before the first '
      'statement', () async {
    const text =
        'garbage first\r\nDO THIS IS NOT\r\n  ANYTHING AT ALL\r\nPLEASE GIVE UP\r\n';
    final tokens = await tokensOf('file:///w/a.i', text);
    expect(coloredText(text, tokens), [
      ('garbage first', 'comment'),
      ('DO', 'modifier'),
      ('THIS IS NOT', 'comment'),
      ('  ANYTHING AT ALL', 'comment'),
      ('PLEASE', 'modifier'),
      ('GIVE UP', 'keyword'),
    ]);
  });

  test('R5: positions count UTF-16 units', () async {
    const text = 'DO NOTE ¢🎉\nPLEASE .1 <- #1¢#2\nDO GIVE UP\n';
    final tokens = await tokensOf('file:///w/a.i', text);
    expect(
      coloredText(text, tokens),
      containsAllInOrder([('NOTE ¢🎉', 'comment'), ('¢', 'operator')]),
    );
  });

  test('R5: the legend has every kind the plan names', () {
    expect(
      legend['tokenTypes'],
      containsAll([
        'comment',
        'keyword',
        'modifier',
        'enumMember',
        'function',
        'variable',
        'number',
        'operator',
        'string',
      ]),
    );
  });
}
