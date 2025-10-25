#!/usr/bin/env bash
set -eu

# Simple benchmark runner wrapper that runs bombardier and prints a short header.
# Usage: ./scripts/run_benchmark.sh [url] [duration] [concurrency]
# Defaults: url=http://localhost:3000/ duration=10s concurrency=100

URL=${1:-http://localhost:3000/}
DURATION=${2:-10s}
CONCURRENCY=${3:-100}

echo "Running benchmark: URL=${URL} DURATION=${DURATION} CONCURRENCY=${CONCURRENCY}"

if ! command -v bombardier >/dev/null 2>&1; then
  echo "bombardier not found in PATH. Please install it (https://github.com/codesenberg/bombardier)"
  exit 2
fi

echo "-- warmup: 2s (no measurement) --"
bombardier --fasthttp -d 2s -c 10 "${URL}"

echo "-- running measurement --"
bombardier --fasthttp -d ${DURATION} -c ${CONCURRENCY} "${URL}"

echo "benchmark finished"
