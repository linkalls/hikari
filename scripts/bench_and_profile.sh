#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Build production binary"
v -prod -o hikari_server example/main.v

echo "Warmup..."
bombardier --fasthttp -d 5s -c 100 http://localhost:3000/

echo "Benchmark..."
bombardier --fasthttp -d 10s -c 100 http://localhost:3000/

echo "If you want a perf profile, run this while the server is under load (requires sudo):"
echo "  sudo perf record -F 99 -g --pid \\$(pgrep hikari_server) -- sleep 30"
