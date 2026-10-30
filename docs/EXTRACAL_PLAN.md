# EXTRACAL: plan for goal 2

EXTRACAL is CIWAPA's "Mode B". It is a strict superset of Mode 1 (the spec-faithful INTERCAL from goal 1) that adds modern C-INTERCAL extensions, 64-bit and signed numbers, and a real standard library with I/O and networking.

This is the second of five `/goal` runs: **CIWAPA (Mode 1)** → **EXTRACAL** → **INTERCAL on Interstates** → **Editors** → **Playground**. It starts only after goal 1 is done. Interstates (goal 3) depends on it.

Background: [`PLAN.md`](PLAN.md) (goal 1, architecture, workflow) and [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) (every answer, including the Q-numbers cited here).

---

## Vision

INTERCAL that can do real work while staying INTERCAL. A program written for Mode 1 behaves exactly the same under EXTRACAL. EXTRACAL only adds: the extensions modern `ick` grew after 0.15, numbers wider and stranger than 32-bit unsigned, and a standard library that reaches files, the command line, the clock and the network. Everything still lives behind `NEXT`, labels and mingle, so the language stays as uncomfortable as it should be.

## User Experience

- The user writes `foo.xc` (or `foo.3xc`–`foo.7xc` for TriINTERCAL bases) and compiles it with the same CLIs as Mode 1:
  ```
  ciwapa-llvm build foo.xc -o foo
  ciwapa-dart run foo.xc
  ```
  The file extension is the only mode switch (Q43, Q56). `.i` files are always Mode 1.
- Standard library routines are called like the system library: put arguments in variables, `DO (2000) NEXT`, read results. A block of routines is pulled in automatically the first time a program `NEXT`s into it (Q74, Q106).
- 64-bit values use INTERCAL-64's sigils: `::1`, `;;1`, `##70000`, `####5000000000` (Q107, Q123).
- Signed numbers use the existing types read as two's complement, with `WRITE IN SIGNED` and `READ OUT SIGNED` (Q124).
- Errors look exactly like Mode 1 errors: official text, our joke line, `ON THE WAY TO STATEMENT n`, `CORRECT SOURCE AND RESUBMIT` (Q90).

## Requirements

### R1. Superset rule (Q42)
Every valid Mode 1 program behaves byte-for-byte identically when compiled as EXTRACAL: same output, same errors, same exit status. EXTRACAL may only give meaning to programs that Mode 1 rejects or that end in a Mode 1 error (Q122). Every Mode 1 decision in `SPEC_DECISIONS.md` (Q76–Q85 and the T1–T40 table) carries over unchanged unless a requirement below explicitly extends it.

### R2. Mode selection (Q43, Q56)
| Extension | Meaning |
|---|---|
| `.i`, `.3i`–`.7i` | Mode 1 (binary, or TriINTERCAL base 3–7) |
| `.xc` | EXTRACAL, binary |
| `.3xc`–`.7xc` | EXTRACAL, base 3–7 |
| anything else | E998 |

### R3. Modern `ick` extensions, with `ick` 0.35 semantics (Q44)
| # | Extension | Notes |
|---|---|---|
| 1 | NEXT FROM | Like COME FROM, but pushes a NEXT stack entry |
| 2 | Computed COME FROM / NEXT FROM | Target label given by an expression |
| 3 | Computed ABSTAIN | `ABSTAIN expr FROM ...` adds abstention counts. Plain label/gerund ABSTAIN and REINSTATE keep the Mode 1 on/off behavior, so Mode 1 programs are unaffected |
| 4 | ONCE / AGAIN | Statements that abstain or reinstate themselves after running |
| 5 | TRY AGAIN | Restarts the program from the top |
| 6 | Threading | Several COME FROMs on one label (a compile-time E555 in Mode 1) start threads. WHILE |
| 7 | Backtracking | MAYBE, GO BACK, GO AHEAD |
| 8 | Operand overloading | `ick` 0.35's `/` and `\` |
| 9 | CREATE | User-defined statements and operators |
| 11 | CLC-style binary I/O | |
| 12 | Latin keywords | PLACET, FACERE, NON, the Latin gerunds, Latin number words in WRITE IN |

- In `ick` some of these need a flag (for example `-m` for threading). In EXTRACAL every listed extension is always on.
- Not included: item 10 (external calls to C) is deferred, and item 13 (PIC-INTERCAL) is dropped.
- Their behavior is taken from `ick` 0.35's compiler and runtime source and its Revamped Manual. The clean-room rule from Q38 still applies: never read `syslib*.i`, `floatlib.i` or any other library source from `ick`, rick or INTERCAL-64.

### R4. 64-bit types (Q107, Q123)
| Sigil | Name | Width |
|---|---|---|
| `::n` | double cateye | 64-bit scalar |
| `;;n` | double hybrid | 64-bit array |
| `##n` | fence | 32-bit constant |
| `####n` | stockade | 64-bit constant |

- The syntax comes from INTERCAL-64, which is a syntax donor only. EXTRACAL makes no promise to run `.ic64` programs and copies no code (it has a joke license).
- Unary operators rotate at the operand's width (16, 32 or 64).
- Assigning a value to a narrower variable that can't hold it is an error. A Mode 1 case (32-bit into 16-bit) stays E275.

### R5. Mingle widens by value (Q122 b)
| Operand values | Result |
|---|---|
| both ≤ 65535 | 32-bit, exactly as in Mode 1 |
| otherwise both ≤ 4294967295 | 64-bit (where Mode 1 would raise E533) |
| otherwise | a 128-bit **ephemeral** value |

- An ephemeral value can only be consumed by a select, which may use a 128-bit mask. Storing it, printing it or feeding it to a unary operator is an error.
- The width of a mingle result is therefore known only at run time. The compiler adds a static fast path whenever it can prove both operands fit in 16 bits.

### R6. Signed numbers (Q124 b)
- The existing types (16, 32 and 64-bit) are read as two's complement by the signed operations. No new sigils.
- `WRITE IN SIGNED list` accepts a leading `MINUS` word before the digit words.
- `READ OUT SIGNED list` prints negative values as a minus sign followed by the butchered Roman numeral of the magnitude.
- Signed arithmetic (add, subtract, multiply, divide, compare) at all three widths lives in the math block (R10).

### R7. 64-bit Roman numerals and number input (Q125)
- READ OUT splits a value into groups of 12 decimal digits. The lowest group uses the Mode 1 scheme (T30) unchanged.
- The ×10¹² group uses the same scheme with one extra overline on every character, printed as an extra `_` row above. So output can have up to three lines: two overline rows, then the letters. The largest 64-bit value needs only two groups.
- WRITE IN into a 64-bit variable accepts up to 20 digit words. A value over 2⁶⁴−1 is an error.

### R8. Strings (Q108)
A string is a tail array (`,`) holding one Unicode code point per element.

### R9. Floating point (Q109)
- Floats use the layout from spec §8.4: a 32-bit variable whose upper 16 bits are the mantissa and lower 16 bits the characteristic (exponent).
- The library covers add, subtract, multiply, divide, compare, natural logarithm (the §8.4 project list), and conversions to and from integers and decimal strings.

### R10. Standard library (Q74, Q75, Q106)
- Routines live in reserved label blocks and are called with `NEXT`. Arguments and results pass through variables, following syslib's convention (inputs in `.1`/`.2` or `:1`/`:2`, results in the next variables, everything else unchanged).
- **Auto-inclusion:** a block is included when the program `NEXT`s to a label inside it and defines no label in that block itself. That's the same rule as syslib (T36).
- **Native fast paths:** each block also gets a native implementation in `runtime.dart` and `runtime.c`, used whenever the compiler can prove the program can't tell the difference. The INTERCAL version is the reference, exactly like Q37 (c).

| Block | Range | Contents (Q75 item numbers) |
|---|---|---|
| I/O | (2000)–(2999) | 1 plain decimal and ASCII I/O, 2 raw byte I/O on stdin/stdout, 3 stderr, 4 files: open, read, write, close |
| Strings | (3000)–(3999) | 13: length, concatenate, slice, compare, find, number ↔ string, UTF-8 encode/decode |
| Math | (4000)–(4999) | 11 64-bit and signed arithmetic, 15 pow, sqrt, mod, gcd |
| *(reserved)* | (5000)–(5699) | `ick`'s floatlib range: never used, to avoid clashes |
| Arrays | (6000)–(6999) | 14: sort, search, copy, fill, dimension queries |
| Floats | (7000)–(7999) | 12: R9 |
| System | (8000)–(8999) | 5 command-line arguments, 6 environment variables, 7 exit codes, 8 clock and time, 9 seeding the random number generator |
| Network | (9000)–(9999) | 10: TCP client and server sockets, a minimal HTTP/1.1 client, HTTP request/response helpers. No TLS (Q110) |
| *(reserved)* | (16000)–(16999) | INTERCAL on Interstates (goal 3) |

- `(1000)`–`(1999)` stays the clean-room syslib from goal 1.
- Exact routine numbers inside each block, and their argument and result variables, are documented in `packages/ciwapa_core/lib/extracal/README.md` as each block lands.

### R11. Error codes (Q90)
- Every new error condition gets its own new code. Examples: narrowing overflow involving 64-bit values, storing an ephemeral 128-bit value, WRITE IN over 64 bits, file, socket and HTTP failures, string and float domain errors.
- A new code never reuses any code used by `ick` 0.15 or 0.35.
- Each new code gets official text, our joke line (Q90 format), and an entry in `SPEC_DECISIONS.md`.

### R12. Both flavors
Every feature lands in `ciwapa-dart` and `ciwapa-llvm` in the same PR, with conformance tests (Q20). Same platforms, release archives and CI matrix as goal 1.

## Design & Behavior

- **No new dialect, only additions.** The lexer only recognizes new tokens (`::`, `;;`, `##`, `####`, `SIGNED`, the `ick` extension keywords, Latin words) in `.xc` files. In a `.i` file they stay what Mode 1 says they are, usually garbage.
- **Fail loudly.** Library routines report recoverable failures (file not found, connection refused) through a status variable, following syslib's `(1009)`-style `.4` flag. Programming errors (a bad handle, a malformed string) raise an ICL error.
- **INTERCAL style.** Library routines look and feel like syslib's: numbered labels, variables in and out, no hidden state beyond handles.

## Technical Approach

- **Mode in the IR.** `ciwapa_core` records the mode (Mode 1 or EXTRACAL) and the base. Each new construct is a new IR node, lowered by both emitters. Mode 1 code paths are not modified, only extended.
- **Runtime value classes.** Both runtimes gain 64-bit scalars and arrays and the 128-bit ephemeral type. The 128-bit type exists only inside an expression evaluation and never reaches variable storage.
- **Threading and backtracking** follow `ick` 0.35's model. Each runtime implements it natively: Dart isolates or explicit coroutines, and C with explicit context switching. Both must produce identical output on the conformance tests.
- **Library blocks** are written in clean-room INTERCAL as `.xc` sources inside `ciwapa_core`, with the native fast paths in the two runtimes, as in goal 1.
- **Networking** in both runtimes uses the platform's sockets: `dart:io` in `runtime.dart`, and BSD sockets or Winsock in `runtime.c`. HTTP/1.1 is a small hand-written implementation shared in spirit between the two and checked by the same conformance tests. Interstates' `gross` builds on this layer (Q89).

## Affected Areas

- `packages/ciwapa_core`: lexer, parser, type rules, IR nodes, the `.xc` library blocks, auto-inclusion, fast-path proofs.
- `packages/ciwapa_dart`, `packages/ciwapa_llvm`: emitter support for every new IR node.
- `packages/ciwapa_dart` (`runtime.dart`), `packages/runtime_c` (`runtime.c`): 64/128-bit values, signed I/O, threading and backtracking, native library blocks, sockets, HTTP.
- `packages/conformance`: an EXTRACAL suite, plus the superset check (R1).
- `docs/`: EXTRACAL user docs, `SPEC_DECISIONS.md` entries for every new error code and edge-case ruling.
- `tools/goal/`, `tools/oracle/`, `tools/bench/`: goal 1's temporary scaffolding, still present (Q140). This goal reuses it and removes it at the end, along with its own (see Implementation Steps).

## Implementation Steps

The workflow is the same as goal 1, described in [`PLAN.md`](PLAN.md):
- `gh stack` PR stacks on `mega`, merged with merge commits
- a `code-reviewer` sub-agent pass before each merge
- merge on green CI, with every PR starting with the AI-agent note
- `docs/QUESTIONS.md` for anything unforeseen, which stops the goal only if the answer could force undoing a lot of work (Q70)
- auto mode

1. **Temporary scaffolding.** Goal 1 removed nothing (Q140), so these are already in place:
   - `tools/oracle/`: the `ick` 0.35 Docker image plus the `pit/` download. `pit/` has `ick`'s extension tests: `compucome`, `onceagain`, `testonce`, `permute`, `pass` and others.
   - `tools/bench/`: record goal 1's final Mode 1 timings as the no-regression baseline before changing anything.
   - `tools/goal/`: replace goal 1's `goal-status` checks with this plan's acceptance checklist.
2. **The superset harness.** Every Mode 1 conformance program also runs as `.xc` and must produce identical output. This runs on every PR from here on.
3. **Mode plumbing:** `.xc` / `.3xc`–`.7xc` detection and the mode flag in the IR.
4. **64-bit types:** sigils, constants, widths, narrowing errors, unary rotation at 64 bits.
5. **Mingle widening and select** at 64 and 128 bits (R5).
6. **Signed I/O and 64-bit numerals:** `WRITE IN SIGNED`, `READ OUT SIGNED`, 20-digit input, multi-row overlines (R6, R7).
7. **`ick` extensions,** in this order: NEXT FROM → computed COME FROM / NEXT FROM → computed ABSTAIN → ONCE/AGAIN → TRY AGAIN → Latin keywords → CLC-style binary I/O → operand overloading → CREATE → backtracking → threading.
8. **Library blocks,** in this order: System → I/O → Strings → Arrays → Math (including 64-bit and signed arithmetic) → Floats → Network. Each block gets its clean-room INTERCAL source, auto-inclusion, native fast paths in both runtimes, and tests.
9. **User docs** for EXTRACAL.
10. **Cleanup** (Q140). One PR removes **goal 1's and goal 2's** temporary scaffolding together:
    - everything in [`PLAN.md`](PLAN.md)'s "Temporary scaffolding" table: `tools/oracle/`, the `pit/` download, `tools/bench/` and its baseline images, the CI perf-regression check, and the perf-target section of `PLAN.md`;
    - anything this goal added temporarily;
    - every Docker image either loop built.

    Run `goal-status` and show its output, then delete `tools/goal/` and the `goal-status` task last. Show `git status`, the final tree, `git ls-files tools/oracle tools/bench tools/goal` (which must be empty), and `docker image ls`.

## Edge Cases

- A Mode 1 program that ends in E533 by mingling a 32-bit value over 65535 now gets a 64-bit result instead. This is intended (R1, R5), and its conformance test is marked as a deliberate Mode 1 vs. EXTRACAL difference.
- A program that has several COME FROMs on one label is a compile-time E555 in Mode 1 and starts threads in EXTRACAL. The same goes for every construct Mode 1 rejects but EXTRACAL defines.
- Unary operator on a mingle result whose width is only known at run time (R5).
- A 128-bit ephemeral value reaching a store, a READ OUT, or a unary operator.
- `READ OUT SIGNED` of the most negative value at each width.
- A user program that defines one label inside a library block: that block is then not auto-included at all (T36 rule).
- An astral Unicode character (above U+FFFF) in a string. It doesn't fit in one 16-bit tail element; see Assumptions & Decisions.
- Network I/O and threads together: blocking socket calls inside an EXTRACAL thread.
- Windows sockets (Winsock initialisation) and CRLF handling in HTTP.

## Acceptance Criteria

`lattice run goal-status` (temporary, from step 1) prints each item with its linked test and ends in `GOAL: MET` only when every box is ticked.

- [ ] The superset harness passes: every Mode 1 conformance program gives identical output as `.xc`, in both flavors.
- [ ] `.xc` and `.3xc`–`.7xc` select EXTRACAL. Other extensions give E998.
- [ ] Each of `ick` extensions 1–9, 11 and 12 has conformance tests in both flavors. The relevant `pit/` programs match the `ick` 0.35 oracle.
- [ ] 64-bit sigils, constants, widths and narrowing errors are tested.
- [ ] Mingle widening by value (all three cases) and 128-bit select are tested. Misusing an ephemeral value is tested.
- [ ] `WRITE IN SIGNED` and `READ OUT SIGNED` are tested at all widths, including the extremes.
- [ ] 64-bit Roman numerals (both overline rows) and 20-digit WRITE IN are tested.
- [ ] Every library block (System, I/O, Strings, Arrays, Math, Floats, Network) has:
  - its INTERCAL reference version;
  - native fast paths in both runtimes;
  - auto-inclusion;
  - conformance tests showing the reference and fast paths agree.
- [ ] A TCP echo test and an HTTP/1.1 client/server round-trip pass in both flavors on every CI platform.
- [ ] Every new error code is documented in `SPEC_DECISIONS.md` and covered by a test.
- [ ] Mode 1 conformance is unchanged, and Mode 1 benchmark timings show no regression against the goal 1 baseline (Q111).
- [ ] CI is green on all platforms, and the release archives build.
- [ ] All temporary scaffolding from goals 1 and 2 is removed: `git ls-files tools/oracle tools/bench tools/goal` prints nothing, the perf-target section is gone from `PLAN.md`, and no loop-built Docker images remain (Q140).

## Assumptions & Decisions

Decided in the grilling session (see `SPEC_DECISIONS.md`): Q41–Q44, Q56, Q74, Q75, Q89, Q106–Q111, Q122–Q125.

Decided after review (Q135–Q140). These were drafted while writing the plan, and Ryan approved them:
1. **Label block numbers** (R10 table), as written (Q135).
2. **Strings and astral characters.** Strings are tail arrays of code points (Q108). Characters above U+FFFF are stored as UTF-16 surrogate pairs, two elements each (Q136).
3. **Float layout details.** Both halves are 16-bit two's-complement numbers, and value = mantissa × 2^characteristic (Q137).
4. **Negative Roman numerals** print as `-` followed by the numeral of the magnitude (Q138).
5. **Library failure reporting** uses a status flag for recoverable errors and an ICL error for programming errors (Design & Behavior, Q139).
6. **Mode 1 regression baseline.** Goal 1 removes none of its temporary scaffolding, so the benchmark tools are still present to measure "no regression" (Q111). Goal 2's cleanup removes goal 1's and goal 2's scaffolding together (Q140).

## Open Questions

None. Anything unforeseen goes to `docs/QUESTIONS.md` under the Q70 policy.

---

## `/goal` prompt

```
/goal Implement EXTRACAL exactly as specified in docs/EXTRACAL_PLAN.md, following the workflow, clean-room rules and parity rules in docs/PLAN.md, and every decision in docs/SPEC_DECISIONS.md. Never guess: if a decision is missing, record it in docs/QUESTIONS.md, mark the affected checklist item blocked and keep working on everything else. Stop the goal immediately only if the missing answer could force undoing a large amount of work. Work through the Implementation Steps in order, as gh stack PR stacks on mega. Every PR starts with the AI-agent note from docs/PLAN.md and lands both flavors (ciwapa-dart and ciwapa-llvm) together with conformance tests. It needs a code-reviewer sub-agent pass and green CI before you merge it with a merge commit. The superset harness (every Mode 1 conformance program run as .xc gives identical output) must pass on every PR. Use only the dependencies approved in docs/SPEC_DECISIONS.md; anything else goes to QUESTIONS.md. After every stage, run `lattice run goal-status` and show its full output. The goal is met only when that output ends with "GOAL: MET": every acceptance criterion in docs/EXTRACAL_PLAN.md is ticked with a linked passing test, CI is green on every platform, the release archives build, and the cleanup PR has removed goal 1's and goal 2's temporary scaffolding (tools/oracle, tools/bench, tools/goal, the perf-target section of docs/PLAN.md, and every loop-built Docker image). Show `git ls-files tools/oracle tools/bench tools/goal` (empty) and `docker image ls`. The goal is also met if every remaining item is listed as blocked in docs/QUESTIONS.md.
```
