# INTERCAL on Interstates

A web framework for INTERCAL (goal 3, [`docs/INTERSTATES_PLAN.md`](../../docs/INTERSTATES_PLAN.md)).
The user guide is [`docs/INTERSTATES.md`](../../docs/INTERSTATES.md); this file is about how it's
built, and the library's routine tables.
`ioi-dart` and `ioi-llvm` compile EXTRACAL; with `-s` they add the Interstates statements, and
the program becomes a CGI program that `gross` runs once per request.

## How it fits on CIWAPA

CIWAPA knows nothing about Interstates (R1, L36). `apps/interstates` uses CIWAPA's generic hooks:

- **Front end:** `InterstatesParser` extends CIWAPA's parser through a `LexerDialect` and the
  `body`/`extendBody` overrides. Its statements become `HostCall`s, which lower to a PETITION
  carrying computed values, and its routes become do-nothing statements whose ordinals are entry
  points.
- **Host:** every `-s` program runs with a host beside CIWAPA's runtime:
  `lib/runtime/ioi_host.dart` for ioi-dart and `runtime/host.c` for ioi-llvm, which are twins.
  The host picks where the program starts, runs the Interstates services, and writes the CGI
  headers just before the body. `tool/embed_runtime.dart` regenerates
  `lib/src/runtime_sources.g.dart` from them and from the library blocks,
  `runtime/interstates.xc` and `runtime/activecassette.xc`.

## The library blocks, (16001)–(16999)

A `-s` program gets each block when it NEXTs to a label in its range, like the system library:
(16001)–(16199) for the request and response, and (16200)–(16999) for ActiveCassette, so only a
program that uses a database needs SQLite. Each
routine is a single PETITION of its own number. Strings are tail arrays of code points; a lookup
sets `.1` to #1 when it finds something and #2 when it doesn't, leaving the result alone (Q139).

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (16001) | | ,1 = the request method | |
| (16010) | | ,1 = the query string | as sent, without the `?` |
| (16020) | ,1 = header name | ,2 = its value; .1 | ASCII letters, digits, `-` and `_`, in any case |
| (16030) | ,1 = cookie name | ,2 = its value; .1 | from the `Cookie` header |
| (16040) | ,1 = name | ,2 = the query parameter; .1 | decoded; the first one wins |
| (16050) | ,1 = name | ,2 = the form field; .1 | from an `application/x-www-form-urlencoded` body |
| (16060) | | ,1 = the request body | one byte per element |
| (16100) | .1 = status | | |
| (16110) | ,1 = name, ,2 = value | | adds a response header |
| (16120) | ,1 = name, ,2 = value | | sets a cookie, `Path=/` |
| (16130) | ,1 = location | | redirects with 303 See Other |

- **The response** starts with `Status:`, `Content-Type: text/html; charset=utf-8` unless the
  program set one, and the program's headers in order. They are written just before the body's
  first byte, or at GIVE UP if there is no body; changing them after that is E823, and a line
  break in one is E828.
- **The body** is read once, `CONTENT_LENGTH` bytes from stdin. `WRITE IN` reads stdin too, so
  a program uses one or the other.

## ActiveCassette

Tables and columns are numbered, never named: table `#t` is the *t*-th in the database's own order
and column `#c` the *c*-th of that table, both from #1.

```
DO ;49221 <- 'FROM DATABASE #1~#2$#3' SUB .5 HAVING #1 ,3 + #4 .2
DO INTO DATABASE #1~#2$#3 <- ,1 + ,2
DO INTO DATABASE #1~#2 <- ,1 HAVING #1 .7
DO FORGET DATABASE #1 HAVING #1 .7
PLEASE DO AMNESIA
```

| Entry | Inputs | Results | Notes |
|---|---|---|---|
| (16200) | ,1 = SQL, :1 = parameters, :2 = row | ;49221 = that row's columns, :1 = rows returned (or changed) | parameters are `;49221 SUB #1` to `SUB :1`, as text |
| (16210) | | :1 = rows the last read matched, or the last write changed | |

The connection comes from `DATABASE_URL` (`sqlite:./app.db` by default). SQLite is built in; any
other scheme needs an adapter: a shared library implementing `runtime/ioi_adapter.h`, named by
`IOI_ADAPTER_<SCHEME>`. ioi-* find SQLite in `IOI_LIB`, or in a release archive's `lib/`;
`tool/activecassette.sh <dir> <clang> <triple> <cc>` makes it. ioi-llvm programs built by a release
archive for Linux are static, so they can't load user adapters (L42).

