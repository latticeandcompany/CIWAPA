#!/usr/bin/env bash
# Prints the pinned Dart version: the Dockerfile's FROM tag is the single source of truth.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
sed -n 's/^FROM dart:\([0-9][0-9.]*\).*/\1/p' "$repo_root/Dockerfile"
