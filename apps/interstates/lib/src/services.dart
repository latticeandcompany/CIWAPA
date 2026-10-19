/// The host services Interstates statements turn into (HostCall), which a program can't name with
/// PETITION. Their values are documented beside each, in the order the host takes them.
abstract final class HostService {
  /// `READ OUT #n WITH TEMPLATE`: the template's number, then a value for each of its pieces that
  /// needs one. The parser leaves them out; the front end adds them once it has read the template.
  static const render = 16500;

  /// `,a <- ;4400 SUB e`: arrays [a], values [e].
  static const paramToArray = 16510;

  /// `,a <- ;49221 SUB e`: arrays [a], values [e].
  static const argToArray = 16511;

  /// `;49221 SUB e <- ,a`: arrays [a], values [e].
  static const arrayToArg = 16512;

  /// `;49221 SUB e <- ;4400 SUB f`: values [e, f].
  static const paramToArg = 16513;

  /// `;49221 SUB e <- ;49221 SUB f`: values [e, f].
  static const argToArg = 16514;

  /// A statement-local Interstates error: values [code].
  static const fault = 16520;

  /// `;49221 <- 'FROM DATABASE #t~#c$…' SUB r HAVING …`: values [t, columns, c…, r, pairs, pair…].
  static const read = 16600;

  /// `INTO DATABASE #t~#c$… <- items`: values [t, columns, c…, item…].
  static const insert = 16610;

  /// `INTO DATABASE #t~#c$… <- items HAVING …`: values [t, columns, c…, item…, pairs, pair…].
  static const update = 16620;

  /// `FORGET DATABASE #t HAVING …`: values [t, pairs, pair…].
  static const delete = 16630;

  /// `AMNESIA`: no values.
  static const amnesia = 16640;
}

/// How a string or number travels in a HostCall's values: its kind, then one value. A pair in a
/// HAVING list is its column number, then an item.
abstract final class ItemKind {
  /// A number: the value is the number.
  static const number = 0;

  /// A tail array holding a string: the value is its index in the HostCall's arrays.
  static const array = 1;

  /// A route parameter, `;4400 SUB e`: the value is e.
  static const param = 2;

  /// A template argument, `;49221 SUB e`: the value is e.
  static const arg = 3;
}

/// The `(16001)`+ library routines' services (R4), each PETITIONed by the routine of the same
/// number, and the variables each reads and writes, in the order the host takes them.
const libraryServices = <int, ({List<String> scalars, List<String> arrays})>{
  16001: (scalars: [], arrays: [',1']),
  16010: (scalars: [], arrays: [',1']),
  16020: (scalars: ['.1'], arrays: [',1', ',2']),
  16030: (scalars: ['.1'], arrays: [',1', ',2']),
  16040: (scalars: ['.1'], arrays: [',1', ',2']),
  16050: (scalars: ['.1'], arrays: [',1', ',2']),
  16060: (scalars: [], arrays: [',1']),
  16100: (scalars: ['.1'], arrays: []),
  16110: (scalars: [], arrays: [',1', ',2']),
  16120: (scalars: [], arrays: [',1', ',2']),
  16130: (scalars: [], arrays: [',1']),
  16200: (scalars: [':1', ':2'], arrays: [',1']),
  16210: (scalars: [':1'], arrays: []),
};

/// The services that reach the database, which a program that uses any of needs ActiveCassette for.
const databaseServices = {16200, 16210, 16600, 16610, 16620, 16630, 16640};
