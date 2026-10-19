#!/usr/bin/env bash
# Builds ActiveCassette's built-in SQLite adapter, with the SQLite amalgamation, into <out-dir>:
#   activecassette-<triple>.o, which ioi-llvm links into programs built for <triple>
#   libioi_sqlite.so, libioi_sqlite.dylib or ioi_sqlite.dll, which ioi-dart programs load
#   sqlite/, the amalgamation, from which ioi-llvm builds the object for any other triple
# The amalgamation comes from sqlite.org, checked against the SHA-256 in .github/toolchain.env.
# Either compiler may be skipped with "-".
# Usage: activecassette.sh <out-dir> <clang> <triple> <cc for the shared library> [flags for clang...]
set -euo pipefail

out="$(mkdir -p "$1" && cd "$1" && pwd)"
clang="$2"
triple="$3"
cc="$4"
shift 4
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../../../.github/toolchain.env
source "$repo_root/.github/toolchain.env"
runtime="$repo_root/apps/interstates/runtime"

name="sqlite-autoconf-$SQLITE_VERSION"
if [[ ! -f "$out/sqlite/sqlite3.c" ]]; then
  tarball="$out/$name.tar.gz"
  curl -fsSL -o "$tarball" "https://www.sqlite.org/$SQLITE_YEAR/$name.tar.gz"
  actual="$( (sha256sum "$tarball" 2>/dev/null || shasum -a 256 "$tarball") | cut -d' ' -f1)"
  if [[ "$actual" != "$SQLITE_SHA256" ]]; then
    echo "activecassette.sh: $name.tar.gz has SHA-256 $actual, not $SQLITE_SHA256" >&2
    exit 1
  fi
  mkdir -p "$out/sqlite"
  tar -xzf "$tarball" -C "$out/sqlite" --strip-components=1 "$name/sqlite3.c" "$name/sqlite3.h"
  rm "$tarball"
fi

defines=(-DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_THREADSAFE=0)
includes=(-I"$out/sqlite" -I"$runtime")
if [[ "$clang" != - ]]; then
  "$clang" --target="$triple" "$@" -O2 -w "${defines[@]}" "${includes[@]}" \
    -c "$runtime/activecassette.c" -o "$out/activecassette-$triple.o"
fi
if [[ "$cc" != - ]]; then
  case "$(uname -s)" in
    Darwin) library=libioi_sqlite.dylib flags=(-dynamiclib) ;;
    MINGW* | MSYS* | CYGWIN*) library=ioi_sqlite.dll flags=(-shared) ;;
    *) library=libioi_sqlite.so flags=(-shared -fPIC) ;;
  esac
  "$cc" -O2 -w "${flags[@]}" "${defines[@]}" "${includes[@]}" "$runtime/activecassette.c" -o "$out/$library"
fi
