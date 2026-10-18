/// Every ICL error: line 1 is the official text and line 2 is our own joke (§9.1, decisions Q83,
/// Q84, Q90, Q134). The official text is the literal §4 message where one exists, and otherwise the
/// §9.2 description uppercased, with the typesetter's curly quotes written as ASCII.
///
/// Both runtimes get these strings from the emitters, so this table is the only copy.
class IclError {
  const IclError(this.code, this.text, this.joke);

  final int code;

  /// Empty for E000, whose message is the undecodable statement itself.
  final String text;
  final String joke;

  /// The program's exit status: the code mod 256, so E000 exits 0 (decision T34).
  int get exitStatus => code % 256;

  static const all = <IclError>[
    IclError(0, '', 'THAT WAS NOT A STATEMENT. THAT WAS A CRY FOR HELP.'),
    IclError(
      17,
      'AN EXPRESSION CONTAINS A SYNTAX ERROR.',
      'YOUR EXPRESSION HAS BEEN RETURNED TO SENDER, POSTAGE DUE.',
    ),
    IclError(
      79,
      'IMPROPER USE HAS BEEN MADE OF STATEMENT IDENTIFIERS.',
      'THE COMPILER WAS RAISED BETTER THAN THIS. WERE YOU?',
    ),
    IclError(
      99,
      'IMPROPER USE HAS BEEN MADE OF STATEMENT IDENTIFIERS.',
      'NOBODY LIKES A SYCOPHANT, LEAST OF ALL A COMPILER.',
    ),
    IclError(
      111,
      "YOU TRIED TO USE A C-INTERCAL EXTENSION WITH THE 'TRADITIONAL' FLAG ON.",
      'TRADITION IS NOT A SUGGESTION.',
    ),
    IclError(
      123,
      'PROGRAM HAS DISAPPEARED INTO THE BLACK LAGOON.',
      'THE LIFEGUARD HAS BEEN NOTIFIED. HE IS NOT COMING.',
    ),
    IclError(
      129,
      'PROGRAM HAS ATTEMPTED TO TRANSFER TO A NON-EXISTENT LINE LABEL.',
      'THAT LABEL LEFT NO FORWARDING ADDRESS.',
    ),
    IclError(
      139,
      'AN ABSTAIN OR REINSTATE STATEMENT REFERENCES A NON-EXISTENT LINE LABEL.',
      "YOU CANNOT ABSTAIN FROM WHAT ISN'T THERE, THOUGH MANY HAVE TRIED.",
    ),
    IclError(
      182,
      'A LINE LABEL HAS BEEN MULTIPLY DEFINED.',
      'TWO STATEMENTS ANSWERED TO THE SAME NAME. BOTH ARE EMBARRASSED.',
    ),
    IclError(
      197,
      'AN INVALID LINE LABEL HAS BEEN ENCOUNTERED.',
      'LABELS GO FROM 1 TO 65535. COUNTING IS HARD; WE GET IT.',
    ),
    IclError(
      200,
      'AN EXPRESSION INVOLVES AN UNIDENTIFIED VARIABLE.',
      'THIS VARIABLE IS IN THE WITNESS PROTECTION PROGRAM.',
    ),
    IclError(
      222,
      'OUT OF STASH SPACE.',
      'THE STASH WAS NEVER MEANT TO BE FULL. AND YET.',
    ),
    IclError(
      240,
      'AN ATTEMPT HAS BEEN MADE TO GIVE AN ARRAY A DIMENSION OF ZERO.',
      'A ZERO-SIZED ARRAY HOLDS EXACTLY AS MUCH AS YOUR PROGRAM DOES.',
    ),
    IclError(
      241,
      'INVALID DIMENSIONING INFORMATION WAS SUPPLIED IN DEFINING OR USING AN ARRAY.',
      'THE ARRAY DOES NOT GO THERE. NOTHING GOES THERE.',
    ),
    IclError(
      275,
      "DON'T BYTE OFF MORE THAN YOU CAN CHEW.",
      'SIXTEEN BITS WERE OFFERED. YOU BROUGHT THIRTY-TWO.',
    ),
    IclError(
      276,
      'A VALUE REQUIRING OVER 32 BITS HAS BEEN ASSIGNED TO A VARIABLE OF 32 BITS OR FEWER.',
      'THE BIG NUMBER WAS ASKED TO SQUEEZE IN. IT DECLINED.',
    ),
    IclError(
      277,
      'AN IMPOSSIBLE REVERSE ASSIGNMENT HAS BEEN ATTEMPTED.',
      'SOME EQUATIONS ARE ONE-WAY STREETS.',
    ),
    IclError(
      333,
      'TOO MANY VARIABLES.',
      'THE VARIABLES HAVE UNIONIZED AND WILL ACCEPT NO MORE MEMBERS.',
    ),
    IclError(
      404,
      'THERE IS NO CHOICEPOINT TO GO BACK OR AHEAD TO.',
      'THE ROAD NOT TAKEN WAS NEVER BUILT.',
    ),
    IclError(
      436,
      'THROW STICK BEFORE RETRIEVING.',
      'YOU CANNOT TAKE BACK WHAT YOU NEVER PUT AWAY.',
    ),
    IclError(
      444,
      'A COME FROM STATEMENT REFERENCES A NON-EXISTENT LINE LABEL.',
      'THE TRAP DOOR OPENS ONTO A LABEL THAT DOES NOT EXIST.',
    ),
    IclError(
      533,
      'A WRITE IN STATEMENT OR INTERLEAVE (¢) OPERATION HAS PRODUCED A VALUE REQUIRING OVER 32 BITS TO REPRESENT.',
      'THIRTY-TWO BITS SHOULD BE ENOUGH FOR ANYBODY.',
    ),
    IclError(
      534,
      'AN EPHEMERAL 128-BIT VALUE HAS BEEN USED FOR SOMETHING OTHER THAN A SELECT.',
      'IT WAS ONLY EVER MEANT TO BE A PHASE.',
    ),
    IclError(
      535,
      'A WRITE IN STATEMENT HAS PRODUCED A VALUE REQUIRING OVER 64 BITS TO REPRESENT.',
      'SIXTY-FOUR BITS WAS SUPPOSED TO BE ENOUGH FOR ANYBODY. YOU ARE NOT ANYBODY.',
    ),
    IclError(
      536,
      'A WRITE IN SIGNED STATEMENT HAS PRODUCED A VALUE OUTSIDE ITS VARIABLE\'S SIGNED RANGE.',
      'THE NUMBER WAS TOO NEGATIVE, OR TOO POSITIVE, OR POSSIBLY BOTH.',
    ),
    IclError(
      555,
      'MORE THAN ONE COME FROM REFERENCES THE SAME LABEL.',
      'ONE LABEL, SEVERAL COME FROMS. SOMEBODY IS GOING TO GET HURT.',
    ),
    IclError(
      562,
      'INSUFFICIENT DATA.',
      'THE INPUT RAN DRY. HAVE YOU TRIED ADDING MORE INPUT?',
    ),
    IclError(
      579,
      'INPUT DATA IS INVALID.',
      'THAT IS NOT A NUMBER IN ANY LANGUAGE WE WERE TOLD ABOUT.',
    ),
    IclError(
      621,
      'THE EXPRESSION OF A RESUME STATEMENT EVALUATED TO #0.',
      'RESUMING ZERO TIMES IS A PHILOSOPHY, NOT A STATEMENT.',
    ),
    IclError(
      632,
      'PROGRAM EXECUTION WAS TERMINATED VIA A RESUME STATEMENT INSTEAD OF GIVE UP.',
      'YOU WALKED OFF THE TOP OF THE NEXT STACK. NEXT TIME, PLEASE GIVE UP.',
    ),
    IclError(
      633,
      'EXECUTION HAS PASSED BEYOND THE LAST STATEMENT OF THE PROGRAM.',
      'THE PROGRAM RAN OUT OF PROGRAM.',
    ),
    IclError(
      666,
      'TOO MANY SOURCE LINES.',
      'THE SOURCE IS LONGER THAN THE MACHINE IS PATIENT.',
    ),
    IclError(
      774,
      'A COMPILER ERROR HAS OCCURRED (SEE SECTION 12).',
      'THIS ONE IS ON US. NO REFUNDS.',
    ),
    IclError(
      777,
      'NO SUCH SOURCE FILE.',
      'THE FILE YOU NAMED IS IMAGINARY. SO, PERHAPS, IS THE PROGRAM.',
    ),
    IclError(
      778,
      'AN UNEXPLAINABLE COMPILER ERROR HAS OCCURRED.',
      'EVEN THE COMPILER CANNOT EXPLAIN THIS ONE.',
    ),
    IclError(
      801,
      'A PETITION HAS BEEN MADE TO A SERVICE THAT DOES NOT EXIST.',
      'THE OPERATING SYSTEM HAS NO RECORD OF THIS DEPARTMENT.',
    ),
    IclError(
      802,
      'AN EXIT STATUS OUTSIDE 0 TO 255 HAS BEEN REQUESTED.',
      'THE PROGRAM TRIED TO LEAVE WITH MORE THAN IT CAME WITH.',
    ),
    IclError(
      803,
      'A STRING HAS BEEN GIVEN AS AN ARRAY OF MORE THAN ONE DIMENSION.',
      'WORDS COME IN LINES, NOT IN BLOCKS.',
    ),
    IclError(
      804,
      'A FILE HANDLE THAT IS NOT OPEN THAT WAY HAS BEEN USED.',
      'YOU CANNOT READ FROM A LETTERBOX OR POST INTO A NEWSPAPER.',
    ),
    IclError(
      805,
      'A BYTE ABOVE 255 HAS BEEN WRITTEN.',
      'IT DID NOT FIT THROUGH THE SLOT.',
    ),
    IclError(
      806,
      'A FILE HAS BEEN OPENED IN A MODE THAT DOES NOT EXIST.',
      'NEITHER READING, WRITING NOR APPENDING. PERHAPS JUST LOOKING.',
    ),
    IclError(
      807,
      'A SLICE HAS BEEN TAKEN FROM OUTSIDE A STRING.',
      'YOU CANNOT CUT A PIECE FROM THE END OF NOTHING.',
    ),
    IclError(
      808,
      'AN ELEMENT ABOVE 255 HAS BEEN DECODED AS A BYTE.',
      'THAT WAS NOT UTF-8. THAT WAS NOT EVEN A BYTE.',
    ),
    IclError(
      888,
      "CAN'T OPEN C OUTPUT FILE",
      'THE DISK REFUSED TO TAKE PART IN ANY OF THIS.',
    ),
    IclError(
      993,
      'A STATEMENT FOLLOWS TRY AGAIN, WHICH MUST BE THE LAST STATEMENT OF THE PROGRAM.',
      'THERE IS NO AFTER. THERE IS ONLY AGAIN.',
    ),
    IclError(
      997,
      'ILLEGAL POSSESSION OF A CONTROLLED UNARY OPERATOR.',
      'THAT OPERATOR REQUIRES A LICENSE IN THIS BASE.',
    ),
    IclError(
      998,
      'SOURCE FILE NAME WITH INVALID EXTENSION (USE .I OR .[3-7]I).',
      'INTERCAL FILES END IN .I. THIS IS NOT NEGOTIABLE.',
    ),
  ];

  static final _byCode = {for (final e in all) e.code: e};

  static IclError of(int code) => _byCode[code]!;

  /// The four-line message (decision T33). [statement] is the ordinal of the statement that would
  /// have run next; [message] replaces the official text, which E000 needs.
  String format(int statement, {String? message}) {
    final code = this.code.toString().padLeft(3, '0');
    return 'ICL${code}I ${message ?? text}\n'
        '        $joke\n'
        '\tON THE WAY TO STATEMENT $statement\n'
        '        CORRECT SOURCE AND RESUBMIT\n';
  }
}

/// The E000 message: the statement's source lines verbatim, joined by a newline and a tab, and cut
/// off with `...` past 500 characters (decision T10).
String undecodableText(List<String> lines) {
  const limit = 500;
  final text = lines.join('\n\t');
  return text.length <= limit ? text : '${text.substring(0, limit)}...';
}
