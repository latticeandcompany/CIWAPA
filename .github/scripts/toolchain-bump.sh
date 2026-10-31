#!/usr/bin/env bash
# Rewrites the pins in .github/toolchain.env (and the Dockerfile's LLVM_MAJOR), and the editors'
# toolchains in tools/docker and editors/, to the newest upstream releases. Prints the changed pins;
# prints nothing when everything is current.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
env_file="$repo_root/.github/toolchain.env"
# shellcheck source=../toolchain.env
source "$env_file"

latest_llvm="$(gh api repos/llvm/llvm-project/releases --paginate \
  --jq '.[] | select(.prerelease | not) | .tag_name | select(test("^llvmorg-[0-9]+\\.[0-9]+\\.[0-9]+$"))' |
  sed 's/^llvmorg-//' | sort -V | tail -1)"
latest_mingw="$(gh api repos/mstorsjo/llvm-mingw/releases/latest --jq .tag_name)"
latest_musl="$(curl -fsSL https://musl.libc.org/releases.html |
  grep -o 'musl-[0-9][0-9.]*[0-9]\.tar\.gz' | sed 's/^musl-//; s/\.tar\.gz$//' | sort -uV | tail -1)"

require() {
  local name="$1" value="$2" pattern="$3"
  if [[ ! "$value" =~ $pattern ]]; then
    echo "unexpected $name version: '$value'" >&2
    exit 1
  fi
}

require LLVM "$latest_llvm" '^[0-9]+\.[0-9]+\.[0-9]+$'
require llvm-mingw "$latest_mingw" '^[0-9]{8}$'
require musl "$latest_musl" '^[0-9]+(\.[0-9]+)+$'

bump() {
  local key="$1" old="$2" new="$3"
  if [[ "$old" != "$new" ]]; then
    sed -i.bak "s/^$key=.*/$key=$new/" "$env_file" && rm -f "$env_file.bak"
    echo "$key: $old -> $new"
  fi
}

bump LLVM_VERSION "$LLVM_VERSION" "$latest_llvm"
bump LLVM_MINGW_VERSION "$LLVM_MINGW_VERSION" "$latest_mingw"
bump MUSL_VERSION "$MUSL_VERSION" "$latest_musl"

new_major="${latest_llvm%%.*}"
sed -i.bak "s/^ARG LLVM_MAJOR=.*/ARG LLVM_MAJOR=$new_major/" "$repo_root/Dockerfile" && rm -f "$repo_root/Dockerfile.bak"

edit() {  # file, sed expressions...
  local file="$1"
  shift
  sed -i.bak "$@" "$file" && rm -f "$file.bak"
}

# VS Code (Q161, Q175): Node LTS and npm in the node image, the VS Code the smoke test runs, and the
# extension's npm packages. @types/vscode follows engines.vscode, which is raised by hand.
node_dockerfile="$repo_root/tools/docker/node.Dockerfile"
vscode_dir="$repo_root/editors/vscode"
smoke="$vscode_dir/smoke/runSmoke.ts"
latest_node="$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version' | sed 's/^v//')"
latest_npm="$(curl -fsSL https://registry.npmjs.org/npm/latest | jq -r .version)"
latest_vscode="$(curl -fsSL https://update.code.visualstudio.com/api/releases/stable | jq -r '.[0]')"
require Node "$latest_node" '^[0-9]+\.[0-9]+\.[0-9]+$'
require npm "$latest_npm" '^[0-9]+\.[0-9]+\.[0-9]+$'
require "VS Code" "$latest_vscode" '^[0-9]+\.[0-9]+\.[0-9]+$'

old_node="$(sed -n 's/^FROM node:\([0-9.]*\)-trixie-slim$/\1/p' "$node_dockerfile")"
if [[ "$old_node" != "$latest_node" ]]; then
  edit "$node_dockerfile" "s/^FROM node:.*/FROM node:$latest_node-trixie-slim/"
  echo "Node: $old_node -> $latest_node"
fi
old_npm="$(sed -n 's/^ARG NPM_VERSION=//p' "$node_dockerfile")"
if [[ "$old_npm" != "$latest_npm" ]]; then
  edit "$node_dockerfile" "s/^ARG NPM_VERSION=.*/ARG NPM_VERSION=$latest_npm/"
  edit "$vscode_dir/package.json" "s/\"packageManager\": \"npm@[^\"]*\"/\"packageManager\": \"npm@$latest_npm\"/"
  echo "npm: $old_npm -> $latest_npm"
fi
old_vscode="$(sed -n "s/^const vscodeVersion = '\(.*\)';$/\1/p" "$smoke")"
if [[ "$old_vscode" != "$latest_vscode" ]]; then
  edit "$smoke" "s/^const vscodeVersion = .*/const vscodeVersion = '$latest_vscode';/"
  echo "VS Code (smoke test): $old_vscode -> $latest_vscode"
fi
npm_changed=0
for package in vscode-languageclient typescript rolldown oxlint @vscode/vsce @vscode/test-electron jest @swc/jest @swc/core; do
  old="$(jq -r --arg p "$package" '.dependencies[$p] // .devDependencies[$p]' "$vscode_dir/package.json")"
  new="$(curl -fsSL "https://registry.npmjs.org/$package/latest" | jq -r .version)"
  require "$package" "$new" '^[0-9]+\.[0-9]+\.[0-9]+$'
  if [[ "$old" != "$new" ]]; then
    jq --tab --arg p "$package" --arg v "$new" \
      'if .dependencies[$p] then .dependencies[$p] = $v else .devDependencies[$p] = $v end' \
      "$vscode_dir/package.json" >"$vscode_dir/package.json.new"
    mv "$vscode_dir/package.json.new" "$vscode_dir/package.json"
    echo "$package: $old -> $new"
    npm_changed=1
  fi
done
if [[ "$npm_changed" == 1 ]]; then
  (cd "$vscode_dir" && "$repo_root/tools/in-docker" --image node npm install --no-audit --no-fund >&2)
fi

# JetBrains: Temurin 21, Gradle, Kotlin, the IntelliJ Platform Gradle Plugin, and the newest IDE the
# verifier checks. The compile and test target stays at the 2026.1 minimum on purpose.
jetbrains_dir="$repo_root/editors/jetbrains"
jdk_dockerfile="$repo_root/tools/docker/jdk.Dockerfile"
old_jdk="$(sed -n 's/^FROM eclipse-temurin:\(.*\)-jdk-noble$/\1/p' "$jdk_dockerfile")"
latest_jdk="$(curl -fsSL 'https://hub.docker.com/v2/repositories/library/eclipse-temurin/tags/?page_size=100&name=21.' |
  jq -r '.results[].name' | grep -E '^21\.[0-9.]+_[0-9]+-jdk-noble$' | sed 's/-jdk-noble$//' | sort -V | tail -1)"
require JDK "$latest_jdk" '^21\.[0-9.]+_[0-9]+$'
if [[ "$old_jdk" != "$latest_jdk" ]]; then
  edit "$jdk_dockerfile" "s/^FROM eclipse-temurin:.*/FROM eclipse-temurin:$latest_jdk-jdk-noble/"
  echo "Temurin: $old_jdk -> $latest_jdk"
fi

old_gradle="$(sed -n 's|.*gradle-\(.*\)-bin\.zip$|\1|p' "$jetbrains_dir/gradle/wrapper/gradle-wrapper.properties")"
latest_gradle="$(curl -fsSL https://services.gradle.org/versions/current | jq -r .version)"
require Gradle "$latest_gradle" '^[0-9]+\.[0-9]+(\.[0-9]+)?$'
if [[ "$old_gradle" != "$latest_gradle" ]]; then
  sum="$(curl -fsSL "https://services.gradle.org/distributions/gradle-$latest_gradle-bin.zip.sha256")"
  require "Gradle SHA-256" "$sum" '^[0-9a-f]{64}$'
  # The second run replaces the wrapper jar with the new version's own.
  for _ in 1 2; do
    (cd "$jetbrains_dir" && "$repo_root/tools/in-docker" --image jdk ./gradlew --console=plain wrapper \
      --gradle-version "$latest_gradle" --distribution-type bin --gradle-distribution-sha256-sum "$sum" >&2)
  done
  echo "Gradle: $old_gradle -> $latest_gradle"
fi

bump_gradle_plugin() {  # plugin id, new version, name
  local old
  old="$(sed -n "s/.*id(\"$1\") version \"\([^\"]*\)\".*/\1/p" "$jetbrains_dir/settings.gradle.kts")"
  if [[ "$old" != "$2" ]]; then
    edit "$jetbrains_dir/settings.gradle.kts" "s/id(\"$1\") version \"$old\"/id(\"$1\") version \"$2\"/"
    echo "$3: $old -> $2"
  fi
}
latest_kotlin="$(gh api repos/JetBrains/kotlin/releases/latest --jq .tag_name | sed 's/^v//')"
require Kotlin "$latest_kotlin" '^2\.[0-9]+\.[0-9]+$'
bump_gradle_plugin org.jetbrains.kotlin.jvm "$latest_kotlin" Kotlin
latest_ijpgp="$(gh api repos/JetBrains/intellij-platform-gradle-plugin/releases \
  --jq '[.[] | select(.prerelease | not) | .tag_name | select(test("^v?2\\."))][0]' | sed 's/^v//')"
require "IntelliJ Platform Gradle Plugin" "$latest_ijpgp" '^2\.[0-9]+\.[0-9]+$'
bump_gradle_plugin org.jetbrains.intellij.platform.settings "$latest_ijpgp" "IntelliJ Platform Gradle Plugin"

old_ide="$(sed -n 's/.*create(IntelliJPlatformType.IntellijIdea, "\([^"]*\)").*/\1/p' "$jetbrains_dir/build.gradle.kts")"
latest_ide="$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=IIU&type=release&latest=true' | jq -r '.IIU[0].version')"
require IntelliJ "$latest_ide" '^20[0-9]{2}\.[0-9]+(\.[0-9]+)*$'
if [[ "$old_ide" != "$latest_ide" ]]; then
  edit "$jetbrains_dir/build.gradle.kts" "s/create(IntelliJPlatformType.IntellijIdea, \"$old_ide\")/create(IntelliJPlatformType.IntellijIdea, \"$latest_ide\")/"
  echo "IntelliJ (verifier): $old_ide -> $latest_ide"
fi

# Neovim: the newest stable release, and the newest 0.11.x as the floor (R12), each checked by the
# SHA-256 GitHub records for its release archives.
nvim_dockerfile="$repo_root/tools/docker/neovim.Dockerfile"
nvim_sha() {  # version, arch
  gh api "repos/neovim/neovim/releases/tags/v$1" \
    --jq ".assets[] | select(.name == \"nvim-linux-$2.tar.gz\") | .digest" | sed 's/^sha256://'
}
bump_nvim() {  # ARG prefix, new version
  local prefix="$1" new="$2" old x86 arm
  old="$(sed -n "s/^ARG ${prefix}_VERSION=//p" "$nvim_dockerfile")"
  [[ "$old" == "$new" ]] && return
  x86="$(nvim_sha "$new" x86_64)"
  arm="$(nvim_sha "$new" arm64)"
  require "Neovim $new x86_64 SHA-256" "$x86" '^[0-9a-f]{64}$'
  require "Neovim $new arm64 SHA-256" "$arm" '^[0-9a-f]{64}$'
  edit "$nvim_dockerfile" \
    -e "s/^ARG ${prefix}_VERSION=.*/ARG ${prefix}_VERSION=$new/" \
    -e "s/^ARG ${prefix}_SHA256_X86_64=.*/ARG ${prefix}_SHA256_X86_64=$x86/" \
    -e "s/^ARG ${prefix}_SHA256_ARM64=.*/ARG ${prefix}_SHA256_ARM64=$arm/"
  echo "Neovim ($prefix): $old -> $new"
}
latest_nvim="$(gh api repos/neovim/neovim/releases/latest --jq .tag_name | sed 's/^v//')"
latest_nvim_floor="$(gh api repos/neovim/neovim/releases --paginate --jq '.[] | select(.prerelease | not) | .tag_name' |
  grep -E '^v0\.11\.[0-9]+$' | sed 's/^v//' | sort -V | tail -1)"
require Neovim "$latest_nvim" '^[0-9]+\.[0-9]+\.[0-9]+$'
require "Neovim floor" "$latest_nvim_floor" '^0\.11\.[0-9]+$'
bump_nvim NVIM "$latest_nvim"
bump_nvim NVIM_FLOOR "$latest_nvim_floor"
