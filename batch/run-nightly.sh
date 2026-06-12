#!/bin/sh
# ECBS nightly batch launcher.
# Triggers BATCH-NIGHTLY through the COBOL bridge (the role a job
# scheduler like Control-M or cron would play against a mainframe).
#
# Usage: ./run-nightly.sh [bridge-url]
#   default bridge-url: http://localhost:9090
set -e

BRIDGE_URL=${1:-http://localhost:9090}

echo "ECBS nightly batch -> $BRIDGE_URL/run/BATCH-NIGHTLY"
curl -sf -X POST "$BRIDGE_URL/run/BATCH-NIGHTLY" \
     -d '{"user":"scheduler"}'
echo
echo "Output files inside the cobol-runtime container:"
echo "  /opt/ecbs/batch-output/BATCH_LOG.log"
echo "  /opt/ecbs/batch-output/RUN_SUMMARY.rpt"
echo "  /opt/ecbs/batch-output/AUDIT_REPORT.rpt"
