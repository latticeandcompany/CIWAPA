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
  - `WHILE` makes a Mode 1 comment of the form `x WHILE y`, where x and y decode, into ick's 11-statement WHILE: it runs if reached, and its added statements shift every later statement's number.
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
  - `ick` evaluates a created operator's operands (as arguments to a C function, in C's unspecified order) before matching it, whenever the program has a CREATE; with no CREATE at all it raises E000 without evaluating them.
  - A created label that doesn't exist is E129, which `ick` reports at statement 0 for a statement.
  - A whole array as an operand: `:1601` standing for it crashes `ick` (a segmentation fault) when read.
  - Operator names: `ick` allows any byte its lexer doesn't use, including the bytes of non-ASCII characters.
  - An unknown statement whose operands wouldn't compile (an ungrouped chain, a constant too big, an operator the base lacks) is a compile-time error in `ick`.
  - `ick` lexes `PIN` (a PIC-INTERCAL keyword) and its other dialects' words, so those letters can't appear in a template there.
- **Options:**
  - (a) As CIWAPA does: a created operator ends when a RESUME returns to its entry, and a RESUME, FORGET or COME FROM that takes its entry away abandons the expression at once, continuing where it sends control. A created operator's operands, and a created statement's, are evaluated left to right before anything else, CREATE or not. E129 is reported at the statement after the one that jumps. Reading or assigning `:1601` that stands for a whole array is E277. Operator names are ASCII: lowercase letters, punctuation and control characters `ick` doesn't use (not `_`, `\` or `|`) and overstrikes (not `c^H|`). An unknown statement whose operands wouldn't compile stays a comment, as in Mode 1. Only EXTRACAL's own keywords are reserved.
  - (b) Copy `ick -e` exactly, including the postponed FORGET and the crash.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `create/abandon.xc`, `create/forget.xc`, `create/e129.xc` and `create/e277-array.xc` pin (a).
- **Raised:** 2026-10-18

## L25: Where may CIWAPA's backtracking differ from `ick`'s?

- **Context:** R3 asks for `ick` 0.35's backtracking. A few corners of `ick`'s come from how its C is put together rather than from a design:
  - `ick` stores MAYBE in the same number as the `%` chance, so `MAYBE DO %0` loses its MAYBE and makes no choicepoint.
  - A ONCE or AGAIN on a NEXT or GO BACK keeps the abstention it found in a single global variable, which a choicepoint doesn't save, so going back can test a later statement's value.
  - `ick` has no created operators and backtracking together (they need `-e` and `-m`), so it doesn't say what going back to a choicepoint made inside a created operator that has since finished means.
- **Options:**
  - (a) As CIWAPA does: MAYBE always makes its choicepoint; each choicepoint saves the abstention its guard tested; a choicepoint made inside a finished created operator is discarded like a stale one, and one made at a shallower level abandons the operators in between.
  - (b) Copy `ick`'s first two quirks.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18

## L26: Does EXTRACAL accept `ick`'s right-associative operator chains?

- **Context:** Mode 1 follows `ick` 0.15 (Q85, Q97): an ungrouped chain such as `#1$#2~#3` is E017 when it runs, and inside a group it doesn't decode at all. `ick` 0.35 accepts chains, CLC-INTERCAL style, as right-associative: `#1$#2~#3` is `#1$'#2~#3'`. Programs written for `ick` 0.35 use them, such as `pit/tests/whileadd.i`, whose WHILE line can't decode in CIWAPA because of them.
- **Options:**
  - (a) EXTRACAL keeps Mode 1's rule. Programs that rely on chains need grouping added.
  - (b) EXTRACAL accepts chains right-associatively, as `ick` 0.35 does. A Mode 1 program with a chain then runs as `.xc` instead of failing with E017, which R1 allows. But a chain inside a group makes a statement undecodable in Mode 1 and decodable in `.xc`, the same kind of difference as L15.
- **Lean:** (a), because chains aren't one of R3's listed extensions. The compiler does (a) until this is answered.
- **Blocks:** no checklist items. `pit/tests/whileadd.i` can't be used as an oracle test under (a).
- **Raised:** 2026-10-18

## L27: How do threads and created operators interact?

- **Context:** R3 asks for `ick` 0.35's threading and CREATE. `ick` has no created operators and threads together: operators need `-e`, which replaces the code generator that threads use.
- **Options:**
  - (a) As CIWAPA does:
    - A created operator's code runs as one turn, so no other thread runs until it returns.
    - Several COME FROMs taking control inside it can't split the thread, so they are E555 as in Mode 1.
    - A GIVE UP inside it ends the thread and abandons the operator.
  - (b) Let operators split and yield, which needs each thread to carry its own stack of operator calls.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18

## L28: What happens when a computed COME FROM splits a thread?

- **Context:** R3 asks for `ick` 0.35's threading. When a computed or gerund COME FROM is one of several taking control from a statement, `ick` 0.35's generated code splits the thread but then resumes the new thread at the wrong place, so it runs the same COME FROM's code over and over: a program with two computed COME FROMs on one label prints the second one's output forever.
- **Options:**
  - (a) Each thread follows its own COME FROM, as with plain ones: the new thread takes the one found earlier, the running thread the one found last.
  - (b) Copy `ick`'s loop.
- **Lean:** (a), since `ick`'s loop is a bug in how it saves the jump target. The compiler does (a) until this is answered.
- **Blocks:** no checklist items; `threads/computed.xc` pins (a).
- **Raised:** 2026-10-18

## L29: How do library routines reach the operating system?

- **Context:** R10 wants every library block written in INTERCAL, with native fast paths on top. INTERCAL can't reach command-line arguments, the environment, the clock, files or sockets, and Q74 allows "a few new statements" for exactly this without saying what they look like.
- **Options:**
  - (a) One new EXTRACAL statement, `PETITION #n` (gerund `PETITIONING`), which asks the host for numbered service `n`. Each service reads and writes fixed variables documented in `packages/ciwapa_core/lib/extracal/README.md`. A routine in the System, I/O or Network block is INTERCAL around the smallest services that can do its job, for example reading or writing one byte. Everything that can be INTERCAL is: number formatting, string handling, HTTP.
  - (b) One new statement per operation (`OPEN`, `CLOSE`, `CONNECT`, …).
  - (c) Labels the compiler implements natively, with no INTERCAL statement behind them.
- **Lean:** (a). It is one statement, it keeps the host interface small, and it leaves the INTERCAL version as the reference.
- **Blocks:** no checklist items. The compiler does (a) until this is answered.
- **Raised:** 2026-10-18

## L30: How is the empty string stored?

- **Context:** Strings are tail arrays of code points (Q108), but INTERCAL can't DIMENSION an array to zero elements (E240), and nothing says how a string of length zero looks.
- **Options:**
  - (a) The empty string is a tail array with no dimensions, as an array is before its first DIMENSION. Only the library makes one; a program tests for it through the library. INTERCAL can't ask an array's size, so a program learns any string's length only through the Strings block's (3000).
  - (b) Strings carry their length in a separate variable, and the array always has at least one element.
- **Lean:** (a). A string stays one array, and no routine needs an extra length argument. The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18

## L31: Do WHILE's added statements count in statement numbers?

- **Context:** CIWAPA expands `a WHILE b` into the 11 statements `ick`'s preprocessor makes (R3). Error messages give statement ordinals (T33), so the ten added statements shift every later statement's number: an error after one WHILE is reported 10 higher than a reader counting the source would expect. `ick` prints source line numbers, so it doesn't have the question.
- **Options:**
  - (a) Count them. Ordinals stay plain positions in the expanded program, and the user docs say a WHILE counts as 11 statements.
  - (b) Number every statement by the source statement it came from, so a WHILE counts as one. Errors inside the expansion then share a number.
- **Lean:** (a). The compiler does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18

## L32: How do the Math block's routines fail?

- **Context:** R6 and R10 put signed arithmetic at all three widths, 64-bit arithmetic, and power, square root, modulo and gcd in the Math block. Neither says what a result too big for its variable, or a division by zero, does. Syslib (§7.2, goal 1) has an error variant and a flag variant of each operation that can overflow, and gives #0 for a division by zero.
- **Options:**
  - (a) Follow syslib's shape. An error variant raises a new code, E813 (R11), and a flag variant (its number ending in 9) stores the wrapped result and #1 or #2 in the next variable. Division by zero gives #0, so modulo by zero gives the dividend. Signed division truncates toward zero, and the most negative value divided by −1 is E813.
  - (b) Status flags only, with no error variants.
  - (c) Errors only, including a new code for division by zero.
- **Lean:** (a). It matches what syslib's users already know, and Q139 makes a result that doesn't fit a programming error. The Math block does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18

## L33: How do the Floats block's numbers behave?

- **Context:** R9 and Q137 fix the layout: a 32-bit value whose upper 16 bits are the mantissa and lower 16 the characteristic, both two's complement, worth mantissa × 2^characteristic. R9 lists add, subtract, multiply, divide, compare, natural logarithm and conversions to and from integers and decimal strings. Nothing says how results are rounded or normalized, what overflow, underflow, division by zero or the logarithm of a non-positive number do, or what the decimal strings look like. The native versions must agree with the INTERCAL bit for bit (Q37), so each answer also fixes an exact algorithm, the logarithm's included.
- **Options:**
  - **Normal form:** (a) every result has a mantissa magnitude from 2^14 to 2^15 − 1, and zero is #0; inputs may be unnormalized. (b) results are left as they fall.
  - **Rounding:** (a) to nearest, ties to even, as IEEE 754 does. (b) toward zero, which is simpler in INTERCAL and less accurate.
  - **Out of range:** (a) a characteristic above 32767 is a new error, E814, and one below −32768 gives #0. (b) both are errors. (c) both saturate.
  - **Division by zero and ln of a value ≤ 0:** (a) new errors, E815 and E816. (b) status flags.
  - **Logarithm:** (a) shift-and-add with a table of ln(1 + 2^−k) in 32-bit fixed point, then rounded once: within one unit in the last place, and cheap for the natives to reproduce exactly. (b) correctly rounded, which needs much more precision in INTERCAL.
  - **Integers:** (a) from and to `:1` read as signed 32-bit, float to integer truncating toward zero, and E814 out of range. (b) unsigned. (c) both.
  - **Decimal strings out:** (a) scientific with 5 significant digits, correctly rounded, like `-1.2346E+5`, which needs big-number arithmetic for large characteristics (slow in INTERCAL, easy natively). (b) the exact decimal value: up to about 9,900 digits before the point for the largest characteristics, and up to 32,768 after it (about 22,900 of them significant) for the smallest. (c) mantissa and characteristic in decimal, like `-12345*2^-3`.
  - **Decimal strings in:** (a) an optional sign, digits, an optional fraction and an optional `E` exponent, rounded to nearest, with a status flag for malformed input. (b) only what (a) of the output format prints.
- **Lean:** (a) for each. It gives the floats people expect, and every piece has an exact integer algorithm that both runtimes can share.
- **Blocks:** the Floats block (`docs/EXTRACAL_CHECKLIST.md`, Floats). It is a large, user-visible API, and the decimal format and the rounding change every routine. So unlike the corner cases above, it waits for an answer instead of being built on the lean.
- **Raised:** 2026-10-18

## L34: How does the Dart runtime reach the network, and what does the Network block offer?

- **Context:** The plan's Technical Approach says: "**Networking** in both runtimes uses the platform's sockets: `dart:io` in `runtime.dart`, and BSD sockets or Winsock in `runtime.c`." CIWAPA's Dart runtime is synchronous: each statement runs to completion, and a library service must return before the next one runs. `dart:io` has a synchronous client socket (`RawSynchronousSocket`) but no synchronous server socket: `ServerSocket.bind` and `RawServerSocket.bind` return futures, and Dart 3 has no `waitFor`. A server still works on `dart:io` alone if a helper isolate owns the listening sockets and the program talks to it over loopback through `RawSynchronousSocket`, which a reviewer confirmed with a working echo round trip. Q110 fixes the scope (TCP client and server, a minimal HTTP/1.1 client, request/response helpers, no TLS) but not the API.
- **Options:**
  - **Dart sockets:**
    - (a) `dart:io` only. Clients use `RawSynchronousSocket`. A helper isolate holds each listening `ServerSocket`, and the program reaches every accepted connection through a loopback connection to the helper, which copies bytes both ways. The costs are an isolate per networking program, a loopback port, copying, and failure modes of the helper's own.
    - (b) `dart:ffi` to the platform's own sockets (BSD sockets in libc, Winsock's `ws2_32.dll`), the way Q146 reaches database adapters. The two runtimes then share one model, call for call, but the Dart runtime leaves `dart:io` for networking.
    - (c) `RawSynchronousSocket` for clients and `dart:ffi` only for servers.
  - **API:**
    - (a) Sockets are I/O-block handles. CONNECT (host string, port) and LISTEN (port) give a handle, ACCEPT gives a connection handle, and (2000)/(2010)/(2100)–(2310) read and write them, with `.3 = #2` for a refused connection or a name that doesn't resolve (Q139). IPv4 and IPv6 through name resolution, blocking calls, no timeouts. HTTP: GET and POST of a URL string give a status and a body string. The helpers parse a request line and headers and build a response, with `Content-Length` bodies only: no chunked transfer and no redirects.
    - (b) A separate handle space for sockets, with their own read and write routines.
- **Lean:** (a) for both. It keeps to the plan's written approach.
- **Blocks:** no checklist items. The Network block is built on (a) until this is answered.
- **Raised:** 2026-10-18
