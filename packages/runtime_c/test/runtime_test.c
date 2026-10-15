/* Prints the runtime's results for the spec's golden values, one per line. */
#include <stdio.h>

/* Input after the end of input, which only a terminal can produce: "A", end, "B". */
static const int fake_input[] = {'A', EOF, 'B'};
static int fake_at;
#define ICK_GETCHAR() (fake_at < 3 ? fake_input[fake_at++] : EOF)

#include "../runtime.c"

int main(int argc, char **argv) {
  static const ick_program p = {2, 0, 0, 1, NULL, NULL, NULL, 0};
  ick_init(argc, argv, &p);
  printf("%u %u %u %u\n", ick_mingle(65535, 0, 0), ick_mingle(0, 65535, 0), ick_mingle(255, 255, 0), ick_mingle(0, 256, 0));
  printf("%u %u %u %u\n", ick_select(179, 201), ick_select(201, 179), ick_select(179, 179), ick_select(201, 201));
  printf("%u %u %u\n", ick_and16(77), ick_or16(77), ick_xor16(77));
  printf("%u %u %u\n", ick_xor32(1), ick_or32(0x80000000u), ick_and32(0xFFFFFFFFu));
  printf("%u %u\n", ick_select(ick_mingle(165, 203, 0), 358), ick_mingle(165, ick_select(203, 358), 0));
  uint32_t dims[] = {3};
  ick_dimension(0, 1, dims, 0);
  ick_turing_in(0, 0);
  printf("%u %u %u\n", arrays[0].shape.data[0], arrays[0].shape.data[1], arrays[0].shape.data[2]);
  return 0;
}
