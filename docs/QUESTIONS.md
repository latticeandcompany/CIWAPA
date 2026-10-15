# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean, but the loop never acts on its lean: affected checklist items are marked **BLOCKED** with the question's number until Ryan answers. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

## L1: May GitHub Actions open pull requests in this repo?

- **Context:** The plan calls for a scheduled workflow that opens a PR bumping the pinned LLVM, llvm-mingw and musl versions (`.github/workflows/toolchain-bump.yml`). GitHub only lets a workflow's `GITHUB_TOKEN` create PRs when the repo setting *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests* is on. It's off, and changing repo settings wasn't part of the plan.
- **Options:** (a) Ryan turns the setting on; (b) the loop turns it on with `gh api`; (c) the workflow opens an issue instead of a PR.
- **Lean:** (a). Until then, the workflow's push step works but its `gh pr create` step fails. Since pushes made with `GITHUB_TOKEN` don't trigger workflows, the bump job starts `ci.yml` and `release-archives.yml` itself with `gh workflow run`, so the PR still gets checked once it can be opened.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14

## L4: Is a chain inside a group E017 or undecodable?

- **Context:** Q97 makes an ungrouped chain such as `#165¢#203~#358` invalid, following 0.15's parser, with E017 when the statement executes (Q80). Inside a group, as in `'#1¢#2~#3'`, 0.15's parser fails at a different point: it splatters the statement, so it would raise E000 rather than E017. The checklist item names the error E017 without saying where the chain sits.
- **Options:** (a) E017 wherever the chain is; (b) E017 at the top level, and undecodable (E000) inside a group, exactly as 0.15.
- **Lean:** (a). It's the same mistake either way, and the checklist item gives E017. The compiler does (a) until this is answered; the difference from 0.15 is listed under Divergences.
- **Blocks:** no checklist items.
- **Raised:** 2026-10-14
