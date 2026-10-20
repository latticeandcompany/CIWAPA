#!/usr/bin/env bash
# Unpacks a release archive and checks that its compiler works with nothing else installed:
# `doctor` passes, then hello world builds and runs. For an ioi-* archive that's the site's hello
# world through gross, and the sample blog with a database. Prints the unpacked compiler's path.
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
product="${name%%-*}"
compiler="$work/$name/bin/$product-$flavor"
[[ -f "$compiler.exe" ]] && compiler="$compiler.exe"

# The compiler would fall back to a dart or clang on the PATH, so make sure it used its own.
doctor="$(env -u CIWAPA_DART -u CIWAPA_CLANG "$compiler" doctor)"
echo "$doctor" >&2
if [[ "$name" != *-llvm-*macos-* ]] && ! grep -qF "$name" <<<"$doctor"; then
  echo "doctor did not use the toolchain inside $name" >&2
  exit 1
fi
if [[ "$flavor" == llvm ]] && ! grep -q "runtime: .*$name" <<<"$doctor"; then
  echo "doctor did not find the precompiled runtime inside $name" >&2
  exit 1
fi
if [[ "$product" == ioi ]]; then
  "$repo_root/.github/scripts/ioi-sites.sh" "$work/$name" "$flavor" "$work" >&2
  echo "$compiler"
  exit 0
fi
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
