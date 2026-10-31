# Headless Neovim for editors/neovim's lint, unit checks and smoke test (Q161, Q177).
# NVIM_VERSION is the newest stable release; NVIM_FLOOR_VERSION is the oldest the plugin
# supports (R12: 0.11+), installed as nvim-floor so every check runs on both.
FROM debian:trixie-20261027-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

ARG NVIM_VERSION=0.12.6
ARG NVIM_SHA256_X86_64=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
ARG NVIM_SHA256_ARM64=8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815
ARG NVIM_FLOOR_VERSION=0.11.7
ARG NVIM_FLOOR_SHA256_X86_64=38a7c6317f94503841096c00e8fde05ef04b9472fc9d7d62b6e033cecd6f7991
ARG NVIM_FLOOR_SHA256_ARM64=99bb3c53604e83ce18fc0b459e34cf1a5e212f4e5fbe2eb136b3c18092ae9905

RUN set -eu \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && case "$(dpkg --print-architecture)" in \
      amd64) arch=x86_64; sha="$NVIM_SHA256_X86_64"; floor_sha="$NVIM_FLOOR_SHA256_X86_64" ;; \
      arm64) arch=arm64; sha="$NVIM_SHA256_ARM64"; floor_sha="$NVIM_FLOOR_SHA256_ARM64" ;; \
      *) echo "no Neovim release for $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
 && install_nvim() { \
      curl -fsSL -o /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/download/v$1/nvim-linux-$arch.tar.gz" \
      && echo "$2  /tmp/nvim.tar.gz" | sha256sum -c - \
      && mkdir -p "$3" \
      && tar -xzf /tmp/nvim.tar.gz -C "$3" --strip-components=1 \
      && rm /tmp/nvim.tar.gz; \
    } \
 && install_nvim "$NVIM_VERSION" "$sha" /opt/nvim \
 && install_nvim "$NVIM_FLOOR_VERSION" "$floor_sha" /opt/nvim-floor \
 && ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim \
 && ln -s /opt/nvim-floor/bin/nvim /usr/local/bin/nvim-floor \
 && apt-get purge -y curl \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
