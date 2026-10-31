/// What an error means in plain English, and what to do about it (R4, Q180).
class ErrorHelp {
  const ErrorHelp(this.description, this.fix);

  final String description;
  final String fix;
}

/// The help for every one of CIWAPA's errors, by code. A test keeps it complete.
const errorHelp = <int, ErrorHelp>{
  0: ErrorHelp(
    'The statement can\'t be decoded, so it is a comment, and a comment only stays harmless while '
        'nothing runs it. If it ever runs, the program ends here and prints the statement itself '
        'as the error message.',
    'If it\'s meant as a comment, say `PLEASE NOTE` so it starts abstained and never runs. If '
        'it\'s meant as code, fix whatever the compiler couldn\'t read.',
  ),
  17: ErrorHelp(
    'An expression contains a syntax error: a constant too big for its sigil, a `%` chance above '
        '100, or two binary operators in a row without grouping (§3.4.3). The program still '
        'builds; the error waits until the statement runs.',
    'Keep `#` constants within the base\'s 16-bit range (65535 in binary), `%` at 100 or below, '
        'and group every binary operator with sparks or rabbit ears.',
  ),
  79: ErrorHelp(
    'Fewer than a fifth of the program\'s statements say PLEASE. The compiler takes this '
        'personally (§10.4).',
    'Add PLEASE to more statements. The quick fix adds just enough, spread through the file.',
  ),
  99: ErrorHelp(
    'More than a third of the program\'s statements say PLEASE. That isn\'t politeness, it\'s '
        'grovelling, and the compiler won\'t have it (§10.4).',
    'Take PLEASE off some statements. The quick fix removes just enough, spread through the file.',
  ),
  111: ErrorHelp(
    'The program uses something INTERCAL-72 didn\'t have (COME FROM, a base other than 2, or a '
        'C-INTERCAL or EXTRACAL extension) while the `traditional` setting is on.',
    'Turn off the `traditional` setting, or write it the way they did in 1972.',
  ),
  123: ErrorHelp(
    'The NEXT stack overflowed: a NEXT tried to store an 80th entry. The spec allows 79 (§4.4.2).',
    'Every NEXT needs a RESUME or FORGET to match. A loop built from NEXT alone eventually '
        'falls in.',
  ),
  129: ErrorHelp(
    'A NEXT names a label that no statement has. It builds; it fails when the NEXT runs.',
    'Label the statement it should reach, or fix the number.',
  ),
  139: ErrorHelp(
    'An ABSTAIN or REINSTATE names a label that no statement has. It builds; it fails when the '
        'statement runs.',
    'Label the statement it should reach, or fix the number.',
  ),
  182: ErrorHelp(
    'Two or more statements share a label, so nothing that names it can know which one it means.',
    'Give each statement its own label.',
  ),
  197: ErrorHelp(
    'A label is outside 1 to 65535. The program builds; the error fires when the statement runs.',
    'Use a label from 1 to 65535.',
  ),
  200: ErrorHelp(
    'A variable is numbered 0 or above 65535. The program builds; the error fires when the '
        'statement runs.',
    'Number variables from 1 to 65535.',
  ),
  222: ErrorHelp(
    'There was no memory left to STASH another value.',
    'Look for a loop that STASHes without ever RETRIEVing.',
  ),
  240: ErrorHelp(
    'An array was dimensioned with a size of zero.',
    'Give every dimension at least one element.',
  ),
  241: ErrorHelp(
    'An array was used outside its dimensions, with the wrong number of subscripts, or before '
        'being dimensioned at all.',
    'Dimension the array before use (`,1 <- #10`) and keep subscripts within it.',
  ),
  275: ErrorHelp(
    'A value over 16 bits was assigned to a 16-bit variable.',
    'Assign it to a 32-bit variable (`:` or `;`), or SELECT it down to 16 bits first.',
  ),
  276: ErrorHelp(
    'A value over 32 bits was assigned to a variable of 32 bits or fewer.',
    'Use a 64-bit variable (`::` or `;;`), or SELECT the value down first.',
  ),
  277: ErrorHelp(
    'A reverse assignment, through an overloaded or created operator, has no solution.',
    'Assign only values the operator can actually produce.',
  ),
  333: ErrorHelp(
    'The program uses more variables than the compiler could lay out.',
    'Use fewer variables. Most programs get by on a few dozen.',
  ),
  404: ErrorHelp(
    'A GO BACK or GO AHEAD ran with no choicepoint to go to. Only a MAYBE statement makes one.',
    'Make sure a MAYBE runs before every GO BACK and GO AHEAD.',
  ),
  436: ErrorHelp(
    'A RETRIEVE ran for a variable with nothing stashed.',
    'STASH a variable before you RETRIEVE it.',
  ),
  444: ErrorHelp(
    'A COME FROM names a label that no statement has.',
    'Label the statement it should come from, or fix the number.',
  ),
  533: ErrorHelp(
    'A WRITE IN or a mingle produced a value over 32 bits. A mingle\'s operands must each fit in '
        '16 bits.',
    'SELECT the operands down to 16 bits before mingling them.',
  ),
  534: ErrorHelp(
    'A mingle of two 64-bit values makes a 128-bit value that only a SELECT may use, and '
        'something else tried to.',
    'SELECT the 128-bit mingle straight back down to 64 bits.',
  ),
  535: ErrorHelp(
    'A WRITE IN read a number over 64 bits.',
    'Feed it smaller numbers.',
  ),
  536: ErrorHelp(
    'A WRITE IN SIGNED read a number outside its variable\'s signed range.',
    'Feed it a number that fits, or use a wider variable.',
  ),
  555: ErrorHelp(
    'Two COME FROMs name the same label. In INTERCAL that is ambiguous; in EXTRACAL it would start '
        'threads instead.',
    'Point each COME FROM at a different label, or make the file EXTRACAL (`.xc`).',
  ),
  562: ErrorHelp(
    'A WRITE IN ran out of input.',
    'Give the program more input, one number per line.',
  ),
  579: ErrorHelp(
    'A WRITE IN read something that isn\'t a number spelled out in any language the compiler '
        'knows. Numbers are written as digit names, one word per digit: `ONE TWO` is 12.',
    'Spell each digit out (`ZERO`, `ONE`, … or another supported language).',
  ),
  621: ErrorHelp(
    'A RESUME was asked to go back zero levels.',
    'RESUME at least #1.',
  ),
  632: ErrorHelp(
    'A RESUME popped the last entry off the NEXT stack, which ends the program without GIVE UP.',
    'End the program with GIVE UP, and RESUME only as many levels as you NEXTed.',
  ),
  633: ErrorHelp(
    'The program ran past its last statement.',
    'End it with GIVE UP, or make sure control never falls off the end.',
  ),
  666: ErrorHelp(
    'The program is too long for the compiler to hold in memory.',
    'Make it shorter.',
  ),
  774: ErrorHelp(
    'The random compiler bug: one statement in 128 gets an error planted at build time. The '
        'editor never shows it, because it would move with every keystroke.',
    'Build with `--no-random-bug`, or build again and hope.',
  ),
  777: ErrorHelp(
    'A file the program needs couldn\'t be read.',
    'Check that the path exists and is readable.',
  ),
  778: ErrorHelp(
    'The toolchain failed in a way the compiler can\'t explain.',
    'Run `doctor` to check the toolchain.',
  ),
  801: ErrorHelp(
    'A PETITION asked for a service that doesn\'t exist.',
    'PETITION only the services the library documents.',
  ),
  802: ErrorHelp(
    'The program asked to exit with a status outside 0 to 255.',
    'Exit with a status from 0 to 255.',
  ),
  803: ErrorHelp(
    'An array of more than one dimension was used as a string.',
    'Strings are one-dimensional tail arrays.',
  ),
  804: ErrorHelp(
    'A file handle was used in a way it isn\'t open for: reading from standard output, writing to '
        'standard input, or using a closed file.',
    'Read from handles opened for reading, and write to ones opened for writing.',
  ),
  805: ErrorHelp(
    'A byte above 255 was written.',
    'Write values from 0 to 255; the Strings block turns text into UTF-8 bytes.',
  ),
  806: ErrorHelp(
    'A file was opened in a mode other than #1 (read), #2 (write) or #3 (append).',
    'Use mode #1, #2 or #3.',
  ),
  807: ErrorHelp(
    'A slice was taken from outside a string.',
    'Keep slices within the string\'s length.',
  ),
  808: ErrorHelp(
    'An element above 255 was decoded as a UTF-8 byte.',
    'Decode arrays of bytes only.',
  ),
  809: ErrorHelp(
    'An array of more than one dimension was used as a list.',
    'Lists are one-dimensional.',
  ),
  812: ErrorHelp(
    'A dimension the array doesn\'t have was asked about.',
    'Ask about dimensions from 1 up to the array\'s count.',
  ),
  813: ErrorHelp(
    'An arithmetic result was too big for its variable.',
    'Use a wider variable, or the routine\'s wrapping variant.',
  ),
  814: ErrorHelp(
    'A floating-point result was too big to represent.',
    'Keep the numbers smaller.',
  ),
  815: ErrorHelp(
    'A floating-point number was divided by zero.',
    'Check the divisor first.',
  ),
  816: ErrorHelp(
    'The logarithm of zero or a negative number was taken.',
    'Take logarithms of positive numbers.',
  ),
  817: ErrorHelp(
    'A request went to an address that isn\'t a plain `http://` URL.',
    'Use `http://` URLs. There is no HTTPS, by design.',
  ),
  888: ErrorHelp(
    'The compiler couldn\'t write its output file.',
    'Check that the output folder exists and is writable.',
  ),
  993: ErrorHelp(
    'TRY AGAIN must be the program\'s last statement, and something follows it.',
    'Move TRY AGAIN to the end, or delete what follows it, comments included.',
  ),
  997: ErrorHelp(
    'A unary operator the base doesn\'t have: `^` and `@` exist only in bases 3 to 7, and `N@` '
        'only where N is at most the base minus 2 (§6.6).',
    'Use the operators of the file\'s base, or change its extension (`.3i` and so on).',
  ),
  998: ErrorHelp(
    'The file\'s extension doesn\'t name a language this compiler builds.',
    'Use `.i` (or `.2i`–`.7i`) for INTERCAL and `.xc` (or `.2xc`–`.7xc`) for EXTRACAL.',
  ),
};
