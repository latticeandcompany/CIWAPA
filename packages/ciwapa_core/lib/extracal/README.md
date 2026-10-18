# EXTRACAL's standard library

The library is a set of INTERCAL blocks, one per range of labels (R10). A program gets a block
when it NEXTs to a label in the block's range and defines no label in that range itself, the same
rule as the system library (T36). A block can bring in the system library or another block. The
blocks are binary, so only `.xc` programs get them (L17).

The INTERCAL here is the reference. Each block also has native versions in `runtime.dart` and
`runtime.c`, which the compiler uses in place of a routine whenever the program can't tell the
difference, as with the system library (Q37); `--no-opt` turns them off.

## Calling convention

As in the system library, a routine is entered with `DO (entry) NEXT` and returns with
`RESUME #1`. It changes only its documented results; it saves every other variable it writes with
STASH and restores it with RETRIEVE before returning.

- **Strings** are tail arrays (`,`) holding one Unicode code point per element (Q108). A character
  above U+FFFF takes two elements, as a UTF-16 surrogate pair (Q136). The empty string is an
  array with no dimensions, which only the library can make (L30).
- **Status:** a routine that can fail in a way a program should handle sets a status variable,
  `#1` for success and `#2` for failure, like the system library's overflow flags. Programming
  errors raise an ICL error instead (Q139).

## PETITION

`PETITION #n` asks the host for service *n* (L29). It is how the library reaches what INTERCAL
can't: arguments, the environment, the clock, files and sockets. Each service reads and writes
fixed variables, listed with the routines below. It reads and stores variables the way the native
library routines do: it reads a variable's own value, bypassing any overloading, and stores the way
WRITE IN does, so an IGNOREd variable keeps its value. A service the host doesn't have
is E801. PETITIONING is its gerund. It exists only in `.xc` programs. `--traditional` rejects
it (E111), and a program compiled with `--traditional` gets none of the library.

## I/O, (2000)–(2999)

A handle names where bytes come from or go: #0 is standard input, #1 standard output and #2
standard error, and OPEN gives files the lowest free number from #3 up. Bytes for standard output
share READ OUT's buffer, so the two keep their order, and anything for standard error flushes
standard output first. Status `.3` is #1 for success and #2 for failure: the end of input, a file
that can't be opened (a directory, or a path holding NUL, can't be), or a byte that can't be
written to a file. Standard output and standard error never report a failed byte. Files are
unbuffered: a byte written can be read back at once through another handle.

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (2000) | .1 = handle | .2 = the next byte; .3 | .3 = #2 at the end of input, leaving .2 alone |
| (2010) | .1 = handle, .2 = byte | .3 | a byte above 255 is E805 |
| (2020) | ,1 = path, .1 = mode | .2 = handle; .3 | mode #1 reads, #2 writes from empty, #3 appends; any other is E806 |
| (2030) | .1 = handle | .3 | closes a file |
| (2100) | .1 = handle | :1 = the number read; .3 | skips spaces, tabs and line ends, then reads decimal digits up to the first byte that isn't one, which it uses up. No digit at all leaves :1 alone with .3 = #2; a number above 4294967295 gives its low 32 bits and .3 = #2 |
| (2110) | .1 = handle, :1 = number | .3 | writes :1 in decimal digits; .3 is the last byte's |
| (2200) | .1 = handle | ,1 = the next line; .3 | one byte per element, without the line feed (a carriage return before it stays); .3 = #2 only at the end of input with nothing read, leaving ,1 alone |
| (2300) | .1 = handle, ,1 = string | .3 | writes each element as one byte, stopping at the first that fails |
| (2310) | .1 = handle, ,1 = string | .3 | the same, then a line feed unless something failed |

A handle that isn't open the right way (reading from #1, writing to #0, a closed file) is E804.
The routines read and write bytes, not characters: the Strings block turns UTF-8 bytes into code
points and back.

The INTERCAL versions of (2100) to (2310) use the system library and these labels of their own:
(2101)–(2113), (2201)–(2210), (2301)–(2304), (2311), (2312), (2900), (2950)–(2958). They reach at
most 40 NEXT stack levels.

## Strings, (3000)–(3999)

A routine that makes a string puts it in ,1, replacing what was there, so the routines chain: the
result of one is the input of the next, and the I/O block writes ,1.

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (3000) | ,1 | :1 = its length | in elements; a character above U+FFFF counts 2 |
| (3010) | ,1, ,2 | ,1 = ,1 then ,2 | |
| (3020) | ,1, :1 = start, :2 = count | ,1 = :2 elements of ,1 from element :1 | it must lie within ,1, or it is E807; a count of #0 from up to one past the end gives the empty string |
| (3030) | ,1, ,2 | .1 = #1 if ,1 sorts first, #2 if they're equal, #3 if ,2 does | element by element, a prefix first |
| (3040) | ,1, ,2 | :1 = where ,2 first starts in ,1; .1 = #1, or #2 if it doesn't, leaving :1 alone | the empty string is found at #1 |
| (3050) | :1 | ,1 = :1 in decimal digits | |
| (3060) | ,1 | :1 = the number it spells; .1 = #1, or #2 if it is empty, holds anything but decimal digits, or is above 4294967295, leaving :1 alone | |
| (3070) | ,1 | ,1 = its UTF-8 bytes | a lone surrogate becomes U+FFFD |
| (3080) | ,1 = UTF-8 bytes | ,1 = the characters | an element above 255 is E808 |

(3080) turns each malformed sequence into U+FFFD: a lead byte that starts no sequence, or whose
continuation bytes run out or are interrupted, becomes U+FFFD and uses up only itself; a complete
sequence that is overlong, encodes a surrogate or is above U+10FFFF becomes U+FFFD and uses up all
its bytes.

The INTERCAL versions use the system library and the labels from (3100) on.

## System, (8000)–(8999)

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (8000) | | .1 = number of program arguments | |
| (8010) | .1 = n | ,1 = argument n; .2 = #1, or #2 if there is no argument n | arguments count from 1 |
| (8020) | ,1 = name | ,2 = the environment variable's value; .1 = #1, or #2 if it isn't set | |
| (8030) | .1 = status | | ends the program with that exit status; above 255 is E802 |
| (8040) | | ::1 = milliseconds since 1970-01-01 00:00 UTC | |
| (8050) | | ::1 = nanoseconds on a clock that only goes forward | for timing; its zero is arbitrary |
| (8060) | ::1 = seed | | seeds the random numbers behind `%` and (1900)/(1910) |

Each is a single PETITION of the same number.

- **Arguments** are the ones after the runtime options (`+wimpmode`, `+seed n` and the like): from
  the first that starts with neither `+` nor `-`, or from the one after a `--`, which ends the
  options so an argument can start with a sign.
- **Encoding:** arguments and environment values arrive as the host has them: UTF-16 on Windows,
  UTF-8 elsewhere, where an encoded surrogate stays a lone surrogate. An environment variable whose
  value isn't UTF-8, or a name holding NUL or `=`, counts as not set. ciwapa-dart programs can't
  start at all with an argument that isn't UTF-8 (the Dart VM refuses it); ciwapa-llvm programs
  read each malformed sequence as U+FFFD.
- **The empty string:** an empty argument or value gives an array with no dimensions (L30), and
  only the Strings block's (3000) can tell its length: INTERCAL itself can't ask an array's size,
  and reading past its end is E241.
- **Clocks:** (8050) counts in nanoseconds, but how finely it moves depends on the host: by the
  microsecond in ciwapa-dart programs.

## Services

| Service | Reads | Writes | Does |
|---|---|---|---|
| #2000 | .1 | .2, .3 | reads a byte |
| #2010 | .1, .2 | .3 | writes a byte |
| #2020 | ,1, .1 | .2, .3 | opens a file |
| #2030 | .1 | .3 | closes a file |
| #3000 | ,1 | :1 | a string's length; E803 for an array with more than one dimension |
| #3001 | | ,1 | makes ,1 the empty string |
| #3002 | ,2 | :2 | ,2's length, as #3000 |
| #807, #808 | | | raise E807 and E808 for the INTERCAL versions |
| #8000–#8060 | | | as the System routines of the same numbers |

