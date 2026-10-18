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
fixed variables, listed with the routines below. It stores into a variable the way WRITE IN does:
an IGNOREd variable keeps its value, and overloading is bypassed. A service the host doesn't have
is E801. PETITIONING is its gerund. It exists only in `.xc` programs, and `--traditional` rejects
it (E111).

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

Each is a single PETITION of the same number. The program's arguments are the ones after the
runtime options (`+wimpmode`, `+seed n` and the like), from the first that starts with neither `+`
nor `-`. They and the environment are read as UTF-8.
