#!/usr/bin/env bash
# Downloads the Dart SDK that ships inside ciwapa-dart. The version is the Dockerfile's FROM tag.
# Usage: fetch-dart-sdk.sh <linux|macos|windows> <x64|arm64> <out-dir>
set -euo pipefail

os="$1"
arch="$2"
out="$3"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
version="$("$repo_root/.github/scripts/dart-version.sh")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

url="https://storage.googleapis.com/dart-archive/channels/stable/release/$version/sdk/dartsdk-$os-$arch-release.zip"
curl -fsSL -o "$work/sdk.zip" "$url"
expected="$(curl -fsSL "$url.sha256sum" | cut -d' ' -f1)"
actual="$( (sha256sum "$work/sdk.zip" 2>/dev/null || shasum -a 256 "$work/sdk.zip") | cut -d' ' -f1)"
if [[ -z "$expected" || "$expected" != "$actual" ]]; then
  echo "Dart SDK checksum mismatch: expected '$expected', got '$actual'" >&2
  exit 1
fi
rm -rf "$out"
mkdir -p "$out"
unzip -q "$work/sdk.zip" -d "$out"
echo "fetched Dart SDK $version ($os-$arch) into $out/dart-sdk"
