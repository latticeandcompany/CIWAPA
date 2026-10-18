# EXTRACAL checklist

This is the definition of done for EXTRACAL, goal 2 ([`EXTRACAL_PLAN.md`](EXTRACAL_PLAN.md)). Each item names the requirement it comes from and links at least one test that passes in **both** flavors. An item is checked only when its tests exist and pass. Items waiting on an answer in [`QUESTIONS.md`](QUESTIONS.md) are marked **BLOCKED** with the question's number.

Format, as in [`SPEC_CHECKLIST.md`](SPEC_CHECKLIST.md):

```markdown
- [ ] R4 — rule, in one line. Tests: `packages/conformance/...`
```

The sections follow the plan's acceptance criteria. `lattice run goal-status` reads this file; the `pit/` oracle comparison is judged there, from `tools/goal/oracle.json`.

## Superset (R1)

- [x] R1 — every Mode 1 conformance program, compiled as `.xc` (or `.3xc`–`.7xc`), gives identical stdout, stderr and exit status in both flavors. A test with `.xc.out`, `.xc.err` or `.xc.exit` files is a deliberate Mode 1 vs. EXTRACAL difference and is compared with those instead; one whose Mode 1 run doesn't end in an error also needs a `.xc.reason` citing what allows it (such as L15, `come-from/dead-next-from.i`). Tests: `packages/conformance/bin/conformance.dart`
- [x] R1, R5 — a Mode 1 program that ends in E533 by mingling a value over 65535 gets a 64-bit result as `.xc`, a recorded deliberate difference. Tests: `packages/conformance/tests/calculate/e533-mingle-operand.xc.err`, `packages/conformance/tests/ignore/statement-still-executes.xc.err`
- [ ] R1, R3 — several COME FROMs on one label are a compile-time E555 in Mode 1 and start threads as `.xc`, a recorded deliberate difference. Tests: `packages/conformance/tests/come-from/e555.xc.out`

## Mode selection (R2)

- [x] R2 — `.xc` (and `.2xc`, like Mode 1's `.2i`) selects EXTRACAL in base 2. Tests: `packages/ciwapa_core/test/source_test.dart`, `packages/conformance/tests/extracal/mode/xc-is-extracal.xc`
- [x] R2 — `.3xc`–`.7xc` select EXTRACAL in bases 3–7. Tests: `packages/conformance/tests/extracal/mode/base3.3xc`, `packages/conformance/tests/extracal/mode/base7.7xc`
- [x] R2 — `.i` and `.3i`–`.7i` stay Mode 1, where EXTRACAL's tokens are garbage. Tests: `packages/conformance/tests/extracal/mode/i-is-mode1.i`
- [x] R2 — any other extension is E998, including `.xci`, `.8xc` and `.XC`. Tests: `packages/ciwapa_core/test/source_test.dart`, `packages/conformance/tests/errors/e998-extension.bad`

## `ick` extensions (R3)

### 1. NEXT FROM

- [x] R3.1 — `NEXT FROM (n)` takes control after statement (n) like COME FROM, and pushes a NEXT stack entry that returns to the statement after (n). Tests: `packages/conformance/tests/extracal/next-from/basic.xc`, `packages/conformance/tests/extracal/next-from/reinstated.xc`, `packages/conformance/tests/extracal/next-from/off-the-end.xc`
- [x] R3.1 — an executed RESUME springs a plain COME FROM aimed at it (Mode 1's rule) but not a NEXT FROM (`ick`'s), and a NEXT FROM's own fault fires instead of its jump (L2). Tests: `packages/conformance/tests/extracal/next-from/resume-target.xc`, `packages/conformance/tests/extracal/next-from/fault.xc`
- [x] R3.1 — a NEXT FROM aimed at a NEXT fires when the NEXT is RESUMEd to. Tests: `packages/conformance/tests/extracal/next-from/at-next.xc`
- [x] R3.1 — a NEXT FROM that would make the 80th entry is E123. Tests: `packages/conformance/tests/extracal/next-from/e123.xc`
- [x] R3.1 — a NEXT FROM aimed at a missing label is a compile-time E444. Tests: `packages/conformance/tests/extracal/next-from/e444.xc`
- [x] R3.1 — `NEXTING FROM` is its gerund, and `--traditional` rejects it with E111. Tests: `packages/conformance/tests/extracal/next-from/gerund.xc`, `packages/conformance/tests/extracal/next-from/traditional.xc`
- [x] R3 — the control engine that runs `ick`'s control extensions behaves exactly like Mode 1: CI reruns every `.xc` program on it. Tests: `.github/scripts/ci-check.sh`

### 2. Computed COME FROM and NEXT FROM

- [x] R3.2 — `COME FROM expr` takes control after any labelled statement whose label equals the expression's value, evaluated each time a labelled statement finishes. Tests: `packages/conformance/tests/extracal/computed-come-from/basic.xc`, `packages/conformance/tests/extracal/computed-come-from/expression.xc`
- [x] R3.2 — `NEXT FROM expr` does the same and pushes a NEXT stack entry. Tests: `packages/conformance/tests/extracal/computed-come-from/next-from.xc`
- [x] R3.2 — a computed COME FROM may aim at a label that doesn't exist, and does nothing. Tests: `packages/conformance/tests/extracal/computed-come-from/missing-label.xc`
- [x] R3.2 — an executed RESUME springs no computed COME FROM, as in `ick`. Tests: `packages/conformance/tests/extracal/computed-come-from/resume-target.xc`
- [x] R3.2, L18 — `COME FROM` and `NEXT FROM` a gerund list take control after any statement of those kinds; `--traditional` rejects all of them. Tests: `packages/conformance/tests/extracal/computed-come-from/gerund.xc`, `packages/conformance/tests/extracal/computed-come-from/gerund-next-from.xc`, `packages/conformance/tests/extracal/computed-come-from/traditional.xc`

### 3. Computed ABSTAIN

- [x] R3.3 — `ABSTAIN expr FROM (n)` and `ABSTAIN expr FROM gerunds` add to the abstention count; each REINSTATE removes one. A count that would pass 2⁶³−1 saturates. Tests: `packages/conformance/tests/extracal/computed-abstain/counts.xc`, `packages/conformance/tests/extracal/computed-abstain/gerunds.xc`, `packages/conformance/tests/extracal/computed-abstain/huge-count.xc`, `packages/conformance/tests/extracal/computed-abstain/give-up.xc`, `packages/conformance/tests/extracal/computed-abstain/e139.xc`, `packages/conformance/tests/extracal/computed-abstain/traditional.xc` (L20 for saturation)
- [x] R3.3 — plain ABSTAIN and REINSTATE keep Mode 1's on/off behavior. Tests: `packages/conformance/tests/extracal/computed-abstain/plain-is-boolean.xc`

### 4. ONCE and AGAIN

- [x] R3.4 — ONCE on a reinstated statement and AGAIN on an abstained one make it self-abstaining; the other two combinations self-reinstate. A NEXT's happens before it jumps, a COME FROM's where its target is, and an executed RESUME never reaches its own. Tests: `packages/conformance/tests/extracal/once-again/combinations.xc`, `packages/conformance/tests/extracal/once-again/next-once.xc`, `packages/conformance/tests/extracal/once-again/come-from-once.xc`, `packages/conformance/tests/extracal/once-again/resume-once.xc`, `packages/conformance/tests/extracal/once-again/traditional.xc`
- [x] R3.4 — ABSTAIN and REINSTATE turn a statement's ONCE back into AGAIN and back. Tests: `packages/conformance/tests/extracal/once-again/flip.xc`

### 5. TRY AGAIN

- [ ] R3.5 — TRY AGAIN restarts the program from the top; when it doesn't run, the program ends without E633. Tests: `packages/conformance/tests/extracal/try-again/loop.xc`, `packages/conformance/tests/extracal/try-again/abstained-ends.xc`
- [ ] R3.5 — a statement after TRY AGAIN is a compile-time E993. Tests: `packages/conformance/tests/extracal/try-again/e993.xc`

### 6. Threading

- [ ] R3.6 — several COME FROMs or NEXT FROMs aimed at one label split the thread; each thread has its own variables, stashes and NEXT stack and shares abstentions. Tests: `packages/conformance/tests/extracal/threads/split.xc`
- [ ] R3.6 — threads take turns one statement at a time, as in `ick`. Tests: `packages/conformance/tests/extracal/threads/round-robin.xc`
- [ ] R3.6 — GIVE UP ends only the current thread while others remain. Tests: `packages/conformance/tests/extracal/threads/give-up.xc`
- [ ] R3.6 — `a WHILE b` runs b in a woven thread for as long as a is running. Tests: `packages/conformance/tests/extracal/threads/while.xc`

### 7. Backtracking

- [ ] R3.7 — MAYBE creates a choicepoint; GO BACK returns to it with the statement's abstention reversed; GO AHEAD discards it. **BLOCKED** (L15) Tests: `packages/conformance/tests/extracal/backtracking/maybe.xc`
- [ ] R3.7 — GO BACK and GO AHEAD with no choicepoint are E404. Tests: `packages/conformance/tests/extracal/backtracking/e404.xc`

### 8. Operand overloading

- [ ] R3.8 — `.n/expr` returns `.n`'s value and makes `.n` stand for expr from then on. Tests: `packages/conformance/tests/extracal/overloading/slat.xc`
- [ ] R3.8 — assigning to an overloaded variable assigns to its expression, and an impossible reverse assignment is E277. Tests: `packages/conformance/tests/extracal/overloading/reverse.xc`, `packages/conformance/tests/extracal/overloading/e277.xc`

### 9. CREATE

- [ ] R3.9 — `CREATE (n) template` makes statements of that shape NEXT to (n) with `:1601`… standing for their operands. Tests: `packages/conformance/tests/extracal/create/statement.xc`
- [ ] R3.9 — `CREATE (n) x` makes `x` a binary operator. Tests: `packages/conformance/tests/extracal/create/operator.xc`

### 11. CLC-style binary I/O

- [ ] R3.11 — CLC-INTERCAL style binary I/O. **BLOCKED** (L14)

### 12. Latin keywords

- [ ] R3.12 — `PLACET`, `FAC` and the other Latin statement identifiers. **BLOCKED** (L15) Tests: `packages/conformance/tests/extracal/latin/identifiers.xc`
- [ ] R3.12 — the Latin statements, `NON`, `QUONDAM`/`ITERUM` and gerunds. Tests: `packages/conformance/tests/extracal/latin/statements.xc`
- [ ] R3.12 — Latin number words in WRITE IN. Tests: `packages/conformance/tests/extracal/latin/write-in.xc`

## 64-bit types (R4)

- [x] R4 — `::n` is a 64-bit scalar and `;;n` a 64-bit array. Tests: `packages/conformance/tests/extracal/wide/cateye.xc`, `packages/conformance/tests/extracal/wide/double-hybrid.xc`
- [x] R4 — `##n` is a 32-bit constant and `####n` a 64-bit constant; one above its range is E017. Tests: `packages/conformance/tests/extracal/wide/constants.xc`, `packages/conformance/tests/extracal/wide/e017-fence.xc`, `packages/conformance/tests/extracal/wide/e017-stockade.xc`
- [x] R4 — unary operators rotate at the operand's width: 16, 32 or 64 bits, and select works at 64 bits. Tests: `packages/conformance/tests/extracal/wide/unary-64.xc`, `packages/conformance/tests/extracal/wide/select-64.xc`
- [x] R4 — a value over 32 bits stored in a 16- or 32-bit variable is E276; 32 into 16 stays E275. Tests: `packages/conformance/tests/extracal/wide/narrowing-32.xc`, `packages/conformance/tests/extracal/wide/narrowing-16.xc`, `packages/conformance/tests/extracal/wide/e275-stays.xc`
- [x] R4 — 64-bit values used as dimensions, subscripts and FORGET/RESUME counts: a dimension past 32 bits is E241 (after any E240), a subscript past 32 bits is E241, and a count past 32 bits acts like the largest 32-bit count. Tests: `packages/conformance/tests/extracal/wide/dimension-over-32.xc`, `packages/conformance/tests/extracal/wide/dimension-over-32-wide.xc`, `packages/conformance/tests/extracal/wide/subscript-64.xc`, `packages/conformance/tests/extracal/wide/counts-64.xc`
- [x] R4 — 64-bit variables work with STASH, RETRIEVE, IGNORE, REMEMBER, Turing Text and wimp mode. Tests: `packages/conformance/tests/extracal/wide/cateye.xc`, `packages/conformance/tests/extracal/wide/double-hybrid.xc`, `packages/conformance/tests/extracal/wide/turing-64.xc`, `packages/conformance/tests/extracal/wide/wimp-64.xc`
- [x] R4, L17 — bases 3–7 have no 64-bit sigils. Tests: `packages/conformance/tests/extracal/wide/base3-has-no-wide.3xc`, `packages/ciwapa_core/test/ir_test.dart`

## Mingle widening (R5)

- [x] R5 — operands up to 65535 give a 32-bit result, as in Mode 1. Tests: `packages/conformance/tests/extracal/mingle/small.xc`
- [x] R5 — operands up to 4294967295 give a 64-bit result. Tests: `packages/conformance/tests/extracal/mingle/wide-64.xc`
- [x] R5 — larger operands give a 128-bit ephemeral value that a select can consume, with a 128-bit mask. Tests: `packages/conformance/tests/extracal/mingle/ephemeral-select.xc`, `packages/conformance/tests/extracal/mingle/select-over-64.xc`
- [x] R5 — storing, mingling or applying a unary operator to an ephemeral value is E534. Tests: `packages/conformance/tests/extracal/mingle/ephemeral-store.xc`, `packages/conformance/tests/extracal/mingle/ephemeral-unary.xc`, `packages/conformance/tests/extracal/mingle/ephemeral-mingle.xc`
- [ ] R5, R3.8 — printing an ephemeral value, which only operand overloading can ask for, is E534. Tests: `packages/conformance/tests/extracal/overloading/ephemeral-read-out.xc`
- [x] R5 — a unary operator on a mingle rotates at the width the mingle had at run time. Tests: `packages/conformance/tests/extracal/mingle/unary-runtime-width.xc`

## Signed numbers (R6)

- [x] R6 — `WRITE IN SIGNED` reads an optional `MINUS` before the digits, at 16, 32 and 64 bits, including each width's extremes, and in wimp mode. Tests: `packages/conformance/tests/extracal/signed/write-in.xc`, `packages/conformance/tests/extracal/signed/minus-in-the-middle.xc`, `packages/conformance/tests/extracal/signed/wimp-signed.xc`
- [x] R6 — `READ OUT SIGNED` prints negative values as `-` and the numeral of the magnitude, including each width's most negative value. Tests: `packages/conformance/tests/extracal/signed/read-out.xc`
- [x] R6 — a signed value out of its variable's range is E536. Tests: `packages/conformance/tests/extracal/signed/out-of-range.xc`, `packages/conformance/tests/extracal/signed/out-of-range-negative.xc`

## 64-bit numerals (R7)

- [x] R7 — READ OUT of a value of 10¹² or more prints the ×10¹² group with an extra overline row, three lines in all. Tests: `packages/conformance/tests/extracal/numerals/three-lines.xc`, `packages/conformance/tests/extracal/numerals/clockface.xc`
- [x] R7 — the largest 64-bit value. Tests: `packages/conformance/tests/extracal/numerals/largest.xc`
- [x] R7 — WRITE IN into a 64-bit variable takes up to 20 digits; a value over 2⁶⁴−1 is E535, and 20 digits into a 32-bit variable stays E533. Tests: `packages/conformance/tests/extracal/numerals/write-in-20.xc`, `packages/conformance/tests/extracal/numerals/write-in-over.xc`, `packages/conformance/tests/extracal/numerals/write-in-32-stays.xc`

## Standard library (R8–R10)

Every block has its INTERCAL reference version, native fast paths in both runtimes, auto-inclusion, and tests that run the reference (`--no-opt`) and the fast path and compare them.

### System (8000)–(8999)

- [ ] R10 — reference, native paths, auto-inclusion and agreement tests. Tests: `packages/conformance/tests/extracal/lib-system`

### I/O (2000)–(2999)

- [ ] R10 — reference, native paths, auto-inclusion and agreement tests. Tests: `packages/conformance/tests/extracal/lib-io`

### Strings (3000)–(3999)

- [ ] R8, R10 — reference, native paths, auto-inclusion and agreement tests, including astral characters as surrogate pairs. Tests: `packages/conformance/tests/extracal/lib-strings`

### Arrays (6000)–(6999)

- [ ] R10 — reference, native paths, auto-inclusion and agreement tests. Tests: `packages/conformance/tests/extracal/lib-arrays`

### Math (4000)–(4999)

- [ ] R6, R10 — reference, native paths, auto-inclusion and agreement tests, including signed arithmetic at all three widths. Tests: `packages/conformance/tests/extracal/lib-math`

### Floats (7000)–(7999)

- [ ] R9, R10 — reference, native paths, auto-inclusion and agreement tests. Tests: `packages/conformance/tests/extracal/lib-floats`

### Network (9000)–(9999)

- [ ] R10 — reference, native paths, auto-inclusion and agreement tests. Tests: `packages/conformance/tests/extracal/lib-network`
- [ ] R10 — a TCP echo round trip passes in both flavors on every CI platform. Tests: `packages/conformance/tests/extracal/lib-network/tcp-echo.xc`
- [ ] R10 — an HTTP/1.1 client/server round trip passes in both flavors on every CI platform. Tests: `packages/conformance/tests/extracal/lib-network/http-round-trip.xc`

### Auto-inclusion

- [ ] R10 — a program that defines any label in a block doesn't get that block (T36). Tests: `packages/ciwapa_core/test/extracal_library_test.dart`

## Error codes (R11)

Each new code is listed under "EXTRACAL error codes" in [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) and has a test here.

- [ ] R11 — every new error code has official text and a joke line, an entry in `SPEC_DECISIONS.md`, and a test. Tests: `packages/ciwapa_core/test/errors_test.dart`

## Mode 1 is unchanged (Q111)

- [ ] Q111 — the Mode 1 conformance suite passes unchanged in both flavors. Tests: `packages/conformance/bin/conformance.dart`
- [ ] Q111 — Mode 1 benchmark timings show no regression against goal 1's. Tests: `tools/goal/no-regression.json`
