# Editors: plan for goal 4

Goal 4 gives INTERCAL, EXTRACAL and INTERCAL on Interstates a language server and editor extensions for VS Code, JetBrains IDEs and Neovim. The tooling is genuinely helpful. The jokes live in the copy, the way they do in the README (Q149).

This is the fourth of five `/goal` runs: **CIWAPA (Mode 1)** → **EXTRACAL** → **INTERCAL on Interstates** → **Editors** → **Playground** (Q148). It starts after goal 3, which is done.

Background: [`PLAN.md`](PLAN.md) (architecture, workflow), [`EXTRACAL_PLAN.md`](EXTRACAL_PLAN.md), [`INTERSTATES_PLAN.md`](INTERSTATES_PLAN.md), and [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) (every answer, including the Q-numbers cited here). The definition of done is [`EDITORS_CHECKLIST.md`](EDITORS_CHECKLIST.md).

---

## Vision

Writing INTERCAL should be hard because of INTERCAL, not because of the editor. Open a `.i` file and you see what the compiler sees: every compile error at once, where it happens, explained. You can jump from `NEXT (1000)` to the routine, see which `COME FROM` will hijack a line before it hijacks it, and know how polite the file is before the compiler tells you.

## User experience

```
ciwapa-llvm lsp          # the language server, on stdio
```

- The user installs a compiler archive as today, then the **INTERCAL** extension for their editor (Q170). The extension finds the server on `PATH`, so nothing new needs installing.
- `.i`, `.xc` and `.ioi` files get diagnostics, hovers, navigation, completion, inlay hints and highlighting as soon as they open.
- Each extension has **Run this file** and **Build this file** commands, plus a setting that picks `llvm` or `dart` (Q157).

## Requirements

### R1. Interstates gets its own file extension (Q154)
- `.ioi` and `.2ioi` select INTERCAL on Interstates. `.3ioi`–`.7ioi` are E998, as L35 already decided for `-s` in bases 3–7.
- The `ioi-*` CLIs drop `-s`. Passing it fails with a message saying to rename the file to `.ioi`.
- Without `.ioi`, the `ioi-*` CLIs keep L35's other rules: they take EXTRACAL (`.xc`, `.2xc`–`.7xc`), and anything else is E998.
- Q141's tolerances (prose before the first statement, a bare `GIVE UP`) now apply to `.ioi` files instead of `-s` builds.
- CIWAPA's own packages still never learn about Interstates. `.ioi` is recognized by the Interstates front end, not by `Source.dialectOf`. `ciwapa-*` treats a `.ioi` file as an unknown extension, E998.
- The blog, the hello world and every Interstates golden test are renamed to `.ioi`, and the docs follow.

### R2. Every compile error, with a place (Q153)
- `ciwapa_core` collects every compile error it can find in one pass, each with the rune span of its statement, instead of throwing at the first.
- The CLIs still print only the first error, exactly as today. Conformance output, error text and exit codes don't change by one byte.
- Where an error is about one token (a bad label, an out-of-range constant), it carries that token's span too.

### R3. The server (Q151, Q167, Q169, Q171)
- `packages/ciwapa_lsp` is a Dart workspace package with a hand-rolled JSON-RPC layer over stdio and only the LSP types it uses. It has no new dependencies.
- Every CLI gets an `lsp` subcommand: `ciwapa-llvm`, `ciwapa-dart`, `ioi-llvm`, `ioi-dart`.
- `ciwapa-* lsp` handles `.i` and `.xc`. `ioi-* lsp` handles those plus `.ioi` and the templates, through the same `Frontend` hook the CLIs use, so `ciwapa_lsp` never names Interstates.
- Each file is diagnosed as the CLI that builds it would diagnose it: `.i`/`.xc` with CIWAPA's front end, `.ioi` with Interstates'.
- The random compiler bug (E774) is never reported. The server analyzes as if `--no-random-bug` were given.
- Compiler flags come from editor settings passed to the server: `traditional`, `clockface` (Q160). Files carry no hidden configuration.
- The server reports its version. The extensions require the exact version they shipped with, and warn when it differs (Q179).

### R4. Diagnostics and hovers (Q152, Q163, Q180)
- Every compile error is an Error diagnostic on its statement (R2).
- Undecodable statements, the `DO NOTE …` lines everyone uses as comments, are highlighted as comments and carry an Information-level hint: E000 if this statement ever runs. They never get a warning.
- Hovering an error shows the exact `ICLnnnI` line the compiler prints, its joke line, the §9.2 description in plain English, and what to do about it.
- Hovering an operator (mingle, select, the unary operators), a sigil, a gerund or a library label explains it. Library routine hovers say what goes in and what comes out (`.1` and `.2` in, `.3` out, and so on).
- All hover text lives in Dart, in the server, so every editor shows the same words.

### R5. Highlighting (Q155)
- Semantic tokens from the real lexer are the only highlighter. There is no TextMate grammar and no tree-sitter grammar.
- The legend covers statement identifiers (DO, PLEASE, PLEASE DO, NOT), keywords and gerunds, labels, variables by kind, constants, operators, the EXTRACAL and Interstates words, string literals, and comments (undecodable statements).

### R6. Label navigation (Q152, Q165, Q166)
- Go to definition from any label use (`NEXT`, `ABSTAIN FROM`, `REINSTATE`, `COME FROM`, `NEXT FROM`) to the labelled statement.
- Find references to a label, and rename it everywhere it's used.
- Rename in a file with computed targets (EXTRACAL's computed `COME FROM`, computed `ABSTAIN`, gerund `COME FROM`) renames every literal use and warns that a computed target might still mean the old number.
- Labels in the system library and EXTRACAL's library open their source as a read-only virtual document. Each extension registers a `ciwapa-lib:` URI scheme and fetches the text from the server with a custom request, so nothing is written to disk.

### R7. The COME FROM code lens (Q152)
- Above every labelled statement that something comes from, a code lens lists who: `COMES FROM: line 42`, or several lines. Clicking it goes there.
- `NEXT FROM` gets the same lens.
- Computed and gerund `COME FROM`s can't be resolved. A lens on the file's first statement says so: `This file has computed COME FROMs. Anything could come from anywhere.`

### R8. Completion, inlay hints and politeness (Q152, Q164, Q172, Q173)
- Completion offers:
  - statement keywords after an identifier, including the EXTRACAL and Interstates words where the file's dialect has them;
  - labels inside `( )`, from the file and the libraries, with their hover docs;
  - gerunds after `ABSTAIN FROM` and `REINSTATE`.
- Inlay hints show:
  - constants in decimal, hex and binary, and the value of a mingle or select whose operands are all constants;
  - each statement's ordinal, the number runtime errors report (`ON THE WAY TO STATEMENT 43`);
  - in `.ioi` files, which `;49221 SUB #k` a template argument `,m` is, and the argument names of a `READ OUT #n WITH TEMPLATE`.
- Politeness:
  - The file's ratio (`PLEASE 4/17, 24%`) is shown in VS Code's status bar and as an inlay hint on the first statement elsewhere. The server sends it with a custom notification.
  - On E079 and E099, quick fixes add or remove just enough PLEASEs, spread evenly through the file.

### R9. Comment toggling (Q174)
- Toggle comment turns `DO X`, `PLEASE X` or `PLEASE DO X` into `PLEASE NOTE X`, keeping any label. `PLEASE NOTE` lexes as `PLEASE NOT E…`, an abstained undecodable statement, so it never runs and never raises E000.
- Toggling `PLEASE NOTE X` or `DO NOTE X` back gives `DO X`.
- It works on whole statements, including ones that span lines. The server does it through a custom request that returns edits. Each extension binds the editor's usual comment shortcut to it for INTERCAL files.

### R10. Interstates templates (Q156)
- The `.html` files a `.ioi` program names in `WITH TEMPLATE` get diagnostics (E820, E821, and E443 for links) in the template itself.
- Hovering a grumpy's `,m` shows which `;49221 SUB #k` it is.
- Go to definition from a `WITH TEMPLATE "path"` opens the template.
- The server only treats an `.html` file as a template when an open `.ioi` program names it. Other HTML is left alone.

### R11. Claiming file extensions (Q178)
- `.2i`–`.7i`, `.2xc`–`.7xc`, `.ioi` and `.2ioi` are always INTERCAL.
- `.i` and `.xc` are also SWIG/preprocessed C and XMOS XC. They're INTERCAL only when one of their first 50 lines matches `^\s*(\(\d+\)\s*)?(PLEASE|DO)\b`.
- When a `.i` or `.xc` file fails that check, the extension asks once: "This .i doesn't look like INTERCAL. Open it as INTERCAL anyway?" The answer is remembered for that file.

### R12. The editors (Q150, Q158, Q162, Q170)
- **VS Code** (`editors/vscode`): one extension, display name **INTERCAL**, id `latticeandcompany.intercal`. The same `.vsix` installs in VS Code's forks.
- **JetBrains** (`editors/jetbrains`): a plugin named **INTERCAL**, written in Kotlin on the native IntelliJ LSP API, for IDEs 2026.1 and later. That's the first release with code lens.
- **Neovim** (`editors/neovim`): a small Lua plugin for Neovim 0.11+ that registers the filetypes (R11) and starts the server with `vim.lsp.config`. Ryan mirrors it by hand to `latticeandcompany/intercal-neovim`, which is what `docs/EDITORS.md` tells users to install. The loop never creates repos.
- Helix, Zed, Sublime and Emacs are out of scope (Q150, Q155).

### R13. Running programs (Q157)
- **Run this file** and **Build this file** call `<cli> run` and `<cli> build` in a terminal.
- A `flavor` setting picks `llvm` or `dart` for these commands and for the server.
- Debugging (DAP) is a later goal.

### R14. Releases (Q159, Q179)
- The `.vsix` and the JetBrains plugin `.zip` are attached to the GitHub release next to the compiler archives, with the same version.
- Nothing is published to the VS Code Marketplace, Open VSX or the JetBrains Marketplace.

## Technical approach

- **Server discovery**, in every extension:
  1. the `serverPath` setting, if set;
  2. otherwise `ioi-<flavor>` on `PATH`;
  3. otherwise `ciwapa-<flavor>` on `PATH`.

  With only `ciwapa-*` found, `.ioi` files show one diagnostic saying to install `ioi-*`.
- **Sync** is full-text. The server re-analyzes a file on each change. The front end takes at most 14 ms on any benchmark, so incremental parsing isn't worth its complexity.
- **Custom protocol**, documented in `packages/ciwapa_lsp/README.md`:
  - `intercal/librarySource` returns a library document's text;
  - `intercal/toggleComment` returns the edits for R9;
  - the `intercal/politeness` notification carries the ratio for R8.
- **"Ask once" storage** (R11) is VS Code's `workspaceState`, JetBrains' per-project `PropertiesComponent`, and in Neovim a table that lasts for the session. None of these is a file the extension writes itself.
- **Node** follows Ryan's conventions from `~/Source/arenaswap` (Q175):
  - npm 12 with `packageManager` pinned and an `allowScripts` allowlist that turns off `@swc/core`'s and `esbuild`'s install scripts;
  - TypeScript 7 with a `tsconfig.base.json` like deMotivator-v15's;
  - rolldown bundles the extension into one CommonJS file;
  - oxlint with deMotivator-v15's rules, and no formatter beyond `.editorconfig`;
  - Jest with `@swc/jest` for unit tests;
  - tabs, single quotes, semicolons, no trailing commas, arrow functions, camelCase file names.

  The exception is line endings. CIWAPA is LF everywhere, and `editors/` follows it.
- **Toolchains run in Docker** (Q161). `tools/in-docker` takes an image name. The new images are pinned `node`, `eclipse-temurin:21` with Gradle from the checked-in wrapper, and one with Neovim 0.11+ for the smoke test. Nothing is installed on the host. CI runners set the same pinned versions up with their setup actions, the way they already set up Dart.
- **Lattice** runs the tasks. `editors/vscode`, `editors/jetbrains` and `editors/neovim` are Lattice workspaces with `lint`, `test` and `build` scripts. `packages/ciwapa_lsp` is a Dart workspace package like the others.

## Affected areas

- `packages/ciwapa_core`: error collection with spans (R2), and a way for a front end to supply the dialect for an extension core doesn't know (R1).
- `packages/ciwapa_lsp`: new.
- `packages/ciwapa_core/lib/src/cli.dart`: the `lsp` subcommand.
- `apps/interstates`: `.ioi`, the removal of `-s`, the renames, and the server's Interstates hooks.
- `editors/vscode`, `editors/jetbrains`, `editors/neovim`: new.
- `tools/in-docker`, `lattice.json`, `.github/workflows/ci.yml`, `.github/workflows/release-archives.yml`, `.github/workflows/toolchain-bump.yml`.
- `docs/EDITORS.md` (new), `docs/INTERSTATES.md`, `README.md`, `apps/interstates/README.md`.

## Implementation steps

The workflow is the same as goals 1–3, described in [`PLAN.md`](PLAN.md):
- `gh stack` PR stacks on `mega`, merged with merge commits;
- a `code-reviewer` pass, then merge on green CI;
- every PR starts with the AI-agent note;
- `docs/QUESTIONS.md` under the Q70 policy.

1. **Temporary scaffolding:** `tools/goal/` with a `goal-status` task that prints [`EDITORS_CHECKLIST.md`](EDITORS_CHECKLIST.md) and ends in `GOAL: MET` only when every item is checked, CI is green on the `mega` HEAD, and the release builds the `.vsix` and the plugin `.zip`.
2. **`.ioi`** (R1): the extension, the `-s` error, the renames, and the docs.
3. **Every error, with a place** (R2), proved byte-identical by the conformance suite in both flavors.
4. **The server skeleton** (R3): JSON-RPC, lifecycle, text sync, diagnostics, `lsp` on all four CLIs, version reporting, settings.
5. **Semantic tokens and hovers** (R4, R5).
6. **Label navigation and library documents** (R6).
7. **The COME FROM code lens** (R7).
8. **Completion, inlay hints and politeness** (R8), and **comment toggling** (R9).
9. **Templates** (R10).
10. **Docker images and Lattice workspaces** for Node, the JDK and Neovim.
11. **VS Code extension** (R11, R12, R13), with Jest unit tests and an `@vscode/test-electron` smoke test.
12. **JetBrains plugin**, with a headless IntelliJ test-framework smoke test.
13. **Neovim plugin**, with a headless `nvim` smoke test driven by a plain Lua script (Q177).
14. **CI and releases** (R14): the editor smoke tests run on PRs that touch `packages/ciwapa_core`, `packages/ciwapa_lsp`, `apps/interstates` or `editors/**`, and on releases (Q168). The release attaches the `.vsix` and the plugin `.zip`, and `toolchain-bump.yml` bumps the new pins.
15. **User docs:** `docs/EDITORS.md` (install, settings, every feature), a README section, and the protocol notes in `packages/ciwapa_lsp/README.md`.
16. **Cleanup:** run `goal-status` and show its output, delete `tools/goal/`, then show `git status` and the final tree.

## Edge cases

- A file with no statements at all, a file of only prose, and a file whose only statements are undecodable.
- A statement spanning many lines, and CRLF or mixed line endings. `Source` strips `\r`, but LSP positions count UTF-16 units on the original text. The server converts rune offsets to UTF-16 positions against the text as the editor holds it.
- Non-ASCII text (the overstrike characters, Latin, `¢`, `¥`) in hovers, spans and semantic tokens.
- A label defined twice (E182), and a label used but never defined. Go to definition offers what exists and does nothing for the missing one.
- `(16000)` in a `.ioi` file: the entry label that no program defines. Its hover explains that, and go to definition lists the routes.
- A politeness quick fix in a file so short that no number of PLEASEs fits the band.
- A template named by two open programs that disagree about how many arguments it takes.
- The server binary is missing, crashes, or is the wrong version. Each extension says which, once, and offers the `serverPath` setting.
- A `.i` that is really SWIG, and a `.xc` that is really XMOS XC (R11).
- Windows paths and `file:` URIs with drive letters.

## Acceptance criteria

`lattice run goal-status` prints each checklist item with its linked test and ends in `GOAL: MET` only when every box is ticked.

- [ ] `.ioi` replaces `-s`, and goal 3's tests all pass under their new names.
- [ ] The CLIs' output is unchanged: the full conformance suite passes in both flavors.
- [ ] Every requirement R2–R11 has protocol-level tests in `packages/ciwapa_lsp`, run against both `ciwapa-*` and `ioi-*` front ends where they apply.
- [ ] The VS Code, JetBrains and Neovim smoke tests each open a sample file, see a diagnostic, and follow a go to definition, on every CI platform where that editor runs headless.
- [ ] The release attaches the `.vsix` and the JetBrains plugin `.zip`, with the compilers' version.
- [ ] `docs/EDITORS.md` covers installing and using every extension.
- [ ] CI is green.
- [ ] The temporary scaffolding is removed.

## Assumptions & decisions

Decided in the grilling session (see `SPEC_DECISIONS.md`): Q148–Q180.

Engineering decisions made while writing the plan, without a separate question:
1. **The server's front-end hook.** `ciwapa_lsp` takes the same `Frontend` the CLIs take, so `ioi-* lsp` adds `.ioi` and templates without `ciwapa_lsp` depending on Interstates.
2. **Server discovery** prefers `ioi-*` over `ciwapa-*`, because the `ioi-*` server understands everything the `ciwapa-*` one does.
3. **Full-text sync**, because the front end is fast enough (see Technical approach).
4. **Hover, completion and inlay text are written once, in Dart**, so the three editors can't drift apart.
5. **The random bug is never diagnosed**, because it's planted at random when a program builds and would flicker with every keystroke.

## Later goals

- **Goal 5, WASM playground.** Unchanged from [`PLAN.md`](PLAN.md#later-goals).
- **Debugging (DAP).** Deferred (Q157). When it's planned, the likely design is a `--debug` build flag that makes both backends call a small runtime debug agent before every statement.

## Open questions

None. Anything unforeseen goes to `docs/QUESTIONS.md` under the Q70 policy.

---

## `/goal` prompt

```
/goal Build CIWAPA goal 4, the language server and editor extensions, exactly as specified in docs/EDITORS_PLAN.md and docs/EDITORS_CHECKLIST.md, following the workflow and parity rules in docs/PLAN.md and every decision in docs/SPEC_DECISIONS.md. Never guess: if a decision is missing, record it in docs/QUESTIONS.md, mark the affected checklist item blocked and keep working on everything else. Stop the goal immediately only if the missing answer could force undoing a large amount of work. Work through the Implementation Steps in order, as gh stack PR stacks on mega (submitted with gh stack submit). Every PR starts with the AI-agent note from docs/PLAN.md and has tests. It needs a code-reviewer sub-agent pass and green CI before it is merged with a merge commit. The CLIs' output must not change: the conformance suite passes in both flavors after every PR. CIWAPA's own packages, ciwapa_lsp included, must never depend on Interstates. Use only the dependencies approved in docs/SPEC_DECISIONS.md, pinned; anything else goes to QUESTIONS.md. Locally, Node, the JDK and Neovim run only through tools/in-docker, never on the host; CI may use setup actions with the same pins, as it does for Dart. After every stage, run `lattice run goal-status` and show its full output. The goal is met only when that output ends with "GOAL: MET": every acceptance criterion is ticked with a linked passing test, the three editor smoke tests pass, CI is green, the release attaches the .vsix and the JetBrains plugin .zip, and tools/goal is removed. The goal is also met if every remaining item is listed as blocked in docs/QUESTIONS.md.
```
