import 'package:ciwapa_core/ciwapa_core.dart';

/// Interstates' own ICL errors, in the same form as CIWAPA's (line 1 the official text, line 2 our
/// joke). Each one has an entry under "INTERCAL on Interstates error codes" in
/// docs/SPEC_DECISIONS.md.
const interstatesErrors = <IclError>[
  IclError(
    403,
    'THIS ROUTE CAN ONLY BE REACHED FROM A PAGE THAT LINKS TO IT.',
    'NO TELEPORTING ON THE INTERSTATES. TAKE THE EXIT RAMP LIKE EVERYONE ELSE.',
  ),
  IclError(
    440,
    'NO ROUTE MATCHES THE REQUESTED PATH.',
    'THIS ROAD IS NOT ON THE MAP. RECALCULATING. RECALCULATING.',
  ),
  IclError(
    441,
    'TWO ROUTES ARE EQUALLY SPECIFIC.',
    'THE ROAD FORKS, AND BOTH SIGNS SAY THE SAME THING.',
  ),
  IclError(
    442,
    'A ROUTE IS NOT A PATH.',
    'A ROUTE STARTS WITH A SLASH AND NAMES ITS PARAMETERS. THIS ONE DOES NEITHER.',
  ),
  IclError(
    443,
    'A RESTRICTED ROUTE IS NOT LINKED FROM ITS PAGE.',
    'AN ON-RAMP WITH NO ROAD LEADING TO IT IS JUST A RAMP.',
  ),
  IclError(
    504,
    'THE PROGRAM DID NOT GIVE UP IN TIME.',
    'GROSS WAITED, AND WAITED. GROSS IS NOT A PATIENT SERVER.',
  ),
  IclError(
    822,
    'STRINGS AND NUMBERS DO NOT MIX.',
    'A STRING WALKED INTO AN EXPRESSION. THE EXPRESSION DID NOT LAUGH.',
  ),
  IclError(
    823,
    'THE RESPONSE HEADERS HAVE ALREADY BEEN SENT.',
    'THE TRUCK HAS LEFT THE DEPOT. YOUR PARCEL IS NOT ON IT.',
  ),
  IclError(
    827,
    'AN INTO DATABASE HAS THE WRONG NUMBER OF VALUES.',
    'THE CASSETTE HAS A SLOT FOR EACH COLUMN. COUNT THEM.',
  ),
  IclError(
    828,
    'A RESPONSE HEADER OR COOKIE IS MALFORMED.',
    'ONE HEADER, ONE LINE, NO SURPRISES. THIS IS NOT POETRY.',
  ),
  IclError(
    829,
    'THE PROGRAM DID NOT ANSWER IN CGI.',
    'GROSS ASKED A QUESTION AND GOT A SHRUG.',
  ),
];

final _byCode = {for (final e in interstatesErrors) e.code: e};

/// The Interstates error [code].
IclError interstatesError(int code) => _byCode[code]!;

/// A compile-time Interstates error at statement [statement].
CompileError interstatesCompileError(int code, int statement) =>
    CompileError.of(interstatesError(code), statement);
