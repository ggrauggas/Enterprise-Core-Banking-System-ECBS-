#!/bin/sh
# ECBS nightly batch launcher.
# Triggers BATCH-NIGHTLY through the COBOL bridge (the role a job
# scheduler like Control-M or cron would play against a mainframe).
#
# Usage: ./run-nightly.sh [bridge-url]
#   default bridge-url: http://localhost:9090
#
# Fase 15 - recuperación ante fallos: the launch is retried with backoff
# while the bridge is still warming up or transiently unavailable, and the
# script exits non-zero if the run cannot be started or the program reports
# a failing exit code, so the scheduler can alert and re-queue.
set -eu

BRIDGE_URL=${1:-http://localhost:9090}
MAX_ATTEMPTS=${ECBS_BATCH_MAX_ATTEMPTS:-5}
BACKOFF=${ECBS_BATCH_BACKOFF_SECONDS:-10}
RESP=/tmp/ecbs_nightly_resp.json

echo "ECBS nightly batch -> $BRIDGE_URL/run/BATCH-NIGHTLY"

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    echo "Attempt $attempt/$MAX_ATTEMPTS ..."
    if curl -sf -X POST "$BRIDGE_URL/run/BATCH-NIGHTLY" \
            -H 'Content-Type: application/json' \
            -d '{"user":"scheduler"}' -o "$RESP"; then
        # The bridge wraps the program result; exitCode 0 means success.
        exit_code=$(python3 -c "import json;print(json.load(open('$RESP')).get('exitCode',1))" 2>/dev/null || echo 1)
        if [ "$exit_code" = "0" ]; then
            echo "Nightly batch completed successfully."
            cat "$RESP"; echo
            echo "Output files inside the cobol-runtime container:"
            echo "  /opt/ecbs/batch-output/BATCH_LOG.log"
            echo "  /opt/ecbs/batch-output/RUN_SUMMARY.rpt"
            echo "  /opt/ecbs/batch-output/AUDIT_REPORT.rpt"
            exit 0
        fi
        echo "Batch program returned a non-zero exit code ($exit_code):"
        cat "$RESP"; echo
        echo "Not retrying a business failure; investigate the BATCH_LOG."
        exit 2
    fi

    echo "Bridge unreachable; retrying in ${BACKOFF}s..."
    attempt=$((attempt + 1))
    sleep "$BACKOFF"
done

echo "Nightly batch could not be launched after $MAX_ATTEMPTS attempts." >&2
exit 1
