# CIWAPA (Compiler for INTERCAL With A Pronounceable Acronym): A native, spec-faithful INTERCAL compiler in Dart

## Role and working agreement
You are building a production-quality INTERCAL compiler. Correctness against the spec comes first, performance second, extensibility third.

**Do not make assumptions. Ask me.** This applies to spec interpretation, architecture, tooling, naming, scope, and anything else not explicitly decided in this prompt. Specifically:
- If the spec is ambiguous, contradictory, or silent on something, stop and ask. Quote the relevant section, list the plausible interpretations, and say which one you'd lean toward and why. Do not implement until I answer.
- If this prompt is ambiguous or seems to conflict with the spec, ask. Do not resolve it yourself.
- If something you planned turns out to be infeasible (a tool won't install, a design won't perform), report it and ask how to proceed. Do not substitute an alternative on your own.
- Batch questions at natural stopping points rather than interrupting for each one, but never proceed past a blocking question.
- "Reasonable defaults" are still assumptions. If you catch yourself picking one, ask instead.

Record every answer I give in `docs/SPEC_DECISIONS.md` (question, options, my decision, date) so it's never asked twice.

Use the `temporary-tooling-docker` skill for the Dart toolchain, builds, and running tests.


## Source of truth
- Primary spec: the INTERCAL reference manual, University of Virginia redistribution (2005). See [`spec/README.md`](../spec/README.md).
- Before writing code, read the spec end to end and produce `docs/SPEC_CHECKLIST.md`: every rule, statement, operator, error code, and I/O behavior as a checkbox with a section reference. This checklist is the definition of "100% compliance". Each item must link to at least one test when done.
- Where this spec and C-INTERCAL (`ick`) disagree, the spec wins in Mode 1 (strict). Record each divergence.

Create a 100% faithful compiler to the INTERCAL language specification (University of Virginia redistribution, 2005). All features should be supported, except in cases of extreme exceptions.

Goals:
- 100% compliance to the language specification
- No bytecode (INTERCAL-64 runs on .NET, this version will run natively)
- Extremely performant
  - Should run faster than most other interpretations (check against other implementations)
- Open to expansion
  - Adding INTERCAL on Interstates
  - 2nd "mode" with more features
    - Standard library
    - I/O
    - More compiler features (see "ick")

Questions:
- Can we compile to LLVM IR? Would there be a benefit to this

## Backends

CIWAPA ships two backends and the user picks one:
- **LLVM:** emits LLVM IR, which `clang` compiles to an optimized native executable. Needs an LLVM toolchain on the machine doing the build.
- **Dart:** emits Dart source, which `dart compile exe` compiles to a native executable. Needs only the Dart SDK.

Both produce native executables with no bytecode, so the "no bytecode" goal applies to both.

## Open items

Found during workspace setup. These aren't decided yet.

- **INTERCAL on Interstates**: a web framework built on C-INTERCAL ([intercaloninterstates.org](http://www.intercaloninterstates.org/), linked from the [Esolang INTERCAL page](https://esolangs.org/wiki/INTERCAL)). No source repository is linked. Still to decide: what "adding" it means (running its programs unmodified, porting it, or something else) and which C-INTERCAL extensions that would pull into scope.
- **Backend details** (see [Backends](#backends)). Prior art: [qpliu/esolang](https://github.com/qpliu/esolang/tree/master/intercal) has an INTERCAL-72 compiler that targets LLVM. Still to decide:
  - which backend is the default
  - how the user chooses (CLI flag, config file, ...)
  - whether both backends must pass the full spec checklist, or one comes first
  - whether the backends share a runtime (I/O, error messages) or each has its own
  - whether the performance goal applies to both backends or only to LLVM
- **Host vs. container platform**: the Docker toolchain runs `linux_arm64`, so anything compiled inside the container is a Linux binary, not a macOS one. Still to decide: which platforms the compiler and its output must run on, and how a macOS-native build gets produced and tested.
- **Benchmark baselines**: which implementations count as "other implementations" (C-INTERCAL `ick`, CLC-INTERCAL, INTERCAL-64, qpliu's LLVM compiler, ...), and what benchmark programs to use.
- **Mode naming and scope**: what Mode 2 is called and which `ick` features it includes.
