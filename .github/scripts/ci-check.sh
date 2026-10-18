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

exe=""
case "$platform" in windows-*) exe=".exe" ;; esac
mkdir -p .cache/build .cache/conformance
dart --suppress-analytics compile exe "packages/ciwapa_$flavor/bin/ciwapa_$flavor.dart" -o ".cache/build/ciwapa-$flavor$exe"
(
  cd packages/conformance
  dart --suppress-analytics run bin/conformance.dart \
    --compiler "../../.cache/build/ciwapa-$flavor$exe" --results ../../.cache/conformance/results.json
)

# Once per flavor, every .xc program runs again on the control engine, which then has to behave
# exactly as Mode 1 does on the whole suite (CIWAPA_TEST_ENGINE is test-only).
if [[ "$platform" == linux-x64 ]]; then
  (
    cd packages/conformance
    CIWAPA_TEST_ENGINE=1 dart --suppress-analytics run bin/conformance.dart \
      --compiler "../../.cache/build/ciwapa-$flavor$exe" --extracal-only
  )
fi

echo "ci-check passed for $platform $flavor"
