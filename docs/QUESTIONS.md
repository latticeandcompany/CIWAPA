# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean. Checklist items a question affects are marked **BLOCKED** with its number until Ryan answers. When a question touches behavior that no checklist item covers, the code needs *some* behavior in the meantime: it follows the lean, and the question says so. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

## L11: Does `fft` also get C-INTERCAL's `floatlib.i` appended?

- **Context:** L10 answered: `primes`, `pi`, `fft` and `life` run with 0.35's `syslib.i` appended for every compiler. With that, `primes`, `pi` and `life` match ick byte for byte in both flavors. But `fft` also NEXTs to (5000), (5010), (5030), (5080), (5090) and (5200). Those are in C-INTERCAL's floating-point library, `floatlib.i`, which ick includes on its own when a program calls 5000–5999. CIWAPA has no such library, so `fft` stops with E129 in both flavors. L10 only names `syslib.i`.
- **Options:**
  - (a) Append `floatlib.i` to `fft` as well, extracted from the same hash-checked tarball the same way: never read or committed.
  - (b) Drop `fft` from the set.
  - (c) Replace `fft` with a clean-room program of our own.
- **Lean:** (a), the same reasoning as L10. It touches the clean-room boundary, so the loop waits. Until then, `fft`'s guardrails are recorded as blocked in `tools/bench/results.json`.
- **Blocks:** the guardrails for `fft`, and both flavors' geometric means, which are taken over the whole set. No checklist items.
- **Raised:** 2026-10-16

## L12: Which error does the compiler give when it runs out of memory generating code?

- **Context:** L7 decided that running out of memory is E666 while parsing and E333 while laying out variables. A review gave the compiler a real heap limit and found a third place it can run out: building the generated `.dart` or `.ll` text, which for a huge program is the compiler's biggest allocation. A 200,000-statement program parses in about 135 MB but then runs out there, and the compiler crashed with a stack trace (exit 255). L7 doesn't name an error for this stage.
- **Options:** (a) E666, "too many source lines", since a program too big to generate code for is a program with too many lines; (b) E333; (c) E778, the unexplainable compiler error.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-16

