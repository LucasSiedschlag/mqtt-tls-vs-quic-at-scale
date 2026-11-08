FROM ubuntu:24.04
# shortcut: arm64 build for Apple silicon hosts, use the amd64 asset on x86
ARG V=0.6.2
ARG ARCH=arm64
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates libatomic1 libssl3t64 iproute2 \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir /opt/emqtt-bench \
 && curl -fsSL https://github.com/emqx/emqtt-bench/releases/download/$V/emqtt-bench-$V-ubuntu24.04-$ARCH-quic.tar.gz \
    | tar -xz -C /opt/emqtt-bench
ENV PATH=/opt/emqtt-bench/bin:$PATH
