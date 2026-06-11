#!/bin/sh
# Compiles every COBOL program under /opt/ecbs/src into /opt/ecbs/bin.
# Programs containing EXEC SQL blocks are precompiled with ocesql first
# and linked against libocesql (PostgreSQL).
set -e

SRC_DIR=/opt/ecbs/src
BIN_DIR=/opt/ecbs/bin
BUILD_DIR=/opt/ecbs/build
CPY_DIR=/opt/ecbs/copybooks

mkdir -p "$BIN_DIR" "$BUILD_DIR"

for src in "$SRC_DIR"/*.cbl; do
    [ -e "$src" ] || continue
    name=$(basename "$src" .cbl)
    if grep -qi "EXEC SQL" "$src"; then
        ocesql "$src" "$BUILD_DIR/$name.cob"
        cobc -x -O2 -I "$CPY_DIR" -o "$BIN_DIR/$name" "$BUILD_DIR/$name.cob" \
            -L/usr/local/lib -locesql
    else
        cobc -x -O2 -I "$CPY_DIR" -o "$BIN_DIR/$name" "$src"
    fi
    echo "compiled: $name"
done

echo "COBOL compilation finished. Binaries in $BIN_DIR:"
ls -1 "$BIN_DIR"
