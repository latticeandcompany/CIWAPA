# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean. Checklist items a question affects are marked **BLOCKED** with its number until Ryan answers. When a question touches behavior that no checklist item covers, the code needs *some* behavior in the meantime: it follows the lean, and the question says so. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

## L1: May GitHub Actions open pull requests in this repo?

- **Context:** The plan calls for a scheduled workflow that opens a PR bumping the pinned LLVM, llvm-mingw and musl versions (`.github/workflows/toolchain-bump.yml`). GitHub only lets a workflow's `GITHUB_TOKEN` create PRs when the repo setting *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests* is on. It's off, and changing repo settings wasn't part of the plan.
- **Options:** (a) Ryan turns the setting on; (b) the loop turns it on with `gh api`; (c) the workflow opens an issue instead of a PR.
- **Lean:** (a). Until then, the workflow's push step works but its `gh pr create` step fails. Since pushes made with `GITHUB_TOKEN` don't trigger workflows, the bump job starts `ci.yml` and `release-archives.yml` itself with `gh workflow run`, so the PR still gets checked once it can be opened.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14

## L2: When do a COME FROM statement's own statement-local errors fire?

- **Context:** A COME FROM can carry an invalid label (`(0) DO COME FROM (1)`, E197) or an invalid percentage (`DO %101 COME FROM (1)`, E017). Q80 says such errors fire "when the statement executes". But §4.4.14.2 says reaching a COME FROM "has no effect", and its NOT and `%` guard the *jump*, which is evaluated at the target. C-INTERCAL 0.15 reports both at compile time, so it gives no run-time answer.
- **Options:** (a) when control reaches the COME FROM, by falling into it or by its jump; (b) only when its jump is considered: after the target runs, if the COME FROM isn't abstained, the error fires instead of the jump; (c) never.
- **Lean:** (b), because the COME FROM only acts at its jump, and a `%101` can't be rolled. The emitters do (b) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14

## L3: On an undecodable statement, does E000 or a label/percentage error win?

- **Context:** `(0) DO FOO` has an invalid label (E197) and can't be decoded (E000). `DO %101 FOO` has an invalid percentage (E017) and can't be decoded. Each of these errors fires when the statement executes (Q80, T8). Nothing says which one is reported.
- **Options:** (a) source order: the label, then the percentage, then E000; (b) E000 always wins, because the statement as a whole is undecodable.
- **Lean:** (a), the same rule as every other statement with more than one problem. The IR does (a) until this is answered.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14

## L4: Is a chain inside a group E017 or undecodable?

- **Context:** Q97 makes an ungrouped chain such as `#165¢#203~#358` invalid, following 0.15's parser, with E017 when the statement executes (Q80). Inside a group, as in `'#1¢#2~#3'`, 0.15's parser fails at a different point: it splatters the statement, so it would raise E000 rather than E017. The checklist item names the error E017 without saying where the chain sits.
- **Options:** (a) E017 wherever the chain is; (b) E017 at the top level, and undecodable (E000) inside a group, exactly as 0.15.
- **Lean:** (a). It's the same mistake either way, and the checklist item gives E017. The compiler does (a) until this is answered; the difference from 0.15 is listed under Divergences.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14

## L5: Must "too large to allocate" give the same answer in both flavors on every machine?

- **Context:** T26 says dimensions too large to allocate raise E241, and T27 rules out artificial caps. Both runtimes now raise E241 without trying when the element count passes 2^61, which no machine can allocate. Below that, the allocation itself decides, and the flavors can disagree. C's `calloc` may succeed under Linux overcommit, while the Dart VM refuses sooner and also prints its own `Exhausted heap space` line to stderr before the E241. The same applies to E222 (stash space). Requirement 2 asks for byte-identical output on the conformance suite, which only uses sizes past 2^61, so the suite isn't affected.
- **Options:** (a) keep it this way: deterministic past 2^61, machine-dependent below it; (b) a shared, lower cap (an artificial limit, against T27); (c) probe for physical memory before allocating.
- **Lean:** (a). The code does (a) until this is answered.
- **Blocks:** no checklist items. The E241 "too large to allocate" test uses a size past 2^61.
- **Raised:** 2026-10-14

## L6: Should WRITE IN accept CRLF line endings?

- **Context:** T7 strips `\r` from source files only. At run time both runtimes read stdin as raw bytes, so `ONE\r\n` is the word `ONE\r`, which is E579. That's exactly what C-INTERCAL 0.15 does, so the tie-breaker (Q91, Q98) gives today's behavior. But on the Windows release archives, typing at a console may deliver `\r\n`, which would make interactive WRITE IN fail every time.
- **Options:** (a) keep 0.15's behavior; (b) strip one `\r` before each `\n` in WRITE IN, and record the divergence next to T7/T28.
- **Lean:** (b), for Windows users. The code does (a), the tie-breaker's answer, until this is answered, because (b) would be a new divergence.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14
