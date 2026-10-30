# INTERCAL on Interstates: plan for goal 3

INTERCAL on Interstates ("IoI") was an April Fools' joke from 2013: a web framework for INTERCAL, in the style of Ruby on Rails, with a 346-byte "download" that contained only `APRIL FOOL'S! :)`. Goal 3 makes the joke real.

This is the third of five `/goal` runs: **CIWAPA (Mode 1)** → **EXTRACAL** → **INTERCAL on Interstates** → **Editors** → **Playground**. It starts only after goal 2 is done, because Interstates programs are EXTRACAL programs (Q88).

Background: [`PLAN.md`](PLAN.md) (architecture, workflow), [`EXTRACAL_PLAN.md`](EXTRACAL_PLAN.md) (the language Interstates builds on), and [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) (every answer, including the Q-numbers cited here).

---

## Vision

A working web framework for INTERCAL, **inspired by the parody site** at intercaloninterstates.org rather than bound to it (Q86 B). The site's best jokes are kept on purpose (the punchlines), and its hello world runs exactly as printed. Underneath, it's a real CGI-style server, real routing, real templates, and a real database layer, all driven by `COME FROM`.

## User Experience

```
ioi-llvm build -s hello.xc -o hello      # -s = 'States: turns on the Interstates extensions
gross ./hello                            # serves it on http://127.0.0.1:10585
```

- The user writes `.xc` (EXTRACAL) source with the Interstates extensions and compiles it with `ioi-dart` or `ioi-llvm` (Q112).
- `gross` runs the compiled program once per request (Q94).
- Routes are declared with `COME FROM (...) WITH ROUTE "/path/:param"`, pages are rendered with `READ OUT #n WITH TEMPLATE "file.html"`, and data comes from ActiveCassette's `FROM DATABASE`.
- When something goes wrong, the browser shows an `ICL`-style error page.

### Punchlines kept from the site (Q93, items 1–7)
| # | Punchline |
|---|---|
| 1 | `gross`, the "General READ OUT Server System", listening on port **10585** by default |
| 2 | The `-s` ("'States") compile flag enables the Interstates extensions |
| 3 | The database layer is called **ActiveCassette** |
| 4 | `{{ }}` "double grumpies" in templates |
| 5 | The magic arrays `;4400` (route parameters) and `;49221` (template arguments), which appear in templates as `,144` counting downward |
| 6 | `(16000)` is the implicit entry label |
| 7 | The site's hello world compiles and runs exactly as written |

Declined: item 8 (every other site example runs as written) and item 9 ("under 3MB").

## Requirements

### R1. Its own implementation, built on EXTRACAL (Q87, Q88, Q112)
- It lives in `apps/interstates/`, which reuses `ciwapa_core` as a library, adds the Interstates syntax, and lowers to the shared IR.
- It ships its own CLIs, `ioi-dart` and `ioi-llvm`, with the same subcommands as CIWAPA's (`build`, `run`, `doctor`).
- Without `-s`, the `ioi-*` CLIs compile plain EXTRACAL. With `-s`, the Interstates extensions are on.
- CIWAPA's own packages and CLIs never learn about Interstates.
- Sources are `.xc`. Everything from EXTRACAL and Mode 1 applies, including politeness checking: PLEASE is mandatory on the web too (Q147).

### R2. `gross` (Q94, Q120)
```
gross [--port 10585] [--bind 127.0.0.1] [--static <dir>] [--database <url>] ./program
```
- It's CGI-style: each request starts the program fresh, with clean variables.
  - The request reaches the program through CGI/1.1-style environment variables plus stdin (the body).
  - The program's stdout is the response.
  - `GIVE UP` ends the response.
- Static files are served only when `--static` names a folder. There's no hidden `public/` convention.
- `--database` or `DATABASE_URL` picks the ActiveCassette connection, and is passed along to each run.
- Logs go to stderr.

### R3. Routes (Q113, Q114)
- **Public routes.** `COME FROM (16000) WITH ROUTE "/x"` declares a public route. `(16000)` is implicit; no program defines it.
- **Restricted routes.** `COME FROM (L) WITH ROUTE "/x"`, for any other label `L`, is reachable **only from a page rendered at line `L`**. That's enforced twice:
  - **Compile time:** `L` must be a `READ OUT … WITH TEMPLATE` statement, and its template must contain a link matching `/x`. Otherwise the build fails. This is the site's "static link checking".
  - **Run time:** the request's `Referer` must be a page that line `L` could have rendered. Otherwise `gross` answers **403** with an ICL-style page. This is the "URL security".
- **Not trap doors.** A `WITH ROUTE` COME FROM never fires as an ordinary COME FROM. It's an entry point that `gross` dispatches to. Plain COME FROM keeps its normal meaning.
- **Selection.**
  - Many `WITH ROUTE` COME FROMs may target the same label. They select routes, so they're exempt from E555.
  - A bare `COME FROM (16000)` is the catch-all.
  - More specific routes win: fixed segments beat `:param` segments. A genuine tie fails at compile time.
  - No match and no catch-all gives an ICL-style **404** page.

### R4. Request and response (Q115)
- `;4400` holds the route's `:param` values in order, so `;4400 SUB #1` is the first one.
- The Interstates library block `(16001)`–`(16999)` is called with `NEXT` and auto-included like syslib. It covers:
  - the request method, query string, headers and cookies;
  - setting the status, setting headers, setting cookies, and redirecting.
- `WRITE IN` reads the request body.
- `GIVE UP` ends the response.
- No built-in sessions or authentication in v1.

### R5. The array-of-strings type (Q116)
- `;4400` and `;49221` are a special Interstates-only kind of array whose elements are whole strings. Strings are tail arrays of code points, as in EXTRACAL.
  - `,1 <- ;4400 SUB #1` copies one string into `,1` and resizes `,1` to fit.
  - `;49221 SUB #2 <- ,5` stores a string in the other direction.
- `"..."` string literals are allowed **only** right after `WITH ROUTE` and `WITH TEMPLATE`, so they never clash with rabbit-ear grouping.

### R6. Templates (Q117, Q118)
- Templates are **embedded in the program at compile time**. The link check needs them then anyway.
- `READ OUT #n WITH TEMPLATE "f.html"`: `#n` must equal the number of template arguments, and a mismatch is an error.
- Inside the template, the strings in `;49221` appear as `,144`, `,143`, `,142`, … (`;49221 SUB #1` becomes `,144`).
- `{{ expr }}` (double grumpies) holds any INTERCAL expression.
  - Strings print as text, **HTML-escaped**.
  - `{{{ expr }}}` (triple grumpies) prints raw.
  - **Numbers print as butchered Roman numerals with real CSS overlines.**
- **No loops or conditionals** in templates. A list is built by looping in INTERCAL and rendering one fragment per item.

### R7. ActiveCassette (Q95, Q99, Q119)
- Tables and columns are **numbered, never named**. Table `#t` is the *t*-th table in the database's own schema order, and column `#c` is the *c*-th column of that table.
- **Reads:** `'FROM DATABASE #t~#c$#c$…' HAVING #col value`. Inside a `FROM DATABASE` clause, `~` separates the table from its columns and `$` separates columns. These are list separators, not mingle and select. `HAVING` pairs are equality tests, combined with AND.
- **Writes** use the matching `INTO DATABASE` form (Q145):
  - insert: `DO INTO DATABASE #t~#c$#c <- …`;
  - update: the same form plus `HAVING`;
  - delete: `DO FORGET DATABASE #t HAVING …`.
- **`PLEASE DO AMNESIA`** drops the database: every table in the configured database, through the adapter interface (Q145).
- **Every value is a bound parameter**, so SQL injection is impossible by construction.
- **Escape hatch:** a raw, parameterized SQL routine in the `(16001)`+ block.
- **Swappable databases:** an adapter interface (connect, query, rows/columns, execute). The adapter is picked by the connection URL's scheme when the program runs. **SQLite** is built in and is the default (`sqlite:./app.db`). Users can add their own adapters.

### R8. Both flavors (Q96)
Every feature works in programs built by `ioi-dart` and `ioi-llvm`, held to the same parity rule as goal 1 (Q20).

### R9. Releases (Q121)
- Separate archives named `ioi-<flavor>-<os>-<arch>`, for the same platforms as CIWAPA.
- Each bundles the matching CIWAPA toolchain, the `ioi-*` CLI and `gross`.
- They're built in CI and published by Ryan (Q103).

## Design & Behavior

- **The joke, played straight.** Every punchline behaves exactly like the site claims. Everything the site never specified gets the least surprising real-world behavior.
- **Errors are pages.**
  - 403, 404, and any ICL error during a request render as an ICL-style HTML page: official text, joke line, `ON THE WAY TO STATEMENT n`, `CORRECT SOURCE AND RESUBMIT`.
  - An ICL error inside the program gives HTTP 500.
- **Templates are HTML-first:** escaped by default, raw only when asked.
- **Explicit server flags,** with no magic folders or config files.

## Technical Approach

- **Front end.** `apps/interstates` is a Dart package depending on `ciwapa_core`. It adds the `-s` grammar: `WITH ROUTE`, `WITH TEMPLATE`, `FROM DATABASE`, `INTO DATABASE`, `FORGET DATABASE`, `AMNESIA`, `HAVING`, string literals in the two allowed positions, and the array-of-strings type. The output is the same IR plus a small set of Interstates IR nodes, lowered by both emitters.
- **Route table.** The compiler builds the route table statically. A reachability pass over the IR finds, for each route, which `READ OUT … WITH TEMPLATE` statements it can reach. That powers the run-time `Referer` check: a referring page is allowed when its route can reach line `L`.
- **Templates** are parsed at compile time: `{{ }}`, `{{{ }}}` and links are extracted, then compiled into calls into the runtime.
- **CGI runtime layer.** In both runtimes this reads the environment and stdin into `;4400` and the request routines, buffers headers and status, and writes a well-formed CGI response.
- **`gross`** is a native executable built from Dart in `apps/interstates`. It uses the HTTP/1.1 and socket layer from EXTRACAL's runtime (Q89), and runs one child process per request.
- **ActiveCassette** has one C ABI for adapters, so both flavors can load the same adapter:
  - `ioi-llvm` programs compile the public-domain SQLite amalgamation straight into the C runtime.
  - `ioi-dart` programs load a prebuilt SQLite library for each platform through `dart:ffi`.
  - User adapters are shared libraries that implement the C ABI.

## Affected Areas

- `apps/interstates/`: the Interstates front end, the `ioi-dart` and `ioi-llvm` CLIs, the template compiler, the route table and reachability pass, `gross`, ActiveCassette and its SQLite adapter, the `(16001)`+ library block, examples and docs.
- `packages/ciwapa_dart` (`runtime.dart`) and `packages/runtime_c` (`runtime.c`): only if Interstates needs a hook that EXTRACAL doesn't already provide. Any such hook is added generically, never Interstates-specific.
- `lattice.json`: add the `apps/interstates` workspace.
- CI: the `ioi-*` release archives and the Interstates test suite on every platform.
- `docs/`: Interstates user docs, `SPEC_DECISIONS.md` entries for new error codes and rulings.

## Implementation Steps

The workflow is the same as goal 1, described in [`PLAN.md`](PLAN.md):
- `gh stack` PR stacks on `mega`, merged with merge commits
- a `code-reviewer` pass, then merge on green CI, with every PR starting with the AI-agent note
- `docs/QUESTIONS.md` under the Q70 policy
- auto mode

1. **Temporary scaffolding:** `tools/goal/` with a `goal-status` task that prints this plan's acceptance checklist.
2. **Workspace:** create `apps/interstates/`, register it in `lattice.json`, and build the `ioi-dart` and `ioi-llvm` CLI skeletons with `-s`.
3. **Grammar:** the `-s` extensions, string literals, the array-of-strings type, and the hello-world tolerances (see Assumptions & Decisions, item 1).
4. **CGI runtime layer** in both runtimes: environment and stdin in, CGI response out, `GIVE UP` ending the response, the `(16001)`+ request/response routines.
5. **`gross`:** HTTP/1.1 serving, one child process per request, `--port`, `--bind`, `--static`, `--database`, the ICL-style error pages.
6. **Routes:** the route table, specificity matching, the catch-all, the 404 page, the compile-time link check, reachability, and the run-time `Referer` check returning 403.
7. **Templates:** compile-time embedding, the `#n` argument check, the `,144`-downward arguments, escaped and raw grumpies, Roman numerals with CSS overlines.
8. **ActiveCassette:**
   - the adapter C ABI;
   - the SQLite adapter in both flavors;
   - `FROM DATABASE`, `HAVING`, `INTO DATABASE` and `FORGET DATABASE` lowered to parameterized SQL;
   - `AMNESIA` dropping every table through the adapter interface;
   - the raw-SQL routine;
   - loading user adapters.
9. **The hello world from the site** (Appendix A) as a golden test that must run exactly as written.
10. **Sample blog app** in `apps/interstates/examples/blog/`:
    - a post list, built by looping in INTERCAL and rendering fragments;
    - a post view, `/blog/post/:id`;
    - a form that creates a post with `INTO DATABASE`;
    - links between pages, so the link check and the `Referer` check are exercised.
11. **Release archives** `ioi-<flavor>-<os>-<arch>`.
12. **User docs.**
13. **Cleanup:** run `goal-status` and show its output, delete `tools/goal/`, then show `git status` and the final tree.

## Edge Cases

- A request with no `Referer` header for a restricted route returns 403. Only `(16000)` routes are reachable directly.
- `:param` values that are empty, contain encoded characters (`%2F`), or contain non-ASCII text.
- Two routes with identical specificity give a compile-time error. A route that isn't linked from its `L` page fails the build.
- A template that references `,144` when `#n` is 0, or an `#n` that doesn't match the actual number of arguments.
- HTML-escaping of template strings versus `{{{ }}}` raw output, and Roman numerals inside attribute values.
- ActiveCassette:
  - a table or column number past the end of the schema;
  - no matching rows;
  - many rows;
  - NULL values;
  - a database file that doesn't exist yet.
- A program that loops forever or never reaches `GIVE UP` during a request (see Assumptions & Decisions, item 4).
- An ICL error after part of the response body was already written.
- Windows: spawning a child process per request, and paths in `--static`.

## Acceptance Criteria

`lattice run goal-status` prints each item with its linked test and ends in `GOAL: MET` only when every box is ticked.

- [ ] The site's hello world (Appendix A) compiles with `ioi-dart` and `ioi-llvm` and serves its page through `gross`, exactly as written.
- [ ] Each punchline 1–7 has a test.
- [ ] Route matching, the catch-all, 404, the compile-time link check, and the 403 `Referer` check are tested.
- [ ] `;4400`, `;49221`, every `(16001)`+ routine, `WRITE IN` of the body, and `GIVE UP` ending the response are tested in both flavors.
- [ ] Templates are tested: the argument count check, escaped and raw output, Roman numerals with overlines, and `,144`-downward arguments.
- [ ] ActiveCassette reads, `HAVING`, writes (insert, update, `FORGET DATABASE` delete), raw SQL, and SQLite are tested in both flavors, along with loading an adapter through the C ABI.
- [ ] `PLEASE DO AMNESIA` drops every table in the configured database, tested in both flavors with SQLite and with a user adapter.
- [ ] The sample blog app runs end to end (list, view, create) in both flavors on every CI platform.
- [ ] Every new error code is documented in `SPEC_DECISIONS.md` and tested.
- [ ] EXTRACAL and Mode 1 conformance are unchanged.
- [ ] CI is green, and the `ioi-*` release archives build.
- [ ] The temporary scaffolding is removed.

## Assumptions & Decisions

Decided in the grilling session (see `SPEC_DECISIONS.md`): Q45, Q50, Q54, Q86–Q89, Q93–Q96, Q99, Q112–Q121.

Decided after review (Q141–Q147). These were drafted while writing the plan, and Ryan approved them:
1. **Hello-world tolerances.** Punchline 7 says the site's hello world must run exactly as written, but as INTERCAL it has two problems:
   - It starts with a `NOTE …` line containing lowercase letters before any statement.
   - It ends with a bare `GIVE UP` that has no `DO`/`PLEASE`. Under Mode 1 rules (T9), that bare `GIVE UP` would turn the `READ OUT` statement before it into garbage.

   So with `-s` only, two narrow rules apply:
   - Text before the first statement identifier is a comment.
   - A bare `GIVE UP` is accepted as `DO GIVE UP`.

   Nothing else from the site's other examples is accepted (punchline 8 was declined). (Q141)
2. **`WITH ROUTE` COME FROMs are entry points, never trap doors** (R3). Without this, `COME FROM (16) WITH ROUTE …` would jump the moment line 16 runs, which contradicts Q113. (Q142)
3. **`gross` is written in Dart** on top of EXTRACAL's runtime networking layer, rather than in EXTRACAL itself. Writing it in EXTRACAL would need a "spawn a process" primitive, which isn't in EXTRACAL's library (Q75). (Q143)
4. **Per-request timeout.** `gross` needs a limit for runaway programs, which INTERCAL makes very likely. The plan adds `--timeout` (default 30 s), which answers **504** with an ICL-style page. (Q144)
5. **`INTO DATABASE` details.**
   - Insert: `DO INTO DATABASE #t~#c$#c <- …`.
   - Update: the same form with `HAVING`.
   - Delete: `DO FORGET DATABASE #t HAVING …`.
   - Drop: `PLEASE DO AMNESIA` drops every table in the configured database, through the adapter interface (Ryan's addition). (Q145)
6. **Adapters use one C ABI** loaded as a shared library. That's the only mechanism that works the same in both flavors. (Q146)
7. **Politeness applies to Interstates programs**, inherited through EXTRACAL. (Q147)

## Open Questions

None. Anything unforeseen goes to `docs/QUESTIONS.md` under the Q70 policy.

---

## Appendix A: the site's five examples, verbatim

From `examples.html` on intercaloninterstates.org (live in 2026, identical to its April 2013 snapshot).

**A. Hello, world.** This one **must run exactly as written** (punchline 7, see Assumptions & Decisions, item 1).
```
NOTE At the start of the program, handle the default route.

DO COME FROM (16000)
PLEASE READ OUT #0 WITH TEMPLATE "hello.html"
GIVE UP
```

**B. Routing and templating.** Not supported as written. It uses `STASH … <-` as assignment and bare `READ OUT`/`NOTE` statements (punchline 8 declined). The equivalent supported program assigns with `;49221 SUB #1 <- ,4` instead.
```
        NOTE At the start of the program, handle the default route.
        DO (15) NEXT
            
(2)     DO COME FROM (16) WITH ROUTE "/blog/post/:id"

        PLEASE DO ,1 <- ;4400 SUB #1
        PLEASE NOTE ,1 now contains the first argument passed 
        NOTE to the route.

        NOTE This is where you could load up some data based upon ,1.
        NOTE For the purposes of this example, assume we loaded 
        NOTE our data into ,4, ,5, and ,6.
        DO STASH ;49221 SUB #1 <- ,4
        DO STASH ;49221 SUB #2 <- ,5
        DO STASH ;49221 SUB #3 <- ,6

        NOTE Render the template. 
        NOTE Pass #3 because there are three arguments.
        PLEASE READ OUT #3 WITH TEMPLATE "blog_post.html"
        PLEASE GIVE UP

        NOTE This is the default page of the website.
(15)    DO COME FROM (16000) WITH ROUTE "/home"
        NOTE Render the template. Pass #0 if no parameters are required.
(16)    READ OUT #0 WITH TEMPLATE "home.html"
        PLEASE GIVE UP
```

**C. Template.** Supported as written.
```
<!-- blog_post.html -->
<h1>{{,144}}</h1> <!-- Title -->
<h3>Posted {{,143}}</h3> <!-- Date -->
<p>{{,142}}</p> <!-- Blog post text -->
```

**D. Database access.** Not supported as written: `STASH … <-`. It also reads `#0~#1` as table~row, which conflicts with example E. The plan follows E (table~columns, Q119).
```
NOTE Retrieves row 1 from table 0 into ;1, then extracts 
NOTE column 3, then renders a template using it.
DO COME FROM (16000)

NOTE Use sparks to create an order of operations.
PLEASE DO STASH ;49221 SUB #1 <- 'FROM DATABASE #0~#1' SUB #3
DO READ OUT #1 WITH TEMPLATE "db_sample.html"
PLEASE GIVE UP
```

**E. Database with routing.** Not supported as written: `STASH … <-` and bare `READ OUT`. Its `FROM DATABASE #1~#3$#4$#5' HAVING #0 ,3` clause is the model for R7.
```
PLEASE NOTE Retrieves the specified blog post from the database,
PLEASE NOTE then renders a template using it.

DO COME FROM (16000) WITH ROUTE "/blog/post/:id"
DO STASH ,3 <- ;4400 SUB #1

NOTE Use multiple MINGLE to specify multiple columns.
NOTE Multiple columns in a FROM DATABASE clause will 
NOTE automatically fill an array.
PLEASE NOTE Specify the HAVING clause to constrain
NOTE results, in this case column #0 must equal ,3
DO STASH ;49221 <- 'FROM DATABASE #1~#3$#4$#5' HAVING #0 ,3
READ OUT #3 WITH TEMPLATE "blog_post.html"
PLEASE GIVE UP
```

---

## `/goal` prompt

```
/goal Implement INTERCAL on Interstates exactly as specified in docs/INTERSTATES_PLAN.md, on top of the finished EXTRACAL from docs/EXTRACAL_PLAN.md, following the workflow and parity rules in docs/PLAN.md and every decision in docs/SPEC_DECISIONS.md. Never guess: if a decision is missing, record it in docs/QUESTIONS.md, mark the affected checklist item blocked and keep working on everything else. Stop the goal immediately only if the missing answer could force undoing a large amount of work. Work through the Implementation Steps in order, as gh stack PR stacks on mega. Every PR starts with the AI-agent note from docs/PLAN.md and works for programs built by both ioi-dart and ioi-llvm, with tests. It needs a code-reviewer sub-agent pass and green CI before you merge it with a merge commit. CIWAPA's own packages must never depend on Interstates. Use only the dependencies approved in docs/SPEC_DECISIONS.md; anything else goes to QUESTIONS.md. After every stage, run `lattice run goal-status` and show its full output. The goal is met only when that output ends with "GOAL: MET": the site's hello world runs exactly as written through gross in both flavors, the sample blog app works end to end, every acceptance criterion is ticked with a linked passing test, CI is green on every platform, the ioi-* release archives build, and tools/goal is removed. The goal is also met if every remaining item is listed as blocked in docs/QUESTIONS.md.
```
