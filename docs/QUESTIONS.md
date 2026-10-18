# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean. Checklist items a question affects are marked **BLOCKED** with its number until Ryan answers. When a question touches behavior that no checklist item covers, the code needs *some* behavior in the meantime: it follows the lean, and the question says so. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

## L14: How does a program ask for CLC-style binary I/O?

- **Context:** R3 item 11 asks for "CLC-style binary I/O" with `ick` 0.35 semantics. `ick` 0.35 has two CLC-INTERCAL I/O mechanisms, and neither fits EXTRACAL as written:
  - Baudot text I/O on tail arrays, which `ick` only uses with `-x`, in place of Turing Text.
  - Generalised binary I/O on hybrid arrays, which `ick`'s manual says C-INTERCAL doesn't implement at all.

  Both take over `READ OUT ,1` / `WRITE IN ;1`, which Mode 1 already defines as Turing Text (§5.2, T31). Using either one for array I/O in `.xc` files would break R1 for every Mode 1 program that does character I/O. EXTRACAL has no flags, and no syntax picks the CLC mechanism instead.
- **Options:**
  - (a) A compiler flag such as `--clc-io`, like `ick -x`, that switches array I/O in `.xc` files to the CLC mechanisms.
  - (b) New syntax, for example `READ OUT BAUDOT ,1` and `WRITE IN BINARY ;1`, leaving plain array I/O as Turing Text.
  - (c) Drop item 11, like item 13.
- **Lean:** (b), because R1 and "the file extension is the only mode switch" (Q43) both rule out a flag. It means inventing syntax, so the loop waits.
- **Blocks:** the item-11 part of "Each of `ick` extensions 1–9, 11 and 12 has conformance tests" (`EXTRACAL_CHECKLIST.md`, CLC-style binary I/O).
- **Raised:** 2026-10-17

## L15: What happens to EXTRACAL keywords inside a Mode 1 program's comments?

- **Context:** R1 says every valid Mode 1 program behaves identically as `.xc`. But `ick` recognizes several of the new words anywhere, even in the middle of a comment, and some of them change how a program is split into statements:
  - `MAYBE`, `FAC`, `PLACET` and `PLACET FACERE` start a new statement, like `DO` (T8). A Mode 1 comment such as `PLEASE NOTE THE FACT THAT MAYBE ...` becomes three statements in `.xc`. The new ones aren't abstained, so they raise E000 if reached, and the politeness count changes.
  - A comment that happens to read as `TRY AGAIN` before the last statement is a compile-time E993 in `ick`.
  - A comment that reads as `NEXT FROM (n)` with no label `n` is a compile-time E444. With a label `n`, it becomes a working trap on `n` even though Mode 1 never executes it, since a COME FROM acts where its target is (`come-from/dead-next-from.i`).
  - A keyword that ends in `D`, such as `SIGNED` or `GO AHEAD`, swallows the `D` of a `DO` that follows it with no space, so a Mode 1 comment containing `SIGNEDO` is split differently in `.xc`.

  `ick`'s manual warns about exactly this for `MAYBE` ("be careful what words you use in comments!"). No existing conformance test or `pit/` program trips over it, but user programs could. There is no rule that keeps every Mode 1 program identical while still letting `MAYBE` and the Latin identifiers start statements.
- **Options:**
  - (a) Follow `ick`: the words work anywhere. A Mode 1 program whose comments contain them is a deliberate Mode 1 vs. EXTRACAL difference, recorded like the E533 mingle case.
  - (b) Follow R1 as far as possible: only recognize the new statement identifiers at the start of a line or right after a label, and turn E993/E444 from comments into run-time E000. Mode 1 programs then break only when a comment line *starts* with one of the words, and `ick` programs that write `MAYBE` mid-line stop working.
  - (c) Leave `MAYBE` and the Latin statement identifiers out.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** the backtracking (`MAYBE`) and Latin statement identifier items in `EXTRACAL_CHECKLIST.md`.
- **Raised:** 2026-10-17

## L16: What is a select's result when it selects more than 64 bits?

- **Context:** R5 says a 128-bit ephemeral value "can only be consumed by a select, which may use a 128-bit mask". With a mask of 64 set bits or fewer, the result always fits in 64 bits, and the loop treats it as an ordinary 64-bit value; that is the only reading under which "consumed" means anything. Q77 says a select takes its right operand's type, though, and a 128-bit mask with more than 64 set bits can select more than 64 bits. Nothing says whether that result is another ephemeral value or an error.
- **Options:**
  - (a) The result is a 64-bit value when it fits in 64 bits, and otherwise another ephemeral value that only a further select can use.
  - (b) The result is always 64-bit, and a select that produces more than 64 bits is an error.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items; the 128-bit select tests use results that fit in 64 bits.
- **Raised:** 2026-10-17

## L17: Which EXTRACAL features exist in bases 3–7?

- **Context:** R2 makes `.3xc`–`.7xc` EXTRACAL in bases 3–7, but R4–R10 are written for binary: 64-bit sigils, mingle widening "by value" past 65535, two's-complement signed numbers, the §8.4 float layout and a library written in binary INTERCAL. L9 already keeps the binary system library out of bases 3–7.
- **Options:**
  - (a) Bases 3–7 get the `ick` extensions (R3) and nothing else. The 64-bit sigils and `SIGNED` aren't recognized there (so a statement using them is undecodable), mingle keeps Mode 1's E533, and the library blocks are never included, as in L9.
  - (b) Generalize everything to base N: 64-bit types hold four small words of digits, widening uses the base's limits, signed numbers use radix complement, and the library gets per-base versions.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-17

## L18: Does EXTRACAL have `ick`'s "COME FROM gerund" form?

- **Context:** R3 item 2 lists computed COME FROM and NEXT FROM. `ick` 0.35 also accepts a gerund list after both (`DO COME FROM CALCULATING`, `DO NEXT FROM NEXTING FROM`), through the same grammar rule as the computed form, and its manual describes it in the same section. R3 doesn't mention it.
- **Options:** (a) include it as part of item 2; (b) leave it out, so such statements stay undecodable.
- **Lean:** (a), since it is part of `ick` 0.35's COME FROM. The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-17

## L19: Is `.2xc` a valid EXTRACAL extension?

- **Context:** R2 lists `.xc` and `.3xc`–`.7xc`, and says anything else is E998. Mode 1 also accepts `.2i` as base 2 (§6.3, T40), although R2's own Mode 1 row lists only `.i` and `.3i`–`.7i`. The superset harness renames each Mode 1 test to its EXTRACAL twin, so the two `.2i` tests become `.2xc`.
- **Options:** (a) accept `.2xc` as binary EXTRACAL, mirroring `.2i`; (b) make `.2xc` E998, and rename `.2i` tests to `.xc` in the superset harness.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18
