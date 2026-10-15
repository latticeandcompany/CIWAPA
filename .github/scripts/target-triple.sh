#!/usr/bin/env bash
# Prints the exact LLVM target triple ciwapa-llvm emits for a platform.
# Usage: target-triple.sh <linux-x64|linux-arm64|macos-arm64|windows-x64|windows-arm64>
set -euo pipefail
case "$1" in
  linux-x64) echo x86_64-unknown-linux-musl ;;
  linux-arm64) echo aarch64-unknown-linux-musl ;;
  macos-arm64) echo arm64-apple-macosx11.0.0 ;;
  windows-x64) echo x86_64-w64-windows-gnu ;;
  windows-arm64) echo aarch64-w64-windows-gnu ;;
  *) echo "unknown platform: $1" >&2; exit 1 ;;
esac
