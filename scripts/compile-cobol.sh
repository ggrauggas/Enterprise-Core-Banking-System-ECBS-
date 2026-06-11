#!/bin/sh
# Compiles the ECBS COBOL sources:
#   src/modules/*.cbl  -> dynamic libraries (.so) reachable via CALL
#   src/programs/*.cbl -> executables exposed through the HTTP bridge
# Sources containing EXEC SQL are precompiled with ocesql and linked
# against libocesql (PostgreSQL).
set -e

SRC_DIR=/opt/ecbs/src
BIN_DIR=/opt/ecbs/bin
BUILD_DIR=/opt/ecbs/build
CPY_DIR=/opt/ecbs/copybooks

mkdir -p "$BIN_DIR" "$BUILD_DIR"

compile_one() {
    src=$1
    mode=$2
    name=$(basename "$src" .cbl)
    input=$src
    extra=""
    if grep -qi "EXEC SQL" "$src"; then
        ocesql "$src" "$BUILD_DIR/$name.cob"
        input="$BUILD_DIR/$name.cob"
        extra="-L/usr/local/lib -locesql"
    fi
    if [ "$mode" = "module" ]; then
        cobc -m -O2 -I "$CPY_DIR" -o "$BIN_DIR/$name.so" "$input" $extra
    else
        cobc -x -O2 -I "$CPY_DIR" -o "$BIN_DIR/$name" "$input" $extra
    fi
    echo "compiled ($mode): $name"
}

for f in "$SRC_DIR"/modules/*.cbl; do
    [ -e "$f" ] || continue
    compile_one "$f" module
done

for f in "$SRC_DIR"/programs/*.cbl; do
    [ -e "$f" ] || continue
    compile_one "$f" program
done

echo "COBOL compilation finished. Contents of $BIN_DIR:"
ls -1 "$BIN_DIR"
