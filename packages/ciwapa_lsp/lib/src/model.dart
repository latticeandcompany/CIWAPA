import 'package:ciwapa_core/ciwapa_core.dart';

/// What a stretch of the file is, for highlighting and hovers (R5).
enum Role {
  comment,
  keyword,
  identifier,
  gerund,
  label,
  variable,
  constant,
  operator,
  string,
}

/// A classified stretch of the user's file: one token, or a sigil or mesh with its number, or the
/// undecodable part of a statement.
class Piece {
  const Piece(
    this.span,
    this.role, {
    this.token,
    this.extension = false,
    this.dialect = false,
    this.definition = false,
  });

  final Span span;
  final Role role;

  /// The token it starts with; null for a comment.
  final Token? token;

  /// A word only EXTRACAL has.
  final bool extension;

  /// A word that a language built on CIWAPA's adds.
  final bool dialect;

  /// A label on its own statement, rather than one a statement names.
  final bool definition;
}

/// The user's statements, once each, with their ordinals: a WHILE's added statements share the
/// WHILE's text, so the first statement with each text stands for it.
class FileStatement {
  const FileStatement(this.ordinal, this.statement, this.tokens);

  final int ordinal;
  final Statement statement;
  final List<Token> tokens;

  Span get span => Span(statement.start, statement.end);

  bool get undecodable => statement.body is Undecodable;
}

const _extensionKinds = {
  TokenKind.nextFrom,
  TokenKind.abstain,
  TokenKind.from,
  TokenKind.slat,
  TokenKind.once,
  TokenKind.again,
  TokenKind.tryAgain,
  TokenKind.create,
  TokenKind.createLabel,
  TokenKind.goBack,
  TokenKind.goAhead,
  TokenKind.whileKeyword,
  TokenKind.petition,
  TokenKind.signed,
  TokenKind.readOutBaudot,
  TokenKind.writeInBaudot,
  TokenKind.doubleCateye,
  TokenKind.doubleHybrid,
  TokenKind.fence,
  TokenKind.stockade,
};

const sigils = {
  TokenKind.oneSpot,
  TokenKind.twoSpot,
  TokenKind.tail,
  TokenKind.hybrid,
  TokenKind.doubleCateye,
  TokenKind.doubleHybrid,
};

const meshes = {TokenKind.mesh, TokenKind.fence, TokenKind.stockade};

/// What stays code at the start of an undecodable statement: its label and identifier. Not its
/// NOT, because `DO NOTE` lexes as `DO NOT E…`, and the comment starts at NOTE.
const _headKinds = {TokenKind.label, TokenKind.identifier};

class SyntaxModel {
  SyntaxModel(this.program) {
    final tokens = program.tokens
        .where((t) => t.kind != TokenKind.end)
        .toList();
    final seen = <int>{};
    for (final (i, s) in program.statements.indexed) {
      if (!identical(s.source, program.source) || !seen.add(s.start)) continue;
      statements.add(
        FileStatement(i + 1, s, [
          for (final t in tokens)
            if (t.start >= s.start && t.end <= s.end) t,
        ]),
      );
    }
    _classify(tokens);
  }

  final Program program;
  final statements = <FileStatement>[];
  final pieces = <Piece>[];

  void _classify(List<Token> tokens) {
    final owner = <Token, FileStatement>{
      for (final s in statements)
        for (final t in s.tokens) t: s,
    };
    final comments = <Span>[];
    for (final s in statements.where((s) => s.undecodable)) {
      final head = s.statement.hasIdentifier
          ? s.tokens.takeWhile((t) => _headKinds.contains(t.kind)).length
          : 0;
      final rest = s.tokens.skip(head);
      if (rest.isNotEmpty) {
        comments.add(Span(rest.first.start, s.statement.end));
      }
    }
    var i = 0;
    while (i < tokens.length) {
      final t = tokens[i];
      final statement = owner[t];
      // Text outside every statement, such as prose a dialect allows before the first, is a
      // comment.
      if (statement == null) {
        var end = i;
        while (end + 1 < tokens.length && owner[tokens[end + 1]] == null) {
          end++;
        }
        comments.add(Span(t.start, tokens[end].end));
        i = end + 1;
        continue;
      }
      if (comments.any((c) => t.start >= c.start && t.start < c.end)) {
        i++;
        continue;
      }
      final next = i + 1 < tokens.length ? tokens[i + 1] : null;
      final withNumber =
          next != null &&
          next.kind == TokenKind.number &&
          owner[next] == statement;
      final extension = _extensionKinds.contains(t.kind);
      Piece piece(Role role, {Token? last, bool definition = false}) => Piece(
        Span(t.start, (last ?? t).end),
        role,
        token: t,
        extension: extension,
        definition: definition,
      );
      switch (t.kind) {
        case final k when sigils.contains(k):
          pieces.add(piece(Role.variable, last: withNumber ? next : null));
          if (withNumber) i++;
        case final k when meshes.contains(k):
          pieces.add(piece(Role.constant, last: withNumber ? next : null));
          if (withNumber) i++;
        case TokenKind.number:
          pieces.add(piece(Role.constant));
        case TokenKind.label:
          pieces.add(
            piece(Role.label, definition: identical(statement.tokens.first, t)),
          );
        case TokenKind.identifier || TokenKind.not || TokenKind.percent:
          pieces.add(piece(Role.identifier));
        case TokenKind.gerund:
          pieces.add(piece(Role.gerund));
        case TokenKind.mingle ||
            TokenKind.select ||
            TokenKind.unary ||
            TokenKind.slat ||
            TokenKind.spark ||
            TokenKind.ears ||
            TokenKind.gets ||
            TokenKind.intersection:
          // The wow `!` is a zero-width spark before its spot.
          if (t.end > t.start) pieces.add(piece(Role.operator));
        case TokenKind.dialect:
          pieces.add(
            Piece(
              Span(t.start, t.end),
              t.tag == 'string' ? Role.string : Role.keyword,
              token: t,
              dialect: true,
            ),
          );
        case TokenKind.badChar || TokenKind.end:
          break;
        default:
          pieces.add(piece(Role.keyword));
      }
      i++;
    }
    for (final c in comments) {
      pieces.add(Piece(c, Role.comment));
    }
    pieces.sort((a, b) => a.span.start.compareTo(b.span.start));
  }

  /// The piece under rune offset [offset], if any.
  Piece? pieceAt(int offset) {
    for (final p in pieces) {
      if (p.span.start <= offset && offset < p.span.end) return p;
      if (p.span.start > offset) break;
    }
    return null;
  }

  /// The statement whose text holds [offset], if any.
  FileStatement? statementAt(int offset) {
    for (final s in statements) {
      if (s.statement.start <= offset && offset < s.statement.end) return s;
    }
    return null;
  }
}
