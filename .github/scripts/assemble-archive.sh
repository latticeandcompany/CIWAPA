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

# Every binary in bin/ is a `dart compile exe` executable, so it carries the Dart runtime.
dart_sdk="$(dirname "$(dirname "$(command -v dart)")")"
cp "$dart_sdk/LICENSE" "$root/licenses/Dart-BSD-3-Clause.txt"
cp "$repo_root/LICENSE" "$root/licenses/CIWAPA-ISC.txt"
case "$flavor-$platform" in
  dart-*)
    cp -R "$toolchain/dart-sdk" "$root/dart-sdk"
    ;;
  llvm-linux-*)
    cp -R "$toolchain" "$root/toolchain"
    mv "$root/toolchain/licenses/"* "$root/licenses/"
    rmdir "$root/toolchain/licenses"
    ;;
  llvm-windows-*)
    # Only what ciwapa-llvm runs: the clang driver and lld with their DLLs, clang's resource
    # directory, the C headers, and the host target's sysroot.
    case "$platform" in
      windows-x64) cpu=x86_64 ;;
      windows-arm64) cpu=aarch64 ;;
    esac
    tc="$root/toolchain"
    mkdir -p "$tc/bin" "$tc/lib"
    for f in clang.exe clang-[0-9]*.exe ld.lld.exe libLLVM-*.dll libclang-cpp.dll libc++.dll \
      libunwind.dll libwinpthread-1.dll mingw32-common.cfg "$cpu-w64-windows-gnu.cfg"; do
      cp "$toolchain/bin/"$f "$tc/bin/"
    done
    cp -R "$toolchain/lib/clang" "$tc/lib/"
    cp -R "$toolchain/include" "$tc/include"
    rm -rf "$tc/include/c++"
    cp -R "$toolchain/$cpu-w64-mingw32" "$tc/"
    cp "$toolchain/LICENSE.TXT" "$root/licenses/LLVM-Apache-2.0-with-LLVM-exception.txt"
    curl -fsSL -o "$root/licenses/llvm-mingw-ISC.txt" \
      "https://raw.githubusercontent.com/mstorsjo/llvm-mingw/$LLVM_MINGW_VERSION/LICENSE.txt"
    mkdir -p "$root/licenses/mingw-w64"
    cp "$toolchain/$cpu-w64-mingw32/share/mingw32/"COPYING* "$root/licenses/mingw-w64/"
    ;;
esac
if [[ "$flavor" == llvm ]]; then
  # The runtime, precompiled by the toolchain the archive uses (Apple clang on macOS), so builds
  # only compile the program.
  triple="$("$repo_root/.github/scripts/target-triple.sh" "$platform")"
  clang=clang
  flags=()
  case "$platform" in
    linux-*) clang="$root/toolchain/bin/clang" flags=(--sysroot="$root/toolchain/sysroot") ;;
    windows-*) clang="$root/toolchain/bin/clang.exe" ;;
  esac
  mkdir -p "$root/lib"
  "$clang" --target="$triple" ${flags[@]+"${flags[@]}"} -O2 -w -c "$repo_root/packages/runtime_c/runtime.c" \
    -o "$root/lib/runtime-$triple.o"
fi
cp "$repo_root/.github/release/README.txt" "$root/README.txt"

cd "$out"
if [[ "$platform" == windows-* ]]; then
  rm -f "$name.zip"
  7z a -tzip -bd -mx=9 "$name.zip" "$name" >/dev/null
  echo "$out/$name.zip"
else
  XZ_OPT=-T0 tar -cJf "$name.tar.xz" "$name"
  echo "$out/$name.tar.xz"
fi
rm -rf "$root"
