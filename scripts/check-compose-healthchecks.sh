#!/bin/sh
# Usage: sh scripts/check-compose-healthchecks.sh
# Requires: docker compose, jq
set -eu

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required." >&2; exit 2; }

cd "$(dirname "$0")/.."
JSON=$(docker compose --env-file .env.example config --format json 2>/dev/null)
[ -n "$JSON" ] || { echo "ERROR: docker compose config returned empty output." >&2; exit 2; }

# For each service that is a depends_on target with condition:service_healthy,
# check that the target service itself defines a healthcheck block.
# tr -d '\r' strips CRLF from jq.exe output on Windows.
FAILED=0
for DEP in $(printf '%s' "$JSON" | jq -r '.services | to_entries[] | .value.depends_on // {} | to_entries[] | select(.value.condition == "service_healthy") | .key' | tr -d '\r' | sort -u); do
  HAS=$(printf '%s' "$JSON" | jq -r --arg s "$DEP" '.services[$s].healthcheck // empty' | tr -d '\r')
  if [ -z "$HAS" ]; then
    echo "FAIL: service '$DEP' is a service_healthy dependency but has no healthcheck block." >&2
    FAILED=1
  fi
done

if [ "$FAILED" -eq 0 ]; then
  echo "OK: every depends_on service_healthy target declares a healthcheck."
fi
exit "$FAILED"
