# INTERCAL in your editor

CIWAPA's compilers are also a language server. `ciwapa-llvm lsp` (or `ciwapa-dart lsp`, `ioi-llvm lsp`, `ioi-dart lsp`) speaks the Language Server Protocol on stdin and stdout, with the same front end the CLI builds with, so the editor and the compiler never disagree about your program. They disagree with you instead.

There are extensions for VS Code, JetBrains IDEs and Neovim. They start the server, decide which files are INTERCAL, and add the few things LSP has no word for. Everything else comes from the server, through each editor's own LSP support.

## Install

First install a compiler from [Releases](https://github.com/latticeandcompany/CIWAPA/releases) and put its `bin/` on your `PATH`, as in the [README](../README.md#install). For `.ioi` files, install the `ioi-<flavor>` archive: it reads everything `ciwapa-<flavor>` does, plus Interstates. Then install the extension from the same release. An extension and a compiler expect the same version, and say so once if they don't match.

| Editor | Needs | Install |
|---|---|---|
| VS Code, and forks such as VSCodium and Cursor | VS Code 1.91 or later | Download `intercal-vscode-<version>.vsix`, then **Extensions: Install from VSIX...**, or `code --install-extension intercal-vscode-<version>.vsix` |
| IntelliJ IDEA and the other JetBrains IDEs | 2026.1 or later | Download `intercal-jetbrains-<version>.zip`, then **Settings › Plugins › ⚙ › Install Plugin from Disk...** |
| Neovim | 0.11 or later | `{ 'latticeandcompany/intercal-neovim', opts = {} }` with lazy.nvim, or `vim.pack.add({ 'https://github.com/latticeandcompany/intercal-neovim' })` on 0.12 |

The Neovim plugin lives in [`editors/neovim`](../editors/neovim) and is mirrored to `latticeandcompany/intercal-neovim` so that plugin managers can find it. Any plugin manager that takes a local path can use `editors/neovim` from a checkout too. Don't lazy-load it on the `intercal` filetype: the plugin is what decides which files are INTERCAL.

Nothing is published to the VS Code Marketplace, Open VSX or the JetBrains Marketplace.

## Which files are INTERCAL

`.2i` to `.7i`, `.2xc` to `.7xc`, `.ioi` and `.2ioi` always are.

`.i` belongs to SWIG as well, and `.xc` to XMOS XC. One of those is INTERCAL when one of its first 50 lines is a statement: a line starting with `DO` or `PLEASE`, maybe after a `(label)`. Otherwise the extension asks once whether to open it as INTERCAL anyway, and remembers the answer for that file: in VS Code's workspace state, in the JetBrains project's properties, and in Neovim until you quit. No extension writes the answer to a file of its own.

## Settings

Every extension has the same four. The compiler flags come from here and nowhere else, so files carry no hidden configuration.

| Setting | Default | What it does |
|---|---|---|
| `serverPath` | empty | The CLI to run as the server, and for Run and Build. Empty means `ioi-<flavor>` on `PATH`, then `ciwapa-<flavor>`. |
| `flavor` | `llvm` | Which CLI to look for: `llvm` or `dart`. They say the same things about your program. |
| `traditional` | off | `--traditional`: INTERCAL-72 only, so COME FROM and the other extensions are E111. |
| `clockface` | off | `--clockface`: IIII instead of IV. It changes what programs print, so only Run and Build notice. |

- **VS Code:** `intercal.serverPath`, `intercal.flavor`, `intercal.traditional` and `intercal.clockface`. `serverPath` is a user setting only, so a workspace can't choose a program for you to run.
- **JetBrains:** **Settings › Languages & Frameworks › INTERCAL**. The settings apply to every project.
- **Neovim:** `require('intercal').setup({ serverPath = '', flavor = 'llvm', traditional = false, clockface = false })`. The server is an ordinary `vim.lsp.config` entry called `intercal`.

Changing `traditional` or `clockface` re-checks every open file. Changing `serverPath` or `flavor` restarts the server in VS Code and JetBrains, and applies to servers started afterwards in Neovim.

## What you get

| Feature | VS Code | JetBrains | Neovim |
|---|---|---|---|
| Diagnostics: every compile error, on the statement or token that causes it | Problems | Problems | `vim.diagnostic` |
| Hovers for errors, operators, sigils, gerunds, labels and library routines | hover | hover | `K` |
| Go to definition, references and rename for labels | F12, Shift+F12, F2 | Ctrl+B, Alt+F7, Shift+F6 | `CTRL-]`, `grr`, `grn` |
| The COME FROM lens | code lens | code lens | `grx` (0.12), `vim.lsp.codelens.run()` |
| Completion | as you type | as you type | `CTRL-X CTRL-O` |
| Inlay hints | yes | yes | `vim.lsp.inlay_hint.enable()` |
| Politeness | status bar | inlay hint | inlay hint |
| E079 and E099 quick fixes | Ctrl+. | Alt+Enter | `gra` |
| Toggle comment | Ctrl+/ (Cmd+/) | Ctrl+/ (Cmd+/) | `gcc`, `gc`, `:IntercalToggleComment` |
| Run and Build the file | command palette | **Run This File**, **Build This File** | `:IntercalRun`, `:IntercalBuild` |

**Diagnostics** cover every compile error at once, not the first one a build stops at. Hover one for the `ICLnnnI` line and its joke as the compiler prints them, what the error means, and what to do about it. The errors that only fire when a statement runs (E017, E129, E139, E197, E200) say so. The random compiler bug (E774) never appears, because it would move with every keystroke. An undecodable statement, which is how `DO NOTE` comments work, gets a quiet hint that it would be E000 if it ever ran.

**Highlighting** comes from the compiler's own lexer, as semantic tokens. There is no TextMate grammar or tree-sitter parser, so a file stays plain until the server starts. Undecodable statements are comments, labels are functions, and variables carry their kind (`spot`, `twoSpot`, `tail`, `hybrid`, `doubleCateye`, `doubleHybrid`) as a modifier for themes that want to tell them apart.

**Labels.** Go to definition works from `NEXT`, `ABSTAIN FROM`, `REINSTATE`, `COME FROM`, `NEXT FROM` and `CREATE`. A label defined twice offers both statements. A library label, such as `(1000)`, opens the library's source read-only from a `ciwapa-lib:` document, which the server provides and nothing writes to disk. Rename changes every use of a label in the file, and refuses a number that is taken, already used, or in the range of a library the file relies on. If the file has computed targets (a computed or gerund `COME FROM`, a computed `ABSTAIN` or `CREATE`), rename warns that one of them might still mean the old number. INTERCAL declines to say which.

**The COME FROM lens** sits above every labelled statement that a `COME FROM` or `NEXT FROM` names: `COMES FROM: line 42`, one lens per statement that comes from it. Clicking one goes there. A file with computed or gerund `COME FROM`s gets a lens on its first statement saying that anything could come from anywhere, which is true.

**Completion** offers statement keywords after `DO` or `PLEASE` (EXTRACAL's in `.xc` files, Interstates' in `.ioi` files), labels inside `( )` with the library routines' documentation, and gerunds after `ABSTAIN FROM` and `REINSTATE`.

**Inlay hints** show each statement's number, as runtime errors count them (`ON THE WAY TO STATEMENT 43`); constants in hex and binary; and, in binary files, the value of a mingle or select whose operands are all constants.

**Politeness.** Between a fifth and a third of a program's statements must say PLEASE (§10.4). The ratio (`PLEASE 4/17, 24%`) is in VS Code's status bar and in an inlay hint on the first statement elsewhere. On E079 or E099, a quick fix adds or removes just enough PLEASEs, spread evenly through the file.

**Toggle comment** turns `DO X`, `PLEASE X` or `PLEASE DO X` into `PLEASE NOTE X`, keeping the label. `PLEASE NOTE` lexes as `PLEASE NOT E…`, a statement that starts abstained, so it never runs and never raises E000. Toggling `PLEASE NOTE X` or `DO NOTE X` gives `DO X`. It works on whole statements, across lines. A commented statement still counts towards politeness, so commenting out half a file can make it grovel.

## INTERCAL on Interstates

With an `ioi-*` compiler, `.ioi` files get Interstates' words, errors and library on top of everything above.

- **Templates.** The `.html` files a program names in `WITH TEMPLATE` get their own diagnostics, where the problem is in the template: E820 for a grumpy that doesn't parse or sits where no value can go, E821 when the program passes a different number of arguments, and E443 when a restricted route's page doesn't link it. An open template is checked as the editor holds it, so fixing it clears the errors before you save. HTML that no open program names is left alone.
- **Grumpy hovers.** Hovering `{{,143}}` says it is `;49221 SUB #2`, argument 2 of the `READ OUT` that renders the template.
- **Go to the template** from the `"path.html"` in `WITH TEMPLATE "path.html"`.
- **`(16000)`,** the label every request comes in at, has a hover, and go to definition lists the routes.
- **Inlay hints** name template arguments: `,144` after `;49221 SUB #1`, and `,144 to ,143` after a `READ OUT #2 WITH TEMPLATE`.

If only `ciwapa-*` is installed, `.ioi` files say to install `ioi-*` instead of pretending to understand them.

## When something's wrong

Each extension tells you once, with a way to open the `serverPath` setting, when:

- no compiler is found on `PATH`;
- the server crashes;
- the server's version isn't the extension's.

The server logs its own failures to stderr, which each editor shows in its LSP log: VS Code's **Output › INTERCAL**, JetBrains' `idea.log`, and Neovim's `:LspLog`. A broken file doesn't take the server down with it.

## For extension authors

The protocol, including the requests and notifications beyond LSP, is in [`packages/ciwapa_lsp/README.md`](../packages/ciwapa_lsp/README.md). Each extension is a Lattice workspace (`vscode`, `jetbrains`, `neovim`) whose `lint`, `test` and `build` tasks run in Docker through `tools/in-docker`, so nothing is installed on your machine. `test` includes the smoke test, which opens a sample in the real editor, headless, sees a diagnostic and follows a go to definition.
