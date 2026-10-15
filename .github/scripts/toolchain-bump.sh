#!/usr/bin/env bash
# Rewrites the pins in .github/toolchain.env (and the Dockerfile's LLVM_MAJOR) to the newest
# upstream releases. Prints the changed pins; prints nothing when everything is current.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
env_file="$repo_root/.github/toolchain.env"
# shellcheck source=../toolchain.env
source "$env_file"

latest_llvm="$(gh api repos/llvm/llvm-project/releases --paginate \
  --jq '.[] | select(.prerelease | not) | .tag_name | select(test("^llvmorg-[0-9]+\\.[0-9]+\\.[0-9]+$"))' |
  sed 's/^llvmorg-//' | sort -V | tail -1)"
latest_mingw="$(gh api repos/mstorsjo/llvm-mingw/releases/latest --jq .tag_name)"
latest_musl="$(curl -fsSL https://musl.libc.org/releases.html |
  grep -o 'musl-[0-9][0-9.]*[0-9]\.tar\.gz' | sed 's/^musl-//; s/\.tar\.gz$//' | sort -uV | tail -1)"

require() {
  local name="$1" value="$2" pattern="$3"
  if [[ ! "$value" =~ $pattern ]]; then
    echo "unexpected $name version: '$value'" >&2
    exit 1
  fi
}

require LLVM "$latest_llvm" '^[0-9]+\.[0-9]+\.[0-9]+$'
require llvm-mingw "$latest_mingw" '^[0-9]{8}$'
require musl "$latest_musl" '^[0-9]+(\.[0-9]+)+$'

bump() {
  local key="$1" old="$2" new="$3"
  if [[ "$old" != "$new" ]]; then
    sed -i.bak "s/^$key=.*/$key=$new/" "$env_file" && rm -f "$env_file.bak"
    echo "$key: $old -> $new"
  fi
}

bump LLVM_VERSION "$LLVM_VERSION" "$latest_llvm"
bump LLVM_MINGW_VERSION "$LLVM_MINGW_VERSION" "$latest_mingw"
bump MUSL_VERSION "$MUSL_VERSION" "$latest_musl"

new_major="${latest_llvm%%.*}"
sed -i.bak "s/^ARG LLVM_MAJOR=.*/ARG LLVM_MAJOR=$new_major/" "$repo_root/Dockerfile" && rm -f "$repo_root/Dockerfile.bak"
