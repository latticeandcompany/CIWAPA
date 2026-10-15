# System library

`syslib.i` is CIWAPA's clean-room INTERCAL implementation of the §7.2 subroutine library. It was written from the §7.2 descriptions alone. Behavior §7.2 leaves open was settled by running C-INTERCAL 0.15 as a black box (see [Confirmed against the oracle](#confirmed-against-the-oracle)).

The file has 316 statements, one per line, with blank lines between routines. "Statement #n" below means the n-th statement of `syslib.i`, counting from 1. When the library is included, its statements follow the user's, so library statement #n has ordinal `u + n` in error messages, where `u` is the number of statements in the user's program. All labels are in 1000–1999. The file contains no COME FROM and no TriINTERCAL operators, and its largest constant is `#65535`. It uses PLEASE on 69 of its 316 statements, so it also passes the politeness check when it is concatenated onto a program.

## Calling convention

Every routine is entered with `DO (entry) NEXT` and returns with `RESUME #1`, so the caller's NEXT stack is the same after the call as before it. A routine changes only its documented results. It saves every other variable it writes, including those written by the routines it calls, with STASH and restores it with RETRIEVE before returning. Each stash stack is therefore back to its original depth on return. No routine uses arrays.

"Error exit" means the routine runs an undecodable statement whose source line is exactly `DOUBLE OR SINGLE PRECISION OVERFLOW`. This gives:

```
ICL000I DOUBLE OR SINGLE PRECISION OVERFLOW
        THAT WAS NOT A STATEMENT. THAT WAS A CRY FOR HELP.
	ON THE WAY TO STATEMENT <u + n + 1>
        CORRECT SOURCE AND RESUBMIT
```

Here `n` is the E000 statement's number from the table below. The exit status is 0. No library routine prints anything.

## Entry points

`D` is the deepest NEXT stack the routine reaches, counted in entries above the caller's depth `d`. The routine's own entry is one of them, so a routine that never NEXTs has `D = 1`. A call succeeds only if `d + D ≤ 79`; otherwise one of its NEXTs raises E123 (see [NEXT stack depth and E123](#next-stack-depth-and-e123)). D depends on the input only for the three division routines, and only when the divisor is zero.

| Entry | Inputs | Results | Also writes, then restores | D | E000 at |
|---|---|---|---|---|---|
| (1000) | .1 .2 | .3 = .1 + .2 | .4–.11 | 5 | #5 |
| (1009) | .1 .2 | .3 = (.1 + .2) mod 2^16; .4 = #1, or #2 on overflow | .5–.11 | 4 | |
| (1010) | .1 .2 | .3 = (.1 − .2) mod 2^16 | .5–.11 | 4 | |
| (1020) | .1 | .1 = (.1 + 1) mod 2^16 | .5–.11 | 4 | |
| (1030) | .1 .2 | .3 = .1 × .2 | .4–.16, :1, :6 | 7 | #45 |
| (1039) | .1 .2 | .3 = (.1 × .2) mod 2^16; .4 = #1, or #2 on overflow | .5–.16, :1, :6 | 6 | |
| (1040) | .1 .2 | .3 = .1 ÷ .2, truncated; #0 if .2 = #0 | .5–.22, :1–:3, :7 | 6 (5 if .2 = #0) | |
| (1050) | :1 .1 | .2 = :1 ÷ .1, truncated; #0 if .1 = #0 | .5–.22, :2, :3, :7 | 6 (5 if .1 = #0) | #71 |
| (1060) | .1 .2 | .3 = .1 OR .2 | none | 1 | |
| (1070) | .1 .2 | .3 = .1 AND .2 | none | 1 | |
| (1080) | .1 .2 | .3 = .1 XOR .2 | none | 1 | |
| (1500) | :1 :2 | :3 = :1 + :2 | .5–.11, :4 | 5 | #87 |
| (1509) | :1 :2 | :3 = (:1 + :2) mod 2^32; :4 = #1, or #2 on overflow | .5–.11 | 4 | |
| (1510) | :1 :2 | :3 = (:1 − :2) mod 2^32 | .5–.11 | 4 | |
| (1520) | .1 .2 | :1 = .1 × 65536 + .2 | .3, .6, .7 | 2 | |
| (1525) | .3 | .3 = (.3 × 256) mod 2^16 | none | 1 | |
| (1530) | .1 .2 | :1 = .1 × .2 (cannot overflow) | .5–.16, :6 | 5 | |
| (1540) | :1 :2 | :3 = :1 × :2 | .5–.16, :4, :6 | 6 | #148 |
| (1549) | :1 :2 | :3 = (:1 × :2) mod 2^32; :4 = #1, or #2 on overflow | .5–.16, :6 | 5 | |
| (1550) | :1 :2 | :3 = :1 ÷ :2, truncated; #0 if :2 = #0 | .5–.22, :7 | 5 (4 if :2 = #0) | |
| (1900) | none | .1 = uniform random 0–65535 | none | 1 | |
| (1910) | .1 | .2 = approximately normal random value from 0 to .1 | .1, .5–.22, :1–:4, :6, :7 | 6 | |

The E000-raising routines overflow exactly when the true result does not fit: above 65535 for (1000) and (1030), above 4294967295 for (1500) and (1540), and a quotient above 65535 for (1050). (1050) with `.1 = #0` returns #0 without an error, whatever `:1` is.

The flag variants never error. They leave the wrapped result in `.3`/`:3`, which is the true result mod 2^16 or 2^32, and set the flag to #2.

## NEXT stack depth and E123

An E123 fault inside a routine comes from the first NEXT that would store an 80th entry. Its `ON THE WAY TO STATEMENT` is that NEXT's target, so a fast path must know which NEXT first reaches each depth. The table lists, for k = 1…D, the label targeted by the first NEXT that brings the stack to `d + k`. If `d + k = 80` for some k ≤ D, E123 names `u +` that label's statement number. k = 1 is the caller's own NEXT.

Label statement numbers: (1000) #1, (1009) #10, (1010) #21, (1020) #32, (1030) #41, (1039) #50, (1040) #58, (1050) #65, (1060) #77, (1070) #79, (1080) #81, (1500) #83, (1509) #92, (1510) #102, (1520) #115, (1525) #127, (1530) #136, (1540) #144, (1549) #153, (1550) #162, (1600) #171, (1601) #174, (1700) #189, (1701) #194, (1800) #218, (1804) #266, (1900) #270, (1910) #288, (1911) #293, (1990) #316.

| Entry | First NEXT target reaching depth k = 1, 2, … D |
|---|---|
| (1000) | 1000, 1009, 1600, 1601, 1990 |
| (1009) | 1009, 1600, 1601, 1990 |
| (1010) | 1010, 1600, 1601, 1990 |
| (1020) | 1020, 1600, 1601, 1990 |
| (1030) | 1030, 1039, 1530, 1700, 1701, 1601, 1990 |
| (1039) | 1039, 1530, 1700, 1701, 1601, 1990 |
| (1040) | 1040, 1550, 1800, 1804, 1990, 1990 (the last is absent when .2 = #0) |
| (1050) | 1050, 1550, 1800, 1804, 1990, 1990 (the last is absent when .1 = #0) |
| (1060), (1070), (1080) | the entry only |
| (1500) | 1500, 1509, 1600, 1601, 1990 |
| (1509) | 1509, 1600, 1601, 1990 |
| (1510) | 1510, 1600, 1601, 1990 |
| (1520) | 1520, 1525 |
| (1525) | 1525 |
| (1530) | 1530, 1700, 1701, 1601, 1990 |
| (1540) | 1540, 1549, 1700, 1701, 1601, 1990 |
| (1549) | 1549, 1700, 1701, 1601, 1990 |
| (1550) | 1550, 1800, 1804, 1990, 1990 (the last is absent when :2 = #0) |
| (1900) | 1900 |
| (1910) | 1910, 1911, 1990, 1601, 1990, 1990 |

Each sequence is fixed for a given divisor-is-zero case. It does not depend on operand values or on `%` rolls, because every NEXT that first reaches a new depth runs unconditionally on the first pass. The `depth-*` conformance tests pin each routine at `d = 79 − D`, where it succeeds, and at `d = 80 − D`, where it raises E123.

## How the routines work

Five internal routines carry the arithmetic.

- **(1990) branch helper.** `RESUME "?'.5$#1'"~#3` returns one level if `.5` is #0 and two levels if `.5` is #1. A two-way branch is `DO (X) NEXT` followed by the `.5 = #1` path, with `(X) DO (1990) NEXT` / `DO FORGET #1` followed by the `.5 = #0` path. Loops jump back with `DO (L) NEXT` to a head that begins `(L) DO FORGET #1`, so they never grow the stack.
- **32-bit values in halves.** A 32-bit value is kept as its odd-position bits and its even-position bits, each a 16-bit value (`:x~'#65535$#0'` and `:x~'#0$#65535'`), and is recombined with `odd$even`. In this form AND, OR and XOR are one select each, and shifting left by one moves the even half into the odd half and shifts the old odd half left by one (`'y$#0'~'#32767$#1'`).
- **(1600) adder.** Adds halves `.8 .9` into halves `.6 .7` with the carry loop (sum = a XOR b, carry = (a AND b) shifted left) until the carry is zero. This takes at most 33 passes. It sets `.10` to the carry out of bit 31 (0/1) and leaves `.8 = .9 = #0`. It saves `.5` and `.11`.
- **(1700) multiplier.** Shift-and-add over the bits of `:6`, lowest first, stopping when the remaining multiplier is zero. Each pass adds the multiplicand (halves `.12 .13`), masked to zero when the current bit is clear, via (1600). The product's halves end in `.6 .7`. `.14` becomes 1 if an add carried, or if a set multiplicand bit 31 was shifted out while multiplier bits remained. It saves `.5 .15 .16`.
- **(1800) divider.** Restoring long division over 32 bits of the dividend (halves `.12 .13`) by the divisor (halves `.16 .17`). It compares by adding the divisor's two's complement and checking the carry. The quotient's halves end in `.14 .15`. A zero divisor returns quotient 0 immediately. It saves `.5 .18–.22 :7`.

The public routines are thin wrappers:

- (1009), (1010), (1020), (1509) and (1510) call (1600) directly. Subtraction is computed as NOT(NOT a + b).
- (1000) and (1500) call their flag variants and branch to their E000 statement when the flag is #2.
- (1530) and (1549) call (1700). (1039) calls (1530), and (1030) and (1540) call their flag variants.
- (1550) calls (1800), and (1040) and (1050) call (1550).
- (1060)–(1080) are single expressions.
- (1525) is eight copies of a shift left by one.
- (1520) calls (1525) twice to build the halves of the concatenated value.

## Randomness

`%` qualifiers are the only randomness source, and the order of rolls is part of the observable behavior once the `%` RNG is seeded.

**(1900)** sets `.1` to #0, then runs 16 statements of the form `DO %50 .1 <- (.1 OR bit)`, for bits #1, #2, #4, … #32768 in that order. So it makes 16 rolls, and roll k (from 0) decides bit k.

**(1910)** uses the Irwin–Hall approximation to a normal distribution. With `R` the input `.1`, it calls (1900) 12 times, makes no other rolls (192 rolls in all), and sums the draws into `S` (0 to 786420). Then:

```
A  = floor(S / 12)                       0 … 65535
.2 = floor((R × A + 32767) / 65535)      R × A / 65535, rounded half up
```

The result is always in 0…R, and it is 0 when R is 0. Its mean is R/2. Its standard deviation is R × sqrt(12 × (65536² − 1) / 12) / (12 × 65535), which is R/12 to within 0.01%. No intermediate value overflows 32 bits.

Sampled through CIWAPA:

| R | draws | mean | sd | expected sd |
|---|---|---|---|---|
| 1200 | 2000 | 598.4 | 101.9 | 100 |
| 65535 | 2000 | 32805 | 5333 | 5461 |

C-INTERCAL 0.15's (1910) gave mean 607 and sd 95 for R = 1200 over 300 draws. (1900) over 2000 draws gave mean 32145 and sd 19086, against 32767.5 and 18919 expected.

## Confirmed against the oracle

Every routine except (1060)–(1080) was compared with C-INTERCAL 0.15's library on 50–60 random and edge-case inputs each (0, 1, 2, maxima, powers of two). All results matched. The following points were settled that way.

- Overflow on the flag variants leaves the wrapped result: 65535 + 2 gives `.3 = 1, .4 = 2`; 300 × 300 gives `.3 = 24464`; 4294967295 × 2 gives `:3 = 4294967294`.
- "No action on overflow" wraps: 0 − 1 is 65535 for (1010) and 4294967295 for (1510); 65535 + 1 is 0 for (1020).
- Division truncates (7 ÷ 2 = 3), and dividing by zero gives #0 for (1040), (1050) and (1550).
- (1050) errors exactly when the quotient exceeds 65535 (131071 ÷ 2 is fine, 131072 ÷ 2 errors), and returns #0 without error when `.1 = #0`.
- (1525) drops the high byte: 65535 gives 65280 and #4660 gives #13312.
- (1520) is plain concatenation: #4660, #22136 gives 305419896.
- The overflow errors carry the text `DOUBLE OR SINGLE PRECISION OVERFLOW`. The oracle's E000 also prints its own label, which CIWAPA's deliberately omits (decision Q38).

C-INTERCAL 0.15's library has no (1060), (1070) or (1080): calling them is E129 there. Those three were checked against a model of bitwise OR, AND and XOR instead.

## Notes for native fast paths

The reference routines run ordinary statements, so program state that changes how statements execute also changes the library's behavior. A fast path is only equivalent when none of the following can be in effect.

- Gerund abstentions such as `ABSTAIN FROM CALCULATING`, `NEXTING`, `RESUMING`, `FORGETTING`, `STASHING` or `RETRIEVING` also abstain the library's statements.
- An IGNOREd variable in a routine's write set (results or the scratch variables above) makes the reference compute different results.
- ABSTAIN, REINSTATE or COME FROM aimed at a library label.

Under `--traditional` the library behaves the same, because it uses no COME FROM.

## Tests

`packages/conformance/tests/syslib/` has one or more tests per entry point, covering edge values, every overflow error, unchanged inputs, scratch variables (`preserves-variables`), the NEXT stack (`next-stack-unchanged`) and the depth table above (`depth-*`). The tests are user programs without the library text and rely on auto-inclusion. Their expected output was produced by running each test with `syslib.i` appended through both `ciwapa-llvm` and `ciwapa-dart`, and checked against the values written into the tests. The two random tests (`random-1900`, `random-1910`) check properties that fail with probability below 10⁻¹².
