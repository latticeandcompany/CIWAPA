# INTERCAL for Neovim

INTERCAL, EXTRACAL and INTERCAL on Interstates in Neovim, using the language server built into [CIWAPA](https://github.com/latticeandcompany/CIWAPA), the Compiler for INTERCAL With A Pronounceable Acronym. Open a `.i` file and you see what the compiler sees: every compile error at once, where it happens, explained. You can jump from `NEXT (1000)` to the routine, see which `COME FROM` will hijack a line before it hijacks it, and know how polite the file is before the compiler tells you.

The plugin is a few hundred lines of Lua with no dependencies. The language server does the work.

## Install

You need Neovim 0.11 or later, and a CIWAPA compiler on your `PATH`. The compiler is the language server too (`ciwapa-llvm lsp`), so if you can build INTERCAL you have everything. Get an archive from [CIWAPA's releases](https://github.com/latticeandcompany/CIWAPA/releases): `ioi-<flavor>` if you write INTERCAL on Interstates, otherwise `ciwapa-<flavor>`. `ioi-*` understands everything `ciwapa-*` does, plus `.ioi` files and their templates.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'latticeandcompany/intercal-neovim', opts = {} }
```

With Neovim 0.12's built-in `vim.pack`:

```lua
vim.pack.add({ 'https://github.com/latticeandcompany/intercal-neovim' })
```

Or as a plain package:

```sh
git clone https://github.com/latticeandcompany/intercal-neovim \
  ~/.local/share/nvim/site/pack/intercal/start/intercal-neovim
```

Don't lazy-load it on the `intercal` filetype. The plugin is what decides which files are INTERCAL, so Neovim would wait for a filetype that nothing can set.

The plugin's version matches the compilers'. If they differ, it says so once, and things still mostly work until they don't.

## Settings

Everything is optional. Without a `setup` call, the plugin runs with these defaults:

```lua
require('intercal').setup({
  serverPath = '',      -- the CLI to run as the server; empty means search PATH
  flavor = 'llvm',      -- 'llvm' or 'dart': which CLI to look for
  traditional = false,  -- like --traditional: INTERCAL-72 only, extensions are errors
  clockface = false,    -- like --clockface: IIII instead of IV
})
```

With `serverPath` empty, the plugin looks for `ioi-<flavor>` on your `PATH`, then `ciwapa-<flavor>`. The same CLI runs `:IntercalRun` and `:IntercalBuild`.

The compiler flags live here and nowhere else. Files carry no hidden configuration, because INTERCAL source is hard enough to read already.

`traditional` and `clockface` take effect as soon as you call `setup` again. A new `serverPath` or `flavor` applies to servers started afterwards: restart Neovim, or run `:lsp restart` on 0.12.

The server is an ordinary Neovim LSP config called `intercal`, so `vim.lsp.config` can change any part of it after `setup`:

```lua
vim.lsp.config('intercal', { cmd = { '/opt/ciwapa/bin/ioi-llvm', 'lsp' } })
```

## Which files are INTERCAL

`.2i` to `.7i`, `.2xc` to `.7xc`, `.ioi` and `.2ioi` always are.

`.i` and `.xc` are taken too, by SWIG and XMOS XC, who got there first. One of those files is INTERCAL when a statement turns up in its first 50 lines: a line that starts with `DO` or `PLEASE`, maybe after a `(label)`. Otherwise the plugin asks once whether to open it as INTERCAL anyway. It remembers the answer until you quit Neovim, and it never writes the answer to a file.

## What you get

All of these come from the server, through Neovim's own LSP support:

- **Diagnostics** for every compile error, on the statement that causes it. A `DO NOTE` line is an undecodable statement, which is how INTERCAL does comments, and it gets a quiet hint saying it would be E000 if it ever ran.
- **Hovers** (`K`) explain error codes, operators, sigils, gerunds and library routines, including what goes into a routine and what comes out.
- **Go to definition** (`CTRL-]`), **references** (`grr`) and **rename** (`grn`) for labels. Renaming in a file with computed `COME FROM`s warns that a computed target might still mean the old number.
- **The COME FROM lens.** Above every statement that something comes from, a code lens lists the lines it comes from. Run it with `grx` on 0.12, or `:lua vim.lsp.codelens.run()` on 0.11, to go there.
- **Inlay hints**: constants in decimal, hex and binary, each statement's number as runtime errors report it, the politeness ratio on the first statement, and template arguments in `.ioi` files.
- **Quick fixes** (`gra`) for E079 and E099, which add or remove just enough PLEASEs.
- **Completion** for statement keywords, labels and gerunds, through `CTRL-X CTRL-O`, or as you type with `vim.lsp.completion.enable()`.
- **Highlighting** from the compiler's lexer, as semantic tokens. There is no syntax file, so the file stays plain until the server starts. The colors are Neovim's standard `@lsp.type.*` highlight groups. Variable kinds arrive as modifiers (`spot`, `twoSpot`, `tail`, `hybrid`), so `vim.api.nvim_set_hl(0, '@lsp.typemod.variable.twoSpot.intercal', { link = 'Constant' })` gives two-spot variables a color of their own.

And from the plugin:

- **`gc`, `gcc`, and `:IntercalToggleComment`** turn `DO X` into `PLEASE NOTE X` and back, keeping labels, across whole statements. `PLEASE NOTE` reads as `PLEASE NOT E…`, an abstained statement that never runs. Set `vim.g.no_intercal_maps = true` to keep Neovim's own `gc`.
- **`:IntercalRun` and `:IntercalBuild`** save the file and run `<cli> run` or `<cli> build` on it in a terminal split. Runs are interactive, since INTERCAL reads its input one spelled-out digit at a time.
- **Library sources.** Going to definition on a system-library label like `(1009)` opens the routine as a read-only `ciwapa-lib:` buffer. The text comes from the server, so nothing is written to disk.
- **Templates.** With `ioi-*`, any `.html` file you open while a `.ioi` program is open joins the same server, which reports template errors in the template. HTML with no INTERCAL program open is left alone.

## When something is wrong

The plugin warns once for each of these, and the warning says what to do:

- **No server.** Nothing called `ioi-<flavor>` or `ciwapa-<flavor>` is on your `PATH`, or `serverPath` points at nothing.
- **The server crashed.** Reopen the file to start it again.
- **Wrong version.** The server and the plugin come from different releases.
- **Only `ciwapa-*` is installed** and you opened a `.ioi` file. The file gets one diagnostic asking you to install `ioi-<flavor>`, since `ciwapa-*` has never heard of Interstates.

`:checkhealth vim.lsp` shows what the `intercal` client is doing.

## License

ISC, the same as [CIWAPA](https://github.com/latticeandcompany/CIWAPA). This plugin is developed in CIWAPA's `editors/neovim`, so file issues and pull requests there.
