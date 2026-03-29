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
REQUESTS=10000

# Function to run benchmark and wait for the port
run_benchmark() {
    local name=$1
    local port=$2

    echo "Waiting for $name to be ready on port $port..."
    # A simple loop using curl/wget to check if server is up instead of nc which may hang
    for i in {1..50}; do
        if curl -s http://localhost:$port/ > /dev/null; then
            break
        fi
        sleep 0.2
    done

    echo "Running benchmark for $name..."
    bombardier -c $CONNECTIONS -n $REQUESTS http://localhost:$port/
}

echo ""
echo "--- Compiling and Starting Hikari (V) ---"
cd ..
v -prod benchmark/main.v
./benchmark/main > /dev/null 2>&1 &
HIKARI_PID=$!
run_benchmark "Hikari" 3000
kill -9 $HIKARI_PID
cd benchmark
echo "Hikari benchmark complete."

echo ""
echo "--- Compiling and Starting Go Fiber ---"
cd fiber
go build -o fiber_app main.go
./fiber_app > /dev/null 2>&1 &
FIBER_PID=$!
run_benchmark "Go Fiber" 3001
kill -9 $FIBER_PID
rm fiber_app
cd ..
echo "Go Fiber benchmark complete."

echo ""
echo "--- Starting Hono (Bun) ---"
cd hono
bun run index.ts > /dev/null 2>&1 &
HONO_PID=$!
run_benchmark "Hono" 3002
kill -9 $HONO_PID
cd ..
echo "Hono benchmark complete."

echo ""
echo "====================================="
echo "         Benchmarks Completed        "
echo "====================================="
