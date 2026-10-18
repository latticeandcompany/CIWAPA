# CIWAPA, goal 1: a spec-faithful native INTERCAL compiler

CIWAPA (Compiler for INTERCAL With A Pronounceable Acronym) is built by four `/goal` loops run one after another. This document is goal 1. It is written so that the loop never has to ask a question.

| Goal | Plan |
|---|---|
| 1. CIWAPA, Mode 1 | this file |
| 2. EXTRACAL | [`EXTRACAL_PLAN.md`](EXTRACAL_PLAN.md) |
| 3. INTERCAL on Interstates | [`INTERSTATES_PLAN.md`](INTERSTATES_PLAN.md) |
| 4. WASM playground | planned in a later session ([Later goals](#later-goals)) |

Related documents:
- [`SPEC_CHECKLIST.md`](SPEC_CHECKLIST.md) defines what "100% compliance" means. Each item cites its section of the spec and links at least one test.
- [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) records every question, the options, Ryan's answer and the date. That includes the T1–T40 spec-ambiguity table.

## Source of truth

The spec is *The INTERCAL Programming Language Revised Reference Manual* (Woods & Lyon; the C-INTERCAL 0.15 edition). Ryan's copy is the University of Virginia CS 415 redistribution from Fall 2005.

| | |
|---|---|
| URL | https://www.cs.virginia.edu/~asb/teaching/cs415-fall05/docs/intercal.pdf |
| SHA-256 | `793b6c1e6483640b76543396657bbbfade8fdc051477816dc976638330ba62b2` |

The PDF is GPL and isn't kept in the repo (Q126). When the loop needs it, it downloads the file to `spec/intercal.pdf`, which is gitignored, and checks the hash. Code listings must be retyped from the rendered pages; extracted PDF text puts spurious spaces into letter-spaced code.

Rules for resolving disagreements:
- **Where the spec is explicit, it wins.** Q85/Q97 chose `ick` 0.15's parser for ungrouped binary-operator chains, and 0.15 agrees with the spec: they are invalid (E017).
- **Where the spec is silent, ambiguous or self-contradictory, C-INTERCAL 0.15's behavior decides.** Every case is recorded in the T1–T40 table.
- **C-INTERCAL 0.35 is the differential oracle, not an authority.** Every difference from it is either a CIWAPA bug or a recorded divergence. Divergences are listed in `SPEC_CHECKLIST.md` under "Divergences from C-INTERCAL".
- **Mode 1 covers everything in the PDF.** That includes COME FROM (§4.4.14), Turing Text I/O (§5), TriINTERCAL (§6), the system library (§7), the C-INTERCAL compiler and runtime behaviors (§10), and the error codes (§9).
- **The Princeton compiler's options (§12) are out of scope** (Q16).

## Vision

A production-quality INTERCAL compiler, written in Dart, that turns `.i` programs into native executables with no bytecode. Correctness against the spec comes first, then performance, then extensibility. It ships as two separate downloads that each just work:

- **`ciwapa-dart`** emits Dart source and compiles it with a bundled Dart SDK (`dart compile exe`).
- **`ciwapa-llvm`** emits textual LLVM IR and links it with a bundled clang + lld. On macOS it uses Apple clang instead.

The design leaves room for later goals (EXTRACAL, Interstates, a WASM backend) without building any of them now.

## User experience

```
ciwapa-llvm build hello.i -o hello      # compile to a native executable
ciwapa-llvm run hello.i -- +wimpmode    # compile to a temp dir, run, clean up
ciwapa-llvm doctor                      # check the bundled/required toolchain
```

`ciwapa-dart` has the same commands.

Compiler flags (Q101) give the C-INTERCAL behaviors (§10.2) their own spellings:

| Flag | Behavior | `ick` equivalent |
|---|---|---|
| `--traditional` | INTERCAL-72 only: COME FROM and bases other than 2 give E111 (T39) | `-t` |
| `--no-random-bug` | disables E774 (T23) | `-b` |
| `--clockface` | IIII instead of IV, MMMM for 4000 (T30) | `-C` |
| `--seed <n>` | seeds the compile-time E774 placement | — |
| `--keep` | keeps the generated `.dart` / `.ll` | `-c` |
| `--dump=ast\|ir` | debug output | `-d` |
| `--no-opt` | disables optimization (on by default) | `-O` is inverted |

Compiled programs accept the spec's runtime options exactly as written (§10.3, Q102):
- `+help` / `-help` prints usage and exits with E778. The 0.15 three-second sleep is dropped (T38).
- `+traditional` does nothing.
- `+wimpmode` switches to decimal I/O and prints our own humiliating message to stderr (T32).
- `+seed <n>` seeds the `%` qualifier (T22).

READ OUT and Turing Text output go to stdout. Errors go to stderr in this format (§9.1, Q83, Q90, T33):

```
ICL633I EXECUTION HAS PASSED BEYOND THE LAST STATEMENT OF THE PROGRAM.
        <our original joke line>
	ON THE WAY TO STATEMENT 43
        CORRECT SOURCE AND RESUBMIT
```

- **Line 1, official text.** Use the literal message where §4 gives one: E123 BLACK LAGOON, E436 THROW STICK, and E275 DON'T BYTE OFF (Q84). Otherwise use the §9.2 description, uppercased. E000 prints the undecodable statement's source lines verbatim (T10).
- **Line 2, joke.** An original joke line, written by us; never copied from `ick`.
- **Line 3, next statement.** The ordinal number of the statement that would have run next, without zero-padding. For E633 it is the last statement plus 1 (T33).
- **Exit status.** The error code mod 256, `ick`'s quirks included: E000 exits 0 (T34). GIVE UP exits 0 (T18).

On macOS, `ciwapa-llvm doctor` tells the user to run `xcode-select --install` when the Command Line Tools are missing. The README explains the one-time Gatekeeper (`xattr -d com.apple.quarantine`) and Windows SmartScreen steps, because releases are unsigned (Q64).

## Requirements

1. Every item in `SPEC_CHECKLIST.md` is implemented in **both** flavors and linked to at least one passing test (Q3, Q4).
2. Both flavors produce byte-identical stdout, stderr and exit codes on the whole conformance suite (Q4, Q20).
3. Supported platforms, for both flavors, are Linux x64, Linux arm64, macOS arm64, Windows x64 and Windows arm64. There is no Intel macOS (Q21, Q62).
4. Each release archive bundles its toolchain (Q18, Q61):
   - **`ciwapa-dart`:** the Dart SDK.
   - **`ciwapa-llvm` on Linux:** a slim clang + lld and a musl sysroot, producing static executables.
   - **`ciwapa-llvm` on Windows:** llvm-mingw.
   - **`ciwapa-llvm` on macOS:** no bundled LLVM. It uses Apple clang from the Command Line Tools, because the Apple SDK can't be redistributed.
5. The system library is a clean-room `syslib.i` written only from the §7.2 descriptions. It gets native fast paths wherever the compiler can prove the program can't tell the difference (Q35, Q37, Q38).
6. The library is included automatically, following §7.3 (T36).
7. Politeness is checked (§10.4, T35).
8. The C-INTERCAL compiler and runtime behaviors are supported (§10, Q15).
9. The performance guardrails are met before the goal ends (Q32–Q34). They are temporary and stay in place until goal 2's cleanup (Q140).
10. Release archives build in CI for all 10 platform × flavor combinations. The loop never publishes a release; Ryan does, starting at semver `0.1.0` (Q65, Q103).

## Design and behavior

The full rule list lives in `SPEC_CHECKLIST.md` and `SPEC_DECISIONS.md`. These are the decisions most likely to surprise an implementer:

- **Types.**
  - 16-bit variables may hold 65535 (§4.4.1 off-by-one, Q76).
  - SELECT takes the type of its right operand (§3.4.1.1, Q77).
  - A mingle operand over 65535 gives E533 at runtime (Q78).
  - Unary rotation width is the operand's static type (Q79).
  - All variables start at 0. Using an undimensioned array gives E241 (Q82).
- **When errors fire (Q80, Q81).** Statement-local errors behave like a splat and fire only when that statement executes:
  - a constant over `#65535`: E017
  - a variable `.0` or one above 65535: E200
  - an invalid label: E197
  - a NEXT to a missing label: E129
  - an ABSTAIN or REINSTATE to a missing label: E139
  - an ungrouped binary chain: E017 (§3.4.3, Q97)

  Whole-program errors fire at compile time: E182, E444, E555, E079, E099 and E998.
- **Lexing (T5–T15).**
  - Uppercase only.
  - Spaces inside numbers join the digits.
  - Multi-word keywords may omit the space (`READOUT`, `GIVEUP`).
  - `DO`, `PLEASE` and `(n)` are recognized even mid-word (§4.5).
  - `DO PLEASE` is accepted.
  - CR is stripped, so CRLF works.
  - Mingle is `$`, `¢` or `c⌫/`. XOR is `?`, `V⌫-` or `-⌫V`. Source is UTF-8.
  - A literal `*` in the source is junk.
- **Grouping and subscripts (T1, T2).**
  - A spark or ears character that directly follows a complete operand closes a group. Otherwise it opens one.
  - A subscript list ends at the first binary operator, so the §4.4.1 example `,1SUB#1#1¢#1` must compile.
- **Control flow.**
  - The NEXT stack holds 79 entries; the 80th push gives E123 (§4.4.2, T16).
  - RESUME and FORGET follow T17.
  - COME FROM follows T19.
  - ABSTAIN is a boolean; gerunds follow T20 and T21. CALCULATING includes array dimensioning. ABSTAINING covers every kind of ABSTAIN.
  - `%0` never runs the statement and `%100` always does (T13).
- **I/O (T28–T31).**
  - WRITE IN reads one number per line, uppercase, in `ick`'s word lists for every language the spec names. Volapük words are accepted in both UTF-8 and TeX spelling.
  - READ OUT writes two lines per value: an overline line made of `_`, then the numeral, using `ick`'s `butcher()` algorithm.
  - Turing Text: EOF reads as 256. Output flushes at every newline and at exit.
- **Limits.** No artificial limits (T27). The NEXT-stack depth of 79 is the only fixed limit, and the spec requires it.
- **TriINTERCAL.** The extensions `.3i` through `.7i` select the base. Behavior follows T40.

## Technical approach

```
foo.i → lexer → parser → AST → checks (labels, politeness, COME FROM, syslib inclusion) → IR ─┬→ Dart emitter → foo.dart + runtime.dart → dart compile exe → foo
                                                                                               └→ LLVM emitter → foo.ll   + runtime.c    → clang (+lld)     → foo
```

- **One shared front end and IR** in `ciwapa_core`. Types are known statically (Q77), which lets the IR fold constants and keep values in machine words.
- **Two small runtimes, `runtime.dart` and `runtime.c`** (Q17). They hold:
  - number-word input
  - Roman numeral output
  - the NEXT stack and STASH stacks
  - ABSTAIN and IGNORE state
  - `%` and E774 randomness
  - the Turing tapes
  - error printing

  The conformance suite keeps the two in sync.
- **Optimizations that preserve semantics,** for example:
  - skip ABSTAIN checks for statements nothing can abstain
  - inline mingle, select and unary operators
  - remove the bookkeeping for COME FROM targets that are never used

  qpliu's INTERLAC design (one function per statement, linked with `musttail`) is prior art worth evaluating for the LLVM emitter.
- **The LLVM IR stays conservative.** Opaque `ptr` only, nothing newer than both Apple clang (LLVM 19–21) and the bundled LLVM accept. Emit an exact target triple. CI checks both compilers.
- **The Dart flavor** compiles generated programs in a temp directory with no `pubspec.yaml` above it, and passes `--suppress-analytics`, so `dart compile exe` never runs `pub get` or writes to `~/.pub-cache`.
- **Clean-room syslib with native fast paths (Q37).**
  - The INTERCAL `syslib.i` is the reference.
  - The emitter swaps in a native routine only when the program can't observe the difference: no COME FROM, ABSTAIN or REINSTATE aimed at labels 1000–1999.
  - Even then, the native routine must reproduce the NEXT-stack depth the INTERCAL version would use, so E123 and RESUME behave identically, and it must leave non-result variables unchanged (§7.2).
  - On overflow, the observable E000 must print the statement text `DOUBLE OR SINGLE PRECISION OVERFLOW`, exactly like the original (Q38).
- **Tooling** (Q47, Q48, Q68):
  - Lattice 1.1.1 runs the tasks, with `latticeVersion` pinned.
  - The Dart pub workspace has one lockfile.
  - Docker provides every toolchain, through one long-lived image, `ciwapa-toolchain:<hash of Dockerfile>`. Each workspace's Lattice tasks are written out through `tools/in-docker`, for example `"test": "tools/in-docker dart test"`.
  - The image pins its Dart tag and LLVM major version. Dependabot bumps the `FROM` tag, and a scheduled workflow opens a bump PR for LLVM and the other bundled toolchain versions (Q24).
  - In CI, macOS and Windows jobs use `dart-lang/setup-dart` at the same pinned version.

## Affected areas

```
lattice.json
pubspec.yaml                 # Dart pub workspace root (one lockfile)
Dockerfile                   # ciwapa-toolchain: pinned Dart + LLVM
.github/                     # CI matrix, release builds, Dependabot, toolchain-bump workflow
packages/
  ciwapa_core/               # lexer → parser → checks → IR, clean-room syslib.i
  ciwapa_dart/               # Dart emitter + runtime.dart + CLI   ⇒ ciwapa-dart
  ciwapa_llvm/               # LLVM emitter + CLI                  ⇒ ciwapa-llvm
  runtime_c/                 # runtime.c for the LLVM flavor
  conformance/               # golden tests run against both flavors
tools/
  in-docker                  # permanent: runs a command inside ciwapa-toolchain
  oracle/  bench/  goal/     # TEMPORARY: ick oracle, baselines, pit fetch, goal-status
docs/
  PLAN.md  EXTRACAL_PLAN.md  INTERSTATES_PLAN.md  SPEC_CHECKLIST.md  SPEC_DECISIONS.md  QUESTIONS.md
  assets/do-not-use.png      # README banner (Ryan removes it, Q130)
```

`apps/interstates/` and `apps/playground/` belong to goals 3 and 4. They don't exist until those goals create them; there are no empty placeholder folders (Q69).

## Before you run `/goal`

Ryan does these by hand (Q105):

- [x] **Remove the spec PDF from git history** (Q132). The rewrite was blocked by permissions during the planning session. There are three unpushed commits:
  ```sh
  git branch backup/pre-pdf-removal mega
  FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --index-filter 'git rm --cached --ignore-unmatch spec/intercal.pdf' -- mega
  git update-ref -d refs/original/refs/heads/mega
  git log --oneline mega -- spec/intercal.pdf   # must print nothing
  git branch -D backup/pre-pdf-removal           # once you're happy
  ```
- [x] Create the **public** GitHub repo (Q104) and push `mega` as the default branch.
- [x] Turn on GitHub Actions and Dependabot.
- [x] Make sure the README carries the 🚨 DO NOT USE banner (`docs/assets/do-not-use.png`). The loop never removes it (Q130).
- [x] Start Docker.
- [x] Authenticate `gh` with the `repo` and `workflow` scopes. `gh stack` (v0.2.0) is already installed.
- [ ] Start Claude Code in **auto mode**, then paste the [goal prompt](#goal-prompt).

## Loop rules

These apply to every turn of the loop.

- **Never assume** (Q53, Q70). Every decision was made during planning. If something unforeseen comes up anyway:
  - write it to `docs/QUESTIONS.md` with the context, options, and the lean
  - mark the affected checklist items **blocked**
  - keep working on everything else

  If the answer could force undoing substantial work, the question is **CATASTROPHIC**: record it and stop the goal.
- **Git workflow** (Q11, Q27, Q59, Q67, Q72):
  - Each feature is one PR in a `gh stack` on `mega`, created with `gh stack init -b mega`, `add`, `push` and `submit`.
  - Each feature PR implements the feature in **both** backends, with its tests (Q20).
  - Before merging, run a `code-reviewer` subagent pass and wait for green CI.
  - Merge with `gh stack merge --merge`. Never squash and never rebase-merge.
- **The AI note.** Every PR, issue and comment starts with:
  ```
  > [!NOTE]
  > This content was created by an AI agent acting on behalf of Ryan.
  ```
- **Dependencies** (Q129, Q131). Approved:
  - Dart: `test` (dev), `args`, and the existing `lints`
  - toolchain downloads: Dart SDK zips, LLVM release binaries (cut down to clang + lld), llvm-mingw, and musl (to build the sysroot)
  - CI: `dart-lang/setup-dart` and the standard `actions/*`
  - temporary-scaffolding downloads: the oracle and benchmark baselines listed below

  Anything else goes to `QUESTIONS.md`. That is never catastrophic: carry on without it.
- **Toolchains come from Docker** (Q48, Q68). Nothing is installed on the host. Docker images are named and versioned. Goal 1 removes none of them; goal 2's cleanup removes every image the loops created (Q140).
- **Clean room** (Q38). Whoever writes `syslib.i` may read only §7.2 of the spec. They must not open the §8.3 listing, `ick`'s `syslib*.i`, or rick's `syslib.rs`. Reading `ick`'s compiler and runtime for behavior is fine. Copying its code or its message strings is not.
- **The `pit/` corpus** (Q39) is GPL. It is downloaded at test time from the C-INTERCAL 0.35 tarball, with its hash checked, into a gitignored directory. It is never committed.
- **Error messages** (Q83, Q90). Line 1 carries the official text. The joke lines are original.
- **Determinism.** Conformance tests always use `--no-random-bug`, and use fixed `--seed` and `+seed` values wherever randomness matters.

## Implementation steps

Work in this order, because each stage builds on the ones before it.

1. **Toolchain spike** (Q63, Q71).
   - Write the `Dockerfile` (pinned Dart, plus LLVM from `apt.llvm.org`; it currently says `FROM dart:latest`), the Dependabot config and the toolchain-bump workflow. `tools/in-docker` already exists from the planning session.
   - Build hello-world executables for all 10 platform × flavor combinations on the hosted runners: `ubuntu-24.04`, `ubuntu-24.04-arm`, `macos-latest`, `windows-latest`, `windows-11-arm`. That covers the bundled Dart SDK, slim clang + lld + musl on Linux, llvm-mingw on Windows, and Apple clang on macOS.
   - Known risks: `dart compile exe` on Windows arm64 hasn't been confirmed; the musl sysroot has to be built; llvm-mingw has to work on arm64.
   - Best effort, and it never blocks: build `ick` 0.15 from tag `0.15` as a second oracle. Expect `-std=gnu89`, a `<varargs.h>` → `stdarg` port, missing includes, and the flex/bison renames. If it won't build, log that and drop it (Q98).
   - Every failure goes into `QUESTIONS.md`.
2. **Workspace.** Create the pub workspace and the packages from [Affected areas](#affected-areas). Write out `lattice.json` workspaces and tasks; Dart pub workspaces aren't auto-discovered. Confirm with `lattice run test --dry-run`.
3. **Front end** (`ciwapa_core`). Covers lexing (T5–T15), statements and qualifiers (§4.1–4.3, T11–T13), and the expression grammar with grouping and subscripts (§3.4.3, T1–T4). Also: undecodable statements and the comments mechanism (§4.5, T8–T10), statement-local error capture (Q80), the whole-program checks (E182, E444, E555, politeness T35, E998), and the TriINTERCAL base from the file extension (T40).
4. **IR.** Statement ordinals and labels, the next-statement map used by error line 3, static types, and the ABSTAIN/COME FROM analysis that later optimizations rely on.
5. **Both emitters and both runtimes, side by side,** one feature PR at a time:
   - calculate and array dimensioning (§4.4.1)
   - NEXT, FORGET, RESUME and GIVE UP (§4.4.2–4.4.4, §4.4.11)
   - STASH and RETRIEVE (§4.4.5–4.4.6)
   - IGNORE and REMEMBER (§4.4.7–4.4.8)
   - ABSTAIN and REINSTATE (§4.4.9–4.4.10)
   - WRITE IN and READ OUT (§4.4.12–4.4.13)
   - COME FROM (§4.4.14)
   - Turing Text (§5)
   - errors (§9)
   - runtime options (§10.3)
   - TriINTERCAL operators (§6)
   - E774
6. **Clean-room syslib** (§7). Write `syslib.i` from §7.2 alone, add automatic inclusion (§7.3, T36), add the native fast paths with the conditions from [Technical approach](#technical-approach), and test the INTERCAL and native versions against each other.
7. **Conformance suite** (`packages/conformance`).
   - Each test is a set of golden files: `.i`, optional `.in`, and expected `.out`, `.err` and exit code. The same tests run through both flavors.
   - Every `SPEC_CHECKLIST.md` item links to its tests.
   - The spec's own examples are included: the §2.1 program, the §3.4 expression values, the §4.4.1 LSB example, the §4.5 comment examples, and the §6.5.3 TriINTERCAL examples.
   - The §5.3 `cat` program is a known-failing politeness case (3 polite statements out of 22), with a polite variant beside it.
8. **Oracle and differential testing** (Q36, temporary). Run the conformance suite and `pit/` through `ick` 0.35 (and 0.15, if it built) and through both flavors. Triage every difference: a CIWAPA bug gets fixed, and an intended difference is recorded under Divergences in `SPEC_CHECKLIST.md`.
9. **CI matrix.** Lint, test and conformance for all 10 combinations on every PR, plus a cross-check of the LLVM IR against both Apple clang and the bundled LLVM.
10. **Release archives.** CI builds `ciwapa-dart-<ver>-<os>-<arch>` and `ciwapa-llvm-<ver>-<os>-<arch>`, each with its bundled toolchain and license notices: Dart BSD-3, LLVM Apache-2.0 with the LLVM exception, musl MIT, mingw-w64. Each archive passes a smoke test of `doctor`, then building and running hello world. Nothing is published.
11. **Performance guardrails** (temporary). Build the benchmark harness and the baseline images, then optimize until the guardrails were met. (Their targets lived in a section goal 2's cleanup removed, Q140.)
12. **Final verification** (Q140). Remove nothing: the [temporary scaffolding](#temporary-scaffolding) stays for goal 2. Run `lattice run goal-status` on the `mega` HEAD and confirm that it ends in `GOAL: MET` and that CI is green.

## Temporary scaffolding

Goal 1 removes **none** of this (Q140). It is kept until goal 2's cleanup, which removes goal 1's and goal 2's scaffolding together. Everything in the right column is permanent.

| Kept until goal 2's cleanup | Permanent |
|---|---|
| `tools/oracle/`: the `ick` 0.35 (and 0.15) oracle images and differential tests | `packages/conformance`, our own golden suite |
| the `pit/` download script and its gitignored download directory | unit tests in every package |
| `tools/bench/`: the benchmark harness and the rick / INTERCAL-64 / CLC images | the CI matrix (lint, test, conformance) |
| the CI performance-regression check | the release-archive pipeline |
| the performance targets in the docs (removed by goal 2's cleanup) | `tools/in-docker`, `Dockerfile`, Dependabot, the toolchain-bump workflow |
| `tools/goal/` and the `goal-status` Lattice task | `docs/QUESTIONS.md`, if anything is still in it |
| every Docker image the loop built, including `ciwapa-toolchain` | the README banner, which Ryan removes |

## Edge cases

- **Spec examples copied with their listing `*`.** The `*` is junk and turns the statement before it into garbage (T15). Retype examples without it.
- **Spaces inside numbers.** `#1 2` is `#12` (T5).
- **Mid-word identifiers.** A comment containing "DOES" starts a new statement at `DO` (§4.5, T8).
- **`DO %50 NOT`** can't be decoded, because NOT must come before `%` (T12). `%0` and `%100` are valid (T13).
- **The 80th NEXT** gives E123. `ick` allows 80 levels; we follow the spec's 79 (T16).
- **E000 exits with status 0** (T34). Tests must check stderr, not only the exit code.
- **Tiny programs.** Politeness is only checked above 2 statements. The spec's own §5.3 program fails it (T35).
- **Syslib auto-inclusion** doesn't happen if the program defines *any* label from 1000 to 1999 (T36). Running past the last statement always gives E633, never a fall into the syslib (T37).
- **Turing input after EOF.** The first read gives 256. The next one gives the character + 1 (T31).
- **CRLF sources** must work, for Windows (T7).
- **Randomness.** `%` and E774 are random: tests always seed them or disable E774.
- **Windows arm64.** `dart compile exe` there is unconfirmed until stage 1.
- **macOS without the Command Line Tools.** `doctor` has to say so. Apple clang's IR dialect also lags upstream LLVM.
- **Stray `pubspec.yaml`.** One anywhere above the Dart flavor's temp build directory triggers a silent `pub get`.

## Acceptance criteria

`lattice run goal-status` prints one line per criterion, and the final verdict.

1. Every `SPEC_CHECKLIST.md` item is checked and links to at least one test. The only exceptions are items marked blocked in `QUESTIONS.md`.
2. The conformance suite passes in both flavors, with identical stdout, stderr and exit codes.
3. CI on the `mega` HEAD is green for all 10 platform × flavor jobs.
4. All 10 release archives build and pass their smoke test.
5. Every performance guardrail is met; the script prints each ratio.
6. Every difference from the 0.35 oracle is either fixed or recorded under Divergences.

When criteria 1–6 hold, `goal-status` ends with `GOAL: MET`. Nothing is removed at the end of goal 1 (Q140).

## Goal prompt

Paste this after completing [Before you run `/goal`](#before-you-run-goal):

```
/goal Build CIWAPA goal 1 exactly as specified in docs/PLAN.md, docs/SPEC_CHECKLIST.md and docs/SPEC_DECISIONS.md. Follow the "Loop rules" section of docs/PLAN.md on every turn. Never assume anything: record any unforeseen question in docs/QUESTIONS.md, mark the affected checklist items blocked, and keep working on unblocked items. If a question is CATASTROPHIC (its answer could force undoing substantial work), record it with that label and stop. Work through docs/PLAN.md "Implementation steps" in order. Make one gh stack PR per feature on mega, implementing every feature in both backends with its tests. Run a code-reviewer subagent before each merge, and merge with merge commits only when CI is green. After every merge, run `lattice run goal-status` and show its full output.

The goal is met when this conversation shows ONE of:
(A) `lattice run goal-status` output on the mega HEAD ending in `GOAL: MET`, followed by a green CI run for that commit on mega. Do not remove any temporary scaffolding; goal 2 removes it;
(B) `lattice run goal-status` output showing that every remaining item is blocked, followed by the contents of docs/QUESTIONS.md;
(C) a CATASTROPHIC entry in docs/QUESTIONS.md, shown in full.
```

## Later goals

- **Goal 2, EXTRACAL:** [`EXTRACAL_PLAN.md`](EXTRACAL_PLAN.md).
- **Goal 3, INTERCAL on Interstates:** [`INTERSTATES_PLAN.md`](INTERSTATES_PLAN.md).
- **Goal 4, WASM playground.** This gets its own planning session. Decisions so far:
  - a static site with a WebAssembly backend, so the compiler runs in the browser with no server (Q23)
  - the deliberate exception to "no bytecode"
  - its own goal, after goal 3 (Q127)
  - deliberately hostile INTERCAL-spirit UX (Q128)
  - built on Ryan's existing stack (Astro 7, React 19, Tailwind 4, Bootstrap 5 / Bootstrap Icons, Sass) following his UI rules (Q129). See `~/Source/latticeandcompany.github.io` and `~/Source/arenaswap/apps/docs`, and their `CLAUDE.md` / `AGENTS.md`.

## Assumptions and decisions

Every answer, with its options and date, is in [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md). Engineering decisions made during planning without a separate question:
- The Dart flavor compiles in a temp directory with no `pubspec.yaml` above it, with `--suppress-analytics`.
- A scheduled workflow bumps the pinned LLVM and bundled-toolchain versions. Dependabot handles the Docker `FROM` tag and the Actions.
- Lattice tasks run through `tools/in-docker`, which is permanent.
- `goal-status` reports `GOAL: MET` when criteria 1–6 hold. The script and all other temporary scaffolding survive goal 1 and are removed by goal 2's cleanup (Q140).
- The emitted LLVM IR is limited to the subset both Apple clang and the bundled LLVM accept.

## Open questions

None. The PDF history rewrite is a step for Ryan in [Before you run `/goal`](#before-you-run-goal), not an open question.
