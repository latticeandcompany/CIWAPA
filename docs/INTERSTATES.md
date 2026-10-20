# INTERCAL on Interstates

INTERCAL on Interstates is a web framework for EXTRACAL. You write a site as one INTERCAL program.
`gross` runs that program once per request, CGI style, and its output becomes the response. On top
of EXTRACAL it adds:

- **routes**, which are `COME FROM`s with a path;
- **templates**, HTML files with `{{ }}` double grumpies;
- the request and response, through a library block and two string arrays;
- **ActiveCassette**, a database layer where tables and columns are numbered rather than named.

This guide shows how to use each part. The rules behind every detail are in
[`INTERSTATES_PLAN.md`](INTERSTATES_PLAN.md) and decisions L35–L42 in
[`SPEC_DECISIONS.md`](SPEC_DECISIONS.md). The library's routine tables are in
[`apps/interstates/README.md`](../apps/interstates/README.md).

## Getting it

Download the `ioi-<flavor>-<os>-<arch>` archive for your platform from a release. It holds:

- `ioi-dart` or `ioi-llvm`;
- `gross`;
- ActiveCassette's SQLite;
- the toolchain the compiler builds with.

Its `README.txt` covers unpacking and unsigned binaries.

`ioi-dart` and `ioi-llvm` are CIWAPA's two compilers under new names. They have the same `build`,
`run` and `doctor` commands, plus one flag:

```
ioi-llvm build -s --no-random-bug site.xc -o site   # an Interstates site
ioi-llvm build prog.xc                              # plain EXTRACAL, as ciwapa-llvm builds it
```

`--no-random-bug` turns off CIWAPA's random compiler bug. Without it, each statement has a 1 in 128
chance of an E774 planted at build time. In a site of any size, that means some route answers 500
until the next build moves the bug somewhere else. Leave the flag off for the authentic
experience.

`-s` turns on everything in this guide. It takes binary EXTRACAL files only (`.xc`, `.2xc`), and
it can't be combined with `--traditional` (E111).

## Hello, world

`hello.xc`:

```
NOTE At the start of the program, handle the default route.

DO COME FROM (16000)
PLEASE READ OUT #0 WITH TEMPLATE "hello.html"
GIVE UP
```

`hello.html`, next to it:

```html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Hello, world!</title></head>
<body><h1>Hello, world!</h1></body>
</html>
```

```
ioi-llvm build -s --no-random-bug hello.xc -o hello
gross ./hello
```

Then open <http://127.0.0.1:10585/>.

Under `-s`, two of the site's habits are allowed:

- text before the first statement is a comment, so the `NOTE` line needs no statement identifier;
- a bare `GIVE UP` means `DO GIVE UP`.

Politeness is still checked. Between a fifth and a third of a program's statements must say
`PLEASE` (E079 for too few, E099 for too many), so the fragments in this guide need a few more
before they stand alone as programs.

## Routes

A program starts at `(16000)`, a label no program defines, so it starts at a `COME FROM (16000)`.

```
PLEASE COME FROM (16000) WITH ROUTE "/blog"
DO COME FROM (16000) WITH ROUTE "/blog/tag/:name"
DO COME FROM (16000)
```

- **A route** is a `COME FROM (16000) WITH ROUTE "pattern"`. A pattern starts with `/`, and a
  `:name` segment is a parameter. `?`, `#` and `%` can't appear in one (E442): fixed segments are
  compared with the request's decoded segments, so write `/café`, not `/caf%C3%A9`.
- **The catch-all** is a bare `COME FROM (16000)`. It handles any path no route matches.
- **No match:** without a catch-all, a request no route matches gets a 404 (E440).

**Choosing a route.** The most specific route wins. Routes are compared segment by segment from
the left, and at the first difference a fixed segment beats a parameter. So `/blog/new` wins over
`/blog/:id` for `/blog/new`. Two routes of the same shape, such as `/a/:x` and `/a/:y`, fail the
build (E441).

**How paths split.** A path splits on `/` and keeps empty segments, so `/blog/` doesn't match
`/blog`. Each segment is percent-decoded as UTF-8, so `%2F` stays inside its parameter. The query
string never takes part in choosing a route.

**Route parameters.** A route's parameters are in `;4400`: `;4400 SUB #1` is the first `:param`.
Copy one into a tail array to work with it:

```
DO ,1 <- ;4400 SUB #1
```

### Restricted routes

A route that comes from a label other than `(16000)` is **restricted**. It can only be reached by
following a link on the page that the labelled `READ OUT` renders.

```
(20) DO READ OUT #2 WITH TEMPLATE "templates/item.html"
...
DO COME FROM (20) WITH ROUTE "/blog/post/:id"
```

The build checks the link: line (20) must render a template that links to the route (E443). A link
is the value of an `href`, `action`, `src` or `formaction` attribute that starts with `/`. A
`{{ }}` segment in a link counts only where the route has a parameter, so
`<a href="/blog/post/{{,144}}">` links `/blog/post/:id`.

At run time, the request's `Referer` must be a page on the same host whose route can reach line
(20). Anything else is a 403 (E403). That includes no `Referer` at all, another site, and a page
that can't reach (20). The compiler works out which routes can reach which lines by following
NEXTs, RESUMEs, COME FROMs, threads and TRY AGAIN. A program with computed or gerund COME FROMs, or
CREATE, can't be followed, so in it every route may reach every line.

A route is a statement that does nothing when it runs. A `WITH ROUTE` COME FROM is never an
ordinary trap door, and many of them may share a label.

## Templates

```
PLEASE READ OUT #n WITH TEMPLATE "path.html"
```

This renders a template with `n` arguments.

- **Where templates live.** The path is relative to the source file's folder. The template is
  compiled into the program, so the site doesn't need its templates at run time.
- **Arguments.** The arguments are the strings in `;49221 SUB #1` to `SUB #n`. A template names
  them counting down from 144: `,144` is `;49221 SUB #1`, `,143` is `SUB #2`, and so on. `n` must
  be the number of arguments the template takes, which is set by the lowest `,m` it names: a
  template that names only `,142` takes three (E821). An argument the program never stored
  prints as the empty string.

```html
<li><a href="/blog/post/{{,144}}">{{,143}}</a></li>
```

A grumpy holds one of these:

| Inside | Prints |
|---|---|
| `,m` | template argument `;49221 SUB (145-m)` |
| `;4400 SUB e` | that route parameter |
| `;49221 SUB e` | that template argument, chosen at run time |
| any other expression | a number, as a butchered Roman numeral |

**Escaping.** `{{ }}` HTML-escapes strings, and `{{{ }}}` prints them as they are.

**Numbers.** Numbers print as READ OUT's numerals. The overlines are CSS in text, and combining
characters inside attribute values, `<title>` and `<textarea>`. A program run by hand in wimp mode
(`+wimpmode`) prints them in plain decimal; gross never passes it.

**Where a grumpy may go:**

- **Allowed:** in text, in a quoted attribute value, or in a `<title>` or `<textarea>`.
- **E820:** in a tag's name, between attributes, in an unquoted value, or inside `<script>` or
  `<style>`. E820 also covers any `{{` that isn't a valid grumpy.

A template's output is written in one piece, so an error partway through writes none of it.

To build a page from pieces, render several templates in a row, a loop included. The blog's list
page is a header template, one `item.html` per post rendered in a loop, then a footer.

## Strings

`;4400` (route parameters, read-only) and `;49221` (template arguments) are arrays of strings. Each
element is a whole string, and a string is a tail array of code points everywhere else. Only these
statements move strings:

```
DO ,1 <- ;4400 SUB #1
DO ,1 <- ;49221 SUB #2
DO ;49221 SUB #1 <- ,1
DO ;49221 SUB #1 <- ;4400 SUB #2
DO ;49221 SUB #1 <- ;49221 SUB #2
```

Any other use of `;4400` or `;49221`, such as a string where a number belongs or a STASH, is E822
when the statement runs. `;4400 SUB n` past the route's parameters is E241.

## The request and the response

A `-s` program gets the library block (16001)–(16130) when it NEXTs into it, as it does the system
library. Inputs and results are strings in tail arrays, one code point per element. Lookups set
`.1` to #1 when they find something and #2 when they don't. To read the form field `title`:

```
DO ,1 <- #5
DO ,1 SUB #1 <- #116
DO ,1 SUB #2 <- #105
DO ,1 SUB #3 <- #116
DO ,1 SUB #4 <- #108
DO ,1 SUB #5 <- #101
PLEASE (16050) NEXT
```

`,2` now holds the field, and `.1` says whether there was one.

| Entry | Does |
|---|---|
| (16001) | `,1` = the request method |
| (16010) | `,1` = the query string |
| (16020) | `,2` = the header named `,1` |
| (16030) | `,2` = the cookie named `,1` |
| (16040) | `,2` = the query parameter named `,1` |
| (16050) | `,2` = the form field named `,1` |
| (16060) | `,1` = the request body |
| (16100) | sets the status to `.1` |
| (16110) | adds the header `,1`: `,2` |
| (16120) | sets the cookie `,1` = `,2` |
| (16130) | redirects to `,1` with 303 See Other |

- **Defaults.** The response is `200 OK`, `text/html; charset=utf-8`, unless the program says
  otherwise.
- **When headers go out.** Headers are written just before the body's first byte, so set them
  first. Changing them after that is E823. A header or cookie that isn't well formed is E828.
- **Reading the body.** `WRITE IN` reads the request body, as does (16060). Both read stdin, so
  use one or the other.
- **Ending the response.** `GIVE UP` ends the response.

## ActiveCassette

**Numbers, not names.** ActiveCassette numbers tables and columns from #1, in the database's own
order (for SQLite, the order they were made). `#t~#c$#c` is table `#t`, columns `#c` and `#c`. A
number past the end is E824. Every value goes to the database as a bound parameter, never as SQL
text.

```
DO ;49221 <- 'FROM DATABASE #1~#2$#3' HAVING #1 ;4400 SUB #1
DO ;49221 <- 'FROM DATABASE #1~#1$#2' SUB .5
DO INTO DATABASE #1~#2$#3 <- ,1 + ,2
DO INTO DATABASE #1~#2 <- ,1 HAVING #1 .7
DO FORGET DATABASE #1 HAVING #1 .7
PLEASE DO AMNESIA
```

- **Reading.** A read puts one row's columns in `;49221 SUB #1` on, ready for a template. It reads
  row 1 by default, or row `r` with `SUB r`. With no such row, `;49221` stays empty. Integers become
  their digits and NULL the empty string. `HAVING #c value + #c value` filters on columns.
- **Writing.**
  - `INTO DATABASE` inserts, and takes one value per column (E827).
  - With `HAVING`, it updates instead.
  - `FORGET DATABASE` deletes the matching rows, or all of them without `HAVING`.
- **Wiping.** `AMNESIA` drops every table.
- **Raw SQL and counts.** (16200) runs one statement of raw parameterized SQL, and (16210) counts
  what the last statement read or changed. See the [routine table](../apps/interstates/README.md#activecassette).

**Connecting.** The connection is `DATABASE_URL`, which `gross --database` sets. Without it, the
connection is `sqlite:./app.db`, a file made on first use. Write an absolute path as
`sqlite:/srv/app.db`; `sqlite://` is refused.

- **SQLite** comes with the compiler. `ioi-llvm` links it into the program. An `ioi-dart` program
  loads it from where it was when the program was built, so move the compiler's folder or copy the
  program to another machine and its database requests fail with E825 until you rebuild.
- **Other databases** need an adapter. That is a shared library implementing
  [`ioi_adapter.h`](../apps/interstates/runtime/ioi_adapter.h), named by `IOI_ADAPTER_<SCHEME>`.
  Linux programs built by an `ioi-llvm` archive are static and can't load one.
- **Errors.** A database that can't be reached is E825, and a statement it refuses is E826. Either
  way, the database's reason goes to stderr.

## gross

```
gross [--port 10585] [--bind 127.0.0.1] [--static <dir>] [--database <url>] [--timeout 30] ./site
```

**One run per request.** gross runs the program once for each request. The request arrives in CGI
environment variables (`REQUEST_METHOD`, `REQUEST_URI`, `HTTP_…`) and the body on stdin.

**Static files.** `--static` answers a GET or HEAD for a file in its folder before the program sees
the request.
There is no `public/` convention and no index file.

**Error pages.** gross turns an ICL error into a page with the error's four lines:

- E403 is 403, E440 is 404, and any other error is 500;
- a run past `--timeout` is 504 (E504);
- output that isn't a CGI response is 500 (E829).

**Logs.** gross logs one line per request to stderr. Just before it come the program's own stderr
lines, each prefixed with its name.

gross speaks a small HTTP/1.1: one request per connection, and no chunked bodies. It is a
development server. Don't put it on the internet. Nothing about this framework belongs there.

## The sample blog

[`apps/interstates/examples/blog`](../apps/interstates/examples/blog) is a whole site with every
part of this guide. It lists posts, shows one at a restricted `/blog/post/:id`, and creates them
from a form whose `POST` route is restricted to the form's page. Its README says how to run it.

## Errors

Interstates' own errors have codes CIWAPA doesn't use. Each one's official text, joke and tests
are under "INTERCAL on Interstates error codes" in [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md).

| Code | When |
|---|---|
| E403 | a restricted route reached without its page |
| E440 | no route matches |
| E441 | two routes are equally specific |
| E442 | a route pattern isn't a path |
| E443 | a restricted route its page doesn't link |
| E504 | the run outlasted `gross --timeout` |
| E820 | a template doesn't parse, or a grumpy sits where no value can go |
| E821 | a template got the wrong number of arguments |
| E822 | a string where a number belongs, or the other way round |
| E823 | the headers were changed after the body started |
| E824 | a table or column past the end of the schema |
| E825 | ActiveCassette can't reach the database |
| E826 | the database refused a statement |
| E827 | an `INTO DATABASE` with the wrong number of values |
| E828 | a malformed response header or cookie |
| E829 | the program didn't answer in CGI |

A missing template is CIWAPA's E777, as for a missing source file.
