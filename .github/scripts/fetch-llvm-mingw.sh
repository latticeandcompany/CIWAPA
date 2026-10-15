#!/usr/bin/env bash
# Downloads the llvm-mingw toolchain that ships inside ciwapa-llvm on Windows.
# Usage: fetch-llvm-mingw.sh <x64|arm64> <out-dir>
set -euo pipefail

arch="$1"
out="$2"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../toolchain.env
source "$repo_root/.github/toolchain.env"

case "$arch" in
  x64) host=x86_64 ;;
  arm64) host=aarch64 ;;
  *) echo "unknown arch: $arch" >&2; exit 1 ;;
esac

name="llvm-mingw-$LLVM_MINGW_VERSION-ucrt-$host"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL -o "$work/$name.zip" \
  "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW_VERSION/$name.zip"
unzip -q "$work/$name.zip" -d "$work"
rm -rf "$out"
mv "$work/$name" "$out"
echo "fetched $name into $out"
