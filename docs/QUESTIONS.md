# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean. Checklist items a question affects are marked **BLOCKED** with its number until Ryan answers. When a question touches behavior that no checklist item covers, the code needs *some* behavior in the meantime: it follows the lean, and the question says so. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

## L12: Which error does the compiler give when it runs out of memory generating code?

- **Context:** L7 decided that running out of memory is E666 while parsing and E333 while laying out variables. A review gave the compiler a real heap limit and found a third place it can run out: building the generated `.dart` or `.ll` text, which for a huge program is the compiler's biggest allocation. A 200,000-statement program parses in about 135 MB but then runs out there, and the compiler crashed with a stack trace (exit 255). L7 doesn't name an error for this stage.
- **Options:** (a) E666, "too many source lines", since a program too big to generate code for is a program with too many lines; (b) E333; (c) E778, the unexplainable compiler error.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-16

