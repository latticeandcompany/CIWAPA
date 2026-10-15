# TEMPORARY (goal 2's cleanup removes it): rick benchmark baseline (Q30), compiled mode with rustc -O.
FROM debian:13.7-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gcc libc6-dev \
 && rm -rf /var/lib/apt/lists/*

# rick itself needs nightly; the Rust it generates is compiled by the same toolchain's rustc.
ARG RUSTUP_VERSION=1.28.2
ARG RUST_TOOLCHAIN=nightly-2026-02-20
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo PATH=/opt/cargo/bin:$PATH
RUN curl -fsSL -o /tmp/rustup-init \
      https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$(uname -m)-unknown-linux-gnu/rustup-init \
 && chmod +x /tmp/rustup-init \
 && /tmp/rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_TOOLCHAIN \
 && rm /tmp/rustup-init

# rick ships no Cargo.lock; ours was resolved against this toolchain and pins the crates.
ARG RICK_COMMIT=1d62fae815da1ac494fe055ec8a3bc4adb213140
COPY Cargo.lock /tmp/Cargo.lock
RUN mkdir -p /opt/src/rick \
 && curl -fsSL https://github.com/birkenfeld/rick/archive/$RICK_COMMIT.tar.gz \
    | tar -xz --strip-components=1 -C /opt/src/rick \
 && mv /tmp/Cargo.lock /opt/src/rick/ \
 && cargo install --locked --path /opt/src/rick --root /usr/local \
 && rm -rf /opt/src/rick/target /opt/cargo/registry

COPY bench-build /usr/local/bin/bench-build
WORKDIR /work
