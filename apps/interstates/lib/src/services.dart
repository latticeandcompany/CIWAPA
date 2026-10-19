/// The host services Interstates statements turn into (HostCall), which a program can't name with
/// PETITION. Their values are documented beside each, in the order the host takes them.
abstract final class HostService {
  /// `READ OUT #n WITH TEMPLATE`: the template's number, then a value for each of its pieces that
  /// needs one.
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
