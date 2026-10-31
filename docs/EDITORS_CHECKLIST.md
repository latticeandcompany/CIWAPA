# Editors checklist

This is the definition of done for the editors, goal 4 ([`EDITORS_PLAN.md`](EDITORS_PLAN.md)). Each item names the requirement it comes from and links at least one test that passes. An item is checked only when its tests exist and pass. Items waiting on an answer in [`QUESTIONS.md`](QUESTIONS.md) are marked **BLOCKED** with the question's number.

Format, as in [`INTERSTATES_CHECKLIST.md`](INTERSTATES_CHECKLIST.md):

```markdown
- [ ] R3 — rule, in one line. Tests: `packages/ciwapa_lsp/...`
```

The sections follow the plan's requirements. `goal-status` reads this file, together with the CI run and the release on the `mega` HEAD.

## `.ioi` (R1)

- [x] R1 — `.ioi` and `.2ioi` select Interstates in both `ioi-*` CLIs; `.3ioi`–`.7ioi` are E998. Tests: `apps/interstates/test/cli_test.dart`
- [x] R1 — `-s` is gone, and passing it fails with a message to rename the file to `.ioi`. Tests: `apps/interstates/test/cli_test.dart`
- [x] R1 — without `.ioi`, the `ioi-*` CLIs still take exactly what L35 says. Tests: `apps/interstates/test/cli_test.dart`
- [x] R1 — Q141's tolerances apply to `.ioi` files. Tests: `apps/interstates/test/cli_test.dart`, `apps/interstates/test/syntax_test.dart`
- [x] R1 — `ciwapa-*` treats `.ioi` as E998, and nothing under `packages/` names Interstates. Tests: `apps/interstates/test/cli_test.dart`, `apps/interstates/test/separation_test.dart`
- [x] R1 — the blog, the hello world and every Interstates golden are `.ioi`, and all of goal 3's tests pass. Tests: `apps/interstates/test/golden`, `apps/interstates/test/hello_test.dart`, `apps/interstates/test/blog_test.dart`

## Errors (R2)

- [x] R2 — the front end reports every compile error in a file, each with its statement's span. Tests: `packages/ciwapa_core/test/analysis_test.dart`, `apps/interstates/test/analysis_test.dart`
- [x] R2 — errors about one token carry that token's span. Tests: `packages/ciwapa_core/test/analysis_test.dart`
- [x] R2 — the CLIs print only the first error, and the conformance suite is unchanged in both flavors. Tests: `packages/conformance`, `packages/ciwapa_core/test/analysis_test.dart`, `apps/interstates/test/analysis_test.dart`

## The server (R3)

- [x] R3 — `lsp` exists on `ciwapa-llvm`, `ciwapa-dart`, `ioi-llvm` and `ioi-dart`, and speaks LSP on stdio. Tests: `packages/ciwapa_llvm/test/lsp_test.dart`, `packages/ciwapa_dart/test/lsp_test.dart`, `apps/interstates/test/lsp_test.dart`, `packages/ciwapa_lsp/test/server_test.dart`, `packages/ciwapa_lsp/test/rpc_test.dart`
- [x] R3 — `ciwapa_lsp` has no dependencies beyond the workspace's, and doesn't depend on Interstates. Tests: `packages/ciwapa_lsp/test/dependencies_test.dart`, `apps/interstates/test/separation_test.dart`
- [x] R3 — `ciwapa-* lsp` diagnoses `.i` and `.xc`; `ioi-* lsp` also diagnoses `.ioi`, each the way its CLI would. Tests: `packages/ciwapa_lsp/test/server_test.dart`, `apps/interstates/test/lsp_test.dart`, `packages/ciwapa_lsp/test/text_test.dart`
- [x] R3 — E774 is never reported. Tests: `packages/ciwapa_lsp/test/server_test.dart`, `packages/ciwapa_core/test/analysis_test.dart`
- [x] R3 — the `traditional` and `clockface` settings change diagnostics as the flags would. Tests: `packages/ciwapa_lsp/test/server_test.dart`, `apps/interstates/test/lsp_test.dart`
- [ ] R3 — the server reports its version, and each extension warns on a mismatch. Tests: —

## Diagnostics and hovers (R4)

- [x] R4 — every compile error is an Error diagnostic on its statement. Tests: `packages/ciwapa_lsp/test/server_test.dart`, `apps/interstates/test/lsp_test.dart`
- [x] R4 — undecodable statements get an Information hint, never a warning or an error. Tests: `packages/ciwapa_lsp/test/hover_test.dart`
- [x] R4 — an error hover shows the `ICLnnnI` line, the joke line, the §9.2 description and a fix. Tests: `packages/ciwapa_lsp/test/hover_test.dart`, `packages/ciwapa_lsp/test/help_test.dart`, `apps/interstates/test/lsp_test.dart`
- [x] R4 — operators, sigils, gerunds and library labels have hovers, and library hovers say what goes in and out. Tests: `packages/ciwapa_lsp/test/hover_test.dart`, `apps/interstates/test/lsp_test.dart`

## Highlighting (R5)

- [x] R5 — semantic tokens cover every token kind in the legend, in all three languages. Tests: `packages/ciwapa_lsp/test/semantic_tokens_test.dart`, `apps/interstates/test/lsp_test.dart`
- [x] R5 — undecodable statements are comment tokens. Tests: `packages/ciwapa_lsp/test/semantic_tokens_test.dart`

## Label navigation (R6)

- [x] R6 — go to definition works from every kind of label use. Tests: `packages/ciwapa_lsp/test/navigation_test.dart`, `apps/interstates/test/lsp_test.dart`
- [x] R6 — find references and rename cover every literal use of a label. Tests: `packages/ciwapa_lsp/test/navigation_test.dart`
- [x] R6 — rename in a file with computed targets warns that they might still use the old number. Tests: `packages/ciwapa_lsp/test/navigation_test.dart`
- [x] R6 — library labels open read-only `ciwapa-lib:` documents served by `intercal/librarySource`. Tests: `packages/ciwapa_lsp/test/navigation_test.dart`, `apps/interstates/test/lsp_test.dart`

## The COME FROM code lens (R7)

- [ ] R7 — a labelled statement that something comes from has a lens listing every `COME FROM` and `NEXT FROM` that targets it. Tests: —
- [ ] R7 — a file with computed or gerund `COME FROM`s has the warning lens on its first statement. Tests: —

## Completion, inlay hints and politeness (R8)

- [ ] R8 — completion offers statement keywords for the file's dialect, labels inside `( )`, and gerunds. Tests: —
- [ ] R8 — inlay hints show constant values, constant mingles and selects, and statement ordinals. Tests: —
- [ ] R8 — in `.ioi` files, inlay hints name template arguments. Tests: —
- [ ] R8 — `intercal/politeness` carries the ratio, shown in VS Code's status bar and as an inlay hint elsewhere. Tests: —
- [ ] R8 — the E079 and E099 quick fixes leave the file inside the band. Tests: —

## Comment toggling (R9)

- [ ] R9 — toggling a statement gives `PLEASE NOTE`, keeps its label, and works across lines. Tests: —
- [ ] R9 — toggling `PLEASE NOTE` or `DO NOTE` back gives `DO`. Tests: —
- [ ] R9 — every extension binds its comment shortcut to `intercal/toggleComment`. Tests: —

## Templates (R10)

- [ ] R10 — a template named by an open `.ioi` program gets E820, E821 and E443 diagnostics in the template. Tests: —
- [ ] R10 — grumpy hovers show the `;49221 SUB #k` they stand for. Tests: —
- [ ] R10 — go to definition from `WITH TEMPLATE "path"` opens the template. Tests: —
- [ ] R10 — an `.html` file that no open program names is left alone. Tests: —

## Claiming file extensions (R11)

- [ ] R11 — the unambiguous extensions are always INTERCAL. Tests: —
- [ ] R11 — `.i` and `.xc` are INTERCAL only when a statement appears in their first 50 lines. Tests: —
- [ ] R11 — a `.i` or `.xc` that fails the check prompts once, and the answer is remembered. Tests: —

## The editors (R12, R13)

- [ ] R12 — the VS Code smoke test opens a sample, sees a diagnostic and follows a go to definition. Tests: —
- [ ] R12 — the JetBrains smoke test does the same on IDE 2026.1. Tests: —
- [ ] R12 — the Neovim smoke test does the same on Neovim 0.11. Tests: —
- [ ] R12 — the VS Code extension's own code has Jest unit tests. Tests: —
- [ ] R13 — Run and Build call the CLI picked by the `flavor` setting. Tests: —
- [ ] R13 — server discovery follows `serverPath`, then `ioi-*`, then `ciwapa-*`, and `.ioi` files say when only `ciwapa-*` is installed. Tests: —

## Releases and CI (R14)

- [ ] R14 — the release attaches the `.vsix` and the plugin `.zip` with the compilers' version. Tests: `.github/workflows/release-archives.yml`
- [ ] R14 — the editor smoke tests run on PRs touching the server, the front ends or `editors/**`. Tests: `.github/workflows/ci.yml`
- [ ] R14 — `toolchain-bump.yml` bumps the Node, JDK, Gradle, IntelliJ and Neovim pins. Tests: `.github/workflows/toolchain-bump.yml`

## Docs and cleanup

- [ ] `docs/EDITORS.md` covers installing and using every extension, and the README links it. Tests: —
- [ ] `packages/ciwapa_lsp/README.md` documents the custom protocol. Tests: —
- [ ] `tools/goal/` is removed. Tests: —
