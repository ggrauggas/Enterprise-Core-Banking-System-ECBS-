# ECBS COBOL runtime: GnuCOBOL toolchain + Open-COBOL-ESQL (PostgreSQL
# embedded SQL precompiler) + a minimal HTTP bridge that exposes the
# compiled COBOL programs to the backend.
#
# Build context is the repository root so both /cobol and /copybooks
# can be copied into the image.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        gnucobol3 \
        gcc \
        make \
        git \
        ca-certificates \
        autoconf \
        automake \
        libtool \
        bison \
        flex \
        gettext \
        pkg-config \
        libpq-dev \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# Open-COBOL-ESQL (ocesql): translates EXEC SQL blocks into calls against
# PostgreSQL. Kept in its own layer so toolchain changes do not force a
# full rebuild.
RUN git clone --depth 1 https://github.com/opensourcecobol/Open-COBOL-ESQL.git /tmp/ocesql \
    && cd /tmp/ocesql \
    && (test -f configure || autoreconf -fiv) \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && ldconfig \
    && mkdir -p /usr/local/share/ocesql/copy \
    && cp /tmp/ocesql/copy/sqlca.cbl /usr/local/share/ocesql/copy/ \
    && rm -rf /tmp/ocesql

WORKDIR /opt/ecbs

COPY copybooks/ /opt/ecbs/copybooks/
COPY cobol/src/ /opt/ecbs/src/
COPY cobol/bridge/ /opt/ecbs/bridge/
COPY scripts/compile-cobol.sh /opt/ecbs/compile-cobol.sh

RUN chmod +x /opt/ecbs/compile-cobol.sh && /opt/ecbs/compile-cobol.sh \
    && mkdir -p /opt/ecbs/logs /opt/ecbs/batch-output /opt/ecbs/reports

ENV ECBS_BIN_DIR=/opt/ecbs/bin
# Where CALL resolves the dynamic COBOL modules (.so)
ENV COB_LIBRARY_PATH=/opt/ecbs/bin
# Preload the ocesql runtime so CALL 'OCESQLConnect' etc. resolve
ENV COB_PRE_LOAD=/usr/local/lib/libocesql.so
ENV ECBS_LOG_FILE=/opt/ecbs/logs/ecbs.log
# Where the nightly batch writes BATCH_LOG / RUN_SUMMARY / AUDIT_REPORT
ENV ECBS_BATCH_DIR=/opt/ecbs/batch-output
# Where the reporting programs write their CSV / PDF exports
ENV ECBS_REPORT_DIR=/opt/ecbs/reports
ENV BRIDGE_PORT=9090

EXPOSE 9090

CMD ["python3", "/opt/ecbs/bridge/server.py"]
