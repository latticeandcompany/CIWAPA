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
  uint32_t ignored;
} ick_array;

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
  rng_state = (uint64_t)time(NULL);
}

/* ---- Errors (§9) ------------------------------------------------------------------------- */

static void print_error(uint32_t code, const char *text, uint32_t next) {
  const char *joke = "";
  for (uint32_t i = 0; i < program->message_count; i++) {
    if (program->messages[i].code == code) {
      if (!text) text = program->messages[i].text;
      joke = program->messages[i].joke;
      break;
    }
  }
  fflush(stdout);
  fprintf(stderr, "ICL%03uI %s\n        %s\n\tON THE WAY TO STATEMENT %u\n        CORRECT SOURCE AND RESUBMIT\n",
          (unsigned)code, text ? text : "", joke, (unsigned)next);
  fflush(stderr);
}

void ick_fatal(uint32_t code, uint32_t next) {
  print_error(code, NULL, next);
  exit((int)(code % 256));
}

void ick_undecodable(const char *text, uint32_t next) {
  print_error(0, text, next);
  exit(0);
}

void ick_give_up(void) {
  fflush(stdout);
  exit(0);
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

void ick_dimension(uint32_t index, uint32_t rank, const uint32_t *dims, uint32_t next) {
  ick_array *a = &arrays[index];
  uint64_t size = 1;
  for (uint32_t i = 0; i < rank; i++) {
    if (dims[i] == 0) ick_fatal(240, next);
  }
  if (a->ignored) return;
  for (uint32_t i = 0; i < rank; i++) {
    size *= dims[i];
    if (size > (uint64_t)SIZE_MAX / sizeof(uint32_t)) ick_fatal(241, next);
  }
  uint32_t *data = calloc((size_t)size, sizeof(uint32_t));
  uint32_t *copy = malloc(rank * sizeof(uint32_t));
  if (!data || !copy) ick_fatal(241, next);
  memcpy(copy, dims, rank * sizeof(uint32_t));
  free(a->data);
  free(a->dims);
  a->rank = rank;
  a->dims = copy;
  a->data = data;
}

uint32_t *ick_element(uint32_t index, uint32_t count, const uint32_t *subscripts, uint32_t next) {
  ick_array *a = &arrays[index];
  if (count != a->rank) ick_fatal(241, next);
  size_t offset = 0;
  for (uint32_t i = 0; i < count; i++) {
    if (subscripts[i] == 0 || subscripts[i] > a->dims[i]) ick_fatal(241, next);
    offset = offset * a->dims[i] + subscripts[i] - 1;
  }
  return &a->data[offset];
}

uint32_t ick_array_ignored(uint32_t index) { return arrays[index].ignored; }
