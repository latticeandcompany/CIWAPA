#!/usr/bin/env bash
# Builds one release archive: the flavor's compiler, its bundled toolchain and the license notices.
# The version is the flavor's pubspec version. Prints the archive's path.
# Usage: assemble-archive.sh <platform> <dart|llvm> <toolchain-dir> <out-dir>
set -euo pipefail

platform="$1"
flavor="$2"
toolchain="$(cd "$3" && pwd)"
out="$(mkdir -p "$4" && cd "$4" && pwd)"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../toolchain.env
source "$repo_root/.github/toolchain.env"

version="$(sed -n 's/^version: *//p' "$repo_root/packages/ciwapa_$flavor/pubspec.yaml")"
name="ciwapa-$flavor-$version-$platform"
exe=""
[[ "$platform" == windows-* ]] && exe=".exe"
root="$out/$name"
rm -rf "$root"
mkdir -p "$root/bin" "$root/licenses"

(cd "$repo_root" && dart --suppress-analytics pub get >/dev/null)
dart --suppress-analytics compile exe "$repo_root/packages/ciwapa_$flavor/bin/ciwapa_$flavor.dart" \
  -o "$root/bin/ciwapa-$flavor$exe" >&2

llvm_license() {
  curl -fsSL -o "$root/licenses/LLVM-Apache-2.0-with-LLVM-exception.txt" \
    "https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-$LLVM_VERSION/llvm/LICENSE.TXT"
}

cp "$repo_root/LICENSE" "$root/licenses/CIWAPA-ISC.txt"
case "$flavor-$platform" in
  dart-*)
    cp -R "$toolchain/dart-sdk" "$root/dart-sdk"
    cp "$toolchain/dart-sdk/LICENSE" "$root/licenses/Dart-BSD-3-Clause.txt"
    ;;
  llvm-linux-*)
    cp -R "$toolchain" "$root/toolchain"
    llvm_license
    cp "$toolchain/licenses/musl-MIT.txt" "$root/licenses/"
    ;;
  llvm-windows-*)
    cp -R "$toolchain" "$root/toolchain"
    llvm_license
    cp "$toolchain/LICENSE.TXT" "$root/licenses/llvm-mingw-ISC.txt"
    mkdir -p "$root/licenses/mingw-w64"
    find "$toolchain" -iname 'COPYING*' -path '*mingw*' | while IFS= read -r f; do
      cp "$f" "$root/licenses/mingw-w64/$(basename "$(dirname "$f")")-$(basename "$f").txt"
    done
    if [[ -z "$(ls "$root/licenses/mingw-w64")" ]]; then
      echo "no mingw-w64 license found in $toolchain" >&2
      exit 1
    fi
    ;;
esac
cp "$repo_root/.github/release/README.txt" "$root/README.txt"

cd "$out"
if [[ "$platform" == windows-* ]]; then
  7z a -tzip -bd -mx=9 "$name.zip" "$name" >/dev/null
  echo "$out/$name.zip"
else
  tar -cJf "$name.tar.xz" "$name"
  echo "$out/$name.tar.xz"
fi
rm -rf "$root"
