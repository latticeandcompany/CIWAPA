/* The runtime that ciwapa-llvm links into every program. runtime.dart is its twin; the
 * conformance suite keeps the two byte-for-byte identical in behavior. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Where input bytes come from, and how stdout is flushed; runtime_test.c substitutes its own. */
#ifndef ICK_GETCHAR
#define ICK_GETCHAR() ick_getchar()
#endif
#ifndef ICK_FLUSH
#define ICK_FLUSH() fflush(stdout)
#endif
#ifndef ICK_TIME
#define ICK_TIME() time(NULL)
#endif

/* stdio's end of input is sticky, but after an end of input on a terminal the program may read
 * on, and the next character reads as itself + 1 (decision T31), so the flag is cleared. */
static int ick_getchar(void) {
  int c = getchar();
  if (c == EOF) clearerr(stdin);
  return c;
}

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

typedef struct {
  uint32_t code;
  const char *text;
  const char *joke;
} ick_message;

typedef struct {
  uint32_t rank;
  uint32_t *dims;
  uint32_t *data;
  size_t size;
} ick_shape;

typedef struct {
  ick_shape shape;
  uint32_t ignored;
} ick_array;

typedef struct {
  uint32_t *items;
  size_t count, capacity;
} ick_value_stash;

typedef struct {
  ick_shape *items;
  size_t count, capacity;
} ick_array_stash;

typedef struct {
  uint32_t base;
  uint32_t clockface;
  uint32_t scalar_count;
  uint32_t array_count;
  uint32_t *values;
  uint8_t *ignored;
  const ick_message *messages;
  uint32_t message_count;
} ick_program;

static const ick_program *program;
static int wimp_mode;
static uint32_t base;
static uint32_t digits;
static uint32_t small_max;
static uint32_t large_max;
static ick_array *arrays;
static ick_value_stash *scalar_stashes;
static ick_array_stash *array_stashes;
static uint64_t rng_state;

static uint32_t pow_u32(uint32_t base, uint32_t exponent) {
  uint32_t result = 1;
  while (exponent--) result *= base;
  return result;
}

static uint32_t small_digits(uint32_t base) {
  static const uint32_t digits[] = {0, 0, 16, 10, 8, 6, 6, 5};
  return digits[base];
}

static void parse_options(int argc, char **argv);

/* A seed is decimal digits for a value below 2^63. */
static int parse_seed(const char *text) {
  uint64_t value = 0;
  if (!*text) return 0;
  for (const char *p = text; *p; p++) {
    if (*p < '0' || *p > '9') return 0;
    if (value > ((((uint64_t)1 << 63) - 1) - (uint64_t)(*p - '0')) / 10) return 0;
    value = value * 10 + (uint64_t)(*p - '0');
  }
  rng_state = value;
  return 1;
}

void ick_init(int argc, char **argv, const ick_program *p) {
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
  _setmode(_fileno(stderr), _O_BINARY);
#endif
  program = p;
  base = p->base;
  digits = small_digits(p->base);
  small_max = p->base == 2 ? 65535u : pow_u32(p->base, small_digits(p->base)) - 1;
  large_max = p->base == 2 ? 0xFFFFFFFFu : (small_max + 1) * (small_max + 1) - 1;
  arrays = calloc(p->array_count ? p->array_count : 1, sizeof(ick_array));
  scalar_stashes = calloc(p->scalar_count ? p->scalar_count : 1, sizeof(ick_value_stash));
  array_stashes = calloc(p->array_count ? p->array_count : 1, sizeof(ick_array_stash));
  rng_state = (uint64_t)ICK_TIME();
  parse_options(argc, argv);
}

/* ---- Errors (§9) ------------------------------------------------------------------------- */

/* [text] is written with its length, so a NUL inside an undecodable statement prints too. */
static void print_error(uint32_t code, const char *text, size_t length, uint32_t next) {
  const char *joke = "";
  for (uint32_t i = 0; i < program->message_count; i++) {
    if (program->messages[i].code == code) {
      if (!text) {
        text = program->messages[i].text;
        length = strlen(text);
      }
      joke = program->messages[i].joke;
      break;
    }
  }
  fflush(stdout);
  fprintf(stderr, "ICL%03uI ", (unsigned)code);
  if (text) fwrite(text, 1, length, stderr);
  fprintf(stderr, "\n        %s\n\tON THE WAY TO STATEMENT %u\n        CORRECT SOURCE AND RESUBMIT\n", joke,
          (unsigned)next);
  fflush(stderr);
}

void ick_fatal(uint32_t code, uint32_t next) {
  print_error(code, NULL, 0, next);
  exit((int)(code % 256));
}

void ick_undecodable(const char *text, uint32_t length, uint32_t next) {
  print_error(0, text, length, next);
  exit(0);
}

void ick_give_up(void) {
  fflush(stdout);
  exit(0);
}

/* ---- The NEXT stack (§4.4.2–§4.4.4, decisions T16, T17) ------------------------------- */

#define NEXT_DEPTH 79

static uint32_t next_stack[NEXT_DEPTH];
static uint32_t next_depth;

/* [target] is the NEXT's target ordinal: the statement that would have run next. */
void ick_next_push(uint32_t id, uint32_t target) {
  if (next_depth == NEXT_DEPTH) ick_fatal(123, target);
  next_stack[next_depth++] = id;
}

void ick_forget(uint32_t count) {
  next_depth = count >= next_depth ? 0 : next_depth - count;
}

uint32_t ick_resume(uint32_t count, uint32_t next) {
  if (count == 0) ick_fatal(621, next);
  if (count > next_depth) ick_fatal(632, next);
  next_depth -= count;
  return next_stack[next_depth];
}

uint32_t ick_next_free(void) { return NEXT_DEPTH - next_depth; }

/* ---- Native system library routines (§7.2, decision Q37) ------------------------------ */

#define OVERFLOW ((uint64_t)1 << 32)

static int64_t exact(uint64_t r, uint64_t max) { return r > max ? -1 : (int64_t)r; }

static int64_t flagged(uint64_t r, uint64_t max) {
  return (int64_t)((r & max) | (r > max ? OVERFLOW : 0));
}

static int product_overflows(uint64_t a, uint64_t b) { return b != 0 && a > 0xFFFFFFFFu / b; }

/* Runs library routine [label] on [a] and [b]. Returns the result in the low 32 bits, with bit
 * 32 set when a routine with an overflow flag overflowed, or -1 when the INTERCAL routine has to
 * run instead because it would take its error exit. */
int64_t ick_syslib(uint32_t label, uint32_t a32, uint32_t b32) {
  uint64_t a = a32, b = b32;
  switch (label) {
  case 1000: return exact(a + b, 0xFFFF);
  case 1009: return flagged(a + b, 0xFFFF);
  case 1010: return (a - b) & 0xFFFF;
  case 1020: return (a + 1) & 0xFFFF;
  case 1030: return exact(a * b, 0xFFFF);
  case 1039: return flagged(a * b, 0xFFFF);
  case 1040:
  case 1550: return b == 0 ? 0 : (int64_t)(a / b);
  case 1050: return b == 0 ? 0 : exact(a / b, 0xFFFF);
  case 1060: return a | b;
  case 1070: return a & b;
  case 1080: return a ^ b;
  case 1500: return exact(a + b, 0xFFFFFFFF);
  case 1509: return flagged(a + b, 0xFFFFFFFF);
  case 1510: return (a - b) & 0xFFFFFFFF;
  case 1520: return a << 16 | b;
  case 1525: return a << 8 & 0xFFFF;
  case 1530: return (int64_t)(a * b);
  case 1540: return product_overflows(a, b) ? -1 : (int64_t)(a * b);
  case 1549: return (int64_t)((a * b & 0xFFFFFFFF) | (product_overflows(a, b) ? OVERFLOW : 0));
  default: return -1;
  }
}

/* ---- Randomness (§4.3, decision T22) ---------------------------------------------------- */

static uint64_t next_random(void) {
  uint64_t z = (rng_state += 0x9E3779B97F4A7C15ull);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
  return z ^ (z >> 31);
}

uint32_t ick_roll(uint32_t percent) { return (uint32_t)((next_random() >> 1) % 100) < percent; }

/* ---- Binary operators (§3.4) ------------------------------------------------------------- */

/* Bases 3-7 call these helpers with a constant base, so the compiler turns every division by it
 * into a multiplication. [count] digits of [value] go into [out], lowest first. */
static inline void split_digits(uint32_t b, uint64_t value, uint32_t count, uint8_t *out) {
  for (uint32_t i = 0; i < count; i++) {
    out[i] = (uint8_t)(value % b);
    value /= b;
  }
}

/* The left operand supplies the high digit of each pair (§6.5.1). */
static inline uint32_t mingle_in(uint32_t b, uint32_t d, uint32_t left, uint32_t right) {
  uint8_t l[16], r[16];
  split_digits(b, left, d, l);
  split_digits(b, right, d, r);
  uint64_t result = 0;
  for (uint32_t i = d; i-- > 0;) result = (result * b + l[i]) * b + r[i];
  return (uint32_t)result;
}

uint32_t ick_mingle(uint32_t left, uint32_t right, uint32_t next) {
  if (left > small_max || right > small_max) ick_fatal(533, next);
  uint32_t result = 0;
  if (base != 2) {
    switch (base) {
    case 3: return mingle_in(3, 10, left, right);
    case 4: return mingle_in(4, 8, left, right);
    case 5: return mingle_in(5, 6, left, right);
    case 6: return mingle_in(6, 6, left, right);
    default: return mingle_in(7, 5, left, right);
    }
  }
  for (int i = 15; i >= 0; i--) {
    result = (result << 2) | (((left >> i) & 1u) << 1) | ((right >> i) & 1u);
  }
  return result;
}

/* §6.5.2.2: AND each digit with its selector digit (0 if either is 0, otherwise the larger),
 * then pack the digits under selector b-1 at the low end, then those under b-2, down to 1. */
static inline uint32_t select_in(uint32_t b, uint32_t d, uint32_t value, uint32_t mask) {
  uint8_t v[32], m[32];
  split_digits(b, value, 2 * d, v);
  split_digits(b, mask, 2 * d, m);
  uint64_t result = 0, out = 1;
  for (uint32_t selector = b - 1; selector > 0; selector--) {
    for (uint32_t i = 0; i < 2 * d; i++) {
      if (m[i] == selector) {
        if (v[i]) result += out * (v[i] > selector ? v[i] : selector);
        out *= b;
      }
    }
  }
  return (uint32_t)result;
}

static uint32_t select_digits(uint32_t value, uint32_t mask) {
  switch (base) {
  case 3: return select_in(3, 10, value, mask);
  case 4: return select_in(4, 8, value, mask);
  case 5: return select_in(5, 6, value, mask);
  case 6: return select_in(6, 6, value, mask);
  default: return select_in(7, 5, value, mask);
  }
}

uint32_t ick_select(uint32_t value, uint32_t mask) {
  if (base != 2) return select_digits(value, mask);
  uint32_t result = 0, bit = 1;
  for (; mask; mask &= mask - 1) {
    if (value & mask & (0u - mask)) result |= bit;
    bit <<= 1;
  }
  return result;
}

/* Rotating right by one and combining with the original pairs every bit with its neighbor,
 * the last bit wrapping around to the first (§3.4.2). */
static uint32_t rotate16(uint32_t x) { return ((x >> 1) | (x << 15)) & 0xFFFFu; }
static uint32_t rotate32(uint32_t x) { return (x >> 1) | (x << 31); }

/* §6.5.2.1, §6.6: the digit-wise unary operators of bases 3–7. Each digit is combined with the
 * next one up, the top digit wrapping around to the bottom, as rotating right and combining does
 * in binary. The logical operators all prefer one digit p: AND prefers 0, OR prefers b-1, BUT
 * prefers 1 and N@ prefers N. ? subtracts without borrow and ^ adds without carry. */
enum { ICK_LOGICAL, ICK_MINUS, ICK_PLUS };

/* Combines each digit with its neighbor, the last wrapping around to the first (§6.5.2). */
static inline uint32_t digitwise_in(uint32_t b, uint32_t length, uint32_t kind, uint32_t p, uint32_t n) {
  uint8_t d[32];
  split_digits(b, n, length, d);
  uint64_t result = 0;
  for (uint32_t i = length; i-- > 0;) {
    uint32_t below = d[i], here = d[i + 1 == length ? 0 : i + 1];
    uint32_t digit;
    if (kind == ICK_MINUS) {
      digit = (b + here - below) % b;
    } else if (kind == ICK_PLUS) {
      digit = (here + below) % b;
    } else if (here <= p) {
      digit = (below < here || below > p) ? here : below;
    } else {
      digit = (below < here && below > p) ? here : below;
    }
    result = result * b + digit;
  }
  return (uint32_t)result;
}

static uint32_t digitwise(uint32_t kind, uint32_t large, uint32_t p, uint32_t n) {
  uint32_t length = large ? 2 * digits : digits;
  switch (base) {
  case 3: return digitwise_in(3, length, kind, p, n);
  case 4: return digitwise_in(4, length, kind, p, n);
  case 5: return digitwise_in(5, length, kind, p, n);
  case 6: return digitwise_in(6, length, kind, p, n);
  default: return digitwise_in(7, length, kind, p, n);
  }
}

uint32_t ick_logical(uint32_t large, uint32_t p, uint32_t n) { return digitwise(ICK_LOGICAL, large, p, n); }
uint32_t ick_minus(uint32_t large, uint32_t n) { return digitwise(ICK_MINUS, large, 0, n); }
uint32_t ick_plus(uint32_t large, uint32_t n) { return digitwise(ICK_PLUS, large, 0, n); }

uint32_t ick_and16(uint32_t x) { return x & rotate16(x); }
uint32_t ick_or16(uint32_t x) { return x | rotate16(x); }
uint32_t ick_xor16(uint32_t x) { return x ^ rotate16(x); }
uint32_t ick_and32(uint32_t x) { return x & rotate32(x); }
uint32_t ick_or32(uint32_t x) { return x | rotate32(x); }
uint32_t ick_xor32(uint32_t x) { return x ^ rotate32(x); }

/* ---- Assignment (§4.4.1) ----------------------------------------------------------------- */

/* A small target takes values up to the small maximum (decision Q76), and E275 fires even when
 * the target is IGNOREd (decision T24). */
uint32_t ick_check_small(uint32_t value, uint32_t next) {
  if (value > small_max) ick_fatal(275, next);
  return value;
}

/* ---- Arrays (§3.3, §4.4.1, decision T26) ------------------------------------------------- */

/* More elements than this can't be allocated on any machine, so it's E241 without asking.
 * Below it, the allocation itself decides (decisions T26, T27). runtime.dart uses the same bound. */
#define ICK_MAX_ELEMENTS ((uint64_t)1 << 61)

void ick_dimension(uint32_t index, uint32_t rank, const uint32_t *dims, uint32_t next) {
  ick_array *a = &arrays[index];
  uint64_t size = 1;
  for (uint32_t i = 0; i < rank; i++) {
    if (dims[i] == 0) ick_fatal(240, next);
  }
  if (a->ignored) return;
  for (uint32_t i = 0; i < rank; i++) {
    if (dims[i] > ICK_MAX_ELEMENTS / size) ick_fatal(241, next);
    size *= dims[i];
  }
  uint32_t *data = calloc((size_t)size, sizeof(uint32_t));
  uint32_t *copy = malloc(rank * sizeof(uint32_t));
  if (!data || !copy) ick_fatal(241, next);
  memcpy(copy, dims, rank * sizeof(uint32_t));
  free(a->shape.data);
  free(a->shape.dims);
  a->shape = (ick_shape){rank, copy, data, (size_t)size};
}

uint32_t *ick_element(uint32_t index, uint32_t count, const uint32_t *subscripts, uint32_t next) {
  ick_shape *a = &arrays[index].shape;
  if (count != a->rank) ick_fatal(241, next);
  size_t offset = 0;
  for (uint32_t i = 0; i < count; i++) {
    if (subscripts[i] == 0 || subscripts[i] > a->dims[i]) ick_fatal(241, next);
    offset = offset * a->dims[i] + subscripts[i] - 1;
  }
  return &a->data[offset];
}

uint32_t ick_array_ignored(uint32_t index) { return arrays[index].ignored; }

void ick_array_set_ignored(uint32_t index, uint32_t ignored) { arrays[index].ignored = ignored; }

/* ---- STASH and RETRIEVE (§4.4.5, §4.4.6, decisions T24, T25) --------------------------- */

/* Grows a stash; the only limit is memory, and running out is E222. */
static void *grow(void *items, size_t *capacity, size_t item_size, uint32_t next) {
  size_t wanted = *capacity ? *capacity * 2 : 4;
  void *grown = realloc(items, wanted * item_size);
  if (!grown) ick_fatal(222, next);
  *capacity = wanted;
  return grown;
}

void ick_stash_scalar(uint32_t slot, uint32_t next) {
  ick_value_stash *s = &scalar_stashes[slot];
  if (s->count == s->capacity) s->items = grow(s->items, &s->capacity, sizeof(uint32_t), next);
  s->items[s->count++] = program->values[slot];
}

void ick_retrieve_scalar(uint32_t slot, uint32_t next) {
  ick_value_stash *s = &scalar_stashes[slot];
  if (s->count == 0) ick_fatal(436, next);
  uint32_t value = s->items[--s->count];
  if (!program->ignored[slot]) program->values[slot] = value;
}

void ick_stash_array(uint32_t index, uint32_t next) {
  ick_array_stash *s = &array_stashes[index];
  ick_shape *a = &arrays[index].shape;
  if (s->count == s->capacity) s->items = grow(s->items, &s->capacity, sizeof(ick_shape), next);
  ick_shape copy = {a->rank, NULL, NULL, a->size};
  if (a->rank) {
    copy.dims = malloc(a->rank * sizeof(uint32_t));
    copy.data = malloc(a->size * sizeof(uint32_t));
    if (!copy.dims || !copy.data) ick_fatal(222, next);
    memcpy(copy.dims, a->dims, a->rank * sizeof(uint32_t));
    memcpy(copy.data, a->data, a->size * sizeof(uint32_t));
  }
  s->items[s->count++] = copy;
}

/* Restores the old dimensions too, even into a currently undimensioned array (decision T25). */
void ick_retrieve_array(uint32_t index, uint32_t next) {
  ick_array_stash *s = &array_stashes[index];
  if (s->count == 0) ick_fatal(436, next);
  ick_shape saved = s->items[--s->count];
  ick_array *a = &arrays[index];
  if (a->ignored) {
    free(saved.dims);
    free(saved.data);
    return;
  }
  free(a->shape.dims);
  free(a->shape.data);
  a->shape = saved;
}

/* ---- WRITE IN (§4.4.12, decisions T28, T29) -------------------------------------------- */

static const struct { const char *word; uint32_t digit; } numerals[] = {
  {"OH", 0},
  {"ZERO", 0},
  {"ONE", 1},
  {"TWO", 2},
  {"THREE", 3},
  {"FOUR", 4},
  {"FIVE", 5},
  {"SIX", 6},
  {"SEVEN", 7},
  {"EIGHT", 8},
  {"NINE", 9},
  {"NINER", 9},
  {"SUTYA", 0},
  {"SHUTYA", 0},
  {"EKA", 1},
  {"DVI", 2},
  {"TRI", 3},
  {"CHATUR", 4},
  {"PANCHAN", 5},
  {"SHASH", 6},
  {"SAPTAM", 7},
  {"ASHTAN", 8},
  {"NAVAN", 9},
  {"ZEROA", 0},
  {"BAT", 1},
  {"BI", 2},
  {"HIRO", 3},
  {"LAU", 4},
  {"BORTZ", 5},
  {"SEI", 6},
  {"ZAZPI", 7},
  {"ZORTZI", 8},
  {"BEDERATZI", 9},
  {"WALA", 0},
  {"ISA", 1},
  {"DALAWA", 2},
  {"TATLO", 3},
  {"APAT", 4},
  {"LIMA", 5},
  {"ANIM", 6},
  {"PITO", 7},
  {"WALO", 8},
  {"SIYAM", 9},
  {"AHTLE", 0},
  {"CE", 1},
  {"OME", 2},
  {"IEI", 3},
  {"NAUI", 4},
  {"NACUILI", 5},
  {"CHIQUACE", 6},
  {"CHICOME", 7},
  {"CHICUE", 8},
  {"CHICUNAUI", 9},
  {"NULI", 0},
  {"ERTI", 1},
  {"ORI", 2},
  {"SAMI", 3},
  {"OTXI", 4},
  {"XUTI", 5},
  {"EKSVI", 6},
  {"SHVIDI", 7},
  {"RVA", 8},
  {"CXRA", 9},
  {"KE'YOS", 0},
  {"'NEM", 1},
  {"MAL'H", 2},
  {"YUDEXW", 3},
  {"MU", 4},
  {"SEK'A", 5},
  {"Q'ETL'A", 6},
  {"ETLEBU", 7},
  {"MALHGWENALH", 8},
  {"'NA'NE'MA", 9},
  {"NOS", 0},
  {"BAL", 1},
  {"TEL", 2},
  {"KIL", 3},
  {"FOL", 4},
  {"LUL", 5},
  {"M\\\"AL", 6},
  {"M\xC3""\x84""L", 6},
  {"VEL", 7},
  {"J\\\"OL", 8},
  {"J\xC3""\x96""L", 8},
  {"Z\\\"UL", 9},
  {"Z\xC3""\x9C""L", 9},
};

static char *line_buffer;
static size_t line_capacity;

/* Reads one line, without its newline. Returns 0 at end of input with nothing read. A final line
 * without a newline keeps every character (decision T28). */
static int read_line(size_t *length, uint32_t next) {
  size_t n = 0;
  int c;
  ICK_FLUSH();
  while ((c = ICK_GETCHAR()) != EOF && c != '\n') {
    if (n + 1 >= line_capacity) line_buffer = grow(line_buffer, &line_capacity, 1, next);
    line_buffer[n++] = (char)c;
  }
  if (c == EOF && n == 0) return 0;
  /* One \r before the \n goes, so CRLF input from Windows consoles works (decision L6). */
  if (c == '\n' && n > 0 && line_buffer[n - 1] == '\r') n--;
  if (!line_buffer) line_buffer = grow(line_buffer, &line_capacity, 1, next);
  line_buffer[n] = '\0';
  *length = n;
  return 1;
}

/* Wimp mode reads a line the way C's atoi does, with a 64-bit long: whitespace, a sign and
 * digits, saturating at the long's range, and keeping the low 32 bits (decision T32). */
static uint32_t wimp_number(void) {
  const char *p = line_buffer;
  while (*p == ' ' || (*p >= '\t' && *p <= '\r')) p++;
  int negative = *p == '-';
  if (*p == '-' || *p == '+') p++;
  uint64_t limit = negative ? (uint64_t)1 << 63 : ((uint64_t)1 << 63) - 1;
  uint64_t magnitude = 0;
  for (; *p >= '0' && *p <= '9'; p++) {
    uint64_t digit = (uint64_t)(*p - '0');
    magnitude = magnitude > (limit - digit) / 10 ? limit : magnitude * 10 + digit;
  }
  return (uint32_t)(negative ? 0 - magnitude : magnitude);
}

/* One number per line, each digit a word separated by spaces: E562 for a blank line or the end
 * of input, E579 for an unknown word, E533 past 32 bits or the base's large maximum. In
 * wimp mode, a decimal number per line, where a blank line reads as 0 (decision T32). */
uint32_t ick_write_in(uint32_t next) {
  size_t length;
  if (!read_line(&length, next)) ick_fatal(562, next);
  if (wimp_mode) {
    uint32_t value = wimp_number();
    if (value > large_max) ick_fatal(533, next);
    return value;
  }
  uint64_t result = 0;
  int digits = 0;
  size_t i = 0;
  while (i < length) {
    while (i < length && line_buffer[i] == ' ') i++;
    if (i == length) break;
    size_t start = i;
    while (i < length && line_buffer[i] != ' ') i++;
    size_t size = i - start;
    int digit = -1;
    for (size_t k = 0; k < sizeof numerals / sizeof numerals[0]; k++) {
      if (strlen(numerals[k].word) == size && memcmp(numerals[k].word, line_buffer + start, size) == 0) {
        digit = (int)numerals[k].digit;
        break;
      }
    }
    if (digit < 0) ick_fatal(579, next);
    result = result * 10 + (uint64_t)digit;
    if (result > 0xFFFFFFFFu) ick_fatal(533, next);
    digits++;
  }
  if (digits == 0) ick_fatal(562, next);
  if (result > large_max) ick_fatal(533, next);
  return (uint32_t)result;
}

/* ---- READ OUT (§4.4.13, decision T30) -------------------------------------------------- */

/* Butchered Roman numerals, by C-INTERCAL's butcher() algorithm. For each decimal digit, the
 * pattern says how many symbols to write and which columns of the digit's row they come from. */
static const int roman_patterns[10][5] = {
    {0, 0, 0, 0, 0}, {1, 0, 0, 0, 0}, {2, 0, 0, 0, 0}, {3, 0, 0, 0, 0}, {2, 1, 2, 0, 0},
    {1, 2, 0, 0, 0}, {2, 2, 1, 0, 0}, {3, 2, 1, 1, 0}, {4, 2, 1, 1, 1}, {2, 1, 3, 0, 0},
};
static const int clockface_four[5] = {4, 0, 0, 0, 0};

/* Four columns per digit position because of the odd way M and I interact. */
static const char roman_symbols[10][4] = {
    {'I', 'I', 'V', 'X'}, {'X', 'X', 'L', 'C'}, {'C', 'C', 'D', 'M'}, {'M', 'I', 'V', 'X'},
    {'X', 'X', 'L', 'C'}, {'C', 'C', 'D', 'M'}, {'M', 'i', 'v', 'x'}, {'x', 'x', 'l', 'c'},
    {'c', 'c', 'd', 'm'}, {'m', 'i', 'v', 'x'},
};
static const char roman_bars[10][4] = {
    {' ', ' ', ' ', ' '}, {' ', ' ', ' ', ' '}, {' ', ' ', ' ', ' '}, {' ', '_', '_', '_'},
    {'_', '_', '_', '_'}, {'_', '_', '_', '_'}, {'_', ' ', ' ', ' '}, {' ', ' ', ' ', ' '},
    {' ', ' ', ' ', ' '}, {' ', '_', '_', '_'},
};

void ick_read_out(uint32_t value) {
  if (wimp_mode) {
    printf("%u\n", (unsigned)value);
    ICK_FLUSH();
    return;
  }
  char numeral[48], bars[48];
  int at = 47;
  numeral[at] = bars[at] = '\0';
  if (value == 0) {
    fputs("_\n\n", stdout);
    fflush(stdout);
    return;
  }
  for (int position = 0; position < 10 && value > 0; position++) {
    uint32_t digit = value % 10;
    const int *pattern = digit == 4 && program->clockface ? clockface_four : roman_patterns[digit];
    for (int j = pattern[0]; j > 0; j--) {
      at--;
      numeral[at] = roman_symbols[position][pattern[j]];
      bars[at] = roman_bars[position][pattern[j]];
    }
    value /= 10;
  }
  printf("%s\n%s\n", bars + at, numeral + at);
  fflush(stdout);
}

/* ---- Turing Text (§5.2, decision T31) -------------------------------------------------- */

static uint32_t last_in, last_out;

static ick_shape *turing_array(uint32_t index, uint32_t next) {
  ick_shape *a = &arrays[index].shape;
  if (a->rank != 1) ick_fatal(241, next);
  return a;
}

/* Each element gets the distance along the input tape from the previous character, mod 256; the
 * end of input reads as 256. After it, the previous character is -1, so the next character reads
 * as itself + 1, as in C-INTERCAL. */
void ick_turing_in(uint32_t index, uint32_t next) {
  ick_shape *a = turing_array(index, next);
  ICK_FLUSH();
  for (uint32_t i = 0; i < a->dims[0]; i++) {
    int c = ICK_GETCHAR();
    uint32_t value = c == EOF ? 256 : ((uint32_t)c - last_in) & 0xFFu;
    last_in = (uint32_t)c;
    if (!arrays[index].ignored) a->data[i] = value;
  }
}

/* Each element is subtracted from the last character written (the subtraction is kept as is for
 * the next one), and the result's low 8 bits go out in reverse order. */
void ick_turing_out(uint32_t index, uint32_t next) {
  ick_shape *a = turing_array(index, next);
  for (uint32_t i = 0; i < a->dims[0]; i++) {
    uint32_t c = last_out - a->data[i];
    last_out = c;
    c &= 0xFFu;
    c = (c & 0x0Fu) << 4 | (c & 0xF0u) >> 4;
    c = (c & 0x33u) << 2 | (c & 0xCCu) >> 2;
    c = (c & 0x55u) << 1 | (c & 0xAAu) >> 1;
    putchar((int)c);
    if (c == '\n') ICK_FLUSH();
  }
}

/* ---- Runtime options (§10.3, decisions T32, T38, Q102) --------------------------------- */

static const char usage[] =
    "Runtime options, read up to the first argument without a sign:\n"
    "  +help, -help     print this, then give up with E778, as is tradition\n"
    "  +traditional     accepted, and does nothing\n"
    "  +wimpmode        read and write plain decimal numbers instead of words and Roman numerals\n"
    "  -wimpmode        the default: proper INTERCAL numbers\n"
    "  +seed <n>        make the % qualifiers' coin flips repeatable\n";

static const char wimp_message[] =
    "WIMP MODE ENGAGED. Numbers will be read and written in plain decimal, like a spreadsheet.\n"
    "Your INTERCAL license has been suspended, and your next of kin have been notified.\n";

static void parse_options(int argc, char **argv) {
  int help = 0;
  const char *unknown = NULL;
  for (int i = 1; i < argc; i++) {
    const char *arg = argv[i];
    if (arg[0] != '+' && arg[0] != '-') break;
    const char *name = arg + 1;
    if (strcmp(name, "help") == 0) {
      help = 1;
    } else if (strcmp(name, "traditional") == 0) {
    } else if (strcmp(name, "wimpmode") == 0) {
      wimp_mode = arg[0] == '+';
    } else if (arg[0] == '+' && strcmp(name, "seed") == 0 && i + 1 < argc && parse_seed(argv[i + 1])) {
      i++;
    } else {
      unknown = arg;
      help = 1;
      break;
    }
  }
  if (help) {
    fflush(stdout);
    if (unknown) fprintf(stderr, "Unknown runtime option: %s\n", unknown);
    fputs(usage, stderr);
    ick_fatal(778, 1);
  }
  if (wimp_mode) {
    fputs(wimp_message, stderr);
    fflush(stderr);
  }
}
