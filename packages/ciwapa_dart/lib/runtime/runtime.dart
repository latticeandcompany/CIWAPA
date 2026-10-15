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
  _arrays = List.generate(arrayCount, (_) => _Array());
  _rngState = DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

// ---- Errors (§9) -----------------------------------------------------------------------------

Never _error(int code, String? text, int next) {
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

Never ickGiveUp() => exit(0);

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
