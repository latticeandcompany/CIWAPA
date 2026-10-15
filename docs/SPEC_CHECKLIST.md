# Spec checklist

This is the definition of "100% compliance" for Mode 1. Every rule, statement, operator, error code and I/O behavior in the spec (see [`spec/README.md`](../spec/README.md)) gets a checkbox with a section reference. An item is checked off only when it links to at least one test that passes in **both** flavors (`ciwapa-dart` and `ciwapa-llvm`).

Format:

```markdown
- [ ] §N.N — rule, in one line. Tests: `packages/conformance/...`
```

`(decision: …)` names the answer in [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) that settled an item. `Q…` items come from the planning interview, and `T…` items from the approved ambiguity table. An item without a tag is spelled out in the spec itself. The spec's literal examples are tagged **golden**: each one becomes a conformance test as written, retyped from the rendered PDF and not from extracted text.

Statement numbers in error output are statement ordinals (decision: T33).

## §2 Fundamental concepts

- [ ] §2.1 — **golden:** the sample program (absolute value of 2's-complement 32-bit inputs, loops until zero) compiles, passes the politeness check (7 of 23 statements) and prints the expected Roman numerals. Tests: (none yet)
- [ ] §2.2 — **golden:** `DO :1 <- #0¢#256` stores 65536. Tests: (none yet)

## §3.1 Variables

- [ ] §3.1 — `.n` is a 16-bit unsigned variable (0–65535) and `:n` is a 32-bit unsigned variable (0–4294967295). Tests: (none yet)
- [ ] §3.1 — variable numbers range from 1 to 65535. Tests: (none yet)
- [ ] §3.1 — `.123` and `:123` are distinct variables. Tests: (none yet)
- [ ] §3.1 — leading zeros don't matter: `.1` and `.0001` are the same variable. Tests: (none yet)
- [x] §3.1 — a variable numbered 0 or above 65535 raises E200 when its statement executes. (decision: Q80, Q81) Tests: `packages/conformance/tests/calculate/e200-variable-zero.i`, `packages/conformance/tests/calculate/e200-variable-too-big.i`
- [ ] §3.1 — every variable starts at 0. (decision: Q82) Tests: (none yet)

## §3.2 Constants

- [ ] §3.2 — `#n` is a 16-bit constant from 0 to 65535. Tests: (none yet)
- [x] §3.2 — a constant above 65535 raises E017 when its statement executes. (decision: Q80, Q81) Tests: `packages/conformance/tests/calculate/e017-constant.i`, `packages/conformance/tests/calculate/e017-constant-not-run.i`

## §3.3 Arrays

- [ ] §3.3 — `,n` is a 16-bit array and `;n` is a 32-bit array, numbered 1–65535. Tests: (none yet)
- [ ] §3.3 — `.123`, `:123`, `#123`, `,123` and `;123` are all distinct. Tests: (none yet)
- [ ] §3.3 — elements are written `SUB` followed by the subscripts, optionally separated by spaces. Tests: (none yet)
- [ ] §3.3 — a subscript can be any expression, including another subscripted element. Tests: (none yet)
- [ ] §3.3 — subscripts are 1-based. Tests: (none yet)
- [x] §3.3 — using an array that has never been dimensioned raises E241. (decision: Q82, T26) Tests: `packages/conformance/tests/calculate/e241-undimensioned.i`
- [x] §3.3 — a wrong number of subscripts, a subscript of 0, or a subscript past the dimension raises E241. (decision: T26) Tests: `packages/conformance/tests/calculate/e241-wrong-count.i`, `packages/conformance/tests/calculate/e241-subscript-zero.i`, `packages/conformance/tests/calculate/e241-past-dimension.i`

## §3.4.1 Mingle

- [ ] §3.4.1 — mingle interleaves the bits of two 16-bit operands into a 32-bit result. The first operand supplies the high bit of each pair. Tests: (none yet)
- [ ] §3.4.1 — **golden:** `#65535¢#0` = 2863311530, `#0¢#65535` = 1431655765, and `#255¢#255` equals `#65535`. Tests: (none yet)
- [ ] §3.4.1 — a mingle result is 32-bit typed. Tests: (none yet)
- [x] §3.4.1, §9.2 — if either operand's value exceeds 65535 at run time, mingle raises E533. (decision: Q78) Tests: `packages/conformance/tests/calculate/e533-mingle-operand.i`
- [ ] §3.4.1, §10.1, §11 — mingle can be written `$`, `¢` (UTF-8) or the overpunch `c<backspace>/`. (decision: T14) Tests: (none yet)

## §3.4.1 Select

- [ ] §3.4.1 — select takes the left operand's bits wherever the right operand has a 1 and packs them toward the low end. Both operands are zero-padded to 32 bits. Tests: (none yet)
- [ ] §3.4.1 — **golden:** `#179~#201` = 9, `#201~#179` = 17, `#179~#179` = 31 and `#201~#201` = 15. Tests: (none yet)
- [ ] §3.4.1.1 — a select result has the static type of its right operand: 16-bit for a 16-bit right operand, 32-bit for a 32-bit one. (decision: Q77) Tests: (none yet)
- [ ] §3.4.1 — the operand types are unrestricted, so either side may be 16- or 32-bit. Tests: (none yet)

## §3.4.2 Unary operators

- [ ] §3.4.2 — `&` ANDs each adjacent bit pair, cyclically: the result equals the operand rotated right by one, ANDed with the operand. Tests: (none yet)
- [ ] §3.4.2 — `V` ORs each adjacent bit pair the same way. Tests: (none yet)
- [ ] §3.4.2 — `V−` (bookworm) XORs each adjacent bit pair the same way. Tests: (none yet)
- [ ] §3.4.2 — **golden:** `#&77` = 4, `#V77` = 32879 and `#V−77` = 32875. Tests: (none yet)
- [ ] §3.4.2 — the rotation width is the operand's static type: 16 bits for `.`, `,`, `#` and 16-bit selects; 32 bits for `:`, `;`, mingle results and 32-bit selects. (decision: Q79) Tests: (none yet)
- [ ] §3.4.2, §10.1, §11 — XOR can be written `?`, the overpunch `V<backspace>-`, or `-<backspace>V`. (decision: T14) Tests: (none yet)
- [ ] §3.4.2 — a unary operator goes between the type character and the number: `.&123`, `#V−123`, `:V1`. Tests: (none yet)
- [ ] §3.4.2 — a unary operator on an array name, as in `,&7SUB#1`, applies to the element's value. (decision: T4) Tests: (none yet)
- [ ] §3.4.3 — a unary operator directly after an opening spark or ears applies to the whole group: `'V−#&123'`, `'V−"&#123"'`. Tests: (none yet)
- [ ] §3.4.2 — concatenated unary operators such as `#V−&123` are invalid, so the statement is undecodable. (decision: T4) Tests: (none yet)
- [ ] §3.4.2 — there is no prefix form: `&.1` is invalid. (decision: T4) Tests: (none yet)

## §3.4.3 Precedence and grouping

- [x] §3.4.3 — an ungrouped chain of two or more binary operators, such as `#165¢#203~#358`, is invalid and raises E017 when its statement executes. (decision: Q85, Q97, Q80) Tests: `packages/conformance/tests/calculate/e017-ungrouped-chain.i`
- [ ] §3.4.3 — **golden:** `'#165¢#203'~#358` = 15 and `#165¢'#203~#358'` = 34915. Tests: (none yet)
- [ ] §3.4.3 — sparks `'` and rabbit-ears `"` group expressions. Tests: (none yet)
- [ ] §3.4.3 — a grouper directly after a complete operand closes the current group; anywhere else it opens a new one. As a result, only the first subscript in a list can be a group. (decision: T1) Tests: (none yet)
- [ ] §3.4.3 — the wow `!` is the same as spark-spot `'.`: `'.1~.2'` ≡ `!1~.2'`, and `'V.1¢.2'` ≡ `"V!1¢.2'"`. (decision: T3) Tests: (none yet)
- [ ] §3.4.3 — the rabbit `".` gets no special treatment; it is ears followed by a spot. (decision: T3) Tests: (none yet)
- [ ] §3.4.3 — a subscript list ends at the first binary operator, so `,1SUB#1#1¢#1` parses as `(,1 SUB #1 #1)¢#1`. (decision: T2) Tests: (none yet)
- [ ] §3.4.3 — the spec's ambiguous examples (`,1 SUB #1 ~ #2`, `,1 SUB ,2 SUB #1 #2 #3`, `,1 SUB " ,2 SUB " ,3 SUB #1 " #2 " " #3 "`) each parse the way T1/T2 dictate, and that result is pinned by a test. (decision: T1, T2) Tests: (none yet)
- [ ] §12 — **golden:** `",1SUB',2SUB#1'#2"`, with alternating sparks and ears, parses as nested subscripts. Tests: (none yet)

## §4.1 General format

- [ ] §4.1 — free format: several statements may share a line, and one statement may span lines. Tests: (none yet)
- [ ] §4.1 — statements cannot interlace: all the text between a statement's start and end belongs to it. Tests: (none yet)
- [ ] §4.1 — spaces, tabs and newlines between tokens are ignored. (decision: T5) Tests: (none yet)
- [ ] §4.1 — spaces inside a number join its digits: `#1 2` = `#12`. (decision: T5) Tests: (none yet)
- [ ] §4.1 — no single word of a statement identifier or keyword may contain spaces: `FOR GET` and `D O` don't work, and neither does a split `<-`. (decision: T5) Tests: (none yet)
- [ ] §4.1 — multi-word keywords may be written with or without their internal spaces: `READOUT`, `GIVEUP`, `WRITEIN`, `COMEFROM`, `PLEASEDO`. (decision: T5) Tests: (none yet)
- [ ] §4.1 — source is uppercase only; lowercase text is undecodable. (decision: T6) Tests: (none yet)
- [ ] §4.1 — CRLF line endings are accepted (the `\r` is stripped). (decision: T7) Tests: (none yet)
- [ ] §4.1 — source files are UTF-8. (decision: T14) Tests: (none yet)
- [ ] §4.1 — there is no column or line-length limit, and no statement or variable count limit. (decision: T27) Tests: (none yet)

## §4.2 Labels

- [ ] §4.2 — an optional label `(n)` with n from 1 to 65535 may precede a statement. Tests: (none yet)
- [ ] §4.2 — a statement has at most one label. Tests: (none yet)
- [ ] §4.2 — spaces are allowed inside the parentheses: `( 123 )`. (decision: T5) Tests: (none yet)
- [ ] §4.2, §9.2 — a duplicate label is a compile-time E182. (decision: Q80) Tests: (none yet)
- [x] §4.2, §9.2 — a label of 0 or above 65535 raises E197 when its statement executes. (decision: Q81) Tests: `packages/conformance/tests/calculate/e197-label.i`, `packages/conformance/tests/calculate/e197-label-too-big.i`

## §4.3 Identifiers and qualifiers

- [ ] §4.3 — the statement identifiers are `DO`, `PLEASE` and `PLEASE DO`, interchangeable. Tests: (none yet)
- [ ] §4.3, §10.4 — `DO PLEASE` is also accepted and counts as polite. (decision: T11) Tests: (none yet)
- [x] §4.3 — `NOT` or `N'T` abstains the statement when execution begins (`DON'T`, `DO NOT`, `PLEASE DON'T`, `PLEASE NOT`). Tests: `packages/conformance/tests/calculate/not-skips.i`
- [ ] §4.3 — `%n` gives the statement an n-percent chance of executing each time it is reached. (decision: T22) Tests: (none yet)
- [x] §4.3 — `%0` never executes and `%100` always executes. (decision: T13) Tests: `packages/conformance/tests/calculate/percent-0-never-runs.i`, `packages/conformance/tests/calculate/percent-100-always-runs.i`
- [x] §4.3 — a `%` value above 100 raises E017 when the statement executes. (decision: T13, Q80) Tests: `packages/conformance/tests/calculate/e017-percent-101.i`
- [ ] §4.3 — spaces are allowed between `%` and its number. (decision: T5) Tests: (none yet)
- [ ] §4.3 — the qualifier order is NOT, then `%`. `DO %50 NOT …` is undecodable. (decision: T12) Tests: (none yet)
- [ ] §4.3 — the `%` roll happens every time the statement is reached, before the abstention check. (decision: T22) Tests: (none yet)

## §4.4.1 Calculate

- [ ] §4.4.1 — `<-` assigns the right-hand expression to a variable or array element. Tests: (none yet)
- [ ] §4.4.1 — a 16-bit value assigned to a 32-bit variable is zero-padded. Tests: (none yet)
- [x] §4.4.1 — a 32-bit value up to 65535 can be assigned to a 16-bit variable. (decision: Q76) Tests: `packages/conformance/tests/calculate/large-fits-small.i`, `packages/conformance/tests/calculate/small-takes-65535.i`
- [x] §4.4.1, §9.2 — assigning a value above 65535 to a 16-bit variable raises E275 `DON'T BYTE OFF MORE THAN YOU CAN CHEW.` (decision: Q134) Tests: `packages/conformance/tests/calculate/e275-large-into-small.i`, `packages/conformance/tests/calculate/e275-element.i`
- [ ] §4.4.1 — **golden:** `,1SUB#1#1 <- 'V−,1SUB#1#1¢#1'~'#0¢#65535'` inverts the element's least significant bit (with a DO identifier added). (decision: T2) Tests: (none yet)
- [ ] §4.4.1 — `<-` with a `BY` list dimensions an array: `;7 <- #7 BY .7 BY …`. Tests: (none yet)
- [ ] §4.4.1 — **golden:** the two `;7` dimensioning statements differ as the spec describes. Tests: (none yet)
- [x] §4.4.1 — dimension values may be any expression, including 32-bit ones. (decision: T26) Tests: `packages/conformance/tests/calculate/dimension-32-bit.i`
- [ ] §4.4.1 — redimensioning loses all element values. Tests: (none yet)
- [x] §4.4.1, §9.2 — a dimension of 0 raises E240. Tests: `packages/conformance/tests/calculate/e240-dimension-zero.i`
- [x] §4.4.1, §9.2 — dimensions too large to allocate raise E241. (decision: T26) Tests: `packages/conformance/tests/calculate/e241-too-large.i`, `packages/conformance/tests/calculate/e241-size-overflow.i`, `packages/conformance/tests/calculate/e241-size-overflow-to-zero.i`

## §4.4.2 NEXT

- [x] §4.4.2 — `(label) NEXT` transfers control to the label and pushes the return point on the NEXT stack, which starts empty. Tests: `packages/conformance/tests/next/next-resume.i`
- [x] §4.4.2 — the stack holds at most 79 entries; a NEXT with 79 entries already stored raises E123 `PROGRAM HAS DISAPPEARED INTO THE BLACK LAGOON.` (decision: T16) Tests: `packages/conformance/tests/next/depth-79.i`, `packages/conformance/tests/next/e123-depth-80.i`, `packages/conformance/tests/next/e123-recursion.i`
- [x] §4.4.2, §9.2 — NEXT to a label that doesn't exist raises E129 when it executes. (decision: Q81) Tests: `packages/conformance/tests/next/e129-missing-label.i`, `packages/conformance/tests/next/e129-not-run.i`

## §4.4.3 FORGET

- [x] §4.4.3 — `FORGET exp` evaluates the expression and discards that many NEXT stack entries. Tests: `packages/conformance/tests/next/forget-empties.i`
- [x] §4.4.3 — forgetting more entries than are stacked empties the stack without an error. Tests: `packages/conformance/tests/next/forget-more-than-stacked.i`
- [x] §4.4.3 — `FORGET #0` does nothing. (decision: T17) Tests: `packages/conformance/tests/next/forget-zero.i`
- [x] §4.4.3 — 32-bit FORGET arguments are handled exactly, with no wraparound. (decision: T17) Tests: `packages/conformance/tests/next/forget-32-bit.i`

## §4.4.4 RESUME

- [x] §4.4.4 — `RESUME exp` pops that many entries and returns to the statement after the NEXT that stored the last entry popped. Tests: `packages/conformance/tests/next/next-resume.i`, `packages/conformance/tests/next/computed-goto-1.i`
- [x] §4.4.4 — **golden:** the computed GO TO fragment `(1) DO (2) NEXT / FORGET #1 / (2) DO RESUME .1` behaves as described. Tests: `packages/conformance/tests/next/computed-goto-1.i`, `packages/conformance/tests/next/computed-goto-2.i`
- [x] §4.4.4, §9.2 — `RESUME` of an expression evaluating to #0 raises E621. Tests: `packages/conformance/tests/next/e621-resume-zero.i`
- [x] §4.4.4, §9.2 — resuming more levels than are stacked raises E632. (decision: T17) Tests: `packages/conformance/tests/next/e632-resume-empty.i`, `packages/conformance/tests/next/e632-resume-too-many.i`
- [x] §4.4.4 — 32-bit RESUME arguments are handled exactly, with no wraparound. (decision: T17) Tests: `packages/conformance/tests/next/resume-32-bit.i`

## §4.4.5 STASH

- [ ] §4.4.5 — `STASH list` saves copies of the listed variables and arrays (separated by `+`) and leaves the current values intact. Tests: (none yet)
- [ ] §4.4.5 — each variable has its own last-in-first-out stash. Tests: (none yet)
- [ ] §4.4.5 — STASHing an array saves its dimensions and its data. Tests: (none yet)
- [ ] §4.4.5 — stashing a single array element is invalid, so the statement is undecodable. (decision: T25) Tests: (none yet)
- [ ] §4.4.5 — stashes have no depth limit; E222 fires only when memory runs out. (decision: T25) Tests: (none yet)

## §4.4.6 RETRIEVE

- [ ] §4.4.6 — `RETRIEVE list` restores the most recently STASHed values, and a second RETRIEVE restores the next most recent. Tests: (none yet)
- [ ] §4.4.6 — RETRIEVE of an array restores its old dimensions as well as its values. Tests: (none yet)
- [ ] §4.4.6 — RETRIEVE into a currently undimensioned array restores it normally. (decision: T25) Tests: (none yet)
- [ ] §4.4.6, §9.2 — RETRIEVE of something never STASHed raises E436 `THROW STICK BEFORE RETRIEVING.` Tests: (none yet)

## §4.4.7 IGNORE

- [ ] §4.4.7 — after `IGNORE list`, later statements cannot change the listed variables or arrays. Tests: (none yet)
- [ ] §4.4.7 — **golden:** `.1 <- #1; IGNORE .1; .1 <- #0` leaves `.1` = 1. Tests: (none yet)
- [ ] §4.4.7 — an IGNOREd variable's value can still be read in expressions. Tests: (none yet)
- [ ] §4.4.7 — the statement that tries to change an IGNOREd variable still executes; only the store is blocked. Tests: (none yet)
- [ ] §4.4.7 — assigning an out-of-range value to an IGNOREd 16-bit variable still raises E275 before the store is dropped. (decision: T24) Tests: (none yet)
- [ ] §4.4.7 — WRITE IN to an IGNOREd variable reads a number and throws it away. Tests: (none yet)
- [ ] §4.4.7 — RETRIEVE of an IGNOREd variable pops its stash and throws the value away; the current value is kept. (decision: T24) Tests: (none yet)
- [ ] §4.4.7 — stores into elements of an IGNOREd array are bounds-checked (E241) and then dropped. (decision: T24) Tests: (none yet)
- [ ] §4.4.7 — redimensioning an IGNOREd array is blocked, but a zero dimension still raises E240. (decision: T24) Tests: (none yet)

## §4.4.8 REMEMBER

- [ ] §4.4.8 — `REMEMBER list` ends the IGNORE for the listed variables and arrays. Tests: (none yet)
- [ ] §4.4.8 — IGNOREing more than once needs only one REMEMBER, and REMEMBERing something never IGNOREd is not an error. Tests: (none yet)

## §4.4.9 ABSTAIN

- [ ] §4.4.9 — `ABSTAIN FROM (label)` abstains the labeled statement. Tests: (none yet)
- [ ] §4.4.9 — `ABSTAIN FROM gerund+gerund…` abstains every statement of those types. Tests: (none yet)
- [ ] §4.4.9 — an abstained statement is skipped, and control moves to the next statement. Tests: (none yet)
- [ ] §4.4.9 — abstention is a single on/off flag; abstaining twice equals abstaining once. (decision: T20) Tests: (none yet)
- [ ] §4.4.9 — labels and gerunds cannot be mixed in one ABSTAIN. (decision: T20) Tests: (none yet)
- [ ] §4.4.9 — the gerunds are CALCULATING, NEXTING, FORGETTING, RESUMING, STASHING, RETRIEVING, IGNORING, REMEMBERING, ABSTAINING, REINSTATING, READING OUT, WRITING IN and COMING FROM. (decision: T21) Tests: (none yet)
- [ ] §4.4.9 — CALCULATING covers both assignment and array dimensioning. (decision: T21) Tests: (none yet)
- [ ] §4.4.9 — ABSTAINING covers every ABSTAIN statement (label and gerund forms), including the one executing. (decision: T21) Tests: (none yet)
- [ ] §4.4.9 — `ABSTAIN FROM REINSTATING` is valid. Tests: (none yet)
- [ ] §4.4.9 — `ABSTAIN FROM GIVING UP` is invalid, so the statement is undecodable. (decision: T20) Tests: (none yet)
- [ ] §4.4.9 — ABSTAIN of a GIVE UP by label works. (decision: T20) Tests: (none yet)
- [ ] §4.4.9, §9.2 — ABSTAIN of a label that doesn't exist raises E139 when it executes. (decision: Q81) Tests: (none yet)

## §4.4.10 REINSTATE

- [ ] §4.4.10 — REINSTATE by label or gerund list clears an abstention, whatever set it (gerund, label or NOT). Tests: (none yet)
- [ ] §4.4.10 — `REINSTATE REINSTATING` can free a `DON'T REINSTATE` statement. Tests: (none yet)
- [ ] §4.4.10 — `REINSTATE GIVING UP` is invalid, so the statement is undecodable. (decision: T20) Tests: (none yet)
- [ ] §4.4.10 — REINSTATE of a GIVE UP by label does nothing, so `DON'T GIVE UP` always stays a no-op. Tests: (none yet)
- [ ] §4.4.10, §9.2 — REINSTATE of a label that doesn't exist raises E139 when it executes. (decision: Q81) Tests: (none yet)
- [ ] §4.4.10 — any argument other than a label or a gerund list is invalid. Tests: (none yet)

## §4.4.11 GIVE UP

- [x] §4.4.11 — `GIVE UP` ends the program cleanly with exit status 0. (decision: T18) Tests: `packages/conformance/tests/next/give-up.i`, `packages/conformance/tests/next/give-up-with-stack.i`
- [x] §4.4.11 — `DON'T GIVE UP` does nothing. Tests: `packages/conformance/tests/next/dont-give-up.i`

## §4.4.12 WRITE IN (numbers)

- [ ] §4.4.12 — `WRITE IN list` reads one number per input line for each variable or array element in the list. Tests: (none yet)
- [ ] §4.4.12 — each digit is a spelled-out word, separated by one or more spaces. Words are uppercase and matched exactly. (decision: T28) Tests: (none yet)
- [ ] §4.4.12 — zero may be written `ZERO` or `OH`. Tests: (none yet)
- [ ] §4.4.12 — `NINER` means nine. Tests: (none yet)
- [ ] §4.4.12 — digit words are also accepted in Sanskrit, Basque, Tagalog, Classical Nahuatl, Georgian, Kwakiutl and Volapük, using ick's word lists. Volapük also accepts UTF-8 umlauts (MÄL, JÖL, ZÜL). There are no Latin words. (decision: T29) Tests: (none yet)
- [ ] §4.4.12 — the largest accepted input is FOUR TWO NINE FOUR NINE SIX SEVEN TWO NINE FIVE. Tests: (none yet)
- [ ] §4.4.12, §9.2 — input above 32 bits raises E533. Tests: (none yet)
- [ ] §4.4.12 — a value of 65536 or more into a 16-bit target raises E275 `DON'T BYTE OFF MORE THAN YOU CAN CHEW.` (decision: Q84, Q134) Tests: (none yet)
- [ ] §4.4.12, §9.2 — a blank line or end of input raises E562. (decision: T28) Tests: (none yet)
- [ ] §4.4.12, §9.2 — an unknown word raises E579. (decision: T28) Tests: (none yet)
- [ ] §4.4.12 — a final line without a trailing newline keeps its last letter. (decision: T28) Tests: (none yet)

## §4.4.13 READ OUT (numbers)

- [ ] §4.4.13 — `READ OUT list` prints one value per line. The list may hold variables, array elements and constants. Tests: (none yet)
- [ ] §4.4.13 — output is butchered Roman numerals, printed as two lines: a line of `_` overbars (with spaces), then the numeral line. (decision: T30) Tests: (none yet)
- [ ] §4.4.13 — zero prints as an overbar with nothing under it (`_`, then an empty line). (decision: T30) Tests: (none yet)
- [ ] §4.4.13 — an overline means ×1,000, lowercase means ×1,000,000, and overlined lowercase means ×1,000,000,000. Tests: (none yet)
- [ ] §4.4.13 — **golden:** `#3999` prints MMMCMXCIX. Tests: (none yet)
- [ ] §4.4.13 — **golden:** `#4000` prints ĪV̄. Tests: (none yet)
- [ ] §4.4.13 — if the value's residue mod 1,000,000 is under 4000, M stands for 1000; otherwise barred Ī does. The same rule applies to M̄/i at 10⁶ and to m/ī at 10⁹, following ick's `butcher()`. (decision: T30) Tests: (none yet)
- [ ] §4.4.13 — **golden:** 4294967295 prints ī v̄ ccxciv C̄M̄L̄X̄V̄ĪĪ CCXCV, with overbars placed as the spec renders them. Tests: (none yet)
- [ ] §4.4.13 — 1972063 prints `MCMLXXMMLXIII` with the first six characters barred. (decision: T30) Tests: (none yet)

## §4.4.14 COME FROM

- [ ] §4.4.14.2 — `COME FROM (label)` jumps to itself immediately after the labeled statement executes or is abstained from. Tests: (none yet)
- [ ] §4.4.14.2 — when the target is an executed NEXT, the jump happens when a RESUME returns to that NEXT. Tests: (none yet)
- [ ] §4.4.14.2 — an ABSTAIN or `%` on the target affects only the target, not the jump. Tests: (none yet)
- [ ] §4.4.14.2 — an ABSTAIN or `%` on the COME FROM itself does affect the jump. Tests: (none yet)
- [ ] §4.4.14.2 — reaching the COME FROM statement itself does nothing. Tests: (none yet)
- [ ] §4.4.14.2 — a target that raises an error, or a GIVE UP target, exits before any jump. (decision: T19) Tests: (none yet)
- [ ] §4.4.14.2 — a COME FROM that targets itself loops forever. (decision: T19) Tests: (none yet)
- [ ] §4.4.14.2 — chained COME FROMs work: arriving at one triggers any COME FROM aimed at it. (decision: T19) Tests: (none yet)
- [ ] §4.4.14.2, §9.2 — two or more COME FROMs aimed at one label are a compile-time E555. Abstained COME FROMs count too. (decision: T19) Tests: (none yet)
- [ ] §9.2 — a COME FROM aimed at a label that doesn't exist is a compile-time E444. (decision: T19) Tests: (none yet)

## §4.5 Comments and undecodable statements

- [x] §4.5 — a statement the compiler can't decode compiles anyway, and raises E000 only if it executes. Tests: `packages/conformance/tests/calculate/e000-only-if-executed.i`, `packages/conformance/tests/calculate/e000-undecodable.i`
- [x] §4.5, §9.1 — E000's message is the statement's source text verbatim. Lines after the first are indented with a tab, and very long text is cut off at about 500 characters. (decision: T10) Tests: `packages/conformance/tests/calculate/e000-shares-lines.i`, `packages/conformance/tests/calculate/e000-long-text.i`
- [ ] §4.5 — **golden:** `PLEASE NOTE THAT THIS LINE HAS NO EFFECT` (abstained by NOT) is ignored. Tests: (none yet)
- [ ] §4.5 — **golden:** the `DON'T YOU REALIZE THIS STATEMENT SHOULD ONLY BE ENCOUNTERED ONCE?` + `PLEASE REINSTATE (123)` pair raises E000 the second time. Tests: (none yet)
- [ ] §4.5 — `DO`, `PLEASE` and `(n)` are recognized anywhere, even inside a word: "NOTE THAT THIS LINE DOES NOTHING" breaks at "DOES". (decision: T8) Tests: (none yet)
- [ ] §4.5 — "D-space-O" is not an identifier. Tests: (none yet)
- [ ] §4.5 — undecodable text runs up to the next `DO`/`PLEASE`/label token, and a following label starts the next statement. (decision: T8) Tests: (none yet)
- [ ] §4.5 — junk after a complete statement makes that statement undecodable (E000 if it executes). (decision: T9) Tests: (none yet)
- [ ] §4.5 — a `*` in the source is junk; it isn't the listing's splat marker. (decision: T15) Tests: (none yet)
- [ ] §4.5, TONSIL — any character with no use in TONSIL A makes its statement undecodable. (decision: T14) Tests: (none yet)
- [ ] §4.5 — an undecodable statement keeps its label, NOT and `%` qualifiers, so it can be ABSTAINed or REINSTATEd by label. (decision: T8) Tests: (none yet)

## §5.2 Turing Text character I/O

- [ ] §5.2 — a one-dimensional array in a WRITE IN or READ OUT list does character I/O, element by element from first to last. Tests: (none yet)
- [ ] §5.2 — both tail and hybrid arrays work. (decision: T31) Tests: (none yet)
- [ ] §5.2 — an array with more than one dimension in an I/O list raises E241. (decision: T31) Tests: (none yet)
- [ ] §5.2 — input stores (current character − previous character) mod 256. Tests: (none yet)
- [ ] §5.2 — end of input stores 256 (one more than the highest character). Tests: (none yet)
- [ ] §5.2 — after end of input, the previous character resets so the next value read is the character + 1. (decision: T31) Tests: (none yet)
- [ ] §5.2 — output computes c = (last output − element) mod 256, remembers c, and writes c's 8 bits in reverse order. Tests: (none yet)
- [ ] §5.2 — the bit reversal affects only what's written out, not the value kept for the next subtraction. Tests: (none yet)
- [ ] §5.2 — input and output use separate tapes, and both start at character 0. Tests: (none yet)
- [ ] §5.2 — characters are 8 bits. Tests: (none yet)
- [ ] §5.2 — newlines get no special treatment. (decision: T31) Tests: (none yet)
- [ ] §5.2 — output is flushed at every newline and when the program exits. (decision: T31) Tests: (none yet)
- [ ] §5.2 — number I/O and Turing Text I/O can be mixed in one list. Tests: (none yet)
- [ ] §5.3 — **golden:** the `cat` program as printed fails politeness with E079 (3 polite statements out of 22), and a polite variant of it copies its input to its output exactly. (decision: T35) Tests: (none yet)

## §6 TriINTERCAL and other bases

- [ ] §6.3, §6.6 — the extension picks the base: `.i` and `.2i` are base 2, `.3i`–`.7i` are bases 3–7. (decision: T40) Tests: (none yet)
- [ ] §6.6, §9.2 — any other source extension is a compile-time E998. (decision: T40) Tests: (none yet)
- [ ] §6.6 — small types hold 16 bits, 10 trits, 8 quarts, 6 quints, 6 sexts or 5 septs; large types hold twice as many digits. Tests: (none yet)
- [ ] §6.4 — the largest small value is 59048 / 65535 / 15624 / 46655 / 16806 in bases 3–7. (decision: T40) Tests: (none yet)
- [ ] §6.4 — the largest large value is 3486784400 / 4294967295 / 244140624 / 2176782335 / 282475248 in bases 3–7. (decision: T40) Tests: (none yet)
- [ ] §6.4 — a constant above the base's small limit raises E017 when its statement executes. (decision: T40, Q80) Tests: (none yet)
- [ ] §6.4 — WRITE IN of a number too big for its target raises E275 (small target) or E533 (large target). (decision: T40) Tests: (none yet)
- [ ] §6.5.1 — mingle interleaves the digits of two small operands into a large result. Tests: (none yet)
- [ ] §6.5.2.2 — select ANDs digit by digit, then packs digits by selector value: the digits under b−1 go to the low end first, then the lower selector values in turn, and the 0-selected digits fill the high end. (decision: T40) Tests: (none yet)
- [ ] §6.5.2.2 — a select result has the same type as in standard INTERCAL. (decision: Q77) Tests: (none yet)
- [ ] §6.5.2.1, §6.6 — `V` (OR) returns the larger digit of each cyclic adjacent pair. Tests: (none yet)
- [ ] §6.5.2.1, §6.6 — `&` (AND) chooses 0 if it can, otherwise the larger digit. Tests: (none yet)
- [ ] §6.5.2.1, §6.6 — `@` (BUT) prefers 1, then 0, then the largest remaining digit. Tests: (none yet)
- [ ] §6.6 — `N@` prefers digit N, and is allowed only where N ≤ b−2. (decision: T40) Tests: (none yet)
- [ ] §6.6 — `0@` is not permitted. Tests: (none yet)
- [ ] §6.5.2.3, §6.6 — `?` subtracts without borrow: the operand rotated right one digit, minus the original, digit by digit mod b. Tests: (none yet)
- [ ] §6.5.2.3, §6.6 — `^` (sharkfin) adds without carry, digit by digit mod b. Tests: (none yet)
- [ ] §6.6, §9.2 — `@` or `^` in a `.i`/`.2i` file, or any operator the base doesn't support, is a compile-time E997. (decision: T40) Tests: (none yet)
- [ ] §6.5.3 — **golden:** the base-3 mappings `"^.3$#1"~#1`, `"V.3$#1"~#1`, `"V'"&.3$#2"~#1'$#1"~#1`, `"?'"&.3$#2"~#1'$#1"~#1`, `"V!3~#2'$#1"~#1`, `"?!3~#2'$#1"~#1` and `"@'"^.3$#7"~#4'$#2"~#10` each produce the stated results. Tests: (none yet)
- [ ] §6.5.3 — **golden:** `"^.3$.3"~"#0$#29524"` swaps 1-trits and 2-trits. Tests: (none yet)
- [ ] §6.6 — **golden:** both balanced-quinary negation forms in a `.5i` file agree. Tests: (none yet)
- [ ] §6 — I/O is decimal digit words and Roman numerals in every base; Turing Text is unchanged. (decision: T40) Tests: (none yet)
- [ ] §6.3 — a program cannot mix dialects. Tests: (none yet)
- [ ] §10.2, §9.2 — `--traditional` with a base other than 2 is E111. (decision: T39) Tests: (none yet)

## §7 Subroutine library

The library is a clean-room implementation written from these contracts alone (decision: Q35, Q37, Q38). Its source and native fast paths must match them.

- [ ] §7.1 — operands go in `.1`/`.2` (or `:1`/`:2`), and results go in the next variable(s). Tests: (none yet)
- [ ] §7.1 — every variable not used for a result is left unchanged. Tests: (none yet)
- [ ] §7.2 — (1000): `.3 <- .1 + .2`, with an error exit on overflow. Tests: (none yet)
- [ ] §7.2 — (1009): `.3 <- .1 + .2`, and `.4 <- #1` if no overflow, otherwise `#2`. Tests: (none yet)
- [ ] §7.2 — (1010): `.3 <- .1 − .2`, with no action on overflow. Tests: (none yet)
- [ ] §7.2 — (1020): `.1 <- .1 + #1`, with no action on overflow. Tests: (none yet)
- [ ] §7.2 — (1030): `.3 <- .1 × .2`, with an error exit on overflow. Tests: (none yet)
- [ ] §7.2 — (1039): `.3 <- .1 × .2`, with the `.4` overflow flag as in (1009). Tests: (none yet)
- [ ] §7.2 — (1040): `.3 <- .1 ÷ .2`, or `#0` if `.2` is `#0`. Tests: (none yet)
- [ ] §7.2 — (1050): `.2 <- :1 ÷ .1`, with an error exit on overflow, or `#0` if `.1` is `#0`. Tests: (none yet)
- [ ] §7.2 — (1060): `.3 <-` the bitwise OR of `.1` and `.2`. Tests: (none yet)
- [ ] §7.2 — (1070): `.3 <-` the bitwise AND of `.1` and `.2`. Tests: (none yet)
- [ ] §7.2 — (1080): `.3 <-` the bitwise XOR of `.1` and `.2`. Tests: (none yet)
- [ ] §7.2 — (1500): `:3 <- :1 + :2`, with an error exit on overflow. Tests: (none yet)
- [ ] §7.2 — (1509): `:3 <- :1 + :2`, and `:4 <- #1` if no overflow, otherwise `#2`. Tests: (none yet)
- [ ] §7.2 — (1510): `:3 <- :1 − :2`, with no action on overflow. Tests: (none yet)
- [ ] §7.2 — (1520): `:1 <- .1` concatenated with `.2`. Tests: (none yet)
- [ ] §7.2 — (1525): internal routine that shifts `.3` left 8 bits. Tests: (none yet)
- [ ] §7.2 — (1530): `:1 <- .1 × .2`. Tests: (none yet)
- [ ] §7.2 — (1540): `:3 <- :1 × :2`, with an error exit on overflow. Tests: (none yet)
- [ ] §7.2 — (1549): `:3 <- :1 × :2`, with the `:4` overflow flag. Tests: (none yet)
- [ ] §7.2 — (1550): `:3 <- :1 ÷ :2`, or `#0` if `:2` is `#0`. Tests: (none yet)
- [ ] §7.2 — (1900): `.1 <-` a uniform random number from #0 to #65535. Tests: (none yet)
- [ ] §7.2 — (1910): `.2 <-` a normal random number from #0 to `.1`, with standard deviation `.1`/#12. Tests: (none yet)
- [ ] §7.2 — an "error exit" is E000 whose message is the statement text `DOUBLE OR SINGLE PRECISION OVERFLOW`. (decision: Q38) Tests: (none yet)
- [ ] §7 — a library call uses NEXT stack levels as a real INTERCAL routine would, so E123 depth behavior is the same whether the native fast path runs or not. (decision: Q37) Tests: (none yet)
- [ ] §7 — the INTERCAL reference version is used whenever a program can observe library internals (COME FROM, ABSTAIN or REINSTATE on a library label, and the like). (decision: Q37) Tests: (none yet)
- [ ] §7.3 — the library is included only when a NEXT targets a label in 1000–1999 and the program defines no label in that range. ABSTAIN and other references don't trigger it. (decision: T36) Tests: (none yet)
- [ ] §7.3 — running off the end of the user's program raises E633; it never falls into the included library. (decision: T37) Tests: (none yet)

## §9 Error messages

- [ ] §9.1 — every error goes to stderr in this form:
  - line 1: `ICLnnnI <official text>`
  - line 2: our joke line, indented
  - line 3: a tab, then `ON THE WAY TO STATEMENT <n>`
  - line 4: eight spaces, then `CORRECT SOURCE AND RESUBMIT`

  (decision: T33, Q90) Tests: (none yet)
- [ ] §9.1 — `<n>` is the ordinal of the statement that would have run next, not zero-padded. For a NEXT that's its target; for a COME FROM target it's the COME FROM; for E633 it's the last ordinal + 1; for compile-time errors it's the offending statement's ordinal. (decision: T33) Tests: (none yet)
- [ ] §9.1 — the official text is the spec's literal message where §4 gives one (E123, E436, and E275 for every trigger); otherwise it is the §9.2 description verbatim, uppercased. (decision: Q83, Q84, Q134) Tests: (none yet)
- [ ] §9.1 — every error code has its own original joke line printed under the official text. (decision: Q90) Tests: (none yet)
- [ ] §9 — the exit status is the error code mod 256 (so E000 exits 0 and E436 exits 180). (decision: T34) Tests: (none yet)
- [ ] §9 — errors local to one statement fire when that statement executes. Errors about the whole program (E182, E444, E555, E079, E099, E998, E997, E111, E777) fire at compile time. (decision: Q80) Tests: (none yet)
- [x] §9.2 — E000: an undecodable statement executed. Tests: `packages/conformance/tests/calculate/e000-undecodable.i`
- [x] §9.2 — E017: expression syntax error (out-of-range constant, ungrouped operator chain, bad `%`). (decision: Q81, Q97, T13) Tests: `packages/conformance/tests/calculate/e017-constant.i`, `packages/conformance/tests/calculate/e017-ungrouped-chain.i`, `packages/conformance/tests/calculate/e017-percent-101.i`
- [ ] §9.2 — E079: insufficiently polite. (decision: T35) Tests: (none yet)
- [ ] §9.2 — E099: excessively polite. (decision: T35) Tests: (none yet)
- [x] §9.2 — E123: 80 attempted levels of NEXTing (fires when 79 are stored). (decision: T16) Tests: `packages/conformance/tests/next/e123-depth-80.i`
- [x] §9.2 — E129: transfer to a non-existent label. Tests: `packages/conformance/tests/next/e129-missing-label.i`
- [ ] §9.2 — E139: ABSTAIN or REINSTATE of a non-existent label. Tests: (none yet)
- [ ] §9.2 — E182: label multiply defined. Tests: (none yet)
- [x] §9.2 — E197: invalid line label. Tests: `packages/conformance/tests/calculate/e197-label.i`
- [x] §9.2 — E200: unidentified variable. Tests: `packages/conformance/tests/calculate/e200-variable-zero.i`
- [x] §9.2 — E240: array dimension of zero. Tests: `packages/conformance/tests/calculate/e240-dimension-zero.i`
- [x] §9.2 — E241: invalid dimensioning information. Tests: `packages/conformance/tests/calculate/e241-undimensioned.i`, `packages/conformance/tests/calculate/e241-too-large.i`
- [x] §9.2 — E275: 32-bit value assigned to a 16-bit variable, printed as `DON'T BYTE OFF MORE THAN YOU CAN CHEW.` (decision: Q134) Tests: `packages/conformance/tests/calculate/e275-large-into-small.i`
- [ ] §9.2 — E436: retrieval of an unSTASHed value. Tests: (none yet)
- [ ] §9.2 — E533: WRITE IN or mingle produced a value over 32 bits. Tests: (none yet)
- [ ] §9.2 — E562: insufficient data. Tests: (none yet)
- [ ] §9.2 — E579: input data invalid. Tests: (none yet)
- [x] §9.2 — E621: RESUME expression evaluated to #0. Tests: `packages/conformance/tests/next/e621-resume-zero.i`
- [x] §9.2 — E632: terminated via RESUME instead of GIVE UP. Tests: `packages/conformance/tests/next/e632-resume-empty.i`
- [x] §9.2 — E633: execution passed beyond the last statement. Tests: `packages/conformance/tests/calculate/e633-after-assignments.i`
- [ ] §9.2, §12 — E774: random compiler bug (see §12). Tests: (none yet)
- [ ] §9.2 — E778: unexplainable compiler error (also used by `+help`, see §10.3). (decision: T38) Tests: (none yet)
- [ ] §9.2 — E111: C-INTERCAL extension used with `--traditional`. (decision: T39) Tests: (none yet)
- [ ] §9.2 — E222: out of stash space (only when memory runs out). (decision: T25) Tests: (none yet)
- [ ] §9.2 — E333: too many variables (only when memory runs out). (decision: T27) Tests: (none yet)
- [ ] §9.2 — E444: COME FROM to a non-existent label. Tests: (none yet)
- [ ] §9.2 — E555: more than one COME FROM to one label. Tests: (none yet)
- [ ] §9.2 — E666: too many source lines (only when memory runs out). (decision: T27) Tests: (none yet)
- [ ] §9.2 — E777: no such source file. Tests: (none yet)
- [ ] §9.2 — E888: can't write the output executable or temp files. (decision: Q133) Tests: (none yet)
- [ ] §9.2 — E998: invalid source extension (use `.i` or `.[3-7]i`). Tests: (none yet)
- [ ] §9.2 — E997: illegal possession of a controlled unary operator. Tests: (none yet)

## §10 The C-INTERCAL compiler (CIWAPA equivalents)

- [ ] §10.1 — ASCII substitutes are accepted: `$` for ¢ and `?` for V−. Tests: (none yet)
- [ ] §10.2 — `--traditional` (`ick -t`) requires strict INTERCAL-72: COME FROM and other bases raise E111. (decision: Q15, Q101, T39) Tests: (none yet)
- [ ] §10.2, §12 — `--no-random-bug` (`ick -b`) turns off E774. (decision: Q101) Tests: (none yet)
- [ ] §10.2 — `--clockface` (`ick -C`) prints IIII, and MMMM for 4000. (decision: Q101, T30) Tests: (none yet)
- [ ] §10.2 — `--keep` (`ick -c`) keeps the generated `.dart`/`.ll` source. (decision: Q101) Tests: (none yet)
- [ ] §10.2 — `--dump=ast|ir` (`ick -d`) prints the parse or IR. (decision: Q101) Tests: (none yet)
- [ ] §10.2 — optimization is on by default (`ick -O`), and `--no-opt` turns it off. Both give identical program behavior. (decision: Q101) Tests: (none yet)
- [ ] §10.2 — `--seed <n>` makes E774 placement reproducible. (decision: Q101, T23) Tests: (none yet)
- [ ] §10.3 — compiled programs accept the `+`/`-` runtime options, read until the first argument without a sign. (decision: Q102) Tests: (none yet)
- [ ] §10.3 — `+help`/`-help` print usage and exit with E778, with no 3-second sleep. (decision: T38) Tests: (none yet)
- [ ] §10.3 — `+traditional` does nothing at run time. Tests: (none yet)
- [ ] §10.3 — `+wimpmode` prints our own humiliating message to stderr, then does decimal number I/O (`%u` per line). The default is `-wimpmode`. (decision: T32) Tests: (none yet)
- [ ] §10.3 — `+seed <n>` makes the `%` randomness reproducible. (decision: Q102, T22) Tests: (none yet)
- [ ] §10.4 — a program where fewer than 1/5 of statements use PLEASE is a compile-time E079. (decision: T35) Tests: (none yet)
- [ ] §10.4 — a program where more than 1/3 of statements use PLEASE is a compile-time E099. (decision: T35) Tests: (none yet)
- [ ] §10.4 — exactly 1/5 and exactly 1/3 both pass, because the comparisons use exact fractions. (decision: T35) Tests: (none yet)
- [ ] §10.4 — the check counts statements whose identifier includes PLEASE (`PLEASE`, `PLEASE DO`, `DO PLEASE`), not PLEASE text anywhere. (decision: T35, T11) Tests: (none yet)
- [ ] §10.4 — comments and undecodable statements count as statements; the auto-included library does not. (decision: T35) Tests: (none yet)
- [ ] §10.4 — the check applies only to programs with more than 2 statements. (decision: T35) Tests: (none yet)

## §12 Princeton compiler (BUG option only)

- [ ] §12 — by default each statement has a fixed 1-in-128 chance, chosen at compile time, of getting a random compiler bug. It fires E774 whenever that statement is reached, even if abstained. (decision: T23) Tests: (none yet)
- [ ] §12 — the BUG option doesn't affect E778. Tests: (none yet)
- [ ] §12 — the conformance suite always compiles with `--no-random-bug`. (decision: T23) Tests: (none yet)

## TONSIL A — character set

- [ ] TONSIL — `.` `:` `,` `;` `#` mark 16-bit variables, 32-bit variables, 16-bit arrays, 32-bit arrays and constants. Tests: (none yet)
- [ ] TONSIL — `'` and `"` are groupers. `!` is spark-spot. Tests: (none yet)
- [ ] TONSIL — `%` is the percentage qualifier; `<` and `-` form `<-`; `(` and `)` wrap labels; `+` separates list items. Tests: (none yet)
- [ ] TONSIL — `&`, `V`, `V−`/`?` are the unary operators; `$`/`¢` mingle; `~` selects. Tests: (none yet)
- [ ] TONSIL, §6 — `@` and `^` are operators only in bases 3–7. (decision: T40) Tests: (none yet)
- [ ] TONSIL — `=`, `` ` ``, `|`, `>`, `[`, `]`, `{`, `}`, `_`, `/`, `\`, `¬` and the blotch have no use, so they make their statement undecodable. (decision: T14) Tests: (none yet)
- [ ] TONSIL — `V` is also an ordinary letter inside keywords (GIVE, REMEMBER, …). Tests: (none yet)

## Program-level behavior

- [x] §9.2 — falling off the end of the program raises E633. Tests: `packages/conformance/tests/calculate/e633-after-assignments.i`
- [x] §4.4.11, §9 — GIVE UP exits 0; any error exits with its code mod 256. (decision: T18, T34) Tests: `packages/conformance/tests/next/give-up.i`, `packages/conformance/tests/calculate/e275-large-into-small.i`, `packages/conformance/tests/calculate/e000-undecodable.i`
- [ ] §4.3 — by default the `%` RNG is seeded from the time; `+seed` overrides it. (decision: T22) Tests: (none yet)

## Excluded by decision

- §12 Princeton compiler options OPT/NOOPT, OPTSUB/NOOPTSUB/NOSUB, IAMBIC/PROSE, FORMAT/NOFORMAT, SEQ/NOSEQ, SOURCE/NOSOURCE, LIST/NOLIST, WIDTH=nn, CODE/NOCODE, LINES=nn, DECK/NODECK, KIDDING/NOKIDDING, GO/NOGO and EXECUTE/NOEXECUTE, plus the JCL procedure. Only BUG/NOBUG is kept, as `--no-random-bug`. (decision: Q16)
- §10.2 `ick -?` and the yacc/bison verbose parse report. Their replacements are CIWAPA's usage output and `--dump`. (decision: Q100, Q101)
- §10.4 the `intercal.el` emacs mode.
- EBCDIC source encoding. Source is UTF-8, and EBCDIC glyphs are accepted only where T14 lists them. (decision: T14)
- §3.4.1 Figures 1–2 and Table 1 (Warmenhovian logic gates). They're joke figures, not rules.
- §5.2 the "possible 2-D interpretation" of higher-dimensional array I/O. Such arrays raise E241. (decision: T31)
- §5.2 multiple I/O channels ("future expansion").
- §8.3 the system library listing. It isn't transcribed; the library is clean-room. (decision: Q35, Q38)
- §9.2 E127 (can't find syslib.i for magical inclusion). The library is embedded in the compiler, so this can't happen. (decision: Q133)
- §9.2 E999 (can't open the C skeleton file). CIWAPA has no skeleton file. (decision: Q133)

## Divergences

Places where the approved behavior differs from `ick` 0.15 and/or 0.35. The tie-breaker is 0.15 (decision: Q91, Q98), and the spec wins where it's explicit.

- T1 grouping: 0.35 tracks groupers on a stack and accepts more grouped subscripts. We follow 0.15.
- T2 a subscript list ends at a binary operator: both versions reject an array element as a mingle/select left operand. We accept it, because the spec's own §4.4.1 example needs it.
- T2 a nested subscript takes the rest of the list, so `,1 SUB ,2 SUB #1 #2 #3` is `,1 SUB (,2 SUB #1 #2 #3)`. 0.15 can't parse it: there a nested subscripted array must come last and take one subscript.
- T7 CRLF is accepted. 0.15 rejects `\r`.
- T9 junk after a complete statement makes it undecodable (E000 when it runs). 0.15 reports compile-time E017.
- T10 E000 text uses 0.35's format. 0.15's multi-line text is broken.
- T11 `DO PLEASE` is accepted, as in 0.15. 0.35 rejects it.
- T13 `%0` and `%100` are valid. Both versions reject them; the spec says 0–100.
- T14 the overpunch `-<backspace>V` and UTF-8 `¢` are accepted, because the spec lists them. `∀`, `¥` and the Latin-1 extras from 0.35 are not.
- T16 NEXT depth is 79, because the spec is explicit. Both versions allow 80.
- T17 32-bit FORGET/RESUME arguments don't wrap. Both versions have a wraparound bug.
- T21 CALCULATING includes dimensioning, and ABSTAINING covers all ABSTAINs, as in 0.35. 0.15 is narrower.
- T23 E774 follows 0.15 (1 in 128 per statement, before the guard). 0.35 uses 1 in 10 per program.
- T25 RETRIEVE into an undimensioned array restores it. Both versions drop the value.
- T27 no MAXLINES/MAXVARS limits. 0.15 caps programs at 1000 statements and 100 variables.
- T28 the last letter of a final line without a newline is kept. Both versions chop it.
- T29 Volapük accepts real UTF-8 umlauts, and there are no Latin words (0.35 has them).
- T31 Turing output is flushed at newlines and at exit. 0.15 never flushes.
- T32 our own wimp-mode message. Both versions use ick's GPL text.
- T33 the spelling is `RESUBMIT` (the spec), not ick's `RESUBNIT`. `<n>` is a statement ordinal, not a source line. E633 prints a number, not "THE NEW WORLD". A joke line is added.
- T35 politeness uses the spec's exact fractions and counts statements. Both versions use integer formulas and count PLEASE tokens.
- T19 A COME FROM aimed at a RESUME jumps after the RESUME executes, because §4.4.14.2 only exempts an executed NEXT. 0.15 doesn't: its RESUME transfers control before the trap is checked.
- T37 E633 never falls through into the included library. Both versions would run the library's first statement.
- T38 `+help` exits E778, as in 0.15, without the 3-second sleep. 0.35 exits E990.
- Q78 mingle operands above 65535 raise E533, as in 0.35. 0.15 silently truncates.
- Q80/Q81 a bad constant (E017), variable (E200), label (E197) or label reference (E129/E139) raises its error when the statement executes. Both versions report these at compile time.
- Q83/Q90 messages are the spec's text plus original joke lines, not ick's message strings.
- Q133 E127 and E999 are excluded, and E888 now means "can't write the output executable or temp files" instead of ick's C output file.
- Q97, L4 a chain inside a group is also E017. 0.15 makes that statement undecodable.
- T39 with `--traditional`, a COME FROM followed by junk is undecodable (E000 when it executes), like any other junk. 0.15 reports E111 because it checks traditional mode before it sees the junk.
- Q97 ungrouped operator chains are rejected, as in 0.15. 0.35 groups them to the right. Timing follows Q80, not 0.15's compile-time error.
