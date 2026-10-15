# TEMPORARY (goal 2's cleanup removes it): C-INTERCAL 0.35, the main differential oracle (Q36).
FROM debian:13.7-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gcc libc6-dev make flex bison \
 && rm -rf /var/lib/apt/lists/*

ARG ICK_SHA256=b55e8edc68e2517a067a902766e2f57b97b502553fdcbae2b5ab2463ba58f0e1

RUN curl -fsSL -o /tmp/ick.tar.gz http://www.catb.org/~esr/intercal/intercal-0.35.tar.gz \
 && echo "$ICK_SHA256  /tmp/ick.tar.gz" | sha256sum -c - \
 && mkdir -p /opt/src && tar -xzf /tmp/ick.tar.gz -C /opt/src \
 && cd /opt/src/intercal-0.35 && ./configure --prefix=/opt/ick >/dev/null && make >/dev/null && make install >/dev/null \
 && rm -rf /tmp/ick.tar.gz

ENV PATH=/opt/ick/bin:$PATH
WORKDIR /work
