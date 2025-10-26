#!/usr/bin/env bash
set -euo pipefail

# Simple automation to compare benchmark configurations and write results to docs/bench_results.md
# Usage: ./scripts/bench_compare.sh [url] [duration] [concurrency]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

URL=${1:-http://localhost:3000/}
DURATION=${2:-10s}
CONCURRENCY=${3:-100}

OUTFILE="docs/bench_results.md"
mkdir -p docs

# pool sizes are specified as BUF:COUNT
pool_sizes=("512:1024" "1024:2048" "2048:4096")

echo "# Benchmark results" > "$OUTFILE"
echo "" >> "$OUTFILE"
echo "| Config | HIKARI_POOL_BUF | HIKARI_POOL_COUNT | HIKARI_WORKERS | HIKARI_CHILD_STDIO | Req/s (avg) | Latency (avg) |" >> "$OUTFILE"
echo "|---|---:|---:|---:|---:|---:|" >> "$OUTFILE"

run_single() {
  local workers=$1
  local child_stdio=$2
  local pool_buf=$3
  local pool_count=$4

  echo "\n=== Running: pool=${pool_buf}:${pool_count} workers=${workers} child_stdio=${child_stdio} ==="

  # set env for this run
  if [ -n "${workers}" ]; then
    export HIKARI_WORKERS="$workers"
  else
    unset HIKARI_WORKERS || true
  fi

  if [ "${child_stdio}" = "devnull" ]; then
    export HIKARI_CHILD_STDIO=devnull
  else
    unset HIKARI_CHILD_STDIO || true
  fi

  export HIKARI_POOL_BUF=${pool_buf}
  export HIKARI_POOL_COUNT=${pool_count}

  # start server
  mkdir -p logs
  ./bin/hikari_server --port 3000 > logs/worker_3000.log 2>&1 &
  pid=$!
  echo "started master pid=${pid}"
  # record master pid for external cleanup
  echo "${pid}" > logs/master.pid

  # wait for readiness (timeout 15s)
  ok=0
  for i in $(seq 1 15); do
    if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q ^2; then
      ok=1
      break
    fi
    sleep 1
  done

  if [ "$ok" -ne 1 ]; then
    echo "server did not become ready; killing pid ${pid}" >&2
    bash scripts/stop_workers.sh || true
    return 1
  fi

  # warmup
  bombardier --fasthttp -d 2s -c 10 "$URL" >/dev/null 2>&1 || true

  # measurement
  tmpfile=$(mktemp)
  bombardier --fasthttp -d ${DURATION} -c ${CONCURRENCY} "$URL" > "$tmpfile" 2>&1 || true

  # parse last Reqs/sec and last Latency lines
  reqs_line=$(grep "Reqs/sec" "$tmpfile" | tail -n1 || true)
  latency_line=$(grep "Latency" "$tmpfile" | tail -n1 || true)
  reqs_val="N/A"
  latency_val="N/A"
  if [ -n "$reqs_line" ]; then
    # second column contains numeric value (may include decimals)
    reqs_val=$(echo "$reqs_line" | awk '{print $2}')
  fi
  if [ -n "$latency_line" ]; then
    # Latency typically in 2nd column (may include units)
    latency_val=$(echo "$latency_line" | awk '{print $2}')
  fi

  # human-friendly displays
  display_workers="${workers:-auto}"
  if [ "${child_stdio}" = "devnull" ]; then
    display_stdio="devnull"
  else
    display_stdio="inherit"
  fi

  # append result row
  echo "| ${pool_buf}:${pool_count} | ${pool_buf} | ${pool_count} | ${display_workers} | ${display_stdio} | ${reqs_val} | ${latency_val} |" >> "$OUTFILE"

  # cleanup for this run
  bash scripts/stop_workers.sh || true
  rm -f "$tmpfile" || true
  return 0

}

# Driver: run combinations of pool sizes and a couple worker/stdio modes
workers_list=("" "1")
child_stdio_list=("inherit" "devnull")

for pool in "${pool_sizes[@]}"; do
  IFS=':' read -r pool_buf pool_count <<< "$pool"
  for w in "${workers_list[@]}"; do
    for cs in "${child_stdio_list[@]}"; do
      run_single "$w" "$cs" "$pool_buf" "$pool_count" || true
      # small cooldown between runs
      sleep 1
    done
  done
done
