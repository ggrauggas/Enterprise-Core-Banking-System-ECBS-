#!/bin/sh
# Compiles and runs the ECBS COBOL unit tests (Fase 14).
#
# The pure business modules (no embedded SQL) are compiled as dynamic
# libraries (.so) and each TEST-*.cbl driver is compiled as an executable
# that CALLs them. A driver returns RETURN-CODE = number of failed
# assertions, so a non-zero exit from any driver fails the whole run.
#
# Usage (locally or in CI, needs gnucobol3):
#   sh scripts/run-cobol-tests.sh
set -e

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC_DIR="$ROOT/cobol/src"
CPY_DIR="$ROOT/copybooks"
BIN_DIR="$ROOT/cobol/build-tests"

# Modules under test: the pure ones, callable without a database.
MODULES="MONEY_UTILS VALIDATION DATE_UTILS IBAN_UTILS"
# Test drivers, each exits with its failure count.
DRIVERS="TEST-MONEY TEST-VALIDATION TEST-DATEUTILS TEST-IBAN"

rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"

echo "Compiling COBOL modules under test..."
for m in $MODULES; do
    cobc -m -O2 -I "$CPY_DIR" -o "$BIN_DIR/$m.so" "$SRC_DIR/modules/$m.cbl"
    echo "  module: $m"
done

echo "Compiling COBOL test drivers..."
for d in $DRIVERS; do
    cobc -x -O2 -I "$CPY_DIR" -o "$BIN_DIR/$d" "$SRC_DIR/tests/$d.cbl"
    echo "  driver: $d"
done

# CALL resolves the .so modules from here.
COB_LIBRARY_PATH="$BIN_DIR"
export COB_LIBRARY_PATH

TOTAL_FAIL=0
echo ""
echo "Running COBOL unit tests"
echo "========================"
for d in $DRIVERS; do
    if "$BIN_DIR/$d"; then
        echo "[OK]   $d"
    else
        rc=$?
        echo "[FAIL] $d ($rc failed assertion(s))"
        TOTAL_FAIL=$((TOTAL_FAIL + rc))
    fi
    echo "------------------------"
done

if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo "All COBOL unit tests passed."
    exit 0
else
    echo "COBOL unit tests failed: $TOTAL_FAIL assertion(s)."
    exit 1
fi
