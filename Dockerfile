FROM dart:3.13.6

ARG LLVM_MAJOR=23

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/trixie/ llvm-toolchain-trixie-${LLVM_MAJOR} main" > /etc/apt/sources.list.d/llvm.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends clang-${LLVM_MAJOR} lld-${LLVM_MAJOR} llvm-${LLVM_MAJOR} libc6-dev make xz-utils \
 && ln -s /usr/bin/clang-${LLVM_MAJOR} /usr/local/bin/clang \
 && ln -s /usr/bin/ld.lld-${LLVM_MAJOR} /usr/local/bin/ld.lld \
 && ln -s /usr/bin/llvm-as-${LLVM_MAJOR} /usr/local/bin/llvm-as \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
