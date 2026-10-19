import 'dart:convert';
import 'dart:io';

import 'package:ciwapa_core/ciwapa_core.dart';

import 'errors.dart';
import 'syntax.dart';

/// One segment of a route's pattern: fixed text, or a `:param` ([text] null).
typedef Segment = ({String? text});

/// A route: where it is, its label, and its pattern's segments (null for the catch-all).
class Route {
  Route(this.ordinal, this.label, this.segments);

  /// The ordinal of its `WITH ROUTE` COME FROM, which is where the program starts for it.
  final int ordinal;
  final int label;
  final List<Segment>? segments;

  bool get catchAll => segments == null;

  /// Restricted routes are reachable only from a page rendered at [label] (R3, Q113).
  bool get restricted => label != 16000;

  /// For a restricted route, the routes (by their index in the table, the catch-all last) whose
  /// requests can render the page at [label].
  List<int> allowed = const [];
}

/// The routes of a program, most specific first and the catch-all, if any, last (R3, Q114).
class RouteTable {
  RouteTable(this.routes);

  final List<Route> routes;

  /// Every route's entry, the ordinals the host may start at.
  List<int> get entries => [for (final r in routes) r.ordinal];
}

/// The program's routes, checked: E442 for a pattern that isn't a path, E441 for two routes
/// equally specific, E444 for a label that doesn't exist, and E443 unless a restricted route's
/// label is a `READ OUT … WITH TEMPLATE` whose template links it.
RouteTable routeTable(Program program) {
  final routes = <Route>[];
  for (final (i, s)
      in program.statements.take(program.userStatements).indexed) {
    if (s.data case RouteDecl(:final label, :final pattern)) {
      routes.add(
        Route(i + 1, label, pattern == null ? null : _pattern(pattern, i + 1)),
      );
    }
  }
  final ordered = [...routes]..sort(_bySpecificity);
  for (var i = 1; i < ordered.length; i++) {
    if (_bySpecificity(ordered[i - 1], ordered[i]) == 0) {
      final later = ordered[i - 1].ordinal > ordered[i].ordinal
          ? ordered[i - 1]
          : ordered[i];
      throw interstatesCompileError(441, later.ordinal);
    }
  }
  final labels = <int, int>{};
  for (final (i, s) in program.statements.indexed) {
    if (s.label case final label?) labels.putIfAbsent(label, () => i + 1);
  }
  for (final r in routes.where((r) => r.restricted)) {
    final target = labels[r.label];
    if (target == null) throw CompileError(444, r.ordinal);
    final page = program.statements[target - 1];
    final use = page.data;
    if (use is! TemplateUse || r.catchAll) {
      throw interstatesCompileError(443, r.ordinal);
    }
    final links = templateLinks(
      _templateText(program.source, use.path, target),
    );
    if (!links.any((link) => linkMatches(link, r.segments!))) {
      throw interstatesCompileError(443, r.ordinal);
    }
  }
  return RouteTable(ordered);
}

/// A template's text: E777 if it can't be read, as for a source file that can't be.
String _templateText(Source source, String path, int statement) {
  final file = File(templatePath(source, path));
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    throw CompileError(777, statement);
  }
}

/// A template's path, relative to the source file's folder.
String templatePath(Source source, String path) {
  if (File(path).isAbsolute) return path;
  final sourceFile = File(source.path);
  return '${sourceFile.parent.path}${Platform.pathSeparator}$path';
}

/// A route pattern's segments: it starts with `/`, `/` separates them, a `:name` segment is a
/// parameter, and `?`, `#` and `%` don't belong (E442): fixed text is compared with the request's
/// decoded segments, so a percent-encoded pattern could never match.
List<Segment> _pattern(String pattern, int statement) {
  if (!pattern.startsWith('/') || pattern.contains(RegExp('[?#%]'))) {
    throw interstatesCompileError(442, statement);
  }
  return [
    for (final s in pattern.substring(1).split('/'))
      if (s.startsWith(':'))
        s.length == 1
            ? throw interstatesCompileError(442, statement)
            : (text: null)
      else
        (text: s),
  ];
}

/// Fixed segments beat `:param` ones, compared left to right; between routes that can't both
/// match a path, any order will do, so it goes by length and text. 0 only for the same shape.
int _bySpecificity(Route a, Route b) {
  if (a.catchAll || b.catchAll) {
    return a.catchAll == b.catchAll ? 0 : (a.catchAll ? 1 : -1);
  }
  final x = a.segments!, y = b.segments!;
  if (x.length != y.length) return x.length - y.length;
  for (var i = 0; i < x.length; i++) {
    final p = x[i].text, q = y[i].text;
    if (p == null && q == null) continue;
    if (p == null) return 1;
    if (q == null) return -1;
    final c = p.compareTo(q);
    if (c != 0) return c;
  }
  return 0;
}

/// A link a template makes: its path's segments, each fixed text or, where a `{{ }}` is in it,
/// dynamic (null).
typedef Link = List<String?>;

/// The links in [template]: inside each tag (comments aside), the values of `href`, `action`,
/// `src` and `formaction` attributes that start with a single `/`, up to any `?` or `#` outside a
/// grumpy, with character references and percent-encoding decoded in each fixed segment.
List<Link> templateLinks(String template) {
  final links = <Link>[];
  final uncommented = template.replaceAll(RegExp(r'<!--[\s\S]*?(-->|$)'), '');
  final attribute = RegExp(
    r"""\s(?:href|action|src|formaction)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))""",
    caseSensitive: false,
  );
  for (final tag in RegExp(r'<[A-Za-z][^<>]*>').allMatches(uncommented)) {
    for (final m in attribute.allMatches(tag[0]!)) {
      var value = m.group(1) ?? m.group(2) ?? m.group(3)!;
      if (!value.startsWith('/') || value.startsWith('//')) continue;
      // A grumpy can hold a ?, so the query starts at the first ? or # outside one.
      final cut = RegExp(r'\{\{.*?\}\}|[?#]')
          .allMatches(value)
          .where((c) => !c[0]!.startsWith('{{'));
      if (cut.isNotEmpty) value = value.substring(0, cut.first.start);
      links.add([
        for (final s in value.substring(1).split('/'))
          s.contains('{{') ? null : _percentDecode(_unescape(s)),
      ]);
    }
  }
  return links;
}

/// HTML's character references for the characters a link might hold.
String _unescape(String s) => s.replaceAllMapped(
  RegExp(r'&(?:(amp|lt|gt|quot|apos)|#([0-9]+)|#[xX]([0-9A-Fa-f]+));'),
  (m) => switch (m[1]) {
    'amp' => '&',
    'lt' => '<',
    'gt' => '>',
    'quot' => '"',
    'apos' => "'",
    _ => String.fromCharCode(
      m[2] != null ? int.parse(m[2]!) : int.parse(m[3]!, radix: 16),
    ),
  },
);

/// `%XX` decoded, the bytes read as UTF-8.
String _percentDecode(String s) {
  final bytes = <int>[];
  final units = utf8.encode(s);
  for (var i = 0; i < units.length; i++) {
    final hex = i + 2 < units.length
        ? String.fromCharCodes(units, i + 1, i + 3)
        : '';
    if (units[i] == 0x25 && RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(hex)) {
      bytes.add(int.parse(hex, radix: 16));
      i += 2;
    } else {
      bytes.add(units[i]);
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// Whether [link] leads to a route of [pattern]: as many segments, each fixed one the same or in
/// a parameter's place, and each dynamic one in a parameter's place.
bool linkMatches(Link link, List<Segment> pattern) {
  if (link.length != pattern.length) return false;
  for (var i = 0; i < link.length; i++) {
    final want = pattern[i].text;
    if (want != null && link[i] != want) return false;
  }
  return true;
}

/// Fills in each restricted route's [Route.allowed]: the routes whose entry can reach its page,
/// over every way control can go (R3's reachability pass). Anything the analysis can't follow
/// (computed or gerund COME FROMs, CREATE) lets every route reach everything.
void allowReferers(RouteTable table, IrProgram program) {
  final labels = <int, int>{};
  for (final s in program.statements) {
    if (s.label case final label?) labels.putIfAbsent(label, () => s.ordinal);
  }
  final unknowable = program.statements.any(
    (s) =>
        s.op is IrComputedComeFrom ||
        s.op is IrGerundComeFrom ||
        s.op is IrCreate ||
        s.op is IrUnknown ||
        program.signatures.isNotEmpty,
  );
  final reach = [
    for (final r in table.routes)
      unknowable ? null : _reachable(program, r.ordinal),
  ];
  for (final r in table.routes.where((r) => r.restricted)) {
    final page = labels[r.label]!;
    r.allowed = [
      for (final (i, set) in reach.indexed)
        if (set == null || set.contains(page)) i,
    ];
  }
}

/// Every statement control can reach from [entry]: running on, NEXTs and the return points a
/// RESUME can go back to, COME FROM traps, and TRY AGAIN's restart.
Set<int> _reachable(IrProgram program, int entry) {
  final returns = [
    for (final s in program.statements)
      if (s.op is IrNext) s.ordinal + 1,
  ];
  final seen = <int>{};
  final work = [entry];
  while (work.isNotEmpty) {
    final o = work.removeLast();
    if (o < 1 || o > program.statements.length || !seen.add(o)) continue;
    final s = program.at(o);
    final skippable =
        s.abstainable ||
        (s.percent != null && s.percent! < 100) ||
        s.maybe ||
        s.onceAgain != OnceAgain.none;
    switch (s.op) {
      case IrGiveUp():
        if (skippable) work.add(o + 1);
      case IrResume():
        work.addAll(returns);
        if (skippable) work.add(o + 1);
      case IrNext(:final target):
        work
          ..add(target)
          ..add(o + 1);
      case IrTryAgain():
        work
          ..add(1)
          ..add(o + 1);
      default:
        work.add(o + 1);
    }
    work.addAll(s.comeFroms);
  }
  return seen;
}
