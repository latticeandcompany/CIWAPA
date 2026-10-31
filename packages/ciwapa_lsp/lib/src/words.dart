import 'package:ciwapa_core/ciwapa_core.dart';

/// Hover text for the things an INTERCAL program is made of (R4). It's written once, here, so
/// every editor shows the same words.

const identifierHelp =
    '**Statement identifier.** Every statement starts with `DO`, `PLEASE` or `PLEASE DO`, after '
    'its label if it has one. Between a fifth and a third of a program\'s statements must say '
    'PLEASE (§10.4): fewer is E079, more is E099.';

const notHelp =
    '**NOT** (or `N\'T`): the statement starts abstained, so it doesn\'t run until something '
    'REINSTATEs it.';

const percentHelp =
    '**%n**: the statement runs only n percent of the times it\'s reached. `%0` never runs it and '
    '`%100` always does.';

const maybeHelp =
    '**MAYBE**: reaching the statement makes a choicepoint, which GO BACK returns to and GO AHEAD '
    'throws away.';

String sigilHelp(TokenKind kind) => switch (kind) {
  TokenKind.oneSpot =>
    '**Spot** (`.`): a 16-bit variable. `.1` through `.65535`.',
  TokenKind.twoSpot =>
    '**Two-spot** (`:`): a 32-bit variable. `:1` through `:65535`.',
  TokenKind.tail =>
    '**Tail** (`,`): an array of 16-bit values. Dimension it with `,1 <- #10` and use '
        '`,1 SUB #3`.',
  TokenKind.hybrid =>
    '**Hybrid** (`;`): an array of 32-bit values. Dimension it with `;1 <- #10` and use '
        '`;1 SUB #3`.',
  TokenKind.doubleCateye =>
    '**Double cateye** (`::`): a 64-bit variable, in EXTRACAL.',
  TokenKind.doubleHybrid =>
    '**Double hybrid** (`;;`): an array of 64-bit values, in EXTRACAL.',
  TokenKind.mesh =>
    '**Mesh** (`#`): a constant that fits in 16 bits. To get a bigger number, mingle two of '
        'them.',
  TokenKind.fence => '**Fence** (`##`): a 32-bit constant, in EXTRACAL.',
  TokenKind.stockade =>
    '**Stockade** (`####`): a 64-bit constant, in EXTRACAL.',
  _ => '',
};

String operatorHelp(Token token) => switch (token.kind) {
  TokenKind.mingle =>
    '**Mingle** (`\$`, `¢`): interleaves the bits of two 16-bit values into one 32-bit value, '
        'the left operand\'s bits in the odd places, starting from the top. `#1\$#1` is 3.',
  TokenKind.select =>
    '**Select** (`~`): takes the bits of the left operand where the right operand has 1s and '
        'packs them to the right. The result has the right operand\'s type. `#179~#201` is 9.',
  TokenKind.slat =>
    '**Slat** (`/`): `.1/expr` has `.1`\'s value, and from then on `.1` stands for `expr`, '
        'both when it is read and when it is assigned to.',
  TokenKind.spark || TokenKind.ears =>
    '**Grouping.** Sparks (`\'`) and rabbit ears (`"`) are INTERCAL\'s parentheses. Every binary '
        'operator needs them once there is more than one (§3.4.3).',
  TokenKind.gets =>
    '**Gets** (`<-`): assignment. The value on the right goes into the left.',
  TokenKind.intersection => '**Intersection** (`+`): joins the variables a STASH, RETRIEVE, IGNORE or REMEMBER takes.',
  TokenKind.unary => switch (token.unary) {
    UnaryOp.and =>
      '**AND** (`&`), unary: each bit is ANDed with the bit to its left, and the top bit with '
          'the bottom one. In bases 3 to 7 it takes the smaller digit.',
    UnaryOp.or =>
      '**OR** (`V`), unary: each bit is ORed with the bit to its left, and the top bit with the '
          'bottom one. In bases 3 to 7 it takes the larger digit.',
    UnaryOp.xor =>
      '**XOR** (`?`, or `V` overstruck with `-`), unary: each bit is XORed with the bit to its left, and the top bit '
          'with the bottom one.',
    UnaryOp.sharkfin => '**Sharkfin** (`^`): TriINTERCAL\'s add-without-carry, digit by digit. Bases 3 to 7 only.',
    _ =>
      '**Whirlpool** (`@`, `2@` to `5@`): TriINTERCAL\'s BUT, which prefers one digit over the '
          'others. Bases 3 to 7 only, and `N@` only where N is at most the base minus 2.',
  },
  _ => '',
};

String gerundHelp(Gerund gerund) {
  final (word, statements) = switch (gerund) {
    Gerund.calculating => (
      'CALCULATING',
      'assignments, array dimensioning included',
    ),
    Gerund.nexting => ('NEXTING', 'NEXTs'),
    Gerund.forgetting => ('FORGETTING', 'FORGETs'),
    Gerund.resuming => ('RESUMING', 'RESUMEs'),
    Gerund.stashing => ('STASHING', 'STASHes'),
    Gerund.retrieving => ('RETRIEVING', 'RETRIEVEs'),
    Gerund.ignoring => ('IGNORING', 'IGNOREs'),
    Gerund.remembering => ('REMEMBERING', 'REMEMBERs'),
    Gerund.abstaining => ('ABSTAINING', 'ABSTAINs, every kind'),
    Gerund.reinstating => ('REINSTATING', 'REINSTATEs'),
    Gerund.readingOut => ('READING OUT', 'READ OUTs'),
    Gerund.writingIn => ('WRITING IN', 'WRITE INs'),
    Gerund.comingFrom => ('COMING FROM', 'COME FROMs'),
    Gerund.nextingFrom => ('NEXTING FROM', 'NEXT FROMs'),
    Gerund.tryingAgain => ('TRYING AGAIN', 'TRY AGAINs'),
    Gerund.creating => ('CREATING', 'CREATEs'),
    Gerund.commenting => (
      'COMMENTING',
      'comments: the statements nobody can decode',
    ),
    Gerund.goingBack => ('GOING BACK', 'GO BACKs'),
    Gerund.goingAhead => ('GOING AHEAD', 'GO AHEADs'),
    Gerund.whiling => ('WHILING', 'WHILE loops'),
    Gerund.petitioning => ('PETITIONING', 'PETITIONs'),
  };
  return '**$word**: a gerund. ABSTAIN FROM $word and REINSTATE $word switch every statement of '
      'its kind off and on at once: $statements.';
}
