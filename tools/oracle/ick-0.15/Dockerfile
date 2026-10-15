# TEMPORARY (goal 2's cleanup removes it): C-INTERCAL 0.15, the compiler the spec documents,
# built as a second differential oracle. Best effort: see port.sh for what it takes.
FROM debian:13.7-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gcc libc6-dev make flex bison \
 && rm -rf /var/lib/apt/lists/*

ARG ICK_SHA256=b9cbd2b3822542c38ecffe200582850de44219b9336b44a992bf88fc41c6b7ba
COPY port.sh /tmp/port.sh

RUN curl -fsSL -o /tmp/ick.tar.gz https://gitlab.com/esr/intercal/-/archive/0.15/intercal-0.15.tar.gz \
 && echo "$ICK_SHA256  /tmp/ick.tar.gz" | sha256sum -c - \
 && mkdir -p /opt/src /opt/ick && tar -xzf /tmp/ick.tar.gz -C /opt/src \
 && sh /tmp/port.sh /opt/src/intercal-0.15/src \
 && make -C /opt/src/intercal-0.15/src DVMT=/opt/ick \
      CC="gcc -std=gnu89 -w" DEBUG="-O2" YDEBUG="" install \
 && rm -rf /tmp/ick.tar.gz

ENV PATH=/opt/ick/bin:$PATH
WORKDIR /work
