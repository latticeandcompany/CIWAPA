# ciwapa_lsp

The INTERCAL language server. It isn't a program of its own: every CLI runs it as `lsp`
(`ciwapa-llvm lsp`, `ciwapa-dart lsp`, and the same command of any compiler built on CIWAPA's), on
stdin and stdout, with the same front end the CLI builds with. A compiler built on CIWAPA's gets the server for its own
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

## What it provides

Diagnostics, hover, definition, references, rename (with `prepareRename`), code lens,
`workspace/executeCommand`, completion, inlay hints, full semantic tokens (the legend is in the
`initialize` result) and code actions. Diagnostics are Errors, except an Information hint on each
undecodable statement. [`docs/EDITORS.md`](../../docs/EDITORS.md) describes each feature as a user
sees it.

## Beyond LSP

### `intercal/librarySource` (request)

Go to definition on a library label returns a `Location` whose URI has the `ciwapa-lib:` scheme, such
as `ciwapa-lib:/syslib.i`. A client registers the scheme and asks the server for the text, so nothing
is written to disk:

```json
{"method": "intercal/librarySource", "params": {"uri": "ciwapa-lib:/syslib.i"}}
→ {"text": "..."}
```

An unknown URI is `InvalidParams`. The documents are `syslib.i`, EXTRACAL's library blocks, and any
a language built on CIWAPA's adds.

### `intercal/toggleComment` (request)

```json
{"method": "intercal/toggleComment",
 "params": {"textDocument": {"uri": "file:///w/a.i"},
            "range": {"start": {"line": 0, "character": 0}, "end": {"line": 2, "character": 0}}}}
→ [TextEdit, ...]
```

The edits for the document's statements on the lines the range covers. A range that ends at
character 0 of a later line leaves that line out, as editors' line comments do. Every statement
becomes `PLEASE NOTE`, unless every one already is `PLEASE NOTE` or `DO NOTE`, in which case they all
become `DO`. Labels are kept.

### `intercal/politeness` (notification, server to client)

Sent with every round of diagnostics for a document:

```json
{"method": "intercal/politeness",
 "params": {"uri": "file:///w/a.i", "polite": 4, "total": 17, "text": "PLEASE 4/17, 24%"}}
```

`text` is empty when the file has no statements, so a status bar can clear. A client that shows it
sets `politenessInStatusBar: true` in `initializationOptions`, and the server leaves out the inlay
hint that would repeat it.

### The `intercal.goTo` command

Code lenses carry `{"command": "intercal.goTo", "arguments": [uri, {"line": 41, "character": 0}]}`.
The server lists the command in `executeCommandProvider`; when the client sends it back with
`workspace/executeCommand`, the server answers by sending `window/showDocument` (`takeFocus`, and the
position as the selection). A client that can't route commands to the server can handle the command
itself.

### `initializationOptions`

`{traditional, clockface, politenessInStatusBar}`, all booleans, all false when left out. Settings
changes come as `workspace/didChangeConfiguration` with `{traditional, clockface}`, bare or under an
`intercal` key.

## Building on it

A compiler built on CIWAPA's passes a `LanguageExtension` to `runLanguageServer` to add what its own
language needs, without the server learning which language it is:

- `errorHelp`, `routinesFor`, `labelHelp` and `libraries`: hover text for its errors and library
  routines, and the library documents it includes;
- `definitionsOf`: where go to definition takes a label no statement defines, such as an entry point;
- `keywordsFor`: the words that start its own statements, for completion;
- `inlayHintsFor`: inlay hints of its own;
- `companionsOf`: the files a program depends on that aren't programs, such as templates. The server
  publishes their diagnostics, answers hovers in them, and goes to them from where the program names
  them. An open companion is checked as the editor holds it.

`package:ciwapa_lsp/test_client.dart` is a client for tests: it runs a server in the same isolate, or
talks to one in another process, the way an editor would.
