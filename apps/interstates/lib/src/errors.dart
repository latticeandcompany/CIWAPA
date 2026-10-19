import 'package:ciwapa_core/ciwapa_core.dart';

/// Interstates' own ICL errors, in the same form as CIWAPA's (line 1 the official text, line 2 our
/// joke). Each one has an entry under "INTERCAL on Interstates error codes" in
/// docs/SPEC_DECISIONS.md.
const interstatesErrors = <IclError>[
  IclError(
    822,
    'STRINGS AND NUMBERS DO NOT MIX.',
    'A STRING WALKED INTO AN EXPRESSION. THE EXPRESSION DID NOT LAUGH.',
  ),
  IclError(
    827,
    'AN INTO DATABASE HAS THE WRONG NUMBER OF VALUES.',
    'THE CASSETTE HAS A SLOT FOR EACH COLUMN. COUNT THEM.',
  ),
];

final _byCode = {for (final e in interstatesErrors) e.code: e};

/// The Interstates error [code].
IclError interstatesError(int code) => _byCode[code]!;

/// A compile-time Interstates error at statement [statement].
CompileError interstatesCompileError(int code, int statement) =>
    CompileError.of(interstatesError(code), statement);
