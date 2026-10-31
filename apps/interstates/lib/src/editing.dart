import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/ciwapa_lsp.dart';

import 'errors.dart';
import 'frontend.dart';
import 'library_docs.g.dart';
import 'routes.dart';
import 'syntax.dart';
import 'templates.dart';

/// What `ioi-* lsp` adds to CIWAPA's language server for `.ioi` files: the words for Interstates'
/// errors and library, in the server's voice (R4).
class InterstatesEditing extends LanguageExtension {
  const InterstatesEditing();

  @override
  Map<int, ErrorHelp> get errorHelp => interstatesErrorHelp;

  @override
  Map<int, RoutineDoc> routinesFor(String path) =>
      interstatesBase(path) == null ? const {} : _routines;

  @override
  String? labelHelp(String path, int label) =>
      label == 16000 && interstatesBase(path) != null ? _entryHelp : null;

  @override
  List<LibraryBlock> get libraries => interstatesBlocks;

  @override
  List<String> keywordsFor(String path) => interstatesBase(path) == null
      ? const []
      : const ['INTO DATABASE', 'FORGET DATABASE', 'AMNESIA'];

  /// (16000) is where requests come in, and no statement has it: its definitions are the routes.
  @override
  List<Span>? definitionsOf(String path, int label, SyntaxModel model) {
    if (label != 16000 || interstatesBase(path) == null) return null;
    return [
      for (final s in model.statements)
        if (s.statement.data is RouteDecl) s.span,
    ];
  }

  /// The templates a program renders, each checked for every `READ OUT … WITH TEMPLATE` that
  /// names it (R10): E820, E821 and E997 where they are, E443 for a restricted route whose page
  /// doesn't link it, and a hover for each argument grumpy.
  @override
  List<Companion> companionsOf(
    String path,
    Program program,
    String? Function(String path) textOf,
  ) {
    if (interstatesBase(path) == null) return const [];
    final source = program.source;
    final user = program.statements.take(program.userStatements).toList();
    final file = File(path).uri.pathSegments.last;
    return [
      for (final (i, s) in user.indexed)
        if (s.data case TemplateUse(:final count, path: final name)
            when identical(s.source, source))
          _template(
            program,
            user,
            s,
            i + 1,
            count,
            templatePath(source, name),
            name,
            'the READ OUT #$count WITH TEMPLATE on line ${source.lineOf(s.start) + 1} of $file',
            textOf,
          ),
    ];
  }

  Companion _template(
    Program program,
    List<Statement> user,
    Statement statement,
    int ordinal,
    int count,
    String full,
    String name,
    String where,
    String? Function(String path) textOf,
  ) {
    final reference =
        program.tokens
            .where(
              (t) =>
                  t.kind == TokenKind.dialect &&
                  t.tag == 'string' &&
                  t.start >= statement.start &&
                  t.end <= statement.end,
            )
            .map((t) => Span(t.start, t.end))
            .lastOrNull ??
        Span(statement.start, statement.end);
    final text = textOf(full) ?? _read(full);
    if (text == null) return Companion(full, reference);
    final diagnostics = <CompanionDiagnostic>[];
    final scan = scanTemplate(text, name, count, (problem) {
      diagnostics.add((
        error: CompileError.of(
          problem.code == 997
              ? IclError.of(997)
              : interstatesError(problem.code),
          ordinal,
        ),
        span: Span(problem.start, problem.end),
        note: 'For $where.',
      ));
    });
    final firstLine = Span(0, Source(full, text).line(0).runes.length);
    final links = templateLinks(text);
    for (final route in user) {
      if (route.data case RouteDecl(:final label, pattern: final pattern?)
          when label == statement.label && label != 16000) {
        final List<Segment> segments;
        try {
          segments = routePattern(pattern, ordinal);
        } on CompileError {
          continue;
        }
        if (links.any((link) => linkMatches(link, segments))) continue;
        diagnostics.add((
          error: CompileError.of(interstatesError(443), ordinal),
          span: firstLine,
          note:
              'Nothing here links to "$pattern", which line '
              '${program.source.lineOf(route.start) + 1} restricts to this page. ($where)',
        ));
      }
    }
    return Companion(
      full,
      reference,
      text: text,
      diagnostics: diagnostics,
      hovers: [
        for (final a in scan.arguments)
          (
            span: Span(a.start, a.end),
            markdown:
                '`,${a.m}` is `;49221 SUB #${145 - a.m}`: argument ${145 - a.m} of $where.',
          ),
      ],
    );
  }

  /// In `.ioi` files, which name a template gives each `;49221 SUB #k`, and the names a
  /// `READ OUT #n WITH TEMPLATE` passes (R8).
  @override
  List<ExtensionHint> inlayHintsFor(String path, SyntaxModel model) {
    if (interstatesBase(path) == null) return const [];
    return [
      for (final s in model.statements) ...[
        if (s.statement.data case TemplateUse(:final count) when count > 0)
          if (s.tokens.lastOrNull case final last?)
            (
              offset: last.end,
              label: count == 1 ? ',144' : ',144 to ,${145 - count}',
              tooltip:
                  'The template names its arguments ,144 (;49221 SUB #1) down to '
                  ',${145 - count} (;49221 SUB #$count).',
            ),
        for (var i = 0; i + 4 < s.tokens.length; i++)
          if (_argumentIndex(s.tokens, i) case final k?)
            (
              offset: s.tokens[i + 4].end,
              label: ',${145 - k}',
              tooltip: 'Templates name ;49221 SUB #$k as ,${145 - k}.',
            ),
      ],
    ];
  }
}

/// k, when [tokens] from [i] are `;49221 SUB #k` with k from 1 to 144.
int? _argumentIndex(List<Token> tokens, int i) {
  final [sigil, array, sub, mesh, number] = tokens.sublist(i, i + 5);
  if (sigil.kind != TokenKind.hybrid ||
      array.kind != TokenKind.number ||
      array.value != 49221 ||
      sub.kind != TokenKind.sub ||
      mesh.kind != TokenKind.mesh ||
      number.kind != TokenKind.number ||
      number.value < 1 ||
      number.value > 144) {
    return null;
  }
  return number.value;
}

String? _read(String path) {
  try {
    return utf8.decode(File(path).readAsBytesSync(), allowMalformed: true);
  } on FileSystemException {
    return null;
  }
}

const _entryHelp =
    '**(16000)**: where every request comes in. No statement has this label, and none may: '
    '`COME FROM (16000) WITH ROUTE "/path"` makes a route, and a bare `COME FROM (16000)` catches '
    'every request no route matches. Go to definition lists the routes.';

final _routines = {
  for (final MapEntry(key: label, value: doc) in parseRoutineTables(
    libraryTables['Interstates library']!,
    'Interstates library',
  ).entries)
    label: RoutineDoc(
      label,
      label >= 16200 ? 'ActiveCassette library' : 'Interstates library',
      doc.fields,
    ),
};

/// The help for every Interstates error, by code. A test keeps it complete.
const interstatesErrorHelp = <int, ErrorHelp>{
  403: ErrorHelp(
    'A restricted route was requested from somewhere other than a page that links to it. A '
        '`COME FROM (L) WITH ROUTE` is only reachable from a page whose route can reach line L.',
    'Follow the link from its page, or drop the restriction.',
  ),
  440: ErrorHelp(
    'No route matches the requested path, and there is no bare `COME FROM (16000)` to catch it. '
        'gross answers 404.',
    'Add a route for the path, or a bare `COME FROM (16000)` for everything else.',
  ),
  441: ErrorHelp(
    'Two routes are equally specific: their patterns have the same shape, so no request could '
        'choose between them.',
    'Make one more specific, or remove one.',
  ),
  442: ErrorHelp(
    'A route\'s pattern isn\'t a path. It must start with `/`, may not hold `?` or `#`, and every '
        '`:` segment must name its parameter.',
    'Write it like `/blog/post/:id`.',
  ),
  443: ErrorHelp(
    'A restricted route `COME FROM (L) WITH ROUTE "/x"` needs line L to be a `READ OUT … WITH '
        'TEMPLATE` whose template links a path matching `/x`, and it isn\'t. Or a template links '
        'nowhere it should.',
    'Point the COME FROM at the page that links to it, or add the link to that page\'s template.',
  ),
  504: ErrorHelp(
    'gross gave up waiting: the program ran longer than `--timeout` (30 seconds by default).',
    'Find the loop that never reaches GIVE UP, or raise `--timeout`.',
  ),
  820: ErrorHelp(
    'The template doesn\'t parse: an unclosed `{{`, an expression the compiler can\'t read, or a '
        'grumpy where it can\'t go. Templates compile with the program, so the build fails here.',
    'Close every `{{` with `}}` and keep to the template expressions Interstates knows.',
  ),
  821: ErrorHelp(
    'The `READ OUT #n WITH TEMPLATE` gives a different number of arguments from the template\'s: '
        'it takes as many as the highest `,(145-k)` it names.',
    'Make `#n` the number of arguments the template uses.',
  ),
  822: ErrorHelp(
    '`;4400` and `;49221` hold whole strings, which only the Interstates statements can move. '
        'Anything else that touches them is E822 when it runs.',
    'Move route parameters and template arguments with the Interstates statements only.',
  ),
  823: ErrorHelp(
    'The status, a header or a cookie was set after the body started. They go out just before the '
        'body\'s first byte.',
    'Set the status, headers and cookies before writing any of the body.',
  ),
  824: ErrorHelp(
    'ActiveCassette was asked for a table or column the database doesn\'t have.',
    'Create the table first, and number columns from #1.',
  ),
  825: ErrorHelp(
    'ActiveCassette couldn\'t open the database gross was given.',
    'Check gross\'s `--database sqlite:<file>`.',
  ),
  826: ErrorHelp(
    'The database refused the statement, and SQLite didn\'t say why it would accept it.',
    'Check the values against the table\'s columns.',
  ),
  827: ErrorHelp(
    'An `INTO DATABASE` names a different number of columns from the values it gives.',
    'Give one value for each column.',
  ),
  828: ErrorHelp(
    'A response header or cookie has a name that isn\'t a token, or a value with a line break or '
        'a NUL in it.',
    'Use plain names, and values on one line.',
  ),
  829: ErrorHelp(
    'The program didn\'t answer in CGI: gross couldn\'t read its output as a response.',
    'Let the Interstates statements write the response, and don\'t print before them.',
  ),
};
