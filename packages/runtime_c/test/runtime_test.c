/* Prints the runtime's results for the spec's golden values, one per line. */
#include <stdio.h>

/* Input after the end of input, which only a terminal can produce: "A", end, "B". */
static const int fake_input[] = {'A', EOF, 'B'};
static int fake_at;
#define ICK_GETCHAR() (fake_at < 3 ? fake_input[fake_at++] : EOF)

/* The clock reads 42, so the default seed can be compared with +seed 42. */
#define ICK_TIME() 42

/* Counts flushes, to show that output is flushed at every newline. */
static int flushes;
#define ICK_FLUSH() (flushes++, fflush(stdout))

#include "../runtime.c"

int main(int argc, char **argv) {
  static const ick_program p = {2, 0, 0, 1, NULL, NULL, NULL, 0};
  ick_init(argc, argv, &p);
  uint32_t dims[] = {3};
  ick_dimension(0, 1, dims, 0);
  ick_turing_in(0, 0);
  printf("%u %u %u\n", arrays[0].shape.data[0], arrays[0].shape.data[1], arrays[0].shape.data[2]);

  /* Writes "A\n" with Turing Text output, then reports how many flushes that took. */
  arrays[0].shape.data[0] = (uint32_t)(0 - 0x82) & 0xFFu;
  arrays[0].shape.data[1] = (uint32_t)(0x82 - 0x50) & 0xFFu;
  arrays[0].shape.data[2] = 0;
  dims[0] = 2;
  arrays[0].shape.dims[0] = 2;
  fflush(stdout);
  int before = flushes;
  ick_turing_out(0, 0);
  printf("flushes %d\n", flushes - before);

  /* Rolls with the clock's seed, then with +seed 42: they must agree. */
  char rolls_clock[33] = {0}, rolls_seed[33] = {0};
  char *no_args[] = {"t"};
  ick_init(1, no_args, &p);
  for (int i = 0; i < 32; i++) rolls_clock[i] = ick_roll(50) ? '1' : '0';
  char *seed_args[] = {"t", "+seed", "42"};
  ick_init(3, seed_args, &p);
  for (int i = 0; i < 32; i++) rolls_seed[i] = ick_roll(50) ? '1' : '0';
  printf("%s %s\n", rolls_clock, rolls_seed);
  return 0;
}
