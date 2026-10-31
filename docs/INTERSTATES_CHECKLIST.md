# INTERCAL on Interstates checklist

This is the definition of done for INTERCAL on Interstates, goal 3 ([`INTERSTATES_PLAN.md`](INTERSTATES_PLAN.md)). Each item names the requirement it comes from and links at least one test that passes in **both** flavors. An item is checked only when its tests exist and pass. Items waiting on an answer in [`QUESTIONS.md`](QUESTIONS.md) are marked **BLOCKED** with the question's number.

Format, as in [`EXTRACAL_CHECKLIST.md`](EXTRACAL_CHECKLIST.md):

```markdown
- [ ] R3 — rule, in one line. Tests: `apps/interstates/...`
```

Goal 4 replaced `-s` with the `.ioi` extension (Q154), so the items below that say `-s` now mean a `.ioi` file, and the goldens they cite were renamed. The sections follow the plan's acceptance criteria. `goal-status` read this file, together with the CI run and the release archives on the `mega` HEAD, until goal 3's cleanup removed it with `tools/goal`; its last verdict is in the git history.

## The site's hello world

- [x] Punchline 7 — the site's hello world (Appendix A) compiles with `ioi-dart` and `ioi-llvm` exactly as written and serves its page through `gross`. Tests: `apps/interstates/test/golden/hello/hello.ioi`, `apps/interstates/test/hello_test.dart`

## Punchlines

- [x] Punchline 1 — `gross`, the General READ OUT Server System, listens on port 10585 by default. Tests: `apps/interstates/test/gross_test.dart`
- [x] Punchline 2 — `-s` turns on the Interstates extensions; without it the `ioi-*` CLIs compile plain EXTRACAL. Tests: `apps/interstates/test/cli_test.dart`, `apps/interstates/test/syntax_test.dart`
- [x] Punchline 3 — the database layer is ActiveCassette. Tests: `apps/interstates/test/golden/activecassette/read-and-having.ioi`, `apps/interstates/test/golden/activecassette/e825-no-adapter.ioi`
- [x] Punchline 4 — templates use `{{ }}` double grumpies. Tests: `apps/interstates/test/golden/templates/escaped-and-raw.ioi`, `apps/interstates/test/golden/templates/numbers.ioi`
- [x] Punchline 5 — `;4400` holds the route parameters and `;49221` the template arguments, which templates see as `,144` counting downward. Tests: `apps/interstates/test/golden/templates/escaped-and-raw.ioi`, `apps/interstates/test/golden/templates/string-values.ioi`, `apps/interstates/test/golden/routes/param.ioi`
- [x] Punchline 6 — `(16000)` is the implicit entry label that no program defines. Tests: `apps/interstates/test/golden/routes/catch-all.ioi`, `apps/interstates/test/golden/routes/param.ioi`, `apps/interstates/test/golden/routes/no-routes-at-all.ioi`

## Language (R1, R5, Q141, Q147)

- [x] R1 — `ioi-dart` and `ioi-llvm` have CIWAPA's `build`, `run` and `doctor` commands, and `-s` takes the source rules recorded for it (L35). Tests: `apps/interstates/test/cli_test.dart`
- [x] R1 — CIWAPA's own packages and CLIs never learn about Interstates: nothing under `packages/` names it. Tests: `apps/interstates/test/separation_test.dart`, `packages/ciwapa_core/test/dialect_test.dart`
- [x] Q141 — under `-s` only, text before the first statement identifier is a comment and a bare `GIVE UP` is `DO GIVE UP`; nothing else from the site's other examples is accepted. Tests: `apps/interstates/test/syntax_test.dart`
- [x] R5 — `"…"` string literals are allowed only right after `WITH ROUTE` and `WITH TEMPLATE`; anywhere else `"` is rabbit ears. Tests: `apps/interstates/test/syntax_test.dart`
- [x] Q147 — politeness is checked on Interstates programs too. Tests: `apps/interstates/test/syntax_test.dart`

## gross (R2, Q120, Q144)

- [x] R2 — each request runs the program fresh, with the request in CGI/1.1 environment variables and stdin, and its stdout as the response (L39). Tests: `apps/interstates/test/gross_test.dart`
- [x] R2 — `--port` (default 10585) and `--bind` (default 127.0.0.1) (L39). Tests: `apps/interstates/test/gross_test.dart`
- [x] R2 — `--static <dir>` serves files only when it names a folder; there is no `public/` convention (L39). Tests: `apps/interstates/test/gross_test.dart`
- [x] R2 — `--database` or `DATABASE_URL` picks the ActiveCassette connection and reaches each run (L39). Tests: `apps/interstates/test/gross_test.dart`
- [x] R2 — logs go to stderr (L39). Tests: `apps/interstates/test/gross_test.dart`
- [x] Q144 — `--timeout` (default 30 s) answers 504 with an ICL-style page. Tests: `apps/interstates/test/gross_test.dart`
- [x] Design — 403, 404 and any ICL error render as an ICL-style page (official text, joke, `ON THE WAY TO STATEMENT n`, `CORRECT SOURCE AND RESUBMIT`), and an ICL error inside the program is HTTP 500. Tests: `apps/interstates/test/gross_test.dart`
- [x] Edge cases — an ICL error after part of the body was written, a program that never reaches `GIVE UP`, and Windows: a child process per request and `--static` paths (L39). Tests: `apps/interstates/test/gross_test.dart`

## Routes

- [x] R3 — a `COME FROM (16000) WITH ROUTE` is a public route, and a bare `COME FROM (16000)` is the catch-all. Tests: `apps/interstates/test/golden/routes/param.ioi`, `apps/interstates/test/golden/routes/catch-all.ioi`, `apps/interstates/test/golden/routes/root-is-catch-all.ioi`
- [x] R3 — fixed segments beat `:param` segments, and two equally specific routes fail at compile time. Tests: `apps/interstates/test/golden/routes/fixed-beats-param.ioi`, `apps/interstates/test/golden/routes/three-params.ioi`, `apps/interstates/test/golden/routes/e441-tie.ioi`, `apps/interstates/test/golden/routes/e441-two-catch-alls.ioi`, `apps/interstates/test/golden/routes/left-to-right.ioi`, `apps/interstates/test/golden/routes/left-to-right-other.ioi`, `apps/interstates/test/golden/routes/e441-restricted-and-public.ioi`
- [x] R3 — no matching route and no catch-all is a 404 page. Tests: `apps/interstates/test/golden/routes/no-route.ioi`, `apps/interstates/test/golden/routes/no-routes-at-all.ioi`, `apps/interstates/test/gross_test.dart`
- [x] R3 — `COME FROM (L) WITH ROUTE` fails the build unless `L` is a `READ OUT … WITH TEMPLATE` whose template links the route. Tests: `apps/interstates/test/golden/routes/e443-not-a-template.ioi`, `apps/interstates/test/golden/routes/e443-unlinked.ioi`, `apps/interstates/test/golden/routes/e444-route-label.ioi`, `apps/interstates/test/golden/routes/e777-missing-template.ioi`, `apps/interstates/test/golden/routes/links-decoded.ioi`, `apps/interstates/test/golden/routes/e443-commented.ioi`, `apps/interstates/test/golden/routes/e443-data-attribute.ioi`, `apps/interstates/test/golden/routes/e443-text.ioi`, `apps/interstates/test/golden/routes/e443-dynamic-is-no-fixed.ioi`
- [x] R3 — a restricted route answers 403 unless the `Referer` is a page that line `L` could have rendered. Tests: `apps/interstates/test/golden/routes/restricted-ok.ioi`, `apps/interstates/test/golden/routes/restricted-dynamic-link.ioi`, `apps/interstates/test/golden/routes/restricted-no-referer.ioi`, `apps/interstates/test/golden/routes/restricted-wrong-referer.ioi`, `apps/interstates/test/golden/routes/restricted-other-host.ioi`, `apps/interstates/test/golden/routes/restricted-unknown-referer.ioi`, `apps/interstates/test/golden/routes/restricted-referer-line-separator.ioi`, `apps/interstates/test/golden/routes/reach-next.ioi`, `apps/interstates/test/golden/routes/reach-abstained-give-up.ioi`, `apps/interstates/test/golden/routes/reach-come-from.ioi`, `apps/interstates/test/golden/routes/reach-catch-all.ioi`, `apps/interstates/test/golden/routes/reach-blocked.ioi`, `apps/interstates/test/golden/routes/reach-unknowable.ioi`, `apps/interstates/test/golden/routes/reach-shared-routine.ioi`, `apps/interstates/test/golden/routes/reach-shared-routine-ok.ioi`, `apps/interstates/test/blog_test.dart`, `apps/interstates/test/gross_test.dart`
- [x] R3 — a `WITH ROUTE` COME FROM never fires as an ordinary COME FROM, and many may share a label without E555. Tests: `apps/interstates/test/golden/templates/route-is-no-trap-door.ioi`, `apps/interstates/test/golden/routes/restricted-ok.ioi`, `apps/interstates/test/golden/routes/restricted-dynamic-link.ioi`
- [x] Edge cases — empty, percent-encoded (`%2F`) and non-ASCII `:param` values. Tests: `apps/interstates/test/golden/routes/empty-param.ioi`, `apps/interstates/test/golden/routes/encoded-slash.ioi`, `apps/interstates/test/golden/routes/encoded-utf8.ioi`, `apps/interstates/test/golden/routes/raw-utf8.ioi`, `apps/interstates/test/golden/routes/malformed-utf8.ioi`, `apps/interstates/test/golden/routes/absolute-form.ioi`, `apps/interstates/test/golden/routes/absolute-form-query.ioi`, `apps/interstates/test/golden/routes/query-ignored.ioi`, `apps/interstates/test/golden/routes/path-info.ioi`

## Request and response

- [x] R4, R5 — `;4400 SUB n` copies the nth route parameter into a tail array, which is resized to fit. Tests: `apps/interstates/test/golden/routes/param.ioi`, `apps/interstates/test/golden/routes/three-params.ioi`, `apps/interstates/test/golden/routes/param-past-the-end.ioi`
- [x] R5 — `;49221 SUB n` stores a string in either direction. Tests: `apps/interstates/test/golden/cgi/strings.ioi`
- [x] R4 — every `(16001)`+ routine: the method, query string, headers, cookies, status, headers, cookies and redirects (L38). Tests: `apps/interstates/test/golden/cgi/method.ioi`, `apps/interstates/test/golden/cgi/query.ioi`, `apps/interstates/test/golden/cgi/header.ioi`, `apps/interstates/test/golden/cgi/cookie.ioi`, `apps/interstates/test/golden/cgi/form.ioi`, `apps/interstates/test/golden/cgi/form-not-a-form.ioi`, `apps/interstates/test/golden/cgi/body.ioi`, `apps/interstates/test/golden/cgi/status-headers-cookies.ioi`, `apps/interstates/test/golden/cgi/content-type.ioi`, `apps/interstates/test/golden/cgi/redirect.ioi`, `apps/interstates/test/golden/cgi/form-raw-utf8.ioi`, `apps/interstates/test/golden/cgi/body-to-end.ioi`
- [x] R4 — `WRITE IN` reads the request body. Tests: `apps/interstates/test/golden/cgi/write-in.ioi`
- [x] R4 — `GIVE UP` ends the response. Tests: `apps/interstates/test/golden/cgi/give-up.ioi`, `apps/interstates/test/golden/cgi/method.ioi`

## Templates

- [x] R6 — templates are embedded at compile time, and `READ OUT #n` must match the template's argument count. Tests: `apps/interstates/test/golden/templates/e821-too-many.ioi`, `apps/interstates/test/golden/templates/e821-none-given.ioi`, `apps/interstates/test/golden/templates/gap-counts-to-the-highest.ioi`, `apps/interstates/test/golden/templates/e777-missing.ioi`, `apps/interstates/test/golden/templates/e820-unclosed.ioi`
- [x] R6 — `{{ }}` escapes HTML and `{{{ }}}` prints raw. Tests: `apps/interstates/test/golden/templates/escaped-and-raw.ioi`, `apps/interstates/test/golden/templates/string-values.ioi`
- [x] R6 — numbers print as butchered Roman numerals with CSS overlines, including inside attribute values. Tests: `apps/interstates/test/golden/templates/numbers.ioi`, `apps/interstates/test/golden/templates/numbers-wimp.ioi`, `apps/interstates/test/golden/templates/title-and-textarea.ioi`, `apps/interstates/test/golden/templates/e820-unquoted.ioi`
- [x] R6 — `;49221 SUB #1` appears in the template as `,144`, `SUB #2` as `,143`, and so on. Tests: `apps/interstates/test/golden/templates/escaped-and-raw.ioi`, `apps/interstates/test/golden/templates/fragments.ioi`, `apps/interstates/test/golden/templates/unset-argument-is-empty.ioi`

## ActiveCassette

- [x] R7 — `FROM DATABASE` reads columns by table and column number, with `HAVING`. Tests: `apps/interstates/test/golden/activecassette/read-and-having.ioi`, `apps/interstates/test/golden/activecassette/rows.ioi`
- [x] R7 — `INTO DATABASE` inserts, `INTO DATABASE … HAVING` updates and `FORGET DATABASE … HAVING` deletes. Tests: `apps/interstates/test/golden/activecassette/update-and-delete.ioi`, `apps/interstates/test/golden/activecassette/read-and-having.ioi`
- [x] R7 — every value is a bound parameter. Tests: `apps/interstates/test/golden/activecassette/bound-parameters.ioi`, `apps/interstates/test/adapter_test.dart`
- [x] R7 — the raw parameterized SQL routine. Tests: `apps/interstates/test/golden/activecassette/raw-sql.ioi`, `apps/interstates/test/golden/activecassette/e826-bad-sql.ioi`
- [x] R7 — SQLite is built in and is the default. Tests: `apps/interstates/test/golden/activecassette/default-database.ioi`, `apps/interstates/test/golden/activecassette/e825-cannot-open.ioi`
- [x] R7 — an adapter loads through the C ABI. Tests: `apps/interstates/test/adapter_test.dart`
- [x] Edge cases — a table or column past the end of the schema, no rows, many rows, NULLs, and a database file that doesn't exist yet. Tests: `apps/interstates/test/golden/activecassette/e824-table.ioi`, `apps/interstates/test/golden/activecassette/e824-column.ioi`, `apps/interstates/test/golden/activecassette/no-rows-and-nulls.ioi`, `apps/interstates/test/golden/activecassette/rows.ioi`, `apps/interstates/test/golden/activecassette/default-database.ioi`

## AMNESIA

- [x] R7 — `PLEASE DO AMNESIA` drops every table in the configured database, with SQLite and with a user adapter. Tests: `apps/interstates/test/golden/activecassette/amnesia.ioi`, `apps/interstates/test/adapter_test.dart`

## The sample blog app

- [x] Step 10 — the blog lists posts, shows one at `/blog/post/:id`, and creates one with `INTO DATABASE`, in both flavors on every CI platform. Tests: `apps/interstates/test/blog_test.dart`, `apps/interstates/examples/blog/blog.ioi`

## New error codes

Each new code is listed under "INTERCAL on Interstates error codes" in [`SPEC_DECISIONS.md`](SPEC_DECISIONS.md) and has a test.

- [x] Every code in `apps/interstates/lib/src/errors.dart` has its entry and a test. Tests: `apps/interstates/test/errors_test.dart`

## EXTRACAL and Mode 1 are unchanged

- [x] The Mode 1 and EXTRACAL conformance suite passes unchanged in both flavors on every platform. Tests: `packages/conformance/bin/conformance.dart`, `.github/scripts/ci-check.sh`

## CI and release archives

- [x] R9 — CI builds the `ioi-<flavor>-<os>-<arch>` archives, each bundling the CIWAPA toolchain, the `ioi-*` CLI and `gross`, and smoke-tests them. Tests: `.github/workflows/release-archives.yml`, `.github/scripts/ioi-sites.sh`

## Temporary scaffolding

- [x] Step 13 — `tools/goal` is the only temporary scaffolding left, and it goes last. Tests: `git ls-files tools/goal` prints nothing (removed by goal 3's cleanup; see the git history)
