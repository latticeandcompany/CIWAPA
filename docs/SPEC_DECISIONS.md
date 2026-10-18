# Decisions

Every answer Ryan has given, so no question gets asked twice. Newest entries go at the bottom.

## Workspace

### Where does the spec come from?
- **Options:** Ryan adds the file / agent searches and fetches it / Ryan supplies a URL
- **Decision:** Ryan added `intercal.pdf`. It now lives at `spec/intercal.pdf`.
- **Date:** 2026-10-14

### What does workspace setup include?
- **Options:** plan + docs skeleton / project agent instructions (AGENTS.md) / Dart Dockerfile / Dart package scaffold
- **Decision:** plan + docs skeleton, Dart Dockerfile, Dart package scaffold. No project AGENTS.md.
- **Date:** 2026-10-14

### Which branch does setup work go on?
- **Options:** stay on `mega` / new branch off `main` / leave uncommitted
- **Decision:** stay on `mega`
- **Date:** 2026-10-14

### What is "INTERCAL on Interstates"?
- **Options:** Ryan explains / park it / look it up
- **Decision:** look it up. It's a web framework built on C-INTERCAL. What "adding" it means is still open (see `docs/PLAN.md`).
- **Date:** 2026-10-14

### Dart package name
- **Options:** `ciwapa` / `intercal`
- **Decision:** `ciwapa`
- **Date:** 2026-10-14

### Lint setup
- **Options:** `package:lints/recommended` / `very_good_analysis` / no lint package
- **Decision:** `package:lints/recommended`
- **Date:** 2026-10-14

### Commit `pubspec.lock`?
- **Options:** commit it / keep it ignored
- **Decision:** commit it. Removed it from `.gitignore`.
- **Date:** 2026-10-14

### Plain-text copy of the spec?
- **Options:** extract with pdftotext in Docker / keep the PDF only
- **Decision:** PDF only
- **Date:** 2026-10-14

## Architecture

### Compilation target
- **Options:** LLVM IR / generated C / generated Dart compiled with `dart compile exe`
- **Decision:** both LLVM IR and Dart, as two backends the user picks between. Details are open (see `docs/PLAN.md`).
- **Date:** 2026-10-14

## Scope

### Q1: Settle spec ambiguities in the planning session? (SUPERSEDED by Q53)
- **Options:** (a) every spec ambiguity in the planning session / (b) plan-level now, spec questions when the checklist is written
- **Decision:** (b). Superseded by Q53: all grilling, spec ambiguities included, happens in the planning session.
- **Date:** 2026-10-14

### Q13: Does Mode 1 cover everything in the PDF?
- **Options:** (a) everything, including TriINTERCAL / (b) core + COME FROM + Turing Text, TriINTERCAL later / (c) INTERCAL-72 core only
- **Decision:** (a). The PDF is the source of truth. Mode 1 is everything it documents: COME FROM, TriINTERCAL (bases 3–7), Turing Text I/O, the C-INTERCAL error codes. TriINTERCAL may be built last.
- **Date:** 2026-10-14

### Q14: What does "spec vs. ick" mean?
- **Options:** the 0.15 text wins over modern ick, with ick as an oracle / something else
- **Decision:** The PDF is ick 0.15's manual. Where the 0.15 text and modern ick disagree, the text wins and the divergence is recorded. Modern ick is a differential-testing oracle, not an authority.
- **Date:** 2026-10-14

### Q15: Which documented C-INTERCAL options are in scope?
- **Options:** (a) all behaviors, CIWAPA's own flag names / (b) all behaviors, ick's flag names / (c) only library auto-inclusion and politeness
- **Decision:** (a). Traditional mode, the E774 random bug and the flag that disables it, clockface, wimpmode, syslib auto-inclusion, politeness checking. Flag names are in Q101.
- **Date:** 2026-10-14

### Q16: Princeton compiler options (§12)?
- **Options:** out of scope / in scope
- **Decision:** Out of scope, recorded as a deliberate exclusion (WIDTH, LINES, IAMBIC, KIDDING, DECK, SEQ, ...). E774 is covered by Q15.
- **Date:** 2026-10-14

### Q28: Build Mode 2 now, or only design for it?
- **Options:** design for it, build nothing / build now
- **Decision:** Design for it in goal 1 and build none of it. Mode 2 is named **EXTRACAL** and gets its own detailed plan, `docs/EXTRACAL_PLAN.md`.
- **Date:** 2026-10-14

### Q29: What happens to INTERCAL on Interstates?
- **Options:** (a) drop it / (b) future idea: make the joke real / (c) build it in this plan
- **Decision:** (b). The site is a 2013 April Fools' parody, and its tarball is a 346-byte README. Refined by Q45 and Q54: it's separate from EXTRACAL, has its own implementation, and is goal 3.
- **Date:** 2026-10-14

### Q45: Is Interstates the last stage of the EXTRACAL plan?
- **Options:** yes / no
- **Decision:** No. It's separate from EXTRACAL, with its own implementation and its own plan, `docs/INTERSTATES_PLAN.md`.
- **Date:** 2026-10-14

### Q54: How many goals?
- **Options:** one loop for everything / separate goals
- **Decision:** Separate `/goal` runs, one after another: (1) the initial CIWAPA → (2) EXTRACAL → (3) INTERCAL on Interstates. The playground became goal 4 (Q127).
- **Date:** 2026-10-14

## Architecture

### Q2: Which backend comes first?
- **Options:** (a) Dart first / (b) LLVM first / (c) both at once
- **Decision:** (c). Both at once, kept at feature parity.
- **Date:** 2026-10-14

### Q3: Must both backends pass the whole checklist?
- **Options:** (a) both / (b) only the reference backend
- **Decision:** (a). Both pass every checklist item.
- **Date:** 2026-10-14

### Q4: One shared conformance suite?
- **Options:** shared golden suite / separate suites per backend
- **Decision:** Yes. Golden programs (`.i`, optional stdin, expected stdout, stderr and exit code) run through both backends and must match. Every checklist item links its test. Each backend also has its own unit tests.
- **Date:** 2026-10-14

### Q5 / Q17: How is the runtime structured?
- **Options:** (a) two small runtimes, `runtime.dart` + `runtime.c` / (b) one C runtime the Dart flavor reaches through `dart:ffi` / (c) a runtime written by hand in LLVM IR
- **Decision:** (a). The front end and IR are shared. Each backend has its own small runtime, and the conformance suite keeps them identical.
- **Date:** 2026-10-14

### Q6 / Q19: How does the user pick a backend?
- **Options:** CLI flag / config file / two separate compilers
- **Decision:** Two separate downloadable compilers, `ciwapa-dart` and `ciwapa-llvm`, from one repo with one shared front end. There is no backend flag.
- **Date:** 2026-10-14

### Q20: How is parity enforced?
- **Options:** every feature PR covers both backends / one backend may lag
- **Decision:** Every feature PR adds the feature to the front end and both backends, together with its conformance tests.
- **Date:** 2026-10-14

### Q37: How is the clean-room syslib built?
- **Options:** (a) clean-room INTERCAL source / (b) native routines / (c) both
- **Decision:** (c). The clean-room `syslib.i` is the reference. The compiler swaps in native routines wherever it can prove the program can't tell the difference. It falls back to the INTERCAL version for things like COME FROM or ABSTAIN aimed at library labels.
- **Date:** 2026-10-14

### Q49 / Q69: Monorepo layout
- **Options:** the proposed layout / something else (Ryan asked to see where Interstates goes)
- **Decision:**
  - Root: `lattice.json`; `pubspec.yaml` as the Dart pub workspace root (one lockfile); `Dockerfile` for the `ciwapa-toolchain` image.
  - `packages/ciwapa_core`: lexer → parser → checks → IR, plus the clean-room `syslib.i`.
  - `packages/ciwapa_dart`: Dart emitter, `runtime.dart`, CLI.
  - `packages/ciwapa_llvm`: LLVM emitter, CLI.
  - `packages/runtime_c`, `packages/conformance`.
  - `apps/playground` (goal 4) and `apps/interstates` (goal 3: the framework plus `gross`).
  - `tools/oracle`, `tools/bench`, `tools/goal`: all TEMPORARY.
  - `docs/`: PLAN, EXTRACAL_PLAN, INTERSTATES_PLAN, SPEC_CHECKLIST, SPEC_DECISIONS.
  - EXTRACAL is a mode inside the existing packages. No empty placeholder folders.
- **Date:** 2026-10-14

### Q50: Where does Interstates live?
- **Options:** this monorepo / a separate repo
- **Decision:** A future workspace in this monorepo, `apps/interstates/`. Out of scope for goals 1 and 2.
- **Date:** 2026-10-14

### Q100: CLI shape
- **Options:** subcommands / ick-style `ick foo.i`
- **Decision:** Subcommands: `build hello.i -o hello`, `run hello.i [-- +wimpmode]`, and `doctor`. The same for `ciwapa-dart` and `ciwapa-llvm`.
- **Date:** 2026-10-14

### Q101: Flag names
- **Options:** the proposed names / others
- **Decision:**
  - `--traditional` (ick `-t`), `--no-random-bug` (ick `-b`), `--clockface` (ick `-C`)
  - `--seed <n>` sets where E774 is placed at compile time
  - `--keep` keeps the generated `.dart`/`.ll` (ick `-c`)
  - `--dump=ast|ir` (ick `-d`)
  - `--no-opt`, since optimization is on by default
- **Date:** 2026-10-14

### Q102: Runtime options in compiled programs
- **Options:** keep the spec's +/- syntax / rename them
- **Decision:** Keep the spec's syntax (`+help`, `+traditional`, `+wimpmode`), and add `+seed <n>` for `%` randomness.
- **Date:** 2026-10-14

## Platforms & toolchains

### Q7 / Q21: Platforms
- **Options:** macOS + Linux / Linux only / all major platforms
- **Decision:** All major platforms, limited to what GitHub-hosted CI runners can build: x64 and arm64 on each OS that has a hosted runner. Refined by Q62.
- **Date:** 2026-10-14

### Q62: Intel Macs?
- **Options:** support them until the runners go away / don't support them
- **Decision:** No Intel Mac support at all. The targets are linux-x64, linux-arm64, macos-arm64, windows-x64 and windows-arm64: 5 platforms × 2 flavors = 10 builds.
- **Date:** 2026-10-14

### Q8 / Q22: Where are macOS and Windows built and tested?
- **Options:** CI only / a local SDK on the Mac
- **Decision:** CI. Local development runs in the Docker toolchain (Linux arm64). No Dart SDK goes on the Mac.
- **Date:** 2026-10-14

### Q9: Docker toolchain versions
- **Options:** pinned / latest
- **Decision:** Ryan wants the latest supported versions and will fix things as they break. LLVM (latest) goes into the image too. Refined by Q24.
- **Date:** 2026-10-14

### Q24: Pinning
- **Options:** exact pins bumped automatically / plain `latest`
- **Decision:** Exact pins, bumped automatically by Dependabot (the Dart image tag and Actions). This overrides the `latest` rule in the temporary-tooling-docker skill. LLVM in Docker comes from apt.llvm.org.
- **Date:** 2026-10-14

### Q18: Where does each flavor's toolchain come from?
- **Options:** (a) the user installs it / (b) bundled in the download / (c) fetched on request
- **Decision:** (b). Each release archive bundles its toolchain.
- **Date:** 2026-10-14

### Q61: `ciwapa-llvm` toolchain per OS
- **Options:** as proposed / something else
- **Decision:**
  - Linux: bundled slim clang + lld + a musl sysroot, producing static executables.
  - Windows: bundled llvm-mingw.
  - macOS: no bundled LLVM. It uses Apple clang from the Xcode Command Line Tools, because the Apple SDK can't be redistributed. `doctor` prints `xcode-select --install`.
  - The emitted IR sticks to a conservative subset (opaque `ptr`, no new syntax) and is tested against both Apple clang and the bundled upstream LLVM.
- **Date:** 2026-10-14

### Q47: Lattice version
- **Options:** 1.1.1 now / build 2.0 from Ryan's `v2` branch
- **Decision:** Lattice 1.1.1, the installed version, matching the skill on GitHub's `mega` branch. Pin it with `latticeVersion` and move to 2.0 later with `lattice migrate`.
- **Date:** 2026-10-14

### Q48: Toolchains from Lattice or from Docker?
- **Options:** Lattice-managed toolchains / Docker
- **Decision:** Docker provides the toolchains.
- **Date:** 2026-10-14

### Q68: How Lattice tasks run inside Docker
- **Options:** (a) one long-lived image / (b) a fresh image every run, as the skill says
- **Decision:** (a). Workspace tasks go through a wrapper (`tools/in-docker dart test`) that uses one long-lived image, `ciwapa-toolchain`, tagged with a hash of the Dockerfile. Goal 2's cleanup deletes it (Q140). This overrides the skill's per-run temporary image.
- **Date:** 2026-10-14

### Q51: Commit the Lattice skill into the repo?
- **Options:** commit a copy / symlink / neither
- **Decision:** No.
- **Date:** 2026-10-14

### Q52: When is Lattice set up?
- **Options:** now / as step 0 after grilling
- **Decision:** Step 0 of the confirmed plan, right after grilling, together with the PLAN.md rewrite.
- **Date:** 2026-10-14

### Q63 / Q71: Toolchain feasibility spike
- **Options:** run a spike first / skip it
- **Decision:** Yes, as the loop's first stage. It builds hello world for all 10 platform/flavor combinations on CI runners, and also tries to build ick 0.15 (best effort, Q98). Failures go to `QUESTIONS.md` (Q70).
- **Date:** 2026-10-14

### Q64: Code signing
- **Options:** (a) unsigned / (b) sign and notarize
- **Decision:** (a). Releases are unsigned. The docs explain `xattr -d com.apple.quarantine` and SmartScreen's "Run anyway".
- **Date:** 2026-10-14

### Q65: Distribution channels
- **Options:** GitHub Releases only / package managers too
- **Decision:** GitHub Releases only, for now.
- **Date:** 2026-10-14

### Q103: Publishing releases
- **Options:** the loop builds but doesn't publish / the loop publishes
- **Decision:** The loop builds and checks the release archives in CI but never publishes a Release. Ryan publishes and picks versions. Semver, starting at 0.1.0.
- **Date:** 2026-10-14

### Dart flavor compile hygiene (agent decision, recorded)
- **Options:** n/a
- **Decision:** Generated programs are compiled in a temp directory with no `pubspec.yaml` above it, and with `--suppress-analytics`. That way `dart compile exe` never runs `pub get` and never writes analytics.
- **Date:** 2026-10-14

## Repo & workflow

### Q11 / Q27: Git workflow
- **Options:** phase branches + PR stacks / everything on trunk; plain git + gh / a stacking tool / GitHub's native stacks
- **Decision:** Each phase is a branch merged back to trunk through PR stacks, using GitHub's native stacked PRs and the official `gh stack` extension. No other stacking tool.
- **Date:** 2026-10-14

### Q25: Who creates the GitHub repo?
- **Options:** the agent creates it / Ryan does
- **Decision:** Ryan creates and publishes the repo himself. Ryan also asked for the ISC license, now in `LICENSE` (canonical SPDX text, "Copyright 2026 Ryan Mullin").
- **Date:** 2026-10-14

### Q26: Trunk branch
- **Options:** make a `main` from `mega` / keep `mega`
- **Decision:** `mega` is the main branch; it's Ryan's name for his main branch. Stacks target `mega`, and there is no `main`.
- **Date:** 2026-10-14

### Q66: The gh-stack extension
- **Options:** install it / don't
- **Decision:** It's already installed (v0.2.0). The agent may install it if it's ever missing.
- **Date:** 2026-10-14

### Q67 / Q72: Merge method
- **Options:** squash / merge commits / rebase
- **Decision:** No squashing. Merge commits, via `gh stack merge --merge`.
- **Date:** 2026-10-14

### Q12: Where the session's output goes
- **Options:** rewrite PLAN.md + log decisions / something else
- **Decision:** Both: rewrite `docs/PLAN.md` into the final plan, and log every answer here.
- **Date:** 2026-10-14

### Q104: Repo visibility and CI cost
- **Options:** (a) private and pay / (b) private with a smaller matrix / (c) public before the loop starts
- **Decision:** (c). Public from the start, with an enormous, unmissable, busy, crazy DO NOT USE warning at the top of the README.
- **Date:** 2026-10-14

### README banner
- **Options:** text / image
- **Decision:** An image, not text. A throwaway HTML page was rendered and screenshotted to `docs/assets/do-not-use.png` (3200×1200), and then the page was deleted.
- **Date:** 2026-10-14

### Q130: Who removes the banner?
- **Options:** the loop / Ryan
- **Decision:** The loop never removes it. Ryan does, when he decides the project is ready.
- **Date:** 2026-10-14

### Q105: What Ryan sets up before running `/goal`
- **Options:** the proposed list / more
- **Decision:** The plan lists everything Ryan needs to do first: create the GitHub repo, push `mega` as the default branch, turn on Actions and Dependabot, run in auto mode, and anything else that's needed. No merge queue is required.
- **Date:** 2026-10-14

### Q40 / Q126: The spec PDF in the repo
- **Options:** (a) remove it before going public / (b) keep it with a GPL notice
- **Decision:** In Q40 it stayed while the repo was private. In Q126, (a): remove it before going public. The loop works from SPEC_CHECKLIST.md and SPEC_DECISIONS.md, and downloads the PDF from the recorded URL (checking its SHA-256) when it needs the original.
- **Date:** 2026-10-14

### Q132: The PDF in git history
- **Options:** (a) rewrite history so no commit has it / (b) delete it in a new commit
- **Decision:** (a). The rewrite (a backup branch, then `git filter-branch` across the 3 unpushed commits) was blocked by the auto-mode permission check in this session. Ryan must run it or approve it.
- **Date:** 2026-10-14

### Q129 / Q131: Dependencies
- **Options:** the proposed allow-list / something else
- **Decision:** Approved:
  - Dart `test` (dev) and `args`
  - toolchain downloads: Dart SDK, LLVM, llvm-mingw, musl
  - the SQLite amalgamation, plus prebuilt SQLite libraries for the Dart flavor
  - `dart-lang/setup-dart` and the standard `actions/*`
  - Anything else goes to `QUESTIONS.md`; a missing dependency isn't catastrophic. The playground uses Ryan's own stack (Q129).
- **Date:** 2026-10-14

## The /goal loop

### Q53: An interactive Phase 0?
- **Options:** grill spec ambiguities live before the loop / do all grilling in the planning session
- **Decision:** No interactive Phase 0. All grilling happens in the planning session, and the loop runs against the plan it produces.
- **Date:** 2026-10-14

### Q39: Temporary steps
- **Options:** n/a
- **Decision:** The pit corpus, the oracle, and the benchmarks are TEMPORARY and must be removed once the goal is met. Implementation runs in a `/goal` agent loop.
- **Date:** 2026-10-14

### Q55: The full list of temporary scaffolding
- **Options:** the proposed list / additions
- **Decision:**
  - Temporary: the ick 0.35 oracle image and differential tests, the `pit/` download script, the benchmark harness and baseline images (rick, INTERCAL-64, CLC), the CI performance-regression check, the performance targets in the docs, and `goal-status` (Q58). Originally removed at the end of goal 1; Q140 moved the removal to goal 2's cleanup.
  - Kept: the conformance suite, unit tests, the CI matrix, and the release pipeline.
- **Date:** 2026-10-14

### Goal 1: definition of done (the Q54 proposal, as amended)
- **Options:** n/a
- **Decision:**
  - Every checklist item is checked off with a linked test, in both flavors.
  - CI is green on every platform.
  - The release archives build with their bundled toolchains.
  - The performance guardrails are met.
  - Then the loop removes the temporary scaffolding as its last step, and stops.
  - WASM and the playground are not part of goal 1 (Q127).
- **Date:** 2026-10-14

### Q57 / Q70: Questions that come up mid-loop
- **Options:** (a) record the question, mark the item blocked, keep going / (b) stop at the first question
- **Decision:** (a). The question goes into `docs/QUESTIONS.md` and the item is marked blocked. The loop never guesses and keeps working. Exception: if the question is so catastrophic that continuing could mean undoing a lot of work, depending on the answer, the loop stops the goal. Otherwise the goal ends when everything passes, or when everything left is blocked.
- **Date:** 2026-10-14

### Q58: goal-status
- **Options:** one status command / no command
- **Decision:** One command (e.g. `lattice run goal-status`) prints:
  - checklist items done, open and blocked
  - conformance results per flavor
  - CI status
  - performance against the guardrails
  - whether temporary scaffolding is still present
  - It ends with `GOAL: MET` or a list of what's left. The goal prompt requires running it and showing its output. It's temporary and gets deleted last.
- **Date:** 2026-10-14

### Q59: What the loop may do on GitHub
- **Options:** (a) fully autonomous / (b) Ryan merges / (c) stop at each phase
- **Decision:** (a). The loop pushes branches, opens stacked PRs, gets each one reviewed by the code-reviewer sub-agent, and merges into `mega` once CI is green. Every PR starts with Ryan's AI-agent note.
- **Date:** 2026-10-14

### Q60: Turn and cost limits
- **Options:** none / a cap
- **Decision:** None.
- **Date:** 2026-10-14

## Performance

### Q10: What "extremely performant" measures
- **Options:** (a) runtime / (b) runtime + compile time / (c) both, with separate targets; (i) LLVM only / (ii) both backends
- **Decision:** (c) and (ii). Compiled-program runtime and compile time each get targets, for each backend. The targets are faster than the competition but within reason (Q32, Q33).
- **Date:** 2026-10-14

### Q30: Baselines
- **Options:** the proposed four / others
- **Decision:** C-INTERCAL 0.35 built from source and run with `-O`; rick in compiled mode; INTERCAL-64 built in the container with .NET 10; CLC-INTERCAL from apt. Each gets its own Docker image. Skipped: qpliu (its published number is cited), J-INTERCAL, CRINGE.
- **Date:** 2026-10-14

### Q31: Benchmark set
- **Options:** the proposed set / others
- **Decision:** From `pit/`: primes, pi, fft, tpk, unlambda, beer, life (glider input), and hail_mary.3i (ick only). Plus one or two programs we write that stress NEXT/RESUME and ABSTAIN.
- **Date:** 2026-10-14

### Q32: Runtime targets
- **Options:** the proposed targets / others
- **Decision:** Wall-clock time, geometric mean, compared with `ick -O` + gcc `-O2`.
  - LLVM: at least 1.5× faster than the fastest baseline on the geometric mean, and never slower than any baseline on any program.
  - Dart: at least as fast as `ick -O` on the geometric mean, and faster than every non-native baseline on every program.
- **Date:** 2026-10-14

### Q33: Compile-time targets
- **Options:** the proposed targets / others
- **Decision:**
  - Front end + code emission: 100 ms or less for every `pit/` program.
  - LLVM end to end: no slower than ick + gcc end to end.
  - Dart end to end: no more than 1.5× the time `dart compile exe` takes on an empty Dart program.
- **Date:** 2026-10-14

### Q34: Where benchmarks run
- **Options:** locally in Docker plus a loose CI check / strict CI gates
- **Decision:** A benchmark script run on demand, locally in Docker (Linux arm64). CI runs a loose regression check that fails on a slowdown of more than 2× against the last result. This is for the build-out only: these are guardrails, not permanent CI gates, and they're removed once everything is built.
- **Date:** 2026-10-14

### Q36: Differential oracle
- **Options:** use ick 0.35 as the oracle / no oracle
- **Decision:** C-INTERCAL 0.35, built from the official tarball in its own Docker image. A script runs the conformance programs through ick and both CIWAPA flavors and flags any differences. Each one is triaged as a bug or a recorded divergence. The tarball is downloaded only at implementation time.
- **Date:** 2026-10-14

## Licensing & clean room

### Q35: License
- **Options:** (a) GPL-2.0+ with a runtime exception / (b) MIT plus a separate GPL folder / (c) clean room + a permissive license
- **Decision:** Clean-room the syslib and use the ISC license. That also leaves room to optimize the library for performance.
- **Date:** 2026-10-14

### Q38: Clean-room rules
- **Options:** the proposed rules / looser rules
- **Decision:** Whoever writes the syslib may read only §7.2's descriptions. Never the §8.3 listing, ick's `syslib.i`, or rick's `syslib.rs`. Observable behavior must still match, including the E000 overflow output `DOUBLE OR SINGLE PRECISION OVERFLOW`.
- **Date:** 2026-10-14

### Q39: The pit/ corpus
- **Options:** downloaded at test time / committed
- **Decision:** Downloaded at test time from the C-INTERCAL 0.35 tarball, hash-checked, into a gitignored folder, and never committed. Our own conformance tests are ISC and live in the repo. Temporary.
- **Date:** 2026-10-14

### Q123: INTERCAL-64
- **Options:** syntax donor / compatibility target
- **Decision:** A syntax donor only (sigils and names). It isn't a compatibility target, and no code is taken (it has a joke license).
- **Date:** 2026-10-14

## Spec interpretation

### Q76: Can a 16-bit variable hold 65535?
- **Options:** (a) yes, "less than 65535" is a slip / (b) the literal reading: E275
- **Decision:** (a). §4.4.1 says "only if the value is less than 65535", but §3.1 (range 0–65535) and §4.4.12 both allow 65535.
- **Date:** 2026-10-14

### Q77: SELECT result type
- **Options:** (a) the C-INTERCAL rule (the right operand's type) / (b) the INTERCAL-72 rule (count of selected bits)
- **Decision:** (a), the right operand's static type (§3.4.1.1).
- **Date:** 2026-10-14

### Q78: Mingle operand over 16 bits
- **Options:** (a) E533 at run time, by value / (b) a compile-time type error / (c) truncate
- **Decision:** (a). Kept even though 0.15 silently truncates.
- **Date:** 2026-10-14

### Q79: Unary rotation width
- **Options:** the operand's type / other
- **Decision:** Width follows the operand's type: 16 bits for `.`, `,`, `#`; 32 bits for `:`, `;` and mingle results; select results follow Q77.
- **Date:** 2026-10-14

### Q80: When errors fire
- **Options:** (a) statement-local errors fire at execution, whole-program errors at compile time / (b) everything detectable fires at compile time
- **Decision:** (a).
  - At execution: a bad constant, a bad variable number, a malformed expression, a jump to a missing label. The statement compiles, and the error fires only when it runs.
  - At compile time: E182, E444, E555, E079/E099, E998.
  - Kept even though 0.15 reports some of the first group at compile time.
- **Date:** 2026-10-14

### Q81: Codes for cases the spec doesn't give a code for
- **Options:** the proposed mapping / other
- **Decision:** All of these fire when the statement executes:

  | Case | Code |
  |---|---|
  | Constant over #65535 | E017 |
  | Variable .0 or over 65535 | E200 |
  | Label 0 or over 65535 | E197 |
  | NEXT to a missing label | E129 |
  | ABSTAIN/REINSTATE on a missing label | E139 |
- **Date:** 2026-10-14

### Q82: Initial values
- **Options:** (a) everything starts at 0, E241 for an undimensioned array / (b) reading an unassigned variable gives E200
- **Decision:** (a).
- **Date:** 2026-10-14

### Q83 / Q90: Error message text
- **Options:** the official text / ick's jokes / our own jokes; (a) both on every error / (b) jokes fill the gaps / (c) jokes behind a flag
- **Decision:** Our own jokier messages AND the real ones, as Q90 (a):
  - Line 1 is the official text: the literal §4 text where it exists, otherwise the §9.2 description in uppercase.
  - Our joke goes on its own line under it.
  - ick's message strings are inspiration only, because of the clean room.
- **Date:** 2026-10-14

### Q84: Code for 16-bit WRITE IN overflow
- **Options:** E275 / something else
- **Decision:** E275, with the text `DON'T BYTE OFF MORE THAN YOU CAN CHEW.`
- **Date:** 2026-10-14

### Q85 / Q97: Ungrouped binary-operator chains
- **Options:** (a) strict per the spec / (b) follow ick's parser; then (a) the spec's words / (b) ick 0.15's parser
- **Decision:** Q85 chose (b). Then Q92 ("No, follow the paper") led to Q97 (b): follow ick 0.15's parser. 0.15 and the paper agree that the chain is invalid (E017). On timing, Q80 applies: the rejection follows 0.15, and E017 fires when the statement executes.
- **Date:** 2026-10-14

### Q91: Tie-breaker policy
- **Options:** follow ick for the remaining ambiguities / ask about each one
- **Decision:**
  - Where the spec is explicit, it wins (Q85 is a recorded exception).
  - Where it's silent, ambiguous or contradictory, ick's actual behavior decides, and each case is recorded.
  - Which ick version: Q92 and Q98.
- **Date:** 2026-10-14

### Q92: Should ick 0.35 decide?
- **Options:** yes / no
- **Decision:** No. Try to follow the paper.
- **Date:** 2026-10-14

### Q98: Which ick breaks ties?
- **Options:** ick 0.15 / ick 0.35
- **Decision:** ick 0.15, the compiler the paper documents, breaks ties. ick 0.35 stays the main differential oracle, and places where 0.15 and 0.35 differ are recorded as expected divergences. The spike tries to build 0.15 as a second oracle; if it won't build, the attempt is logged and dropped.
- **Date:** 2026-10-14

### T1: Grouping (approved in bulk with T2–T40)
- **Options:** spec silent ("ambiguous cases… the compiler… finds") / ick 0.15 / ick 0.35 (tracks groupers on a stack)
- **Decision:** Follow 0.15. A `'` or `"` right after a complete operand closes the group; anywhere else it opens one. Only the first subscript in a list can be a group.
- **Date:** 2026-10-14

### T2: Subscript lists
- **Options:** spec §4.4.1 example `'V−,1SUB#1#1¢#1'` / ick (can't parse it)
- **Decision:** The spec wins. A subscript list ends at the first binary operator, so `,1SUB#1#1¢#1` means `(,1 SUB #1 #1)¢#1`.
- **Date:** 2026-10-14

### T3: Wow and rabbit
- **Options:** spec §3.4.3 / ick
- **Decision:** `!` means `'.`. `".` gets no special handling; it's ears followed by a spot.
- **Date:** 2026-10-14

### T4: Unary operators
- **Options:** spec / 0.15 / 0.35 (also allows prefix forms)
- **Decision:**
  - Allowed after the type character, after an opening grouper, and on array names (where it applies to the element).
  - Chaining (`#V−&123`) is invalid, so the statement can't be decoded.
  - No prefix form.
- **Date:** 2026-10-14

### T5: Spaces
- **Options:** spec §4.1 / 0.15
- **Decision:**
  - Whitespace between tokens is ignored.
  - Multi-word keywords may be written with or without spaces (READOUT, GIVEUP).
  - Single words and `<-` can't be split.
  - `( 123 )` and `% 50` are fine.
  - Spaces inside a number join its digits: `#1 2` = `#12`.
- **Date:** 2026-10-14

### T6: Case
- **Options:** spec silent / 0.15 is uppercase only
- **Decision:** Uppercase only. Lowercase text can't be decoded.
- **Date:** 2026-10-14

### T7: Line endings
- **Options:** 0.15 chokes on CRLF / 0.35 strips CR
- **Decision:** Strip `\r`, as 0.35 does, because Windows is a target.
- **Date:** 2026-10-14

### T8: Where statements start
- **Options:** spec §4.5 (explicit) / ick
- **Decision:** DO, PLEASE and `(n)` are recognized anywhere, even in the middle of a word ("DOES"). A label that follows garbage starts the next statement.
- **Date:** 2026-10-14

### T9: Junk after a complete statement
- **Options:** 0.15 gives a compile-time E017 / 0.35 makes the statement undecodable
- **Decision:** The statement becomes undecodable and gives E000 when executed (0.35), consistent with Q80 and §4.5.
- **Date:** 2026-10-14

### T10: E000 text
- **Options:** spec "the message is the statement itself" / 0.15 (buggy) / 0.35
- **Decision:** The statement's source lines verbatim, continuation lines indented with a tab, cut off at about 500 characters (0.35's format).
- **Date:** 2026-10-14

### T11: DO PLEASE
- **Options:** §4.3 doesn't list it / §10.4 implies it / 0.15 accepts it / 0.35 rejects it
- **Decision:** Accepted, as in 0.15, and it counts as polite.
- **Date:** 2026-10-14

### T12: Qualifier order
- **Options:** spec §4.3 / ick
- **Decision:** NOT/N'T first, then `%n`. `DO %50 NOT` can't be decoded.
- **Date:** 2026-10-14

### T13: % range
- **Options:** spec "between 0 and 100" / ick allows 1–99
- **Decision:** The spec wins: `%0` never runs and `%100` always runs. Anything over 100 gives E017 when executed.
- **Date:** 2026-10-14

### T14: Character set
- **Options:** spec §3.4.1, §3.4.2, §10.1, §11 / 0.15 / 0.35
- **Decision:**
  - Mingle: `$`, UTF-8 `¢`, `c⌫/`.
  - XOR: `?`, `V⌫-`, `-⌫V`.
  - No `∀` or `¥`.
  - Any other TONSIL character makes the statement undecodable.
  - Source files are UTF-8.
- **Date:** 2026-10-14

### T15: `*` in source
- **Options:** spec (the listing's splat marker) / ick (an invalid character)
- **Decision:** A `*` in source is junk (see T9). The gotcha gets documented.
- **Date:** 2026-10-14

### T16: NEXT depth
- **Options:** spec "maximum depth of 79" / ick allows 80
- **Decision:** The spec wins: at most 79 levels, and the 80th push gives E123.
- **Date:** 2026-10-14

### T17: RESUME and FORGET
- **Options:** spec / ick
- **Decision:**
  - RESUME #0 gives E621. RESUME more levels than are stacked gives E632.
  - FORGET more levels than are stacked empties the stack silently. FORGET #0 does nothing.
  - 32-bit arguments are handled correctly; ick's wraparound bug isn't copied.
- **Date:** 2026-10-14

### T18: GIVE UP
- **Options:** spec "has the effect of a PLEASE RESUME #80" (a joke) / ick exits cleanly
- **Decision:** A clean exit with status 0.
- **Date:** 2026-10-14

### T19: COME FROM edge cases
- **Options:** spec §4.4.14.2 / 0.15
- **Decision:**
  - An abstained target still triggers the jump.
  - A target that errors, or a GIVE UP target, exits before any jump happens.
  - On a NEXT target, the jump fires when RESUME returns to it.
  - A COME FROM aimed at itself loops forever. Chains work.
  - E444 and E555 are compile-time errors, and E555 counts abstained COME FROMs too.
- **Date:** 2026-10-14

### T20: ABSTAIN and REINSTATE
- **Options:** spec §4.4.9–4.4.10 / 0.15
- **Decision:**
  - The flag is on or off, so repeating it changes nothing.
  - Labels and gerunds can't be mixed in one statement.
  - ABSTAIN FROM GIVING UP and REINSTATE GIVING UP can't be decoded.
  - REINSTATE of a GIVE UP by label does nothing. ABSTAIN of a GIVE UP by label works.
- **Date:** 2026-10-14

### T21: Gerunds
- **Options:** spec (partial list) / 0.15 / 0.35
- **Decision:**
  - The list: CALCULATING, NEXTING, FORGETTING, RESUMING, STASHING, RETRIEVING, IGNORING, REMEMBERING, ABSTAINING, REINSTATING, READING OUT, WRITING IN, COMING FROM.
  - CALCULATING includes array dimensioning, since §4.4.1 puts dimensioning under Calculate. 0.15 leaves it out.
  - ABSTAINING covers every ABSTAIN statement, including the one executing. 0.15 covers only the label forms.
- **Date:** 2026-10-14

### T22: % randomness
- **Options:** spec silent / 0.15
- **Decision:** The roll happens every time the statement is reached, before the abstain check. Seeded from the time by default, with a runtime seed option (`+seed`).
- **Date:** 2026-10-14

### T23: E774 random bug
- **Options:** spec "fixed probability" / 0.15 (1/128 per statement) / 0.35 (1/10 per program)
- **Decision:**
  - Follow 0.15: each statement has a 1-in-128 chance, decided at compile time.
  - A planted bug fires whenever its statement is reached, even if abstained.
  - `--no-random-bug` turns it off, and the conformance tests always do. The placement can be seeded with `--seed`.
- **Date:** 2026-10-14

### T24: IGNORE
- **Options:** spec §4.4.7 / 0.15
- **Decision:**
  - An out-of-range value assigned to an IGNOREd variable still gives E275, then is thrown away.
  - RETRIEVE pops the stash and throws the value away.
  - Element stores to an IGNOREd array are bounds-checked, then dropped. Redimensioning is blocked.
  - WRITE IN reads a number and discards it.
- **Date:** 2026-10-14

### T25: STASH
- **Options:** spec §4.4.5–4.4.6 / 0.15
- **Decision:**
  - No depth limit (E222 means out of memory).
  - RETRIEVE of an array restores its dimensions.
  - STASHing a single element is invalid.
  - RETRIEVE into an undimensioned array restores normally; ick's bug isn't copied.
- **Date:** 2026-10-14

### T26: Arrays
- **Options:** spec silent / 0.15
- **Decision:**
  - A wrong subscript count, a subscript of 0, a subscript past the end, or an undimensioned array gives E241.
  - A dimension of 0 gives E240.
  - Dimensions can be 32-bit.
- **Date:** 2026-10-14

### T27: Limits
- **Options:** 0.15 (1000 statements, 100 variables) / no caps
- **Decision:** No artificial caps. E333 and E666 fire only when memory actually runs out.
- **Date:** 2026-10-14

### T28: WRITE IN
- **Options:** spec §4.4.12 / 0.15
- **Decision:**
  - One number per line, written as space-separated uppercase words.
  - A blank line or end of file gives E562. An unknown word gives E579.
  - 0.15's bug of dropping the last letter isn't copied.
- **Date:** 2026-10-14

### T29: Number words
- **Options:** spec names the languages without giving the words / ick's lists
- **Decision:** Use ick's lists for every language. Volapük accepts both UTF-8 MÄL/JÖL/ZÜL and the `M\"AL` spelling. No Latin.
- **Date:** 2026-10-14

### T30: Roman numerals
- **Options:** spec §4.4.13 / ick `butcher()` (the same in both versions)
- **Decision:**
  - Two lines: a row of `_` for the overlines, then the numeral.
  - Zero is `_` over an empty line.
  - The algorithm is ick's.
  - `--clockface` gives IIII, and MMMM for 4000.
- **Date:** 2026-10-14

### T31: Turing Text
- **Options:** spec §5.2 / 0.15
- **Decision:**
  - End of file reads as 256, and the next value after it is the character + 1 (ick's quirk, kept).
  - Output uses the value mod 256.
  - Works on `,` and `;` arrays. An array whose rank isn't 1 gives E241.
  - Output is flushed at every newline and when the program exits.
- **Date:** 2026-10-14

### T32: Wimp mode
- **Options:** ick's message / our own
- **Decision:** Decimal I/O, with our own humiliating message sent to stderr.
- **Date:** 2026-10-14

### T33: Error format
- **Options:** spec §9.1 / ick
- **Decision:**
  - Output goes to stderr, in four lines: `ICLnnnI <official text>`, the joke line, `\tON THE WAY TO STATEMENT <n>`, then `        CORRECT SOURCE AND RESUBMIT` (the spec's spelling).
  - `<n>` is the ordinal number of the statement that would have run next, not zero-padded.
  - For E633 it's the last statement + 1. For compile-time errors it's the offending statement's number.
- **Date:** 2026-10-14

### T34: Exit status
- **Options:** spec silent / ick (code mod 256)
- **Decision:** The error code mod 256, keeping ick's quirks: E000 exits 0, and E436 exits 180.
- **Date:** 2026-10-14

### T35: Politeness
- **Options:** spec "fewer than 1/5th… more than 1/3rd" / ick's integer formula
- **Decision:**
  - The spec's exact fractions: E079 if fewer than 1/5 of statements say PLEASE, E099 if more than 1/3.
  - Count the statements whose identifier includes PLEASE.
  - Comments and garbage count as statements. The syslib doesn't count.
  - The check only runs on programs with more than 2 statements.
  - The spec's §5.3 cat program fails the check. It becomes a known-failing case, with a polite variant added as a test.
- **Date:** 2026-10-14

### T36: Syslib auto-inclusion
- **Options:** spec §7.3 / ick
- **Decision:** A NEXT to a label in 1000–1999 includes the syslib, but only when the program defines no label in that range.
- **Date:** 2026-10-14

### T37: Running off the end
- **Options:** ick falls into the library / always E633
- **Decision:** Always E633. Execution never falls into the library.
- **Date:** 2026-10-14

### T38: Runtime options
- **Options:** spec §10.3 / 0.15
- **Decision:** `+help`/`-help` prints usage and exits with E778 (without 0.15's 3-second sleep). `+traditional` does nothing.
- **Date:** 2026-10-14

### T39: Traditional mode
- **Options:** spec §10.2 / ick
- **Decision:** Rejects COME FROM and non-binary bases with E111.
- **Date:** 2026-10-14

### T40: TriINTERCAL
- **Options:** spec §6 / 0.15
- **Decision:**
  - The extensions `.3i`–`.7i` pick the base; any other extension gives E998.
  - Constant limits per base: 59048 / 65535 / 15624 / 46655 / 16806. Out-of-range values give E017, E275 or E533.
  - Operators work digit by digit as in 0.15. `^` and `@` give E997 where they're unsupported.
  - I/O uses decimal words and Roman numerals in every base.
- **Date:** 2026-10-14

## EXTRACAL

### Q41: What is EXTRACAL?
- **Options:** (a) an ick-compatible superset / (b) CIWAPA's own practical INTERCAL / (c) both
- **Decision:** (c). An ick-compatibility layer plus CIWAPA's own standard library and I/O.
- **Date:** 2026-10-14

### Q42: A strict superset of Mode 1?
- **Options:** yes / no
- **Decision:** Yes. Every valid Mode 1 program behaves byte for byte the same.
- **Date:** 2026-10-14

### Q43 / Q56: How a program selects EXTRACAL
- **Options:** (a) a CLI flag / (b) a file extension / (c) a marker in the source
- **Decision:** (b). The extension `.xc`, and `.3xc`–`.7xc` for the other bases.
- **Date:** 2026-10-14

### Q44: Which ick extensions
- **Options:** a list of 14
- **Decision:**
  - As suggested: NEXT FROM, computed COME FROM/NEXT FROM, computed ABSTAIN, ONCE/AGAIN, TRY AGAIN, threading, backtracking, operand overloading, CREATE, CLC-style binary I/O, Latin keywords. All with ick 0.35 semantics.
  - Deferred: external C calls.
  - Dropped: PIC-INTERCAL.
  - 64-bit types: see Q107.
- **Date:** 2026-10-14

### Q46: Its own document?
- **Options:** yes / no
- **Decision:** Yes, `docs/EXTRACAL_PLAN.md`, linked from PLAN.md. Mode 1 never depends on it.
- **Date:** 2026-10-14

### Q74: How the standard library is exposed
- **Options:** (a) reserved label ranges called with NEXT / (b) new statements
- **Decision:** (a). Arguments and results go in variables. A few new statements are added only for I/O that can't be done that way.
- **Date:** 2026-10-14

### Q75: What the standard library contains
- **Options:** 15 items
- **Decision:** All of them:
  - plain decimal/ASCII I/O, raw bytes on stdin/stdout, stderr
  - files, args, env, exit codes
  - clock/time, RNG seeding
  - sockets/HTTP
  - 64-bit/signed numbers, floats
  - strings, array utilities, math
- **Date:** 2026-10-14

### Q89: Where sockets/HTTP live
- **Options:** (a) in EXTRACAL / (b) in Interstates' runtime
- **Decision:** (a). Interstates builds `gross` on top of it.
- **Date:** 2026-10-14

### Q106: Library label blocks
- **Options:** the proposed blocks / other
- **Decision:**
  - Blocks such as (2000) for I/O, (3000) for strings and (4000) for math, avoiding ick's ranges.
  - Each block is auto-included like the syslib and gets native fast paths.
  - The agent picks the exact numbers and documents them.
- **Date:** 2026-10-14

### Q107: 64-bit numbers
- **Options:** (a) library routines on pairs of 32-bit values / (b) new 64-bit types with new sigils
- **Decision:** (b). EXTRACAL is a superset, not a library.
- **Date:** 2026-10-14

### Q122: Mingle widening
- **Options:** (a) INTERCAL-64's rules exactly / (b) by value / (c) by type
- **Decision:** (b).
  - When both operands are 65535 or less, the result is 32-bit, as in Mode 1.
  - Otherwise it widens to 64-bit, where Mode 1 would raise E533.
  - 64$64 gives an ephemeral 128-bit value that only select can use.
- **Date:** 2026-10-14

### Q123: The 64-bit syntax
- **Options:** INTERCAL-64's sigils / our own
- **Decision:** `::` (double cateye, 64-bit scalar), `;;` (64-bit array), `##` (fence, 32-bit constant), `####` (stockade, 64-bit constant). Borrowed as syntax only.
- **Date:** 2026-10-14

### Q124: Signed numbers
- **Options:** (a) new signed types / (b) existing types read as two's complement, plus signed I/O
- **Decision:** (b). Two's complement on the existing types, plus signed WRITE IN/READ OUT forms (e.g. `READ OUT SIGNED .1`).
- **Date:** 2026-10-14

### Q125: Roman numerals above 2^32
- **Options:** extra overline rows / other
- **Decision:** Extra overline rows repeat the four tiers, each row multiplying by 10^12. WRITE IN accepts up to 20 digits.
- **Date:** 2026-10-14

### Q108: How strings are stored
- **Options:** (a) Unicode code points / (b) UTF-8 bytes
- **Decision:** (a). Tail arrays of Unicode code points, shared with Interstates.
- **Date:** 2026-10-14

### Q109: Floating point
- **Options:** (a) IEEE 754 single / (b) the §8.4 layout
- **Decision:** (b). The upper 16 bits hold the mantissa and the lower 16 bits the characteristic.
- **Date:** 2026-10-14

### Q110: Sockets scope
- **Options:** the proposed scope / more
- **Decision:** TCP client and server, a minimal HTTP/1.1 client, and request/response helpers. No TLS in v1.
- **Date:** 2026-10-14

### Q111: Goal 2's definition of done
- **Options:** the proposal / other
- **Decision:** Every feature in EXTRACAL_PLAN.md is tested in both flavors, CI is green, and Mode 1's conformance and performance don't regress. EXTRACAL has no performance targets of its own.
- **Date:** 2026-10-14

## INTERCAL on Interstates

### Q86: Is the site the spec?
- **Options:** (a) the site is the spec / (b) inspired by it
- **Decision:** (b). Inspired by the site, with a few things hardcoded from it just for the punchline.
- **Date:** 2026-10-14

### Q87: How it relates to CIWAPA
- **Options:** (a) a mode inside ciwapa / (b) its own front end / (c) a pure library
- **Decision:** (b).
  - Its own front end in `apps/interstates`, reusing `ciwapa_core`.
  - It adds WITH ROUTE, WITH TEMPLATE, FROM DATABASE and HAVING, and lowers to the shared IR.
  - It has its own CLI, `gross`, and ActiveCassette. CIWAPA itself is untouched.
- **Date:** 2026-10-14

### Q88: Built on EXTRACAL?
- **Options:** yes / no
- **Decision:** Yes. Networking lives in EXTRACAL (Q89).
- **Date:** 2026-10-14

### Q93: Punchlines kept
- **Options:** a list of 9
- **Decision:** Items 1–7:
  1. `gross` (General READ OUT Server System) on port 10585
  2. the `-s` ('States) flag
  3. the ActiveCassette name
  4. `{{ }}` double grumpies
  5. `;4400` and `;49221`, with `,144` counting downward in templates
  6. `(16000)` as the entry label
  7. the site's hello world runs exactly as written
  - Not kept: running the rest of the examples verbatim, and the "under 3MB" claim.
- **Date:** 2026-10-14

### Q94: How gross runs programs
- **Options:** (a) CGI-style / (b) persistent
- **Decision:** (a). Every request runs the program fresh. The request comes in through env and stdin, the response is stdout, and GIVE UP ends the response.
- **Date:** 2026-10-14

### Q95 / Q99: The database
- **Options:** SQLite only / user-swappable
- **Decision:** Users can swap in their own database. ActiveCassette has an adapter interface, and the adapter is picked at run time from a URL (`gross --database sqlite:./app.db` or `DATABASE_URL`). SQLite is the only built-in adapter in v1.
- **Date:** 2026-10-14

### Q96: Both flavors?
- **Options:** yes / one flavor
- **Decision:** Yes, both, under the parity rule.
- **Date:** 2026-10-14

### Q112: CLIs
- **Options:** (a) its own CLIs / (b) `ciwapa -s` hands off to Interstates
- **Decision:** (a). `ioi-dart` and `ioi-llvm`, where `-s` turns on the Interstates syntax. Source files are `.xc`.
- **Date:** 2026-10-14

### Q113: What WITH ROUTE means
- **Options:** the proposal / other
- **Decision:**
  - `(16000)` is the public entry point.
  - A route on any other label L is reachable only from the page rendered at L.
  - Compile-time check: L must be a READ OUT WITH TEMPLATE, and its template must link to the route.
  - Run-time check: the Referer must match, otherwise 403.
- **Date:** 2026-10-14

### Q114: Route matching
- **Options:** the proposal / other
- **Decision:**
  - Many WITH ROUTE COME FROMs can target (16000); they're exempt from E555.
  - A bare `COME FROM (16000)` is the catch-all.
  - The more specific route wins: static segments beat `:param` segments.
  - A genuine tie is a compile error.
  - No match gives an ICL-style 404.
- **Date:** 2026-10-14

### Q115: Request and response
- **Options:** the proposal / other
- **Decision:**
  - `;4400` holds the route parameters.
  - Library routines at (16001)+ cover method, query, headers, cookies, status, response headers and redirects.
  - WRITE IN reads the request body, and GIVE UP ends the response.
  - No sessions or auth in v1.
- **Date:** 2026-10-14

### Q116: Arrays of strings
- **Options:** the proposal / other
- **Decision:**
  - `;4400` and `;49221` get an array-of-strings type.
  - `,1 <- ;4400 SUB #1` copies a string and resizes `,1`. `;49221 SUB #2 <- ,5` stores one.
  - `"..."` literals are allowed only after WITH ROUTE and WITH TEMPLATE.
- **Date:** 2026-10-14

### Q117: Templates
- **Options:** the proposal / other
- **Decision:**
  - Templates are embedded at compile time.
  - `READ OUT #n` checks the argument count. Arguments appear as `,144` counting downward.
  - `{{ expr }}` takes any INTERCAL expression.
  - Strings are HTML-escaped by default; `{{{ }}}` prints raw.
  - Numbers print as butchered Roman numerals with CSS overlines.
- **Date:** 2026-10-14

### Q118: Loops in templates?
- **Options:** (a) none / (b) a minimal repeat block
- **Decision:** (a). No loops or conditionals.
- **Date:** 2026-10-14

### Q119: ActiveCassette
- **Options:** the proposal / other
- **Decision:**
  - Tables and columns are numbered in schema order.
  - Reads use `'FROM DATABASE #t~#c$…' HAVING #col value`, with bound parameters.
  - Writes use INTO DATABASE.
  - A routine runs raw parameterized SQL.
  - Full CRUD.
- **Date:** 2026-10-14

### Q120: The gross CLI
- **Options:** the proposal / other
- **Decision:** `gross [--port 10585] [--bind 127.0.0.1] [--static <dir>] [--database <url>] ./hello`. Static files are served only with `--static`. Logs go to stderr. Binds to localhost by default.
- **Date:** 2026-10-14

### Q121: Shipping, and goal 3's definition of done
- **Options:** the proposal / other
- **Decision:**
  - Release archives `ioi-<flavor>-<os>-<arch>`, each bundling the matching CIWAPA toolchain and `gross`.
  - Done means: the site's hello world runs, a sample blog app (routes, templates, ActiveCassette) works end to end, both flavors pass, and CI is green.
- **Date:** 2026-10-14

## Playground

### Q23: A WASM online version
- **Options:** (a) static site with a Wasm backend / (b) a compile server
- **Decision:** (a).
  - The CIWAPA front end is compiled with dart2wasm, and a third backend emits Wasm directly.
  - It's a deliberate exception to "no bytecode".
  - It comes only after the product works and passes its performance targets.
- **Date:** 2026-10-14

### Q127: Where the playground goes
- **Options:** inside goal 1 / later
- **Decision:** Its own fourth goal, planned later.
- **Date:** 2026-10-14

### Q128: Playground look
- **Options:** (a) retro line printer / (b) clean and modern / (c) deliberately hostile UX
- **Decision:** (c). Deliberately hostile UX, in the INTERCAL spirit.
- **Date:** 2026-10-14

### Q129: Playground stack
- **Options:** vanilla / Ryan's stack
- **Decision:** Ryan's existing stack and UI rules:
  - `~/Source/latticeandcompany.github.io`: Astro 7, React 19, Tailwind 4, Bootstrap 5 + Bootstrap Icons, Sass
  - `~/Source/arenaswap/apps/docs`
  - the UI rules in their CLAUDE.md/AGENTS.md
- **Date:** 2026-10-14

## Final review (decisions made while writing the plans)

### Q133: C-INTERCAL pipeline-only error codes
- **Options:** keep / exclude / remap
- **Decision:**
  - E127 (can't find syslib.i) and E999 (can't open the C skeleton) are excluded: the library is embedded and there is no skeleton file.
  - E888 is kept but means "can't write the output executable or temp files".
- **Date:** 2026-10-14

### Q134: One message for E275
- **Options:** BYTE OFF for WRITE IN only, §9.2 description for assignment / BYTE OFF for every trigger
- **Decision:** One code, one message. Every E275 prints `DON'T BYTE OFF MORE THAN YOU CAN CHEW.`, matching `ick`.
- **Date:** 2026-10-14

### Q135: EXTRACAL label block numbers
- **Options:** as chosen in the EXTRACAL plan's R10 table / other
- **Decision:** As written in R10. The blocks avoid (1000)–(1999), ick's floatlib (5000)–(5699), and Interstates' (16000)+.
- **Date:** 2026-10-14

### Q136: Characters above U+FFFF
- **Options:** (a) UTF-16 surrogate pairs in `,` tail arrays / (b) `;` hybrid arrays, one code point per element
- **Decision:** (a). Strings stay tail arrays, and characters above U+FFFF take two elements.
- **Date:** 2026-10-14

### Q137: Float layout details
- **Options:** both halves 16-bit two's complement, value = mantissa × 2^characteristic / other
- **Decision:** Both halves are 16-bit two's complement, and value = mantissa × 2^characteristic.
- **Date:** 2026-10-14

### Q138: Negative Roman numerals
- **Options:** `-` + numeral of the magnitude / other
- **Decision:** `READ OUT SIGNED` of a negative value prints `-` followed by the numeral of its magnitude.
- **Date:** 2026-10-14

### Q139: Library failure reporting
- **Options:** status flag for recoverable errors + ICL errors for programming errors / always ICL errors
- **Decision:**
  - Recoverable failures (missing file, refused connection) set a status variable.
  - Programming errors (bad handle) raise an ICL error.
- **Date:** 2026-10-14

### Q140: Benchmark tools and oracle between goals 1 and 2
- **Options:** goal 1 deletes them and goal 2 restores them from history / goal 1 keeps them
- **Decision:** Goal 1 deletes **no** temporary scaffolding.
  - Everything carries over to goal 2: the ick oracle images and differential tests, the pit download, tools/bench and the baseline images, the CI perf-regression check, the perf-target doc section, tools/goal and goal-status, and every Docker image the loop built.
  - Goal 2's cleanup removes goal 1's and goal 2's temporary scaffolding together.
  - This supersedes the goal-1 cleanup step from Q54/Q55.
- **Date:** 2026-10-14

### Q141: Interstates hello-world tolerances under `-s`
- **Options:** two narrow allowances / none
- **Decision:** These apply under `-s` only:
  - Text before the first statement identifier is a comment.
  - A bare `GIVE UP` is read as `DO GIVE UP`.

  Nothing else from the site's examples is accepted.
- **Date:** 2026-10-14

### Q142: `WITH ROUTE` COME FROMs
- **Options:** request entry points only / normal trap doors as well
- **Decision:** They are request entry points only and never fire as jumps.
- **Date:** 2026-10-14

### Q143: `gross` implementation language
- **Options:** Dart on EXTRACAL's runtime networking layer / EXTRACAL, with a new process-spawn routine
- **Decision:** Dart.
- **Date:** 2026-10-14

### Q144: `gross --timeout`
- **Options:** add it / no timeout
- **Decision:** Add `--timeout` (default 30 s). A request that runs too long gets a 504 with an ICL-style page.
- **Date:** 2026-10-14

### Q145: ActiveCassette write syntax
- **Options:** as written in the Interstates plan / other
- **Decision:**
  - Insert: `DO INTO DATABASE #t~#c$#c <- …`
  - Update: the same form plus `HAVING`
  - Delete: `DO FORGET DATABASE #t HAVING …`
  - **Plus Ryan's addition:** `PLEASE DO AMNESIA` drops the database, meaning every table in the configured database, through the adapter interface.
- **Date:** 2026-10-14

### Q146: Database adapter mechanism
- **Options:** shared libraries implementing one C interface / other
- **Decision:** One C interface, loaded as a shared library. The Dart flavor uses FFI, and the LLVM flavor calls it natively.
- **Date:** 2026-10-14

### Q147: Politeness in Interstates
- **Options:** applies / doesn't apply
- **Decision:** "Absolutely." It applies, inherited through EXTRACAL from Mode 1. PLEASE is mandatory on the web too.
- **Date:** 2026-10-14

## Loop questions

Answered from `QUESTIONS.md`. Ryan accepted the recommendation on each.

### L1: May GitHub Actions open pull requests in this repo?
- **Options:** Ryan enables it at the org level and then on the repo / a GitHub App or fine-grained token as a secret / open an issue instead of a PR
- **Decision:** Ryan enabled it at the `latticeandcompany` org level and then on CIWAPA. The repo API now reports `can_approve_pull_request_reviews: true`, so the toolchain-bump workflow can open its PR with `GITHUB_TOKEN`.
- **Date:** 2026-10-15

### L2: When a COME FROM's own statement-local errors fire
- **Options:** when control reaches it / only when its jump is considered / never
- **Decision:** Only when its jump is considered: after the target runs, if the COME FROM isn't abstained, its E197 or E017 fires instead of the jump. Falling into the COME FROM does nothing (§4.4.14.2). Matches the loop's interim code.
- **Date:** 2026-10-15

### L3: E000 versus a label or `%` error on an undecodable statement
- **Options:** source order / E000 always wins
- **Decision:** Source order: invalid label, then invalid `%`, then E000. Matches the loop's interim code.
- **Date:** 2026-10-15

### L4: A binary-operator chain inside a group
- **Options:** E017 everywhere / E017 at top level and undecodable inside a group, as 0.15
- **Decision:** As 0.15's parser (Q97): E017 for a top-level chain; a chain inside a group makes the statement undecodable (E000 when it executes). **Code change needed:** the loop's interim code gives E017 inside groups. Drop the L4 divergence.
- **Date:** 2026-10-15

### L5: Allocation limits below 2^61 elements
- **Options:** machine-dependent below 2^61 / shared artificial cap / probe physical memory
- **Decision:** Keep it machine-dependent below 2^61. Past 2^61, both runtimes raise E241 (and E222 for stashes) deterministically. No artificial cap (T27). Matches the loop's interim code.
- **Date:** 2026-10-15

### L6: CRLF in WRITE IN input
- **Options:** keep 0.15's behavior / strip one `\r` before each `\n`
- **Decision:** Strip one `\r` before each `\n` in WRITE IN, for Windows consoles. Recorded as a divergence next to T7/T28. **Code change needed** in both runtimes.
- **Date:** 2026-10-15

### L7: Proving E222, E333 and E666
- **Options:** catch OOM + review / catch OOM + test-only memory limit / drop the codes
- **Decision:** The compiler catches out-of-memory and reports E666 while parsing and E333 while laying out variables. The runtimes keep E222. A test-only environment variable (for example `CIWAPA_TEST_MEMORY_LIMIT`), documented as test-only and never set in normal runs, lets tests force each error. The no-limit tests stay. **Code change needed.**
- **Date:** 2026-10-15

### L8: Program arguments that aren't valid UTF-8
- **Options:** accept as a known flavor difference / make ciwapa-llvm refuse them too
- **Decision:** Accept it as a known difference between the flavors, recorded under Divergences. Only arguments that aren't text trigger it.
- **Date:** 2026-10-15

### L9: The system library in bases 3–7
- **Options:** base 2 only / include anyway as 0.15 / clean-room libraries per base
- **Decision:** Include the binary library only in base 2. In bases 3–7, a NEXT to 1000–1999 raises E129 when it executes, like any missing label. Per-base libraries are a possible future goal. Matches the loop's interim code.
- **Date:** 2026-10-15

### L10: Benchmarks that call ick's internal library labels
- **Options:** append ick's syslib.i at benchmark time / replace with clean-room programs / drop the four
- **Decision:** Benchmark `primes`, `pi`, `fft` and `life` with C-INTERCAL 0.35's own `syslib.i` appended, identically for every compiler. A script extracts it from the hash-checked tarball at benchmark time only, inside the temporary `tools/bench/` scaffolding. It is never committed, and no agent opens or reads the extracted file. Q38's clean-room rule covers reading the listing while writing our library; running it as a black box in a benchmark doesn't cross it. CIWAPA's native fast paths don't apply to these runs. **Code change needed:** unblock the four programs' guardrails and the geometric means.
- **Date:** 2026-10-15

### L11: `fft` and C-INTERCAL's `floatlib.i`
- **Options:** append floatlib.i the same way as L10 / drop fft / clean-room replacement
- **Decision:** Append C-INTERCAL 0.35's `floatlib.i` to `fft` under exactly L10's rules: extracted from the hash-checked tarball at benchmark time inside the temporary `tools/bench/` scaffolding, never committed, never opened or read by any agent, identical for every compiler. **Code change needed:** unblock `fft`'s guardrails and the geometric means.
- **Date:** 2026-10-16

### L12: Out of memory while generating code
- **Options:** E666 / E333 / E778
- **Decision:** E666 ("too many source lines"). With L7 that makes three stages: E666 while parsing, E333 while laying out variables, and E666 while building the generated `.dart` or `.ll` text. Matches the loop's interim code.
- **Date:** 2026-10-16

### L13: Non-native baselines that run a benchmark wrong
- **Options:** count as met / compare their times anyway / fix how they're run, else drop them from that program
- **Decision:** First make INTERCAL-64 and CLC-INTERCAL run `tpk`, `primes`, `pi` and `life` correctly, by investigating input files, command-line flags and each baseline's own system library. Only configuration and harness changes are allowed, never patches to the baselines' source. If a program still can't run correctly on a baseline, remove that baseline from that program in `programs.txt` with the reason recorded next to it. The guardrail then compares only against baselines that produce the correct output. Wrong-output runs are never timed. **Code change needed:** the investigation, plus `programs.txt` and the bench's handling.
- **Date:** 2026-10-16

## EXTRACAL error codes

New error conditions in EXTRACAL get codes of their own that neither C-INTERCAL 0.15 nor 0.35 uses (R11, Q90). Each has official text written for CIWAPA and a joke line, like every other code. Conditions that are the same as Mode 1's keep Mode 1's code: a constant above its sigil's range is E017, 32 bits into a 16-bit variable is E275 (R4), and WRITE IN of more than 32 bits into a 16- or 32-bit variable is E533.

### E276: a value over 32 bits stored in a 16- or 32-bit variable
- **Text:** `A VALUE REQUIRING OVER 32 BITS HAS BEEN ASSIGNED TO A VARIABLE OF 32 BITS OR FEWER.`
- **Joke:** `THE BIG NUMBER WAS ASKED TO SQUEEZE IN. IT DECLINED.`
- **Source:** R4 ("narrowing overflow involving 64-bit values"). Fires when the statement executes, before the store, even into an IGNOREd variable (as T24 does for E275).
- **Tests:** `packages/conformance/tests/extracal/wide/narrowing-32.xc`, `packages/conformance/tests/extracal/wide/narrowing-16.xc`
- **Date:** 2026-10-18

### E535: WRITE IN of a value over 64 bits into a 64-bit variable
- **Text:** `A WRITE IN STATEMENT HAS PRODUCED A VALUE REQUIRING OVER 64 BITS TO REPRESENT.`
- **Joke:** `SIXTY-FOUR BITS WAS SUPPOSED TO BE ENOUGH FOR ANYBODY. YOU ARE NOT ANYBODY.`
- **Source:** R7 ("A value over 2^64−1 is an error").
- **Tests:** `packages/conformance/tests/extracal/numerals/write-in-over.xc`
- **Date:** 2026-10-18

### E534: an ephemeral 128-bit value used for something other than a select
- **Text:** `AN EPHEMERAL 128-BIT VALUE HAS BEEN USED FOR SOMETHING OTHER THAN A SELECT.`
- **Joke:** `IT WAS ONLY EVER MEANT TO BE A PHASE.`
- **Source:** R5. A mingle of operands over 32 bits makes a 128-bit value that only a select may consume. Storing it, printing it, using it as a subscript or count, giving it to a unary operator or mingling it again is E534 when the statement executes. A select whose result doesn't fit in 64 bits is another such value (L16's lean).
- **Tests:** `packages/conformance/tests/extracal/mingle/ephemeral-store.xc`, `packages/conformance/tests/extracal/mingle/ephemeral-unary.xc`, `packages/conformance/tests/extracal/mingle/ephemeral-mingle.xc`, `packages/conformance/tests/extracal/mingle/ephemeral-subscript.xc`, `packages/conformance/tests/extracal/mingle/ephemeral-count.xc`, `packages/conformance/tests/extracal/mingle/select-over-64.xc`
- **Date:** 2026-10-18

### E536: WRITE IN SIGNED of a value outside the variable's signed range
- **Text:** `A WRITE IN SIGNED STATEMENT HAS PRODUCED A VALUE OUTSIDE ITS VARIABLE'S SIGNED RANGE.`
- **Joke:** `THE NUMBER WAS TOO NEGATIVE, OR TOO POSITIVE, OR POSSIBLY BOTH.`
- **Source:** R6. The ranges are −2^(n−1) to 2^(n−1)−1 for an n-bit variable. Wimp mode reads the number as C's atol does (T32), then checks the same range.
- **Tests:** `packages/conformance/tests/extracal/signed/out-of-range.xc`, `packages/conformance/tests/extracal/signed/out-of-range-negative.xc`
- **Date:** 2026-10-18

### E404: no choicepoint
- **Text:** `THERE IS NO CHOICEPOINT TO GO BACK OR AHEAD TO.`
- **Joke:** `THE ROAD NOT TAKEN WAS NEVER BUILT.`
- **Source:** R3 item 7, with `ick` 0.35 semantics. This is `ick`'s own code for `ick`'s own condition, so it keeps the number; the text is CIWAPA's. GO BACK or GO AHEAD with no choicepoint left raises it, reported at the statement after.
- **Tests:** `packages/conformance/tests/extracal/backtracking/e404.xc`, `packages/conformance/tests/extracal/backtracking/go-ahead.xc`
- **Date:** 2026-10-18

### E801: a PETITION to an unknown service
- **Text:** `A PETITION HAS BEEN MADE TO A SERVICE THAT DOES NOT EXIST.`
- **Joke:** `THE OPERATING SYSTEM HAS NO RECORD OF THIS DEPARTMENT.`
- **Source:** R10, R11 and L29. A new condition, so a new code that neither `ick` 0.15 nor 0.35 uses. `PETITION #n` with a number that names no host service is a fault of its statement, raised when it executes.
- **Tests:** `packages/conformance/tests/extracal/lib-system/e801.xc`
- **Date:** 2026-10-18

### E802: an exit status out of range
- **Text:** `AN EXIT STATUS OUTSIDE 0 TO 255 HAS BEEN REQUESTED.`
- **Joke:** `THE PROGRAM TRIED TO LEAVE WITH MORE THAN IT CAME WITH.`
- **Source:** R10, R11. A new code. The System block's exit routine (8030) takes a status from 0 to 255, the range every platform keeps; anything larger is a programming error (Q139).
- **Tests:** `packages/conformance/tests/extracal/lib-system/e802.xc`, `packages/conformance/tests/extracal/lib-system/e802-no-opt.xc`
- **Date:** 2026-10-18

### E803: a string array with more than one dimension
- **Text:** `A STRING HAS BEEN GIVEN AS AN ARRAY OF MORE THAN ONE DIMENSION.`
- **Joke:** `WORDS COME IN LINES, NOT IN BLOCKS.`
- **Source:** R8, R10, R11. A new code. A library routine that takes a string needs a tail array with one dimension, or none for the empty string (L30); more is a programming error (Q139).
- **Tests:** `packages/conformance/tests/extracal/lib-system/e803.xc`, `packages/conformance/tests/extracal/lib-system/e803-no-opt.xc`
- **Date:** 2026-10-18

### E804: a handle not open that way
- **Text:** `A FILE HANDLE THAT IS NOT OPEN THAT WAY HAS BEEN USED.`
- **Joke:** `YOU CANNOT READ FROM A LETTERBOX OR POST INTO A NEWSPAPER.`
- **Source:** R10, R11, Q139. A new code. Reading from a handle that isn't open for reading, writing to one that isn't open for writing, or closing one that isn't an open file, is a programming error.
- **Tests:** `packages/conformance/tests/extracal/lib-io/e804.xc`, `packages/conformance/tests/extracal/lib-io/e804-no-opt.xc`
- **Date:** 2026-10-18

### E805: a byte above 255
- **Text:** `A BYTE ABOVE 255 HAS BEEN WRITTEN.`
- **Joke:** `IT DID NOT FIT THROUGH THE SLOT.`
- **Source:** R10, R11, Q139. A new code. The I/O block writes bytes; a larger value, such as a string element that hasn't been through UTF-8 encoding, is a programming error.
- **Tests:** `packages/conformance/tests/extracal/lib-io/e805.xc`, `packages/conformance/tests/extracal/lib-io/e805-no-opt.xc`
- **Date:** 2026-10-18

### E806: an open mode that doesn't exist
- **Text:** `A FILE HAS BEEN OPENED IN A MODE THAT DOES NOT EXIST.`
- **Joke:** `NEITHER READING, WRITING NOR APPENDING. PERHAPS JUST LOOKING.`
- **Source:** R10, R11, Q139. A new code. OPEN (2020) takes mode #1, #2 or #3.
- **Tests:** `packages/conformance/tests/extracal/lib-io/e806.xc`, `packages/conformance/tests/extracal/lib-io/e806-no-opt.xc`
- **Date:** 2026-10-18

### E807: a slice outside its string
- **Text:** `A SLICE HAS BEEN TAKEN FROM OUTSIDE A STRING.`
- **Joke:** `YOU CANNOT CUT A PIECE FROM THE END OF NOTHING.`
- **Source:** R8, R10, R11, Q139. A new code. SLICE (3020) takes a start from #1 to one past the end and a count that stays within the string; anything else is a programming error.
- **Tests:** `packages/conformance/tests/extracal/lib-strings/e807.xc`, `packages/conformance/tests/extracal/lib-strings/e807-no-opt.xc`
- **Date:** 2026-10-18

### E808: decoding a non-byte as UTF-8
- **Text:** `AN ELEMENT ABOVE 255 HAS BEEN DECODED AS A BYTE.`
- **Joke:** `THAT WAS NOT UTF-8. THAT WAS NOT EVEN A BYTE.`
- **Source:** R8, R10, R11, Q139. A new code. UTF-8 DECODE (3080) reads bytes; an element above 255, when the decoder reaches it, is a programming error.
- **Tests:** `packages/conformance/tests/extracal/lib-strings/e808.xc`, `packages/conformance/tests/extracal/lib-strings/e808-no-opt.xc`
- **Date:** 2026-10-18

### E809: a list with more than one dimension
- **Text:** `A LIST HAS BEEN GIVEN AS AN ARRAY OF MORE THAN ONE DIMENSION.`
- **Joke:** `A SHOPPING LIST DOES NOT HAVE COLUMNS.`
- **Source:** R10, R11, Q139. A new code, the Arrays block's version of E803. FILL, COPY, SORT and FIND (6020)–(6050) and (6120)–(6150) work on lists: arrays with one dimension, or none for the empty list. Anything else is a programming error. 810 and 811 are `ick`'s own (its debugger), so the block's codes skip them.
- **Tests:** `packages/conformance/tests/extracal/lib-arrays/e809.xc`, `packages/conformance/tests/extracal/lib-arrays/e809-no-opt.xc`, `packages/conformance/tests/extracal/lib-arrays/e809-hybrid.xc`, `packages/conformance/tests/extracal/lib-arrays/e809-hybrid-no-opt.xc`
- **Date:** 2026-10-18

### E812: asking about a dimension the array doesn't have
- **Text:** `A DIMENSION THAT THE ARRAY DOES NOT HAVE HAS BEEN ASKED ABOUT.`
- **Joke:** `THE FOURTH DIMENSION IS NOT AVAILABLE AT THIS TIME.`
- **Source:** R10, R11, Q139. A new code. DIMENSION (6010)/(6110) takes a dimension number from #1 to the array's rank; #0, or one past the rank (any dimension at all of an undimensioned array), is a programming error.
- **Tests:** `packages/conformance/tests/extracal/lib-arrays/e812.xc`, `packages/conformance/tests/extracal/lib-arrays/e812-hybrid.xc`, `packages/conformance/tests/extracal/lib-arrays/e812-zero.xc` and their `-no-opt` twins
- **Date:** 2026-10-18

### E813: an arithmetic result too big for its variable
- **Text:** `AN ARITHMETIC RESULT HAS BEEN TOO BIG FOR ITS VARIABLE.`
- **Joke:** `THE ANSWER WAS CORRECT. IT JUST DID NOT FIT.`
- **Source:** R6, R10, R11, Q139, L32's lean. A new code. The Math block's error variants raise it when the true result doesn't fit its width: unsigned for (4000)–(4099) and the (4500)/(4600) powers, two's complement for the signed routines, including the most negative value divided by −1. The flag variants store the wrapped result and #2 instead. Syslib keeps its own E000 for its own routines. With its PETITION abstained, an error variant returns as if nothing had overflowed (`packages/conformance/tests/extracal/lib-math/abstained-e813.xc`).
- **Tests:** `packages/conformance/tests/extracal/lib-math/e813-add64.xc`, `packages/conformance/tests/extracal/lib-math/e813-div32.xc`, `packages/conformance/tests/extracal/lib-math/e813-mul16.xc`, `packages/conformance/tests/extracal/lib-math/e813-mul64.xc`, `packages/conformance/tests/extracal/lib-math/e813-pow32.xc`, `packages/conformance/tests/extracal/lib-math/e813-pow64.xc`, `packages/conformance/tests/extracal/lib-math/e813-sadd16.xc`, `packages/conformance/tests/extracal/lib-math/e813-sadd32.xc`, `packages/conformance/tests/extracal/lib-math/e813-sadd64.xc`, `packages/conformance/tests/extracal/lib-math/e813-sdiv16.xc`, `packages/conformance/tests/extracal/lib-math/e813-sdiv64.xc`, `packages/conformance/tests/extracal/lib-math/e813-smul32.xc`, `packages/conformance/tests/extracal/lib-math/e813-smul64.xc`, `packages/conformance/tests/extracal/lib-math/e813-ssub16.xc`, `packages/conformance/tests/extracal/lib-math/e813-ssub32.xc`, `packages/conformance/tests/extracal/lib-math/e813-sub64.xc`, each with a `-no-opt` twin
- **Date:** 2026-10-18

### E817: a URL that isn't plain HTTP
- **Text:** `AN ADDRESS THAT IS NOT A PLAIN HTTP URL HAS BEEN REQUESTED.`
- **Joke:** `THERE IS NO S IN THIS PROTOCOL, AND NO SECURITY IN THIS PROGRAM.`
- **Source:** R10, R11, Q110, Q139, L34's lean. A new code. The Network block's GET (9100) and POST (9110) take `http://host[:port][/path]`; any other scheme (there is no TLS), an empty host, or a port that is empty, not decimal or above 65535 is a programming error. A refused connection is not: it gives `.3 = #2`.
- **Tests:** `packages/conformance/tests/extracal/lib-network/e817.xc`, `packages/conformance/tests/extracal/lib-network/e817-port.xc`, each with a `-no-opt` twin
- **Date:** 2026-10-18

### E993: a statement after TRY AGAIN
- **Text:** `A STATEMENT FOLLOWS TRY AGAIN, WHICH MUST BE THE LAST STATEMENT OF THE PROGRAM.`
- **Joke:** `THERE IS NO AFTER. THERE IS ONLY AGAIN.`
- **Source:** R3 item 5, with `ick` 0.35 semantics. This is `ick`'s own code for `ick`'s own condition, so it keeps the number (R11 is about conditions new to CIWAPA); the text is CIWAPA's. It is a compile-time error reported against the first statement after the TRY AGAIN. The system library, appended after the user's statements, doesn't count.
- **Tests:** `packages/conformance/tests/extracal/try-again/e993.xc`
- **Date:** 2026-10-18

### E277: an impossible reverse assignment
- **Text:** `AN IMPOSSIBLE REVERSE ASSIGNMENT HAS BEEN ATTEMPTED.`
- **Joke:** `SOME EQUATIONS ARE ONE-WAY STREETS.`
- **Source:** R3 item 8, with `ick` 0.35 semantics. `ick`'s own code for `ick`'s own condition, so it keeps the number; the text is CIWAPA's. Assigning to an overloaded variable works backwards through its expression, and fails with E277 at a constant, at a unary operator whose result can't be produced (found the way `ick` does, by building one candidate and checking it), and in bases 3–7 at any mingle, select or unary operator (L23).
- **Tests:** `packages/conformance/tests/extracal/overloading/e277.xc`, `packages/conformance/tests/extracal/overloading/e277-unary.xc`
- **Date:** 2026-10-18
