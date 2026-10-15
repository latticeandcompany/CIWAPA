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

@msg = private constant [24 x i8] c"$expected\\00"

declare i32 @puts(ptr)

define i32 @main() {
  %r = call i32 @puts(ptr @msg)
  ret i32 0
}
LL
    case "$platform" in
      linux-*)
        "$toolchain/bin/clang" --target="$triple" --sysroot="$toolchain/sysroot" -static -fuse-ld=lld \
          -rtlib=compiler-rt -unwindlib=none -O2 "$work/hello.ll" -o "$exe"
        ;;
      macos-*) clang --target="$triple" -O2 "$work/hello.ll" -o "$exe" ;;
      windows-*) "$toolchain/bin/clang" --target="$triple" -O2 "$work/hello.ll" -o "$exe" ;;
    esac
    ;;
esac

actual="$("$exe" | tr -d '\r')"
echo "$actual"
[[ "$actual" == "$expected" ]]
