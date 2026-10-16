# TEMPORARY (goal 2's cleanup removes it): CLC-INTERCAL benchmark baseline (Q30), from Debian's package.
FROM debian:13.7-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends clc-intercal=1:1.00-3 \
 && rm -rf /var/lib/apt/lists/*

COPY bench-build /usr/local/bin/bench-build
WORKDIR /work
