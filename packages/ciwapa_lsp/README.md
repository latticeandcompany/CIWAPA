# ciwapa_lsp

The INTERCAL language server. It isn't a program of its own: every CLI runs it as `lsp`
(`ciwapa-llvm lsp`, `ciwapa-dart lsp`, `ioi-llvm lsp`, `ioi-dart lsp`), on stdin and stdout, with
the same front end the CLI builds with. A compiler built on CIWAPA's gets the server for its own
files by handing its `Frontend` to `runCli`.

The JSON-RPC layer and the LSP types are hand-rolled (Q169), so the package depends on
`ciwapa_core` alone.

## Lifecycle and sync

- `initialize` answers with `serverInfo`: the CLI's name and the compilers' version, which the
  editor extensions compare with their own (Q179).
- Text sync is full (`change: 1`). Every change is analyzed from scratch.
- Positions are UTF-16, counted on the text as the editor holds it, `\r` included.

## Settings

The compiler flags come from the editor (Q160), in `initializationOptions` and in
`workspace/didChangeConfiguration` (either bare or under an `intercal` key):

| Setting | Flag | Effect on the server |
|---|---|---|
| `traditional` | `--traditional` | INTERCAL-72 only, so extensions are E111 |
| `clockface` | `--clockface` | none: it changes what programs print, not what the compiler says |

The random compiler bug (E774) is never planted, as if `--no-random-bug` were always given.
