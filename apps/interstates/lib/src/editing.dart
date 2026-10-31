import 'package:ciwapa_core/ciwapa_core.dart';
import 'package:ciwapa_lsp/ciwapa_lsp.dart';

import 'frontend.dart';
import 'library_docs.g.dart';
import 'syntax.dart';

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
  List<LibraryBlock> librariesFor(String path) =>
      interstatesBase(path) == null ? const [] : interstatesBlocks;

  /// (16000) is where requests come in, and no statement has it: its definitions are the routes.
  @override
  List<Span>? definitionsOf(String path, int label, SyntaxModel model) {
    if (label != 16000 || interstatesBase(path) == null) return null;
    return [
      for (final s in model.statements)
        if (s.statement.data is RouteDecl) s.span,
    ];
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
