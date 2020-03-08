FROM debian:buster

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bison \
        build-essential \
        ca-certificates \
        coreutils \
        file \
        gawk \
        python3 \
        wget \
    ; \
    apt-get clean; \
    apt-get autoclean; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*;

COPY / /build

RUN /build/build.sh; rm -rf /build;
