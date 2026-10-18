# EXTRACAL

EXTRACAL is CIWAPA's extended language. It runs INTERCAL programs as Mode 1 does (with the
exceptions under [What changes from Mode 1](#what-changes-from-mode-1)) and adds three things:

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

`--traditional` works like `ick -t`. It rejects COME FROM, NEXT FROM, bases other than 2 and
`ick`'s control extensions (computed ABSTAIN, ONCE and AGAIN, TRY AGAIN, CREATE, MAYBE, GO BACK,
GO AHEAD, WHILE and PETITION) with E111, and leaves out the library. The 64-bit types, signed I/O
and mingle widening stay, so it doesn't check that a program is Mode 1.

The 64-bit sigils, signed I/O, mingle widening and the library need binary (L17).

## What changes from Mode 1

Mostly what Mode 1 would have stopped on with an error:

- A mingle of operands over 65535 gives a 64-bit result instead of E533.
- Several COME FROMs aimed at one label start threads instead of being E555.

One change reaches programs that never fail: statements Mode 1 can't parse are comments, and
EXTRACAL can parse more of them. A comment written as a statement that happens to use EXTRACAL's
words, like `PLEASE DON'T READ OUT #1 AGAIN`, is a real statement in `.xc`. Here it reads out #1
once something reinstates READING OUT. `ick`'s manual warns about the same trap.

The conformance suite runs every Mode 1 program again as `.xc` and checks that the output is
identical, apart from a few recorded differences like these.

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

ONCE and AGAIN go at the end of a statement. `DO … ONCE` abstains itself after it runs, and
`DON'T … AGAIN` keeps itself abstained for good. The other two combinations reinstate themselves:
`DO … AGAIN` stays reinstated, and `DON'T … ONCE` reinstates itself when control reaches it.
ABSTAIN and REINSTATE also flip a statement's ONCE to AGAIN and back:

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

`a WHILE b` runs statement b in a woven thread for as long as statement a is running. The woven
thread shares the program's variables:

```
DO READ OUT #1 WHILE READ OUT #2
PLEASE GIVE UP
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
    DO READ OUT .1
    PLEASE GIVE UP
```

### Operand overloading

`.1 <- .2/expr` assigns `.2`'s value to `.1` and from then on makes `.2` stand for the expression.
Reading `.2` evaluates it, and assigning to `.2` works backwards through it. An assignment that
can't be worked backwards is E277.

### CREATE

`CREATE (n) template` defines a new statement: any statement of that shape NEXTs to (n), with
`:1601`, `:1602`, … standing for its operands, and RESUME #1 comes back.

```
        DO .1 <- #3
        DO .2 <- #4
        DO CREATE (100) SWAP .5 AND .6
        DO SWAP .1 AND .2
        PLEASE READ OUT .1 + .2
        DO GIVE UP
(100)   DO :1 <- :1601
        DO :1601 <- :1602
        PLEASE :1602 <- :1
        DO RESUME #1
```

`CREATE (n) x` makes the character `x` a binary operator. It can be any character but a capital
letter, `_`, `\` or `|`, or an overstrike. The routine at (n) gets the operands in `:1601` and
`:1602` and leaves the result in `:1603`:

```
        DO CREATE (200) x
        DO .1 <- #3 x #4
        DO READ OUT .1
        PLEASE GIVE UP
(200)   DO :1603 <- :1601 $ :1602
        PLEASE RESUME #1
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
| Floats | (7000)–(7999) | §8.4's floats: arithmetic, comparison, the natural logarithm, integers and decimal text |
| System | (8000)–(8999) | command-line arguments, environment variables, exit status, clocks, the random seed |
| Network | (9000)–(9999) | TCP connections and listeners as I/O handles, an HTTP/1.1 client, and request and response helpers for servers |

Strings are tail arrays of UTF-16 code units, and most routines that make strings put them in `,1`,
so they chain:

```
    DO .1 <- #1
    DO (8010) NEXT
    DO (3070) NEXT
    PLEASE (2310) NEXT
    DO GIVE UP
```

prints the first command-line argument and a line feed: (8010) puts the argument in `,1`, (3070)
turns its characters into UTF-8 bytes, and (2310) writes them to handle #1, standard output.

Every routine is written in INTERCAL, and the compilers run a native version instead whenever the
program can't tell the difference. `--no-opt` always runs the INTERCAL. The routines reach the host
through `PETITION #n`, EXTRACAL's one new statement for the library; its services are listed in
the library's README.

## Errors

EXTRACAL's errors look like Mode 1's: the official text, a joke line, the statement and `CORRECT
SOURCE AND RESUBMIT`. New conditions have new codes, all listed under "EXTRACAL error codes" in
[`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).
