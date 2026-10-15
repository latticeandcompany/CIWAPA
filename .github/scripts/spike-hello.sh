#!/usr/bin/env bash
# Toolchain spike: builds and runs hello world with a flavor's bundled toolchain.
# Usage: spike-hello.sh <platform> <dart|llvm> <toolchain-dir>
set -euo pipefail

platform="$1"
flavor="$2"
toolchain="$(cd "$3" && pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
exe="$work/hello"
[[ "$platform" == windows-* ]] && exe="$exe.exe"

case "$flavor" in
  dart)
    expected="Hello from ciwapa-dart!"
    echo "void main() => print('$expected');" >"$work/hello.dart"
    "$toolchain/dart-sdk/bin/dart" --suppress-analytics compile exe "$work/hello.dart" -o "$exe"
    ;;
  llvm)
    expected="Hello from ciwapa-llvm!"
    triple="$("$here/target-triple.sh" "$platform")"
    cat >"$work/hello.ll" <<LL
target triple = "$triple"

declare void @greet(i32)

define i32 @main() {
  call void @greet(i32 23)
  ret i32 0
}
LL
    cat >"$work/greet.c" <<'C'
#include <stdint.h>
#include <stdio.h>

void greet(int32_t llvm_major) {
  printf("Hello from ciwapa-llvm!\n");
  fflush(stdout);
  (void)llvm_major;
}
C
    sources=("$work/hello.ll" "$work/greet.c")
    case "$platform" in
      linux-*)
        "$toolchain/bin/clang" --target="$triple" --sysroot="$toolchain/sysroot" -static -fuse-ld=lld \
          -rtlib=compiler-rt -unwindlib=none -O2 "${sources[@]}" -o "$exe"
        ;;
      macos-*) clang --target="$triple" -O2 "${sources[@]}" -o "$exe" ;;
      windows-*) "$toolchain/bin/clang" --target="$triple" -O2 "${sources[@]}" -o "$exe" ;;
    esac
    ;;
esac

actual="$("$exe" | tr -d '\r')"
echo "$actual"
[[ "$actual" == "$expected" ]]
