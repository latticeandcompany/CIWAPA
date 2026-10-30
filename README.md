# CIWAPA

**Compiler for INTERCAL With A Pronounceable Acronym.** CIWAPA is a production-quality compiler for a language that has never been used in production. It turns INTERCAL into native executables, which are much like ordinary executables except that they do things in INTERCAL.

It comes as two compilers, so that you can choose how to be disappointed:

- `ciwapa-llvm` emits LLVM IR and links it with clang.
- `ciwapa-dart` emits Dart and builds it with `dart compile exe`.

Both take the same programs and produce the same output, down to the last error message. Each download bundles the toolchain it needs. There is no bytecode and no interpreter, because INTERCAL deserves to run at the full speed of the hardware.

## INTERCAL, briefly

INTERCAL was designed in 1972 with the goal of having nothing in common with any other programming language. It succeeded. It has no arithmetic operators, only *mingle* (`$`, which interleaves the bits of two numbers) and *select* (`~`, which picks bits out through a mask), so adding two numbers means calling a library routine assembled from those. Input is spelled out one digit at a time, in English. Output is in Roman numerals. A program must say `PLEASE` often enough to be polite, but not so often that it's grovelling, and the compiler checks.

Here is a program that reads a number and prints it back:

```
PLEASE DO ,1 <- #2
DO WRITE IN ,1 SUB #2
DO READ OUT ,1 SUB #2
DO GIVE UP
```

```console
$ ciwapa-llvm build nine.i
$ echo NINE | ./nine

IX
```

The blank line is not a mistake. Numerals print as two lines, and the first holds the overlines that multiply a digit by 1,000. Nine is too small to need any, but it gets the line anyway.

## Install

Download the archive for your platform from [Releases](https://github.com/latticeandcompany/CIWAPA/releases): `ciwapa-<flavor>-<version>-<platform>.tar.xz`, or `.zip` on Windows. There are builds for `linux-x64`, `linux-arm64`, `macos-arm64`, `windows-x64` and `windows-arm64`. Intel Macs are not supported, a decision they will have to learn to live with.

Unpack it and put its `bin/` on your `PATH`. Keep the folder together, because the compiler finds its toolchain next to `bin/`. Then ask it whether everything is in order:

```sh
ciwapa-llvm doctor
```

- **macOS:** `ciwapa-llvm` uses Apple's clang instead of bundling its own. Run `xcode-select --install` once if `doctor` says it's missing.
- **The binaries aren't signed,** so your operating system will warn you before running them. This is the most reasonable thing that will happen to you while using CIWAPA. On macOS, clear the quarantine with `xattr -dr com.apple.quarantine ciwapa-*`. On Windows, choose "More info", then "Run anyway".

Usage:

```sh
ciwapa-llvm build prog.i -o prog     # compile to a native executable
ciwapa-llvm run prog.i               # compile and run in one step
ciwapa-llvm --help                   # every flag
```

`ciwapa-dart` takes the same commands. Compiled programs accept the runtime options from the manual, including `+wimpmode`, which reads and writes plain decimal numbers in exchange for a message explaining what a wimp you are.

## Three languages

The file extension decides what you're in for.

**INTERCAL** (`.i`, or `.3i` to `.7i` for bases 3 to 7, because binary was too mainstream) follows [*The INTERCAL Programming Language Revised Reference Manual*](spec/README.md), the edition that shipped with C-INTERCAL 0.15. That includes COME FROM, character I/O, TriINTERCAL, the system library, and the C-INTERCAL compiler options under their own names (`--traditional`, `--no-random-bug`, `--clockface`). The random compiler bug is on by default, as the manual requires: each statement has a 1 in 128 chance of an E774 planted at build time. Pass `--no-random-bug` if you lack a sense of adventure.

**EXTRACAL** (`.xc`) is a strict superset, for people who found INTERCAL too limiting. It adds the control statements modern C-INTERCAL grew (NEXT FROM, computed COME FROM, threads, backtracking, CREATE, and more), 64-bit and signed numbers, and a standard library for files, strings, sockets and the command line. Every one of these makes the language more capable and none of them make it easier. See [`docs/EXTRACAL.md`](docs/EXTRACAL.md).

**INTERCAL on Interstates** is a web framework for EXTRACAL, written in `.ioi` files. It began in 2013 as an [April Fools' website](https://www.intercaloninterstates.org/) advertising a framework that didn't exist. Now it does. Routes are `COME FROM`s with a path, templates use `{{ }}`, numbers render as Roman numerals with real overlines, and the database layer, ActiveCassette, numbers its tables instead of naming them. The server is called `gross`. It ships in separate `ioi-<flavor>-<platform>` archives. See [`docs/INTERSTATES.md`](docs/INTERSTATES.md).

## Performance

Someone had to measure this. CIWAPA was timed against C-INTERCAL 0.35 (`ick -O` with gcc `-O2`), rick in compiled mode, INTERCAL-64 2.0.3 and CLC-INTERCAL 1.00, on eight programs from C-INTERCAL's `pit/` directory and two of our own.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/perf-speedup-dark.svg">
  <img src="docs/assets/perf-speedup-light.svg" alt="Bar chart of run time relative to ick 0.35 -O, per benchmark. ciwapa-llvm is faster on all ten, from 1.1x on unlambda to 10x on next-resume. ciwapa-dart is faster on next-resume (4.2x), tpk (3.8x) and abstain (4.8x), and slower on the other seven, down to 0.51x on unlambda." width="100%">
</picture>

`ciwapa-llvm` is faster than every other implementation on every benchmark, and 2.2× faster than the fastest of them on the geometric mean. That makes it the fastest INTERCAL compiler in this comparison, a title nobody else was competing for.

`ciwapa-dart` is 1.1× faster than `ick` on the geometric mean, which is a statistician's way of saying it lost seven of the ten races and won the other three by a lot. Part of the loss is fixed cost: a Dart executable takes longer to start, and many of these programs finish in a millisecond. With each implementation's startup time subtracted, `ciwapa-dart` is 1.34× faster than `ick`.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/perf-field-dark.svg">
  <img src="docs/assets/perf-field-light.svg" alt="Bar chart of run time relative to ciwapa-llvm, as a geometric mean. ciwapa-dart takes 2.1x as long, ick 2.3x, rick 2.5x, INTERCAL-64 1,071x and CLC-INTERCAL 2,807x." width="100%">
</picture>

The chart needs a logarithmic axis, which tells you most of what you need to know. INTERCAL-64 and CLC-INTERCAL each ran only four of the ten benchmarks correctly, so they're compared on those four. A run only counted if its output matched `ick`'s, because a wrong answer delivered quickly is still wrong, even in INTERCAL. INTERCAL-64 can only do number I/O in wimp mode. On the others, CLC-INTERCAL stops with an error, doesn't finish within 15 minutes, or prints slightly different output.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/perf-build-dark.svg">
  <img src="docs/assets/perf-build-light.svg" alt="Bar chart of build time relative to ick 0.35 plus gcc, per benchmark. ciwapa-llvm builds faster on all ten, from 1.6x on abstain to 5.3x on unlambda. ciwapa-dart is faster on unlambda (2.2x) and fft (6.7x) and slower on the rest, down to 0.09x on hail_mary." width="100%">
</picture>

Build time runs from source to native executable. `ciwapa-dart` can never build faster than `dart compile exe` does, which takes about 0.6 s even for a program that does nothing. CIWAPA's own front end and code generator take at most 14 ms on any benchmark, so whatever you're waiting for, it isn't us.

<details>
<summary>How these were measured, and the raw numbers</summary>

The numbers are from 2026-10-16, measured on one Linux arm64 machine with every implementation in its own Docker container. Each run time is the fastest of repeated runs: at least one second's worth, up to 200 runs. Each build time is the fastest of three builds.

`primes`, `pi`, `fft` and `life` call routines that only exist inside C-INTERCAL's own system library, so for those four every implementation, CIWAPA included, ran with C-INTERCAL's `syslib.i` appended (and `floatlib.i` for `fft`). CIWAPA's built-in library doesn't take part in those runs. `next-resume` and `abstain` were written for this benchmark set, to stress NEXT/RESUME and ABSTAIN.

Run time, in milliseconds (— means the implementation didn't run that program correctly, or doesn't support base 3):

| Program | ciwapa-llvm | ciwapa-dart | ick 0.35 -O | rick | INTERCAL-64 | CLC-INTERCAL |
|---|---:|---:|---:|---:|---:|---:|
| `tpk` | 1.59 | 3.63 | 13.9 | 13.1 | — | — |
| `unlambda` | 1.20 | 2.52 | 1.30 | 1.58 | 1,571 | 441 |
| `beer` | 1.25 | 2.67 | 1.40 | 1.53 | 731 | 358 |
| `hail_mary` | 1,037 | 1,761 | 1,429 | — | — | — |
| `next-resume` | 7.72 | 18.7 | 78.1 | 63.8 | 21,737 | 342,963 |
| `abstain` | 10.0 | 9.06 | 43.2 | 39.1 | 6,142 | 133,974 |
| `primes` | 1,452 | 3,102 | 1,959 | 2,342 | — | — |
| `pi` | 1.45 | 3.09 | 1.83 | 2.09 | — | — |
| `fft` | 25.9 | 92.6 | 62.9 | 60.6 | — | — |
| `life` | 1.25 | 2.71 | 1.68 | 1.72 | — | — |

Build time, in milliseconds:

| Program | ciwapa-llvm | ciwapa-dart | ick 0.35 + gcc |
|---|---:|---:|---:|
| `tpk` | 398 | 844 | 785 |
| `unlambda` | 350 | 850 | 1,857 |
| `beer` | 177 | 739 | 652 |
| `hail_mary` | 26 | 658 | 59 |
| `next-resume` | 138 | 681 | 299 |
| `abstain` | 197 | 687 | 318 |
| `primes` | 181 | 699 | 353 |
| `pi` | 198 | 836 | 401 |
| `fft` | 2,022 | 933 | 6,232 |
| `life` | 233 | 782 | 559 |

</details>

## Faithful to the manual

The manual contains gaps, typos, a page on operator precedence that is intentionally left blank, and jokes that read exactly like rules. A compiler has to decide what every one of them means, and CIWAPA wrote its decisions down:

- [`docs/SPEC_CHECKLIST.md`](docs/SPEC_CHECKLIST.md) lists 316 rules from the manual, each with its section number and the tests that prove it. All of them pass, in both compilers.
- [`docs/SPEC_DECISIONS.md`](docs/SPEC_DECISIONS.md) records every interpretation and the reason for it. Where the manual is silent, CIWAPA does what C-INTERCAL 0.15, the compiler the manual shipped with, actually did. Where the manual and C-INTERCAL disagree, the manual wins. Every place CIWAPA behaves differently from C-INTERCAL is listed under Divergences in the checklist.

The conformance suite runs every test program through both compilers and requires identical output, identical error text and identical exit codes. Two compilers, one set of wrong answers. Specifically, the right wrong answers.

The system library is a clean-room implementation, written from the manual's description of each routine without looking at anyone else's. When the compiler can prove a program can't tell the difference, it quietly replaces the INTERCAL routines with native ones. Nobody has noticed yet, which is the point.

## Documentation

| | |
|---|---|
| [`docs/EXTRACAL.md`](docs/EXTRACAL.md) | Writing EXTRACAL |
| [`docs/INTERSTATES.md`](docs/INTERSTATES.md) | Building websites in INTERCAL, if you must |
| [`spec/README.md`](spec/README.md) | Where to get the reference manual |
| [`docs/SPEC_CHECKLIST.md`](docs/SPEC_CHECKLIST.md), [`EXTRACAL_CHECKLIST.md`](docs/EXTRACAL_CHECKLIST.md), [`INTERSTATES_CHECKLIST.md`](docs/INTERSTATES_CHECKLIST.md) | Every rule, with its tests |
| [`docs/SPEC_DECISIONS.md`](docs/SPEC_DECISIONS.md) | Every interpretation, and why |

## License

[ISC](LICENSE). You may use CIWAPA for any purpose. We can't think of one.
