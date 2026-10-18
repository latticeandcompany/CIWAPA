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
  - A comment that reads as `NEXT FROM (n)` with no label `n` is a compile-time E444. With a label `n`, it becomes a working trap on `n` even though Mode 1 never executes it, since a COME FROM acts where its target is (`come-from/dead-next-from.i`). The same goes for never-executed text that reads as a computed or gerund COME FROM (`COME FROM .1`, `COME FROM CALCULATING`), which can trap every labelled statement or every statement of a kind. And never-executed text that reads as `ABSTAIN expr FROM` takes the label of the statement after it as its target, so that statement loses its label.
  - A keyword that ends in `D`, such as `SIGNED` or `GO AHEAD`, swallows the `D` of a `DO` that follows it with no space, so a Mode 1 comment containing `SIGNEDO` is split differently in `.xc`.
  - A character `ick` doesn't use between two operands is a created operator (R3 item 9), so `DO .1 <- #1 x #2`, a comment in Mode 1, is a CALCULATE in `.xc`: still E000 when it runs without a CREATE, but now subject to `ABSTAIN FROM CALCULATING` and `REINSTATE CALCULATING`. The new words `CREATE`, `CONFICE`, `COMMENT` and the like do the same to comments that contain them as statements.
  - A slat turns a statement that doesn't decode in Mode 1 into a live one. In Mode 1, `(1) DO .1 <- .2/#3` is a comment that `REINSTATE CALCULATING` leaves alone; in `.xc` it is a CALCULATE that the REINSTATE wakes up, and once it runs `.2` stands for `#3`.
  - A trailing `ONCE`, `AGAIN`, `QUONDAM` or `ITERUM` turns a never-executed statement into a decodable one. After `DO REINSTATE READING OUT`, Mode 1's `PLEASE DON'T READ OUT #1 AGAIN` is a comment that never prints, but in `.xc` it is a READ OUT that runs. And Mode 1's dead `PLEASE COME FROM (5) AGAIN` becomes a working trap on `(5)` in `.xc`.

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

## L20: Do abstention counts wrap around as in `ick`, or saturate?

- **Context:** R3 asks for `ick` 0.35's computed ABSTAIN. `ick` adds the expression's 32-bit value to a C `int` (`ICKABSTAINED(n) += expr`), so large counts overflow. That's undefined behavior, and in practice it wraps: two `ABSTAIN :1 FROM (5)` with `:1` = 2³¹ bring the count back to 0, so the statement runs again. EXTRACAL values can also be 64 bits wide, which `ick` doesn't have.
- **Options:**
  - (a) Counts are 64-bit and saturate at 2⁶³−1, so a huge count stays abstained.
  - (b) Imitate `ick`: truncate the value to 32 bits and wrap the count as a 32-bit signed integer, so it can even go negative and stay abstained through 2³² REINSTATEs.
- **Lean:** (a), since `ick`'s behavior there comes from undefined overflow rather than a design. The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `computed-abstain/huge-count.xc` pins (a).
- **Raised:** 2026-10-18

## L21: Where does TRY AGAIN restart after a RESUME or a computed COME FROM?

- **Context:** R3 asks for `ick` 0.35's TRY AGAIN, which its manual describes as restarting the program from the top. But `ick`'s generated code restarts by jumping back to its dispatch on `ick_skipto`, and nothing resets that variable. Every executed RESUME sets it, so after a RESUME, TRY AGAIN goes back to the return point of the last resumed NEXT instead. With computed or gerund COME FROM, every labelled statement sets it too, so TRY AGAIN can give E129 or jump somewhere unrelated.
- **Options:**
  - (a) TRY AGAIN always restarts from the first statement, as the manual and the plan describe.
  - (b) Imitate `ick`'s generated code, including the jumps to the last return point.
- **Lean:** (a), since `ick`'s behavior comes from a stale variable rather than a design. The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `try-again/after-resume.xc` pins (a).
- **Raised:** 2026-10-18

## L22: Does ONCE or AGAIN attach to an undecodable statement?

- **Context:** `ick` parses a comment made only of capital letters as an unknown statement, and a trailing `ONCE` or `AGAIN` attaches to it. So `PLEASE NOTE THIS RUNS ONCE` is an abstained statement that `ONCE` reinstates the first time it's reached: the second time, it raises E000. CIWAPA treats the whole text as the comment, ONCE included, so the comment stays harmless however often it's reached.
- **Options:**
  - (a) A comment's trailing `ONCE` or `AGAIN` is part of the comment.
  - (b) Imitate `ick`: it attaches, so comments that end in those words can wake up and raise E000.
- **Lean:** (a). Mode 1 comments ending in "ONCE" or "AGAIN" inside loops are far more common than programs relying on (b), and R1 asks for them to keep working. The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `once-again/comment.xc` pins (a).
- **Raised:** 2026-10-18

## L23: Where may CIWAPA's operand overloading differ from `ick`'s?

- **Context:** R3 asks for `ick` 0.35's operand overloading. Three corners of it don't fit EXTRACAL as it is:
  - `ick` reads an overloaded onespot as the full 32-bit value of its expression, so `.1/:2` with `:2` = 131072 reads as 131072. CIWAPA's code generation relies on a onespot's value fitting 16 bits.
  - In bases 3–7, `ick` reverses a unary operator by building the binary candidate and checking it with the base's own operator, which works for a few values (such as 0).
  - `ick` lexes a backslash (`\`), the reverse of the slat, but never parses it.
- **Options:**
  - (a) An overloaded variable's value must fit the variable, as an assignment would (E275, E276). In bases 3–7, every mingle, select and unary operator in a reverse assignment is E277. A backslash is undecodable, as in `ick`.
  - (b) Follow `ick` in the first two: overloaded onespot reads have 32 bits (every expression on a onespot then needs 32-bit code when the program overloads), and bases 3–7 copy `ick`'s binary candidate.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `overloading/narrowing.xc` and `overloading/e277.xc` pin (a).
- **Raised:** 2026-10-18

## L24: How do CREATEd statements and operators behave where `ick`'s code generators disagree or crash?

- **Context:** R3 asks for `ick` 0.35's CREATE. `ick` has two implementations: created statements in its ordinary code use its NEXT stack, but created operators exist only with `-e`, whose code runs NEXT and RESUME on the C stack with `setjmp`/`longjmp`. Some corners differ between the two, crash, or aren't defined:
  - A created operator's code is a NEXT from the middle of an expression. When a RESUME or FORGET removes its NEXT stack entry without returning to it, `ick -e` abandons the expression (FORGET is put off until the next jump). A COME FROM can also take control from the RESUME that would return.
  - `ick` passes the operands to the operator's C function before matching it, in C's unspecified argument order.
  - A created label that doesn't exist is E129, which `ick` reports at statement 0 for a statement.
  - A whole array as an operand: `:1601` standing for it crashes `ick` (a segmentation fault) when read.
  - Operator names: `ick` allows any byte its lexer doesn't use, including bytes of non-ASCII characters and control characters.
  - An unknown statement whose operands wouldn't compile (an ungrouped chain, a constant too big, an operator the base lacks) is a compile-time error in `ick`.
  - `ick` lexes `PIN` (a PIC-INTERCAL keyword) and its other dialects' words, so those letters can't appear in a template there.
- **Options:**
  - (a) As CIWAPA does: a created operator ends when a RESUME returns to its entry, and a RESUME, FORGET or COME FROM that takes its entry away abandons the expression at once, continuing where it sends control. The operands are evaluated left to right before matching. E129 is reported at the statement after the one that jumps. Reading or assigning `:1601` that stands for a whole array is E277. Operator names are ASCII: lowercase letters, punctuation `ick` doesn't use (not `_`, `\` or `|`) and overstrikes (not `c^H|`). An unknown statement whose operands wouldn't compile stays a comment, as in Mode 1. Only EXTRACAL's own keywords are reserved.
  - (b) Copy `ick -e` exactly, including the postponed FORGET and the crash.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `create/abandon.xc`, `create/forget.xc`, `create/e129.xc` and `create/e277-array.xc` pin (a).
- **Raised:** 2026-10-18
