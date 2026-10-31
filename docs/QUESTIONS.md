# Questions

Questions the `/goal` loops ran into that the plans don't answer. Each one has the context, the options and the loop's lean. Checklist items a question affects are marked **BLOCKED** with its number until Ryan answers. When a question touches behavior that no checklist item covers, the code needs *some* behavior in the meantime: it follows the lean, and the question says so. Answered questions move to [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

Numbers are `L1`, `L2`, … so they never collide with the planning session's `Q` and `T` numbers.

None of these blocks a checklist item.

### L43: Which JetBrains LSP API names does the plugin use?
- **Context:** IntelliJ 2026.1.4 renamed the LSP API's classes (`LspServerSupportProvider` became `LspIntegrationProvider`, and so on). The plugin uses the old names, so it runs on 2026.1.0 to 2026.1.3. That is why the verifier reports 25 deprecated-API usages against 2026.2, which doesn't fail `lint`.
- **Options:** keep 2026.1 as the floor with the old names / raise the floor to 2026.1.4 (build 261.26222) and use the new names.
- **Lean, and what the code does:** keep the 2026.1 floor until the old names are scheduled for removal.

### L44: How is the Neovim plugin published?
- **Context:** `docs/EDITORS.md` and the plugin's README install it from `latticeandcompany/intercal-neovim`, a mirror of `editors/neovim` that plugin managers can clone. That repository doesn't exist yet, and nothing syncs it.
- **Options:** create the mirror and sync it by hand at each release / sync it from the release workflow (which needs a token with write access to it) / tell users to point their plugin manager at `editors/neovim` in a CIWAPA checkout.
- **Sub-questions:** should the mirror carry its own `LICENSE` (a copy of CIWAPA's ISC license)? Should the plugin grow a `:help intercal` page?
- **Lean:** create the mirror by hand, with a copy of the license, and add the help page later.

### L45: Should library documents be highlighted?
- **Context:** `ciwapa-lib:` documents open read-only, but the protocol only syncs `file:` documents, so the server never sees them and they get no semantic tokens or hovers.
- **Options:** leave them plain / have the server analyze `ciwapa-lib:` documents it serves, and the clients send them.
- **Lean, and what the code does:** leave them plain for now.

### L46: JetBrains settings scope and the Comment menu item
- **Context:** the plugin's settings apply to every project, where VS Code lets a workspace override them (except `serverPath`). Toggle comment takes the Comment with Line Comment *shortcut* through an action promoter, but the **Code › Comment with Line Comment** menu item still runs the platform's own action, which knows no INTERCAL comment syntax.
- **Options:** keep both / per-project settings / override the platform's comment action for INTERCAL files.
- **Lean, and what the code does:** keep both.
