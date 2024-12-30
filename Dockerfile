FROM ubuntu:18.04 AS builder

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential autotools-dev debhelper \
        gobjc gobjc++ gobjc-multilib gobjc++-multilib \
        libgnustep-base-dev gnustep-core-devel sqlite \
        libsqlite3-dev openssl libcurl4-openssl-dev curl \
        tcl tcl-dev tcl-doc tclthread tclreadline \
        freebsd-buildutils binutils libc6-dev perl \
        doxygen swig cvs ed pax rlwrap rsync libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ADD . /tmp/

RUN cd /tmp/ \
    && ./configure --with-objc-runtime=GNU --with-objc-foundation=GNU --enable-maintainer-mode --enable-symbols --enable-readline \
    && make \
    && make install

FROM ubuntu:18.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential autotools-dev debhelper \
        gobjc gobjc++ gobjc-multilib gobjc++-multilib \
        libgnustep-base-dev gnustep-core-devel sqlite \
        libsqlite3-dev openssl libcurl4-openssl-dev curl \
        tcl tcl-dev tcl-doc tclthread tclreadline \
        freebsd-buildutils binutils libc6-dev perl \
        doxygen swig cvs ed pax rlwrap rsync libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/local /opt/local

ENV PATH="/opt/local/bin:$PATH"
