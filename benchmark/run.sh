#!/bin/bash

set -e

echo "====================================="
echo "  Hikari Benchmark Framework Suite   "
echo "====================================="

# Check requirements
if ! command -v bombardier &> /dev/null; then
    echo "bombardier could not be found, please install it: go install github.com/codesenberg/bombardier@latest"
    exit 1
fi
if ! command -v v &> /dev/null; then
    echo "v could not be found, please install Vlang."
    exit 1
fi
if ! command -v go &> /dev/null; then
    echo "go could not be found, please install Go."
    exit 1
fi
if ! command -v bun &> /dev/null; then
    echo "bun could not be found, please install Bun."
    exit 1
fi

CONNECTIONS=100
REQUESTS=100000
WARMUP_REQUESTS=5000

# Function to wait for port to become available
wait_for_port() {
    local name=$1
    local port=$2
    echo "Waiting for $name to be ready on port $port..."
    for i in {1..100}; do
        if curl -sf "http://localhost:${port}/" > /dev/null 2>&1; then
            echo "$name is ready."
            return 0
        fi
        sleep 0.1
    done
    echo "ERROR: $name did not start in time on port $port"
    return 1
}

# Function to run warmup then benchmark
run_benchmark() {
    local name=$1
    local port=$2
    local path=${3:-"/"}

    echo ""
    echo "  [Warmup] $name..."
    bombardier -c 10 -n ${WARMUP_REQUESTS} "http://localhost:${port}${path}" > /dev/null 2>&1 || true

    echo "  [Bench]  $name (${CONNECTIONS} connections, ${REQUESTS} requests) -> ${path}"
    bombardier -c ${CONNECTIONS} -n ${REQUESTS} --print r "http://localhost:${port}${path}"
}

# -----------------------------------------------
echo ""
echo "--- Compiling and Starting Hikari (V) ---"
cd ..
v -prod benchmark/main.v -o /tmp/hikari_bench
/tmp/hikari_bench > /dev/null 2>&1 &
HIKARI_PID=$!
wait_for_port "Hikari" 3000

echo ""
echo "=== Hikari Benchmarks ==="
run_benchmark "Hikari /  (JSON)"     3000 "/"
run_benchmark "Hikari /text"         3000 "/text"
run_benchmark "Hikari /users/42"     3000 "/users/42"

kill -9 $HIKARI_PID 2>/dev/null || true
cd benchmark
echo "Hikari benchmark complete."

# -----------------------------------------------
echo ""
echo "--- Compiling and Starting Go Fiber ---"
cd fiber
go build -o /tmp/fiber_bench main.go
/tmp/fiber_bench > /dev/null 2>&1 &
FIBER_PID=$!
wait_for_port "Go Fiber" 3001

echo ""
echo "=== Go Fiber Benchmarks ==="
run_benchmark "Fiber /  (JSON)"  3001 "/"
run_benchmark "Fiber /text"      3001 "/text"
run_benchmark "Fiber /users/42"  3001 "/users/42"

kill -9 $FIBER_PID 2>/dev/null || true
cd ..
echo "Go Fiber benchmark complete."

# -----------------------------------------------
echo ""
echo "--- Starting Hono (Bun) ---"
cd hono
bun install --frozen-lockfile > /dev/null 2>&1 || bun install > /dev/null 2>&1 || true
bun run index.ts > /dev/null 2>&1 &
HONO_PID=$!
wait_for_port "Hono" 3002

echo ""
echo "=== Hono Benchmarks ==="
run_benchmark "Hono /  (JSON)"  3002 "/"
run_benchmark "Hono /text"      3002 "/text"
run_benchmark "Hono /users/42"  3002 "/users/42"

kill -9 $HONO_PID 2>/dev/null || true
cd ..
echo "Hono benchmark complete."

# -----------------------------------------------
echo ""
echo "====================================="
echo "         Benchmarks Completed        "
echo "====================================="

