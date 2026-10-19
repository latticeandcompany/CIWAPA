// The hooks a language built on CIWAPA's uses: dialect tokens, parser overrides, host calls,
// entries and errors of its own.
import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:test/test.dart';

/// A toy dialect: `SHOUT "text"` is a host call to service 7 carrying the text's length, and a
/// `LOUDLY` after a GIVE UP makes it a host call to service 8.
final toyDialect = LexerDialect(
  words: const ['SHOUT', 'LOUDLY'],
  scan: (text, offset, before) {
    if (text[offset] != 0x22 || before.isEmpty || before.last.tag != 'SHOUT') {
      return null;
    }
    final end = text.indexOf(0x22, offset + 1);
    return Token(
      TokenKind.dialect,
      offset,
      end + 1,
      tag: 'string',
      text: String.fromCharCodes(text, offset + 1, end),
    );
  },
);

class ToyParser extends Parser {
  ToyParser(super.source, {super.leadingComment, super.bareGiveUp})
    : super(wide: true, extensions: true, dialect: toyDialect);

  @override
  Body body() {
    if (current.kind == TokenKind.dialect && current.tag == 'SHOUT') {
      take();
      if (current.tag != 'string') reject();
      final text = take().text!;
      return HostCall(7, values: [Constant(text.length)]);
    }
    return super.body();
  }

  @override
  Body extendBody(Body body) {
    if (body is GiveUp && current.tag == 'LOUDLY') {
      take();
      return const HostCall(8);
    }
    return body;
  }
}

List<Statement> parse(String text, {bool tolerant = false}) => ToyParser(
  Source('t.xc', text),
  leadingComment: tolerant,
  bareGiveUp: tolerant,
).parse();

void main() {
  test('a dialect word and a scanned token become a host call', () {
    final s = parse('DO SHOUT "DO NOT SPLIT"\nPLEASE GIVE UP\n');
    expect(s, hasLength(2));
    expect((s.first.body as HostCall).service, 7);
    expect(((s.first.body as HostCall).values.single as Constant).value, 12);
  });

  test('extendBody can take tokens after a body', () {
    final s = parse('DO GIVE UP LOUDLY\n');
    expect((s.single.body as HostCall).service, 8);
  });

  test('a body the dialect rejects is undecodable as usual', () {
    final s = parse('DO SHOUT .1\nPLEASE GIVE UP\n');
    expect(s.first.body, isA<Undecodable>());
  });

  test('leadingComment drops the text before the first statement', () {
    expect(parse('NOTE hi\nDO GIVE UP\n'), hasLength(2));
    expect(parse('NOTE hi\nDO GIVE UP\n', tolerant: true), hasLength(1));
    // Labels with no identifier after them are part of it.
    expect(parse('NOTE see (1)\nDO GIVE UP\n', tolerant: true), hasLength(1));
    expect(parse('(1) GIVE UP\n', tolerant: true), isEmpty);
  });

  test('a WHILE keeps the statement\'s data', () {
    final program = analyze(
      Source('t.xc', 'DO .1 <- #1 WHILE .2 <- #2\nPLEASE GIVE UP\n'),
      parser: (source, {required wide, required extensions}) =>
          _Tagging(source),
    );
    final a = program.statements.firstWhere(
      (s) => s.body is Calculate && '${(s.body as Calculate).target}' == '.1',
    );
    expect(a.data, 'tagged');
  });

  test('bareGiveUp makes a GIVE UP with no identifier a statement', () {
    final strict = parse('DO .1 <- #1\nGIVE UP\n');
    expect(strict.single.body, isA<Undecodable>());
    final tolerant = parse('DO .1 <- #1\nGIVE UP\n', tolerant: true);
    expect(tolerant.last.body, isA<GiveUp>());
    expect(tolerant.last.polite, isFalse);
  });

  test('parseExpression reads a whole fragment, and nothing else', () {
    expect(ToyParser(Source('f', r'.1$#2')).parseExpression(), isA<Binary>());
    expect(ToyParser(Source('f', '.1 .2')).parseExpression(), isNull);
    expect(ToyParser(Source('f', r'.1$.2~.3')).parseExpression(), isNull);
  });

  test('analyze takes a parser and library blocks of the language\'s own', () {
    final program = analyze(
      Source('t.xc', 'DO SHOUT "HI"\nDO (20000) NEXT\nPLEASE GIVE UP\n'),
      parser: (source, {required wide, required extensions}) =>
          ToyParser(source),
      libraries: const [
        LibraryBlock('toy.xc', 20000, 20999, '(20000) DO RESUME #1\n'),
      ],
    );
    expect(program.userStatements, 3);
    expect(program.statements.last.label, 20000);
  });

  test('a host call lowers to a PETITION with values, and lower carries the '
      'language\'s entries, services, errors and extension', () {
    final program = analyze(
      Source('t.xc', 'DO SHOUT "HI"\nDO PETITION #20001\nPLEASE GIVE UP\n'),
      parser: (source, {required wide, required extensions}) =>
          ToyParser(source),
    );
    const error = IclError(901, 'TOY ERROR.', 'TOY JOKE.');
    final ir = lower(
      program,
      options: const IrOptions(randomBug: false),
      entries: const [3],
      services: const {
        20001: (scalars: ['.1'], arrays: [',1']),
      },
      host: true,
      errors: const [error],
      extension: 'payload',
    );
    final shout = ir.at(1).op as IrPetition;
    expect(shout.service, 7);
    expect((shout.values.single as IrConst).value, 2);
    expect(shout.host, isTrue);
    final petition = ir.at(2).op as IrPetition;
    expect(petition.scalars.single.ref, const VarRef(VarKind.spot, 1));
    expect(ir.at(2).faults, isEmpty);
    expect(ir.entries, [3]);
    expect(ir.host, isTrue);
    expect(ir.errors, [error]);
    expect(ir.extension, 'payload');
    expect(reachable(ir), containsAll([1, 2, 3]));
    expect(CompileError.of(error, 2).toString(), error.format(2));
  });
}

/// Tags every statement, to see what keeps its data.
class _Tagging extends Parser {
  _Tagging(super.source) : super(wide: true, extensions: true);

  @override
  List<Statement> parse() => [
    for (final s in super.parse()) s..data = 'tagged',
  ];
}
