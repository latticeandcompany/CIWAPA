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
trap '[[ -n "$gross_pid" ]] && kill "$gross_pid" 2>/dev/null || true' EXIT

# Starts gross on a free port with the given flags and program, and sets $site once it listens.
serve() {
  "$root/bin/gross$exe" --port 0 "$@" 2>"$work/gross.log" &
  gross_pid=$!
  for _ in $(seq 300); do
    site="$(sed -n 's/.* on \(http:[^ ]*\).*/\1/p' "$work/gross.log")"
    [[ -n "$site" ]] && return
    sleep 0.1
  done
  cat "$work/gross.log" >&2
  echo "gross never started" >&2
  exit 1
}

stop() {
  kill "$gross_pid"
  wait "$gross_pid" 2>/dev/null || true
  gross_pid=""
}

expect() {
  if ! grep -qF -- "$2" <<<"$1"; then
    printf '%s\n' "$1" >&2
    echo "expected the page to contain: $2" >&2
    exit 1
  fi
}

mkdir -p "$work/hello"
cp "$repo_root/apps/interstates/test/golden/hello/hello."{xc,html} "$work/hello/"
"$root/bin/ioi-$flavor$exe" build -s --no-random-bug "$(native "$work/hello/hello.xc")" \
  -o "$(native "$work/hello/hello")"
serve "$(native "$work/hello/hello$exe")"
expect "$(curl -fsS "$site/")" "<h1>Hello, world!</h1>"
stop
echo "hello world served by $flavor" >&2

cp -R "$repo_root/apps/interstates/examples/blog" "$work/blog"
"$root/bin/ioi-$flavor$exe" build -s --no-random-bug "$(native "$work/blog/blog.xc")" \
  -o "$(native "$work/blog/blog")"
serve --static "$(native "$work/blog/public")" --database "sqlite:$(native "$work/blog/blog.db")" \
  "$(native "$work/blog/blog$exe")"
status="$(curl -sS -o /dev/null -w '%{http_code}' -e "$site/blog/new" \
  --data 'title=Smoke+test&body=COME+FROM+the+archive' "$site/blog/create")"
[[ "$status" == 303 ]] || { cat "$work/gross.log" >&2; echo "creating a post gave $status" >&2; exit 1; }
expect "$(curl -fsS "$site/blog")" '<a href="/blog/post/1">Smoke test</a>'
expect "$(curl -fsS -e "$site/blog" "$site/blog/post/1")" "<p>COME FROM the archive</p>"
stop
echo "the blog ran on ActiveCassette's SQLite in $flavor" >&2
