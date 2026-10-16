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

## L13: What does the Dart "faster than INTERCAL-64 and CLC-INTERCAL" guardrail do when they run a program wrong?

- **Context:** Q32 asks the Dart flavor to be faster than every non-native baseline on every program. `programs.txt` lists INTERCAL-64 and CLC-INTERCAL for `tpk`, `primes`, `pi` and `life`, but neither prints what ick and both CIWAPA flavors print: CLC-INTERCAL prints nothing for `tpk`, `pi` and `life`, and INTERCAL-64's output differs on all four. The bench only times a run whose output matches, so for those programs there's nothing to compare. Until now the bench counted that as met, which no decision says. (`hail_mary` is different: Q31 itself leaves both out, so there's nothing to block.)
- **Options:**
  - (a) Count the guardrail as met when no listed baseline runs the program correctly, as the bench did.
  - (b) Compare against their times anyway, wrong output and all.
  - (c) Find out why they differ (input, flags, their own system library) and run them correctly; if a program can't be, drop that baseline from it in `programs.txt`.
- **Lean:** (c), falling back to (a) for whatever can't be fixed. Until then, those four guardrails are recorded as blocked in `tools/bench/results.json`.
- **Blocks:** the Dart guardrails for `tpk`, `primes`, `pi` and `life` against INTERCAL-64 and CLC-INTERCAL. No checklist items.
- **Raised:** 2026-10-16
