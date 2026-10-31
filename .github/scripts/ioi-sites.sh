#!/usr/bin/env bash
# Builds the site's hello world and the sample blog with an unpacked ioi-* archive, serves each
# through its gross, and checks the pages.
# Usage: ioi-sites.sh <unpacked-archive> <dart|llvm> <work-dir>
set -euo pipefail

root="$1"
flavor="$2"
work="$3"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
exe=""
[[ -f "$root/bin/gross.exe" ]] && exe=".exe"
# Git Bash's /d/a/... isn't a path the archive's programs can open.
native() { if [[ -n "$exe" ]]; then cygpath -m "$1"; else echo "$1"; fi; }

gross_pid=""
log=""
finish() {
  local status=$?
  [[ "$status" != 0 && -n "$log" ]] && cat "$log" >&2
  [[ -n "$gross_pid" ]] && kill "$gross_pid" 2>/dev/null
  return "$status"
}
trap finish EXIT

# Only what the archive holds: no compiler, toolchain or SQLite from the environment.
ioi() { env -u IOI_LIB -u CIWAPA_DART -u CIWAPA_CLANG "$root/bin/ioi-$flavor$exe" "$@"; }

# Starts gross on a free port with the given flags and program, logging to <name>.log, and sets
# $site once it listens.
serve() {
  log="$work/$1.log"
  shift
  "$root/bin/gross$exe" --port 0 "$@" 2>"$log" &
  gross_pid=$!
  for _ in $(seq 300); do
    site="$(sed -n 's/.* on \(http:[^ ]*\).*/\1/p' "$log" 2>/dev/null)"
    [[ -n "$site" ]] && return
    sleep 0.1
  done
  echo "gross never started" >&2
  exit 1
}

stop() {
  kill "$gross_pid"
  wait "$gross_pid" 2>/dev/null || true
  gross_pid=""
  log=""
}

expect() {
  if ! grep -qF -- "$2" <<<"$1"; then
    printf '%s\n' "$1" >&2
    echo "expected the page to contain: $2" >&2
    exit 1
  fi
}

rm -rf "$work/hello" "$work/blog"
mkdir -p "$work/hello"
cp "$repo_root/apps/interstates/test/golden/hello/hello."{ioi,html} "$work/hello/"
ioi build --no-random-bug "$(native "$work/hello/hello.ioi")" \
  -o "$(native "$work/hello/hello")"
serve hello "$(native "$work/hello/hello$exe")"
expect "$(curl -fsS "$site/")" "<h1>Hello, world!</h1>"
stop
echo "hello world served by $flavor" >&2

cp -R "$repo_root/apps/interstates/examples/blog" "$work/blog"
ioi build --no-random-bug "$(native "$work/blog/blog.ioi")" \
  -o "$(native "$work/blog/blog")"
serve blog --static "$(native "$work/blog/public")" --database "sqlite:$(native "$work/blog/blog.db")" \
  "$(native "$work/blog/blog$exe")"
status="$(curl -sS -o /dev/null -w '%{http_code}' -e "$site/blog/new" \
  --data 'title=Smoke+test&body=COME+FROM+the+archive' "$site/blog/create")"
[[ "$status" == 303 ]] || { echo "creating a post gave $status" >&2; exit 1; }
expect "$(curl -fsS "$site/blog")" '<a href="/blog/post/1">Smoke test</a>'
expect "$(curl -fsS -e "$site/blog" "$site/blog/post/1")" "<p>COME FROM the archive</p>"
stop
echo "the blog ran on ActiveCassette's SQLite in $flavor" >&2
