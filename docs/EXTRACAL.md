# EXTRACAL

EXTRACAL is CIWAPA's extended language. It runs every INTERCAL program exactly as Mode 1 does and
adds three things:

- the control extensions modern C-INTERCAL (`ick` 0.35) grew;
- numbers wider and stranger than 32-bit unsigned;
- a standard library that reaches the command line, files, strings, arrays and arithmetic.

This guide shows what each addition does. The rules behind every detail are in
[`EXTRACAL_PLAN.md`](EXTRACAL_PLAN.md) and [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md), and the
library's routines are documented in
[`packages/ciwapa_core/lib/extracal/README.md`](../packages/ciwapa_core/lib/extracal/README.md).

## Choosing EXTRACAL

The file extension chooses the language:

| Extension | Language |
|---|---|
| `.i`, `.2i` | Mode 1, binary |
| `.3i` … `.7i` | Mode 1, bases 3–7 |
| `.xc`, `.2xc` | EXTRACAL, binary |
| `.3xc` … `.7xc` | EXTRACAL, bases 3–7 |

Anything else is E998. Both compilers take the same files:

```sh
ciwapa-llvm build hello.xc -o hello
ciwapa-dart run hello.xc -- first-argument
```

`--traditional` turns every EXTRACAL statement into an error (E111) and leaves out the library, so
a program can check that it only uses Mode 1. The 64-bit sigils and the library need binary (L17).

## What changes from Mode 1

Nothing, except where Mode 1 would have stopped with an error:

- A mingle of operands over 65535 gives a 64-bit result instead of E533.
- Several COME FROMs aimed at one label start threads instead of being E555.
- Statements Mode 1 can't parse (EXTRACAL's keywords) mean something.

The conformance suite runs every Mode 1 program again as `.xc` and checks the output is identical.

## Numbers

### 64 bits

| Syntax | Meaning |
|---|---|
| `::1` | a 64-bit scalar (double cateye) |
| `;;1` | a 64-bit array (double hybrid) |
| `##70000` | a 32-bit constant (fence) |
| `####5000000000` | a 64-bit constant (stockade) |

Unary operators rotate at their operand's width (16, 32 or 64 bits), and select works at any width.
Storing a value over 32 bits in a 16- or 32-bit variable is E276; storing 32 bits into 16 is still
E275.

### Mingle widens by value

| Operands | Result |
|---|---|
| both ≤ 65535 | 32 bits, as in Mode 1 |
| both ≤ 4294967295 | 64 bits |
| larger | a 128-bit **ephemeral** value |

Only a select can consume an ephemeral value. Storing it, printing it, mingling it again or
applying a unary operator to it is E534. A select may use a 128-bit mask, so
`'::1$::2'~'####0$####18446744073709551615'` picks the bits of `::2`.

### Signed I/O

Values are unsigned, but the signed forms read and write them as two's complement at the
variable's width:

```
DO WRITE IN SIGNED .1
DO READ OUT SIGNED .1
```

WRITE IN SIGNED takes an optional `MINUS` before the digit words; a value outside the variable's
signed range is E536. READ OUT SIGNED prints `-` and then the numeral of the magnitude. The Math
block does signed arithmetic.

### Bigger numerals

READ OUT of a value of 10¹² or more prints the ×10¹² group with a second overline row above the
first, so output can be three lines. WRITE IN into a 64-bit variable takes up to 20 digit words; a
value over 2⁶⁴ − 1 is E535.

## Control

### NEXT FROM

`NEXT FROM (n)` takes control after statement (n), like COME FROM, but also pushes a NEXT stack
entry, so `RESUME #1` goes back to the statement after (n):

```
(1) DO .1 <- #1
    DO READ OUT .1
    PLEASE GIVE UP
    DO NEXT FROM (1)
    PLEASE READ OUT #2
    DO RESUME #1
```

### Computed and gerund COME FROM

`COME FROM .1` takes control after whichever labelled statement's label equals `.1`'s value at the
time; `NEXT FROM` works the same way. `COME FROM READING OUT` takes control after every READ OUT,
and a list of gerunds joined by `+` after every statement of those kinds. A computed COME FROM aimed at a missing label does nothing.

### Computed ABSTAIN

`ABSTAIN #2 FROM (5)` abstains twice, and takes two REINSTATEs to undo. Plain ABSTAIN and REINSTATE
keep Mode 1's on/off behavior.

### ONCE and AGAIN

A statement ending in `ONCE` abstains itself after it runs; `AGAIN` on an abstained statement
reinstates itself. ABSTAIN and REINSTATE flip a statement's ONCE to AGAIN and back:

```
(11) DO READ OUT #1 ONCE
```

### TRY AGAIN

`TRY AGAIN`, the last statement of a program, starts it again from the top, keeping abstentions.
If it is abstained, the program just ends. A statement after it is E993.

### Threads

Several COME FROMs (or NEXT FROMs) aimed at one label split the program into threads. Each thread
has its own variables, stashes and NEXT stack; all of them share abstentions. They take turns one
statement at a time, and GIVE UP ends only the thread that runs it:

```
(1) DO .1 <- #1
    DO READ OUT #1
    PLEASE GIVE UP
    DO COME FROM (1)
    DO READ OUT #2
    PLEASE GIVE UP
    DO COME FROM (1)
    DO READ OUT #3
    DO GIVE UP
```

`a WHILE b` runs statement b in a woven thread for as long as statement a is running:

```
PLEASE READ OUT #1 WHILE READ OUT #2
```

A WHILE counts as 11 statements in error messages (L31).

### Backtracking

`MAYBE` before a statement makes a choicepoint there. `GO BACK` returns to the most recent
choicepoint, restoring the variables, and runs on with that statement's abstention reversed. `GO
AHEAD` throws the most recent choicepoint away. Either one with no choicepoint is E404:

```
    DO .1 <- #1
    MAYBE DO READ OUT .1
    DO .1 <- #2
    PLEASE GO BACK
```

### Operand overloading

`.1 <- .2/expr` assigns `.2`'s value to `.1` and from then on makes `.2` stand for the expression.
Reading `.2` evaluates it, and assigning to `.2` works backwards through it. An assignment that
can't be worked backwards is E277.

### CREATE

`CREATE (n) template` defines a new statement: any statement of that shape NEXTs to (n), with
`:1601`, `:1602`, … standing for its operands.

```
    DO CREATE (100) SWAP .5 AND .6
    DO SWAP .1 AND .2
```

`CREATE (n) x` makes `x` (a word, an unused punctuation mark or an overstrike) a binary operator:
the routine at (n) gets the operands in `:1601` and `:1602` and leaves the result in `:1603`.

```
    DO CREATE (200) x
    DO .1 <- #3 x #4
```

### Latin

Every statement has a Latin name, as in `ick`: `FAC` and `PLACET` for DO and PLEASE, `NON` for NOT,
`QUONDAM`/`ITERUM` for ONCE/AGAIN, `CONOR ITERUM` for TRY AGAIN, `MULTIPLICATUS A` for BY, and Latin number words in WRITE IN.

## The library

A program calls library routines with `NEXT`, the way it calls the system library. A block is
included when the program NEXTs to a label in its range and defines no label in that range itself.
So defining one label in a block's range replaces the whole block with your own.

| Block | Labels | Contents |
|---|---|---|
| I/O | (2000)–(2999) | bytes, numbers and lines on standard input and output, standard error, and files |
| Strings | (3000)–(3999) | length, concatenate, slice, compare, find, numbers to and from decimal, UTF-8 |
| Math | (4000)–(4999) | 64-bit and signed arithmetic, power, square root, modulo, gcd |
| Arrays | (6000)–(6999) | rank and dimensions, fill, copy, sort, find |
| System | (8000)–(8999) | command-line arguments, environment variables, exit status, clocks, the random seed |

Strings are tail arrays of UTF-16 code units, and routines that make strings put them in `,1`, so
they chain:

```
    DO .1 <- #1
    DO (8010) NEXT
    DO (3070) NEXT
    PLEASE (2310) NEXT
```

prints the first command-line argument and a line feed: (8010) puts the argument in `,1`, (3070)
turns its characters into UTF-8 bytes, and (2310) writes them to handle #1, standard output.

Every routine is written in INTERCAL, and the compilers run a native version instead whenever the
program can't tell the difference. `--no-opt` always runs the INTERCAL. The routines reach the host
through `PETITION #n`, EXTRACAL's one new statement for the library; its services are listed in
the library's README.

Two blocks are still waiting on design questions: Floats (7000)–(7999) (L33) and Network
(9000)–(9999) (L34), in [`QUESTIONS.md`](QUESTIONS.md).

## Errors

EXTRACAL's errors look like Mode 1's: the official text, a joke line, the statement and `CORRECT
SOURCE AND RESUBMIT`. New conditions have new codes, all listed under "EXTRACAL error codes" in
[`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).
