#!/usr/bin/env bash
# Lint, unit tests, conformance and the Interstates suite for one flavor. Runs on every CI job:
# inside ciwapa-toolchain on Linux, and directly on the macOS and Windows runners.
# Usage: ci-check.sh <platform> <dart|llvm>
set -euo pipefail

platform="$1"
flavor="$2"

dart --suppress-analytics pub get
dart --suppress-analytics analyze --fatal-infos

# ActiveCassette's SQLite, for the triple ioi-llvm targets with the clang on the PATH, and as the
# library ioi-dart programs load.
case "$platform" in
  linux-x64) triple=x86_64-unknown-linux-gnu ;;
  linux-arm64) triple=aarch64-unknown-linux-gnu ;;
  macos-arm64) triple=arm64-apple-macosx11.0.0 ;;
  windows-x64) triple=x86_64-w64-windows-gnu ;;
  windows-arm64) triple=aarch64-w64-windows-gnu ;;
esac
apps/interstates/tool/activecassette.sh .cache/ioi-lib clang "$triple" clang
IOI_LIB="$PWD/.cache/ioi-lib"
# Git Bash's /d/a/... isn't a path the compilers or programs can open.
[[ "$platform" == windows-* ]] && IOI_LIB="$(cygpath -m "$IOI_LIB")"
export IOI_LIB
dart --suppress-analytics format --output=none --set-exit-if-changed .

for dir in packages/*/test apps/*/test tools/*/test; do
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

# INTERCAL on Interstates' own suite, through this flavor's ioi-* compiler.
mkdir -p .cache/interstates
dart --suppress-analytics compile exe "apps/interstates/bin/ioi_$flavor.dart" -o ".cache/build/ioi-$flavor$exe"
(
  cd packages/conformance
  dart --suppress-analytics run bin/conformance.dart \
    --compiler "../../.cache/build/ioi-$flavor$exe" --tests ../../apps/interstates/test/golden --extension ioi \
    --results ../../.cache/interstates/results.json
)

# Once per flavor, every .xc program runs again on the control engine, which then has to behave
# exactly as Mode 1 does on the whole suite, and the Interstates suite with it (CIWAPA_TEST_ENGINE is
# test-only).
if [[ "$platform" == linux-x64 ]]; then
  (
    cd packages/conformance
    CIWAPA_TEST_ENGINE=1 dart --suppress-analytics run bin/conformance.dart \
      --compiler "../../.cache/build/ciwapa-$flavor$exe" --extracal-only
    CIWAPA_TEST_ENGINE=1 dart --suppress-analytics run bin/conformance.dart \
      --compiler "../../.cache/build/ioi-$flavor$exe" --tests ../../apps/interstates/test/golden --extension ioi
  )
fi

echo "ci-check passed for $platform $flavor"
