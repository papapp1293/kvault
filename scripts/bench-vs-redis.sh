#!/usr/bin/env bash
# Head-to-head benchmark: kvault vs stock Redis, same machine, same workload.
# Requires: redis-benchmark + redis-server installed (brew install redis),
# and a kv-server that speaks RESP (task 001).
# Usage: ./scripts/bench-vs-redis.sh
set -uo pipefail

if ! command -v redis-benchmark >/dev/null 2>&1; then
  echo "redis-benchmark not found. Install it with: brew install redis"
  exit 1
fi

KVAULT_PORT="${KVAULT_PORT:-6379}"
REDIS_PORT="${REDIS_PORT:-6380}"
N="${N:-100000}"
CLIENTS="${CLIENTS:-50}"

echo "== kvault on :$KVAULT_PORT (make sure 'cargo run -p kv-server --release' is running) =="
redis-benchmark -p "$KVAULT_PORT" -n "$N" -c "$CLIENTS" -t set,get --csv

echo
echo "== stock redis on :$REDIS_PORT (start it with: redis-server --port $REDIS_PORT --daemonize yes) =="
redis-benchmark -p "$REDIS_PORT" -n "$N" -c "$CLIENTS" -t set,get --csv

echo
echo "Paste both CSV blocks into the README Benchmarks section with the command used."
