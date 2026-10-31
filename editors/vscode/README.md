# INTERCAL for VS Code

INTERCAL, EXTRACAL and INTERCAL on Interstates in VS Code and its forks, served by [CIWAPA](https://github.com/latticeandcompany/CIWAPA)'s language server. Writing INTERCAL should be hard because of INTERCAL, not because of the editor. This extension takes care of the second part.

## What you get

- **Every compile error at once,** on the statement that caused it, instead of one per build. Hover one for the exact `ICLnnnI` line, its joke, and what to do about it.
- **Highlighting** from the compiler's own lexer. The `DO NOTE` lines everyone uses as comments look like comments, because to the compiler they are statements it can't understand, which is close enough.
- **Go to definition, find references and rename** for labels, from `NEXT`, `ABSTAIN FROM`, `REINSTATE`, `COME FROM` and `NEXT FROM`. System library labels open the library's source, read-only.
- **The COME FROM lens:** above every statement that something comes from, a list of who. You will know it's going to be hijacked before it's hijacked.
- **Completion and inlay hints:** statement keywords, labels and gerunds; constants in decimal, hex and binary; statement numbers, as runtime errors count them.
- **A politeness meter** in the status bar (`PLEASE 4/17, 24%`). The compiler wants between a fifth and a third of your statements to say PLEASE, and there are quick fixes for when you've misjudged it.
- **Toggle comment** (Ctrl+/, or Cmd+/ on a Mac) turns `DO X` into `PLEASE NOTE X`, which the compiler reads as a polite statement it has been asked not to run. Toggling it back gives `DO X`.
- **Run this file** and **Build this file**, in the command palette, run the compiler in a terminal.

## Install

1. Install a CIWAPA compiler from [Releases](https://github.com/latticeandcompany/CIWAPA/releases) and put its `bin/` on your `PATH`. The language server is the compiler (`ciwapa-llvm lsp`), so there's nothing else to install. For `.ioi` files you need the `ioi-<flavor>` archive, which reads everything `ciwapa-<flavor>` does and Interstates too.
2. Download `intercal-vscode-<version>.vsix` from the same release, and install it with **Extensions: Install from VSIX...** or `code --install-extension intercal-vscode-<version>.vsix`.

The extension and the compiler ship together and expect the same version. If they don't match, you'll be told once, politely.

## Files

`.2i`–`.7i`, `.2xc`–`.7xc`, `.ioi` and `.2ioi` are always INTERCAL. `.i` and `.xc` are also SWIG interfaces and XMOS XC, so those count as INTERCAL only when one of their first 50 lines starts with `DO` or `PLEASE` (after an optional label). When one doesn't, you're asked once whether to open it as INTERCAL anyway, and the answer is remembered for that file in this workspace.

## Settings

| Setting | Default | What it does |
|---|---|---|
| `intercal.serverPath` | empty | The compiler to use. Empty means `ioi-<flavor>`, then `ciwapa-<flavor>`, on `PATH`. User settings only, so a workspace can't choose a program for you to run. |
| `intercal.flavor` | `llvm` | Which compiler to look for: `llvm` or `dart`. They say the same things about your program. |
| `intercal.traditional` | `false` | INTERCAL-72 only (`--traditional`). |
| `intercal.clockface` | `false` | IIII instead of IV (`--clockface`), for Run and Build. |

## When something's wrong

If the server can't be found, crashes, or is the wrong version, the extension says which, once, and offers to open `intercal.serverPath`. If only `ciwapa-*` is installed, `.ioi` files say so instead of pretending to understand them.

## License

ISC, like the rest of CIWAPA.
