#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Build production binary"
# place binary in ./bin to match other scripts
mkdir -p ./bin
v -prod -o ./bin/hikari_server example/main.v

echo "Start server (background)..."
mkdir -p logs
# PERF_MODE: when non-empty (default), select sane defaults for high-throughput
# runs: set worker count to number of CPUs, redirect child stdio to /dev/null,
# and increase buffer pool sizes. Set PERF_MODE=0 to disable.
if [ "${PERF_MODE:-1}" -ne 0 ] 2>/dev/null || [ "${PERF_MODE:-1}" = "1" ]; then
	echo "PERF_MODE enabled: tuning env for throughput"
	# prefer explicit HIKARI_WORKERS if given; otherwise pick nproc
	if [ -z "${HIKARI_WORKERS:-}" ]; then
		if command -v nproc >/dev/null 2>&1; then
			HIKARI_WORKERS=$(nproc --all)
		else
			HIKARI_WORKERS=1
		fi
		export HIKARI_WORKERS
	fi
	export HIKARI_CHILD_STDIO=devnull
	export HIKARI_POOL_BUF=${HIKARI_POOL_BUF:-2048}
	export HIKARI_POOL_COUNT=${HIKARI_POOL_COUNT:-4096}
	echo "HIKARI_WORKERS=${HIKARI_WORKERS} HIKARI_CHILD_STDIO=${HIKARI_CHILD_STDIO} HIKARI_POOL_BUF=${HIKARI_POOL_BUF} HIKARI_POOL_COUNT=${HIKARI_POOL_COUNT}"
else
	echo "PERF_MODE disabled: leaving HIKARI_* env as-is"
fi

echo "Launching server (perf-tuned)..."
./bin/hikari_server --port 3000 > logs/worker_3000.log 2>&1 &
server_pid=$!
echo "server pid=${server_pid}"

# Ensure the started server is killed if this script exits early or is killed.
cleanup() {
	echo "Stopping server pid=${server_pid}"
	# attempt to kill master and any recorded children
	kill ${server_pid} 2>/dev/null || true
	bash scripts/stop_workers.sh || true
}
trap cleanup EXIT

# wait for readiness (timeout 15s)
ok=0
for i in $(seq 1 15); do
	if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/" | grep -q ^2; then
		ok=1
		break
	fi
	sleep 1
done

if [ "$ok" -ne 1 ]; then
	echo "server did not become ready; killing pid ${server_pid}" >&2
	kill ${server_pid} 2>/dev/null || true
	exit 1
fi

echo "Warmup..."
bombardier --fasthttp -d 5s -c 100 http://localhost:3000/hello

echo "Benchmark..."
bombardier --fasthttp -d 10s -c 100 http://localhost:3000/

echo "Stopping server pid=${server_pid}"
kill ${server_pid} 2>/dev/null || true

echo "If you want a perf profile, run this while the server is under load (requires sudo):"
echo "  sudo perf record -F 99 -g --pid \\$(pgrep hikari_server) -- sleep 30"
