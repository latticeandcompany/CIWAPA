// The runtime that ciwapa-dart copies next to every generated program. runtime.c is its twin;
// the conformance suite keeps the two byte-for-byte identical in behavior.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class IckMessage {
  const IckMessage(this.text, this.joke);

  final String text;
  final String joke;
}

class _Shape {
  _Shape(this.dims, this.data);

  final Uint32List dims;
  final Uint32List data;

  int get rank => dims.length;
}

class _Array {
  _Shape shape = _Shape(Uint32List(0), Uint32List(0));
  bool ignored = false;
}

late Map<int, IckMessage> _messages;
late Uint32List _values;
late Uint8List _ignored;
late List<List<int>> _scalarStashes;
late List<List<_Shape>> _arrayStashes;
late int _smallMax;
late int _largeMax;
late bool _clockface;
late List<_Array> _arrays;
int _rngState = 0;

const _smallDigits = [0, 0, 16, 10, 8, 6, 6, 5];

void ickInit(
  List<String> args, {
  required int base,
  required bool clockface,
  required int arrayCount,
  required Uint32List values,
  required Uint8List ignored,
  required Map<int, IckMessage> messages,
}) {
  _messages = messages;
  _values = values;
  _ignored = ignored;
  _scalarStashes = List.generate(values.length, (_) => <int>[]);
  _arrayStashes = List.generate(arrayCount, (_) => <_Shape>[]);
  var max = 1;
  for (var i = 0; i < _smallDigits[base]; i++) {
    max *= base;
  }
  _smallMax = max - 1;
  _largeMax = base == 2 ? 0xFFFFFFFF : max * max - 1;
  _clockface = clockface;
  _arrays = List.generate(arrayCount, (_) => _Array());
  _rngState = DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

// ---- Errors (§9) -----------------------------------------------------------------------------

// ---- Output ----------------------------------------------------------------------------------

/// Everything bound for stdout goes through one buffer, flushed at every newline, when full, before
/// every read and at exit, so numbers and Turing Text characters keep their order (decision T31).
final _output = Uint8List(4096);
var _outputLength = 0;

/// Where output bytes go: stdout, or a test's own sink.
void Function(List<int>) ickWriteBytes = stdout.add;

void _writeByte(int b) {
  if (_outputLength == _output.length) _flush();
  _output[_outputLength++] = b;
}

void _write(List<int> bytes) {
  for (final b in bytes) {
    _writeByte(b);
  }
}

void _flush() {
  if (_outputLength == 0) return;
  ickWriteBytes(
    Uint8List.fromList(Uint8List.sublistView(_output, 0, _outputLength)),
  );
  _outputLength = 0;
}

/// Where input bytes come from: stdin, or a test's own source. -1 is the end of input, and so is
/// an unreadable stdin, as in C.
int Function() ickReadByte = () {
  try {
    return stdin.readByteSync();
  } on StdinException {
    return -1;
  }
};

Never _error(int code, String? text, int next) {
  _flush();
  final message = _messages[code];
  stderr.add(
    utf8.encode(
      'ICL${code.toString().padLeft(3, '0')}I ${text ?? message?.text ?? ''}\n'
      '        ${message?.joke ?? ''}\n'
      '\tON THE WAY TO STATEMENT $next\n'
      '        CORRECT SOURCE AND RESUBMIT\n',
    ),
  );
  exit(code % 256);
}

Never ickFatal(int code, int next) => _error(code, null, next);

Never ickUndecodable(String text, int next) => _error(0, text, next);

Never ickGiveUp() {
  _flush();
  exit(0);
}

// ---- The NEXT stack (§4.4.2–§4.4.4, decisions T16, T17) ---------------------------------------

const _nextDepth = 79;
final _nextStack = Int64List(_nextDepth);
var _nextCount = 0;

/// [target] is the NEXT's target ordinal: the statement that would have run next.
void ickNextPush(int id, int target) {
  if (_nextCount == _nextDepth) ickFatal(123, target);
  _nextStack[_nextCount++] = id;
}

void ickForget(int count) {
  _nextCount = count >= _nextCount ? 0 : _nextCount - count;
}

int ickResume(int count, int next) {
  if (count == 0) ickFatal(621, next);
  if (count > _nextCount) ickFatal(632, next);
  _nextCount -= count;
  return _nextStack[_nextCount];
}

// ---- Randomness (§4.3, decision T22) ------------------------------------------------------------

int _nextRandom() {
  var z = _rngState += 0x9E3779B97F4A7C15;
  z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
  z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
  return z ^ (z >>> 31);
}

bool ickRoll(int percent) => (_nextRandom() >>> 1) % 100 < percent;

// ---- Binary operators (§3.4) -------------------------------------------------------------------

int ickMingle(int left, int right, int next) {
  if (left > _smallMax || right > _smallMax) ickFatal(533, next);
  var result = 0;
  for (var i = 15; i >= 0; i--) {
    result = (result << 2) | (((left >> i) & 1) << 1) | ((right >> i) & 1);
  }
  return result;
}

int ickSelect(int value, int mask) {
  var result = 0, bit = 1;
  for (; mask != 0; mask &= mask - 1) {
    if (value & mask & -mask != 0) result |= bit;
    bit <<= 1;
  }
  return result;
}

// Rotating right by one and combining with the original pairs every bit with its neighbor, the
// last bit wrapping around to the first (§3.4.2).
int _rotate16(int x) => ((x >> 1) | (x << 15)) & 0xFFFF;
int _rotate32(int x) => ((x >> 1) | (x << 31)) & 0xFFFFFFFF;

int ickAnd16(int x) => x & _rotate16(x);
int ickOr16(int x) => x | _rotate16(x);
int ickXor16(int x) => x ^ _rotate16(x);
int ickAnd32(int x) => x & _rotate32(x);
int ickOr32(int x) => x | _rotate32(x);
int ickXor32(int x) => x ^ _rotate32(x);

// ---- Assignment (§4.4.1) ----------------------------------------------------------------------

/// A small target takes values up to the small maximum (decision Q76), and E275 fires even when
/// the target is IGNOREd (decision T24).
int ickCheckSmall(int value, int next) {
  if (value > _smallMax) ickFatal(275, next);
  return value;
}

// ---- Arrays (§3.3, §4.4.1, decision T26) --------------------------------------------------------

/// More elements than this can't be allocated on any machine, so it's E241 without asking. Below
/// it, the allocation itself decides (decisions T26, T27). runtime.c uses the same bound.
const _maxElements = 1 << 61;

void ickDimension(int index, List<int> dims, int next) {
  final a = _arrays[index];
  for (final d in dims) {
    if (d == 0) ickFatal(240, next);
  }
  if (a.ignored) return;
  var size = 1;
  for (final d in dims) {
    if (d > _maxElements ~/ size) ickFatal(241, next);
    size *= d;
  }
  final Uint32List data;
  try {
    data = Uint32List(size);
  } on Error {
    // Too large to allocate (decision T26). There is no artificial cap (decision T27).
    ickFatal(241, next);
  }
  a.shape = _Shape(Uint32List.fromList(dims), data);
}

/// The offset of an element in [ickArrayData], after checking the subscripts.
int ickElement(int index, List<int> subscripts, int next) {
  final a = _arrays[index].shape;
  if (subscripts.length != a.rank) ickFatal(241, next);
  var offset = 0;
  for (var i = 0; i < subscripts.length; i++) {
    final s = subscripts[i];
    if (s == 0 || s > a.dims[i]) ickFatal(241, next);
    offset = offset * a.dims[i] + s - 1;
  }
  return offset;
}

Uint32List ickArrayData(int index) => _arrays[index].shape.data;

bool ickArrayIgnored(int index) => _arrays[index].ignored;

void ickArraySetIgnored(int index, bool ignored) =>
    _arrays[index].ignored = ignored;

// ---- STASH and RETRIEVE (§4.4.5, §4.4.6, decisions T24, T25) ------------------------------------

/// The only limit on a stash is memory; running out is E222.
void _push<T>(List<T> stash, T Function() copy, int next) {
  try {
    stash.add(copy());
  } on OutOfMemoryError {
    ickFatal(222, next);
  }
}

void ickStashScalar(int slot, int next) =>
    _push(_scalarStashes[slot], () => _values[slot], next);

void ickRetrieveScalar(int slot, int next) {
  final stash = _scalarStashes[slot];
  if (stash.isEmpty) ickFatal(436, next);
  final value = stash.removeLast();
  if (_ignored[slot] == 0) _values[slot] = value;
}

void ickStashArray(int index, int next) {
  final a = _arrays[index].shape;
  _push(
    _arrayStashes[index],
    () => _Shape(Uint32List.fromList(a.dims), Uint32List.fromList(a.data)),
    next,
  );
}

/// Restores the old dimensions too, even into a currently undimensioned array (decision T25).
void ickRetrieveArray(int index, int next) {
  final stash = _arrayStashes[index];
  if (stash.isEmpty) ickFatal(436, next);
  final saved = stash.removeLast();
  if (!_arrays[index].ignored) _arrays[index].shape = saved;
}

// ---- WRITE IN (§4.4.12, decisions T28, T29) -----------------------------------------------------

const _numerals = {
  'OH': 0,
  'ZERO': 0,
  'ONE': 1,
  'TWO': 2,
  'THREE': 3,
  'FOUR': 4,
  'FIVE': 5,
  'SIX': 6,
  'SEVEN': 7,
  'EIGHT': 8,
  'NINE': 9,
  'NINER': 9,
  'SUTYA': 0,
  'SHUTYA': 0,
  'EKA': 1,
  'DVI': 2,
  'TRI': 3,
  'CHATUR': 4,
  'PANCHAN': 5,
  'SHASH': 6,
  'SAPTAM': 7,
  'ASHTAN': 8,
  'NAVAN': 9,
  'ZEROA': 0,
  'BAT': 1,
  'BI': 2,
  'HIRO': 3,
  'LAU': 4,
  'BORTZ': 5,
  'SEI': 6,
  'ZAZPI': 7,
  'ZORTZI': 8,
  'BEDERATZI': 9,
  'WALA': 0,
  'ISA': 1,
  'DALAWA': 2,
  'TATLO': 3,
  'APAT': 4,
  'LIMA': 5,
  'ANIM': 6,
  'PITO': 7,
  'WALO': 8,
  'SIYAM': 9,
  'AHTLE': 0,
  'CE': 1,
  'OME': 2,
  'IEI': 3,
  'NAUI': 4,
  'NACUILI': 5,
  'CHIQUACE': 6,
  'CHICOME': 7,
  'CHICUE': 8,
  'CHICUNAUI': 9,
  'NULI': 0,
  'ERTI': 1,
  'ORI': 2,
  'SAMI': 3,
  'OTXI': 4,
  'XUTI': 5,
  'EKSVI': 6,
  'SHVIDI': 7,
  'RVA': 8,
  'CXRA': 9,
  'KE\'YOS': 0,
  '\'NEM': 1,
  'MAL\'H': 2,
  'YUDEXW': 3,
  'MU': 4,
  'SEK\'A': 5,
  'Q\'ETL\'A': 6,
  'ETLEBU': 7,
  'MALHGWENALH': 8,
  '\'NA\'NE\'MA': 9,
  'NOS': 0,
  'BAL': 1,
  'TEL': 2,
  'KIL': 3,
  'FOL': 4,
  'LUL': 5,
  'M\\"AL': 6,
  'MÄL': 6,
  'VEL': 7,
  'J\\"OL': 8,
  'JÖL': 8,
  'Z\\"UL': 9,
  'ZÜL': 9,
};

/// The number words as raw UTF-8 bytes (one char per byte), so input is matched byte for byte.
final _numeralBytes = {
  for (final MapEntry(:key, :value) in _numerals.entries)
    String.fromCharCodes(utf8.encode(key)): value,
};

/// Reads one line, without its newline, or null at the end of input with nothing read. A final
/// line without a newline keeps every character (decision T28).
List<int>? _readLine() {
  _flush();
  final line = <int>[];
  while (true) {
    final c = ickReadByte();
    if (c == -1) return line.isEmpty ? null : line;
    if (c == 0x0A) return line;
    line.add(c);
  }
}

/// One number per line, each digit a word separated by spaces: E562 for a blank line or the end
/// of input, E579 for an unknown word, E533 past 32 bits or the base's large maximum.
int ickWriteIn(int next) {
  final line = _readLine();
  if (line == null) ickFatal(562, next);
  var result = 0, digits = 0, i = 0;
  while (i < line.length) {
    while (i < line.length && line[i] == 0x20) {
      i++;
    }
    if (i == line.length) break;
    final start = i;
    while (i < line.length && line[i] != 0x20) {
      i++;
    }
    final digit = _numeralBytes[String.fromCharCodes(line, start, i)];
    if (digit == null) ickFatal(579, next);
    result = result * 10 + digit;
    if (result > 0xFFFFFFFF) ickFatal(533, next);
    digits++;
  }
  if (digits == 0) ickFatal(562, next);
  if (result > _largeMax) ickFatal(533, next);
  return result;
}

// ---- READ OUT (§4.4.13, decision T30) -----------------------------------------------------------

// Butchered Roman numerals, by C-INTERCAL's butcher() algorithm. For each decimal digit, the
// pattern says how many symbols to write and which columns of the digit's row they come from.
const _romanPatterns = [
  [0, 0, 0, 0, 0],
  [1, 0, 0, 0, 0],
  [2, 0, 0, 0, 0],
  [3, 0, 0, 0, 0],
  [2, 1, 2, 0, 0], //
  [1, 2, 0, 0, 0],
  [2, 2, 1, 0, 0],
  [3, 2, 1, 1, 0],
  [4, 2, 1, 1, 1],
  [2, 1, 3, 0, 0],
];
const _clockfaceFour = [4, 0, 0, 0, 0];

// Four columns per digit position because of the odd way M and I interact.
const _romanSymbols = [
  'IIVX',
  'XXLC',
  'CCDM',
  'MIVX',
  'XXLC',
  'CCDM',
  'Mivx',
  'xxlc',
  'ccdm',
  'mivx',
];
const _romanBars = [
  '    ',
  '    ',
  '    ',
  ' ___',
  '____',
  '____',
  '_   ',
  '    ',
  '    ',
  ' ___',
];

void ickReadOut(int value) {
  if (value == 0) {
    _write(const [0x5F, 0x0A, 0x0A]);
    _flush();
    return;
  }
  final numeral = StringBuffer(), bars = StringBuffer();
  final symbols = <String>[], marks = <String>[];
  for (var position = 0; position < 10 && value > 0; position++) {
    final digit = value % 10;
    final pattern = digit == 4 && _clockface
        ? _clockfaceFour
        : _romanPatterns[digit];
    for (var j = pattern[0]; j > 0; j--) {
      symbols.add(_romanSymbols[position][pattern[j]]);
      marks.add(_romanBars[position][pattern[j]]);
    }
    value ~/= 10;
  }
  for (var i = symbols.length - 1; i >= 0; i--) {
    numeral.write(symbols[i]);
    bars.write(marks[i]);
  }
  _write(utf8.encode('$bars\n$numeral\n'));
  _flush();
}

// ---- Turing Text (§5.2, decision T31) -----------------------------------------------------------

var _lastIn = 0, _lastOut = 0;

int _turingArray(int index, int next) {
  final shape = _arrays[index].shape;
  if (shape.rank != 1) ickFatal(241, next);
  return shape.dims[0];
}

/// Each element gets the distance along the input tape from the previous character, mod 256; the
/// end of input reads as 256. After it, the previous character is -1, so the next character reads
/// as itself + 1, as in C-INTERCAL.
void ickTuringIn(int index, int next) {
  final length = _turingArray(index, next);
  final a = _arrays[index];
  _flush();
  for (var i = 0; i < length; i++) {
    final c = ickReadByte();
    final value = c == -1 ? 256 : (c - _lastIn) & 0xFF;
    _lastIn = c & 0xFFFFFFFF;
    if (!a.ignored) a.shape.data[i] = value;
  }
}

/// Each element is subtracted from the last character written (the subtraction is kept as is for
/// the next one), and the result's low 8 bits go out in reverse order.
void ickTuringOut(int index, int next) {
  final length = _turingArray(index, next);
  final data = _arrays[index].shape.data;
  for (var i = 0; i < length; i++) {
    final c = (_lastOut - data[i]) & 0xFFFFFFFF;
    _lastOut = c;
    var b = c & 0xFF;
    b = ((b & 0x0F) << 4) | ((b & 0xF0) >> 4);
    b = ((b & 0x33) << 2) | ((b & 0xCC) >> 2);
    b = ((b & 0x55) << 1) | ((b & 0xAA) >> 1);
    _writeByte(b);
    if (b == 0x0A) _flush();
  }
}
