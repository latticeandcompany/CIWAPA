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

## Math, (4000)–(4999)

Each operation that can overflow comes in two forms, as in the system library. The error form
raises E813 when the true result doesn't fit. The flag form, whose number ends in 9, stores the
wrapped result and puts #1 in the next variable, or #2 if it didn't fit. Dividing by #0 gives #0,
and taking a modulo by #0 gives the dividend.

**Unsigned 64-bit**, on ::1 and ::2:

| Entry | Results | Notes |
|---|---|---|
| (4000), (4009) | ::3 = ::1 + ::2 | flag in ::4 |
| (4010) | ::3 = (::1 − ::2) mod 2^64 | |
| (4020) | ::1 = :1 × 2^32 + :2 | joins two 32-bit halves |
| (4030) | ::1 = :1 × :2 | can't overflow |
| (4040), (4049) | ::3 = ::1 × ::2 | flag in ::4 |
| (4050) | ::3 = ::1 ÷ ::2, truncated | |
| (4070) | ::3 = #1 if ::1 < ::2, #2 if they're equal, #3 if greater | |

**Signed**, reading each value as two's complement at its width: from (4100) on .1 and .2, from
(4200) on :1 and :2, and from (4300) on ::1 and ::2. Results go in the next variables of the same
kind; below, `x` is `.`, `:` or `::`.

| Entry | Results | Notes |
|---|---|---|
| (4n00), (4n09) | x3 = x1 + x2 | flag in x4 |
| (4n10), (4n19) | x3 = x1 − x2 | flag in x4 |
| (4n40), (4n49) | x3 = x1 × x2 | flag in x4 |
| (4n50) | x3 = x1 ÷ x2, truncated toward zero | the most negative value ÷ −1 is E813 |
| (4n60) | x3 = #1 if x1 < x2, #2 if they're equal, #3 if greater | |

**Powers, roots, modulo and gcd**, unsigned: from (4500) on :1 and :2, and from (4600) on ::1 and
::2.

| Entry | Results | Notes |
|---|---|---|
| (4m00), (4m09) | x3 = x1 to the power x2 | flag in x4; anything to the power #0 is #1 |
| (4m10) | x2 = the largest number whose square is at most x1 | |
| (4m20) | x3 = x1 mod x2 | x1 if x2 is #0 |
| (4m30) | x3 = the greatest common divisor of x1 and x2 | #0 for two #0s |

The INTERCAL versions use the system library and these labels of their own: (4400), (4410),
(4420), (4430), (4440) and (4700) on. They keep a 64-bit value as its odd and even bits in two
32-bit halves, the way the system library keeps 32-bit values in 16-bit ones, so AND, OR and XOR
never need a 128-bit value.

## Floats, (7000)–(7999)

A float is a 32-bit value: the upper 16 bits are the mantissa and the lower 16 the
characteristic, both two's complement, worth mantissa × 2^characteristic (R9, Q137). Every result
is normalized, with a mantissa magnitude from 2^14 to 2^15 − 1, and zero is #0; inputs may be
unnormalized. Results are rounded to nearest, ties to even. One whose characteristic would pass
32767 is E814; one below −32768 is #0 (L33).

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (7000) | :1, :2 | :3 = :1 + :2 | |
| (7010) | :1, :2 | :3 = :1 − :2 | |
| (7020) | :1, :2 | :3 = :1 × :2 | |
| (7030) | :1, :2 | :3 = :1 ÷ :2 | dividing by zero is E815 |
| (7040) | :1, :2 | :3 = #1 if :1 < :2, #2 if they're equal, #3 if greater | exact |
| (7050) | :1 | :2 = ln :1 | :1 must be positive, or it is E816 |
| (7060) | :1 = a signed 32-bit integer | :2 = the nearest float | |
| (7070) | :1 | :2 = :1 truncated toward zero, as a signed 32-bit integer | out of range is E814 |
| (7080) | :1 | ,1 = :1 in decimal | `-1.2346E+5`: 5 significant digits, correctly rounded; zero is `0.0000E+0` |
| (7090) | ,1 = decimal text | :1 = the nearest float; .1 | .1 = #2, leaving :1 alone, unless ,1 is an optional sign, digits, an optional `.` and digits (at least one digit in all), and an optional `E` or `e` with an optional sign and digits |

- **The logarithm** reduces :1 to a fraction from 0.75 to 1.5 times a power of 2^k, takes the
  fraction's logarithm by shift-and-add over tables of ln(1 + 2^−j) and −ln(1 − 2^−j) in Q62
  fixed point, adds k ln 2 in Q32 when k isn't 0, and rounds once: within one unit in the last
  place. Both runtimes follow the same steps, so they agree to the bit.
- **Decimal text** is converted exactly: (7080) and (7090) work through a base-10000 big number,
  so they are slow in the INTERCAL for characteristics in the thousands, which the natives aren't.
  (7090) reads exponents beyond 100000 as 100000, and gives #0 for any spelling of zero.

The INTERCAL versions use the system library, the Math, Strings and Arrays blocks, and these
labels of their own: (7100)–(7350), (7900), (7910), (7930), (7940), (7950), (7960), (7970),
(7980)–(7983), (7985)–(7989), (7991)–(7994) and (7996)–(7998).

## Arrays, (6000)–(6999)

The routines from (6000) work on tail arrays and 16-bit values; the same routines from (6100) work
on hybrid arrays, with ;1 and ;2 for ,1 and ,2 and :2 for .1. FILL, COPY, SORT and FIND work on
lists: arrays with one dimension, or none for the empty list. Anything else is E809.

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (6000), (6100) | ,1 | :1 = its number of dimensions | #0 for an array with none |
| (6010), (6110) | ,1, :1 = n | :1 = the size of dimension n | n from #1 to the number of dimensions, or it is E812 |
| (6020), (6120) | ,1, .1 | every element of ,1 = .1 | |
| (6030), (6130) | ,1 | ,2 = a copy of ,1 | replaces what was in ,2 |
| (6040), (6140) | ,1 | ,1 in ascending order | |
| (6050), (6150) | ,1, .1 | :1 = where .1 first is in ,1; .2 = #1, or #2 if it isn't, leaving :1 alone | |

INTERCAL can make an array with no dimensions only by never dimensioning it, or by RETRIEVEing
one stashed before it was. COPY of an empty list, services #6003 and #6103, and the Strings block's
empty strings make them too. There are no versions for 64-bit (`;;`) arrays.

The routines get a list's length through `:1`, with #6000 and #6010, so FILL, COPY, SORT and FIND
need `:1` to be free, though they don't change it: if it is IGNOREd, they misbehave.

The INTERCAL versions use the system library and the labels from (6200) on.

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

## Network, (9000)–(9999)

Connections and listening sockets are I/O-block handles (L34): (2000)–(2310) read and write a
connection, and (2030) closes either kind. Every call blocks, and there are no timeouts. CLOSE of
a connection ends its output first and then reads and drops what the peer sent that the program
didn't read, for up to a second, since closing with unread input would reset the connection and
could cost the peer the end of what it was sent.

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (9000) | ,1 = host, .1 = port | .2 = connection; .3 | .3 = #2 if the name doesn't resolve or nothing answers on any of its addresses |
| (9010) | .1 = port | .2 = listener; .3 | listens on every address, IPv6 and IPv4 where the host has both; port #0 picks a free one; .3 = #2 if the port is taken |
| (9020) | .1 = listener | .2 = connection; .3 | waits for the next connection |
| (9030) | .1 = listener | .2 = its port | |
| (9100) | ,1 = URL | .1 = status code, ,1 = body; .3 | HTTP/1.1 GET |
| (9110) | ,1 = URL, ,2 = body | .1 = status code, ,1 = body; .3 | HTTP/1.1 POST |
| (9200) | .1 = connection | ,1 = method, ,2 = target, ,3 = body; .3 | reads one HTTP request |
| (9210) | .1 = connection, .2 = status code, ,1 = body, ,2 = reason phrase | .3 | writes one HTTP response, `Connection: close` |

Reading from a listener, or accepting on a connection, is E804.

- **URLs** are `http://host[:port][/path]`: `http` in lower case, a port from 0 to 65535 (80 when it
  is missing), and the path, or `/`, sent as it is. Anything else is E817, including a bracketed
  IPv6 address; a name that resolves to IPv6 works. There is no HTTPS (Q110).
- **The client** sends `Host` and `Connection: close` (and `Content-Length` for POST), reads the
  status from the status line (three digits after the first space, then a space or the line's
  end), and takes the body from `Content-Length`, or up to the
  end of input when there is none. Header names are matched without regard to case. Chunked
  transfer and redirects aren't handled. When no connection can be made, or the status line or a
  `Content-Length` body is cut short, .3 is #2, .1 is #0 and ,1 is the empty string.
- **The server helpers:** (9200) skips empty lines, then reads the request line and headers, and a body of the request's
  `Content-Length` (none without one). For a request cut short, or a request line without two
  spaces, .3 is #2 and all three strings are empty. (9210) writes the status line, the reason
  phrase, `Content-Length` and the body; .3 is #2 if any byte couldn't be written.
- **Bytes:** bodies and strings go out one element per byte, as (2300) writes them, so text
  beyond ASCII wants (3070) first and (3080) after.
- **Native versions:** the four services are native in both runtimes. The HTTP routines run their
  INTERCAL, on top of the I/O and Strings routines' natives; their time goes to the network.
- **ciwapa-dart programs** hold listening sockets in a helper isolate, since `dart:io` can't accept
  connections synchronously, and reach each accepted connection through it over loopback (L34).
  Their connections can't turn off Nagle's delay, as ciwapa-llvm programs' do.

The INTERCAL versions use the system library, the I/O, Strings and Arrays blocks, and these labels
of their own: (9300)–(9374), (9800), (9900), (9920), (9930), (9940), (9950), (9960), (9990),
(9991) and (9993)–(9997).

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
| #6000, #6100 | ,1 or ;1 | :1 | its number of dimensions |
| #6010, #6110 | ,1 or ;1, :1 | :1 | the size of one dimension; E812 for one it doesn't have |
| #6003, #6103 | | ,2 or ;2 | makes it an array with no dimensions |
| #9000–#9030 | | | as the Network routines of the same numbers |
| #9203 | | ,3 | makes ,3 the empty string |
| #807–#809, #813–#817 | | | raise those errors for the INTERCAL versions |
| #8000–#8060 | | | as the System routines of the same numbers |

