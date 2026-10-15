#!/usr/bin/env bash
# Unpacks a release archive and checks that its compiler works with nothing else installed:
# `doctor` passes, then hello world builds and runs. Prints the unpacked compiler's path.
# Usage: smoke-test.sh <archive> <dart|llvm> <work-dir>
set -euo pipefail

archive="$1"
flavor="$2"
work="$(mkdir -p "$3" && cd "$3" && pwd)"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

case "$archive" in
  *.zip) 7z x -bd -y -o"$work" "$archive" >/dev/null ;;
  *) tar -xJf "$archive" -C "$work" ;;
esac
name="$(basename "$archive")"
name="${name%.zip}"
name="${name%.tar.xz}"
compiler="$work/$name/bin/ciwapa-$flavor"
[[ -f "$compiler.exe" ]] && compiler="$compiler.exe"

"$compiler" doctor >&2
cp "$repo_root/.github/release/hello.i" "$work/hello.i"
"$compiler" build --no-random-bug "$work/hello.i" -o "$work/hello" >&2
hello="$work/hello"
[[ -f "$hello.exe" ]] && hello="$hello.exe"
actual="$("$hello" | tr -d '\r')"
[[ "$actual" == "Hello, world!" ]] || {
  echo "hello world printed: $actual" >&2
  exit 1
}
echo "$compiler"
