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

for dir in packages/*/test tools/*/test; do
  if [[ -d "$dir" ]]; then
    (cd "${dir%/test}" && dart --suppress-analytics test)
  fi
done

echo "ci-check passed for $platform $flavor"
