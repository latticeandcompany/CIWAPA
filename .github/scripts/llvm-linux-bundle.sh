#!/usr/bin/env bash
# Builds the slim Linux toolchain that ships inside ciwapa-llvm: clang + lld from the
# LLVM release, compiler-rt builtins, and a static musl sysroot built with that clang.
# Usage: llvm-linux-bundle.sh <x64|arm64> <out-dir> [download-dir]
set -euo pipefail

arch="$1"
out="$2"
downloads="${3:-${RUNNER_TEMP:-/tmp}/ciwapa-downloads}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../toolchain.env
source "$repo_root/.github/toolchain.env"

case "$arch" in
  x64) llvm_arch=X64 cpu=x86_64 ;;
  arm64) llvm_arch=ARM64 cpu=aarch64 ;;
  *) echo "unknown arch: $arch" >&2; exit 1 ;;
esac

major="${LLVM_VERSION%%.*}"
gnu_triple="$cpu-unknown-linux-gnu"
musl_triple="$cpu-unknown-linux-musl"
llvm_root="LLVM-$LLVM_VERSION-Linux-$llvm_arch"
llvm_tar="$downloads/$llvm_root.tar.xz"
musl_tar="$downloads/musl-$MUSL_VERSION.tar.gz"

mkdir -p "$downloads"
[[ -f "$llvm_tar" ]] || curl -fsSL -o "$llvm_tar" \
  "https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/$llvm_root.tar.xz"
[[ -f "$musl_tar" ]] || curl -fsSL -o "$musl_tar" "https://musl.libc.org/releases/musl-$MUSL_VERSION.tar.gz"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

tar -xJf "$llvm_tar" -C "$work" --wildcards \
  "$llvm_root/bin/clang-$major" \
  "$llvm_root/bin/lld" \
  "$llvm_root/bin/llvm-ar" \
  "$llvm_root/bin/llvm-objcopy" \
  "$llvm_root/lib/clang/$major/include/*" \
  "$llvm_root/lib/clang/$major/lib/$gnu_triple/libclang_rt.builtins.a" \
  "$llvm_root/lib/clang/$major/lib/$gnu_triple/clang_rt.crtbegin.o" \
  "$llvm_root/lib/clang/$major/lib/$gnu_triple/clang_rt.crtend.o"

rm -rf "$out"
mkdir -p "$out/bin" "$out/lib/clang/$major/lib/$musl_triple"
cp "$work/$llvm_root/bin/clang-$major" "$out/bin/clang"
cp "$work/$llvm_root/bin/lld" "$out/bin/ld.lld"
"$work/$llvm_root/bin/llvm-objcopy" --strip-all "$out/bin/clang"
"$work/$llvm_root/bin/llvm-objcopy" --strip-all "$out/bin/ld.lld"
cp -R "$work/$llvm_root/lib/clang/$major/include" "$out/lib/clang/$major/include"
cp "$work/$llvm_root/lib/clang/$major/lib/$gnu_triple/"* "$out/lib/clang/$major/lib/$musl_triple/"

tar -xzf "$musl_tar" -C "$work"
(
  cd "$work/musl-$MUSL_VERSION"
  ./configure --prefix=/ --target="$musl_triple" --disable-shared \
    CC="$out/bin/clang --target=$musl_triple -rtlib=compiler-rt" \
    AR="$work/$llvm_root/bin/llvm-ar" RANLIB="$work/$llvm_root/bin/llvm-ar s" >/dev/null
  make -j"$(getconf _NPROCESSORS_ONLN)" >/dev/null
  make DESTDIR="$out/sysroot" install >/dev/null
)

echo "bundled $musl_triple toolchain in $out"
