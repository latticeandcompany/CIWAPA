/* The runtime that ciwapa-llvm links into every program. runtime.dart is its twin; the
 * conformance suite keeps the two byte-for-byte identical in behavior. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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
static uint32_t small_max;
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

void ick_init(int argc, char **argv, const ick_program *p) {
  (void)argc;
  (void)argv;
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
  _setmode(_fileno(stderr), _O_BINARY);
#endif
  program = p;
  small_max = p->base == 2 ? 65535u : pow_u32(p->base, small_digits(p->base)) - 1;
  arrays = calloc(p->array_count ? p->array_count : 1, sizeof(ick_array));
  scalar_stashes = calloc(p->scalar_count ? p->scalar_count : 1, sizeof(ick_value_stash));
  array_stashes = calloc(p->array_count ? p->array_count : 1, sizeof(ick_array_stash));
  rng_state = (uint64_t)time(NULL);
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

/* ---- Randomness (§4.3, decision T22) ---------------------------------------------------- */

static uint64_t next_random(void) {
  uint64_t z = (rng_state += 0x9E3779B97F4A7C15ull);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
  return z ^ (z >> 31);
}

uint32_t ick_roll(uint32_t percent) { return (uint32_t)((next_random() >> 1) % 100) < percent; }

/* ---- Binary operators (§3.4) ------------------------------------------------------------- */

uint32_t ick_mingle(uint32_t left, uint32_t right, uint32_t next) {
  if (left > small_max || right > small_max) ick_fatal(533, next);
  uint32_t result = 0;
  for (int i = 15; i >= 0; i--) {
    result = (result << 2) | (((left >> i) & 1u) << 1) | ((right >> i) & 1u);
  }
  return result;
}

uint32_t ick_select(uint32_t value, uint32_t mask) {
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
