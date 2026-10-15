#!/usr/bin/env bash
# Lint, unit tests and (once it exists) conformance for one flavor. Runs on every CI job:
# inside ciwapa-toolchain on Linux, and directly on the macOS and Windows runners.
# Usage: ci-check.sh <platform> <dart|llvm>
set -euo pipefail

platform="$1"
flavor="$2"

dart --suppress-analytics pub get
dart --suppress-analytics analyze --fatal-infos
dart --suppress-analytics format --output=none --set-exit-if-changed .

mapfile -t test_dirs < <(find . -path ./.cache -prune -o -path '*/test' -type d -not -path '*/.dart_tool/*' -print)
if ((${#test_dirs[@]})); then
  dart --suppress-analytics test "${test_dirs[@]}"
fi

echo "ci-check passed for $platform $flavor"
