# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean. Checklist items a question affects are marked **BLOCKED** with its number until Ryan answers. When a question touches behavior that no checklist item covers, the code needs *some* behavior in the meantime: it follows the lean, and the question says so. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

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

## L35: Which source files do the ioi-* CLIs take?

- **Context:** R1 says "Without `-s`, the `ioi-*` CLIs compile plain EXTRACAL" and Q112 says "Source files are `.xc`". Neither says what happens to a Mode 1 `.i` file, or to `.3xc`–`.7xc` with `-s`, which is built on binary-only pieces: the library blocks (L9, L17) and the 32-bit string machinery. It also isn't said whether `-s --traditional` is allowed, given that `--traditional` turns off every C-INTERCAL extension (E111).
- **Options:**
  - (a) Without `-s`, any EXTRACAL extension (`.xc`, `.2xc`–`.7xc`), and anything else (including `.i`) is E998. With `-s`, binary EXTRACAL only (`.xc`, `.2xc`), and anything else is E998. `-s --traditional` is E111.
  - (b) Without `-s`, everything CIWAPA takes, Mode 1 included. With `-s`, as in (a).
  - (c) Let `-s` work in bases 3–7 as well, with the Interstates extensions but no library.
- **Lean:** (a). The CLIs then do what R1 says, and nothing more. E998's text names `.I`, because it is CIWAPA's message; a code of Interstates' own could replace it if Ryan prefers. The CLIs do (a) until this is answered.
- **Blocks:** no checklist items; `apps/interstates/test/cli_test.dart` pins (a).
- **Raised:** 2026-10-18

## L36: How do Interstates statements reach the emitters without CIWAPA learning about them?

- **Context:** The plan's Technical Approach has `apps/interstates` emit "the same IR plus a small set of Interstates IR nodes, lowered by both emitters". R1 says CIWAPA's own packages never learn about Interstates, and Affected Areas allows only generic hooks in them. CIWAPA's AST and IR node types are sealed, so another package can't add nodes that the emitters would have to understand.
- **Options:**
  - (a) Add generic hooks, and no Interstates nodes at all. A `HostCall` statement lowers to a PETITION carrying computed values. The runtimes hand unknown services, a start point and output hooks to a "host" that the embedding backend supplies, in Dart and in C. Interstates' statements become host calls, its routes become entry points, and its runtime is the host.
  - (b) A generic emitter-plugin hook, through which `apps/interstates` emits Dart and LLVM IR for its own nodes. It would have to know each emitter's internals.
- **Lean:** (a). The emitters stay unaware of anything outside CIWAPA, and each Interstates feature is one place in each host runtime. The code does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-18

## L37: What exactly is the syntax of the string and database statements?

- **Context:** R5 and R7 give a statement's shape, not its grammar. These are the readings the parser takes:
  - **String literals** (R5): `"…"` runs to the next `"` on the same line, with no escapes. An unterminated one leaves the statement undecodable.
  - **Moving strings** (R5):
    - These are the only allowed forms:
      - `,a <- ;4400 SUB e` and `,a <- ;49221 SUB e`
      - `;49221 SUB e <- ,a`
      - `;49221 SUB e <- ;4400 SUB f` and `;49221 SUB e <- ;49221 SUB f`
    - `;4400` can't be written to.
    - Any other use of either array raises E822 when the statement runs, Q80 style. That includes a string in a number's place, STASH, READ OUT, and a hybrid target.
  - **Table and column numbers** (R7) are `#n` constants, because `~` and `$` there are list separators rather than operators.
  - **`HAVING`** pairs are `#column value`, joined with `+`. A value is either a string (a whole tail array, or a `;4400`/`;49221` element) or a number (any other expression).
  - **A read** can only be the whole of `;49221 <- '…'`. With more than one matching row, `'FROM DATABASE …' SUB r` picks row r. Without `SUB` it is row 1. The SUB goes before `HAVING`, because after a HAVING value it would read as that value's subscript, as in example D's position.
  - **`INTO DATABASE #t~#c$… <- item + item`** takes one item per column, or E827 at compile time. A trailing `HAVING` makes it an update.
  - **`FORGET DATABASE #t`** takes an optional `HAVING`. Without one, it deletes every row of the table. It names no columns, so `#t~#c` there is undecodable. `INTO DATABASE #t` with no columns is E827, like any other count that doesn't match.
  - **Gerunds** (T21):
    - FORGET DATABASE counts as FORGETTING.
    - INTO DATABASE, a read and a string copy count as CALCULATING, being assignments.
    - `READ OUT … WITH TEMPLATE` counts as READING OUT.
    - AMNESIA has none, like GIVE UP.
    - A statement made E822 keeps the gerund of the statement it was, so abstaining that kind of statement skips it, as with Q80's faults.
  - **Routes:**
    - A route is a statement that does nothing when it runs, so DON'T, `%`, ONCE, AGAIN and ABSTAIN on one change nothing about the route. The entry point is reached whatever they say.
    - A NEXT FROM (16000) is an ordinary NEXT FROM, so E444, since no program has the label.
    - A program may label a statement (16000), but no COME FROM can trap it, because any COME FROM (16000) is a route.
  - **WHILE** (R3): a WHILE's body can be any statement body, Interstates' included, except the two that need a suffix (`WITH ROUTE`, `WITH TEMPLATE`). Those leave the statement undecodable there.
- **Options:** (a) as above; (b) other spellings, which would change the parser and its tests.
- **Lean:** (a). The code does (a) until this is answered.
- **Blocks:** no checklist items; `apps/interstates/test/syntax_test.dart` pins (a).
- **Raised:** 2026-10-18
