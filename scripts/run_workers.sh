#!/usr/bin/env bash
# Build production binary and run multiple workers on different ports
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Determine number of workers to run. Priority:
# 1) first script arg, 2) HIKARI_WORKERS env var, 3) auto-detect CPU count (nproc/getconf), 4) fallback to 1
if [ ${#} -ge 1 ] && [ -n "$1" ]; then
  WORKERS="$1"
elif [ -n "${HIKARI_WORKERS:-}" ]; then
  WORKERS="$HIKARI_WORKERS"
else
  if command -v nproc >/dev/null 2>&1; then
    WORKERS=$(nproc --all)
  elif command -v getconf >/dev/null 2>&1; then
    WORKERS=$(getconf _NPROCESSORS_ONLN)
  else
    # last resort: parse /proc/cpuinfo (Linux)
    if [ -r /proc/cpuinfo ]; then
      WORKERS=$(grep -c '^processor' /proc/cpuinfo || echo 1)
    else
      WORKERS=1
    fi
  fi
fi

# ensure WORKERS is at least 1
if [ -z "$WORKERS" ] || [ "$WORKERS" -lt 1 ] 2>/dev/null; then
  WORKERS=1
fi

BASE_PORT=${2:-3000}

echo "Building production binary..."
v -prod -o bin/hikari_server example/main.v

echo "Starting $WORKERS workers on ports $BASE_PORT..$((BASE_PORT+WORKERS-1))"
mkdir -p logs
for i in $(seq 0 $((WORKERS-1))); do
  port=$((BASE_PORT + i))
  nohup ./hikari_server --port $port > logs/worker_$port.log 2>&1 &
  echo "started worker $i on :$port"
done

echo "Workers started. Use nginx or a load balancer to distribute traffic to these ports."

# If bombardier is available, try to open it in a new terminal window and run the
# benchmark against the first worker (BASE_PORT). If no GUI terminal emulator is
# found, fall back to running the command in background and printing to stdout.
BENCH_CMD="bombardier --fasthttp -d 10s -c 100 http://localhost:${BASE_PORT}"
if command -v bombardier >/dev/null 2>&1; then
  # detect common terminal emulators
  TERM_EMUS=(gnome-terminal alacritty konsole xfce4-terminal xterm mate-terminal terminator)
  TERM_BIN=""
  for t in "${TERM_EMUS[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      TERM_BIN="$t"
      break
    fi
  done

  if [ -n "$TERM_BIN" ]; then
    echo "Launching benchmark in new terminal ($TERM_BIN): $BENCH_CMD"
    case "$TERM_BIN" in
      gnome-terminal|mate-terminal|xfce4-terminal)
        "$TERM_BIN" -- bash -lc "$BENCH_CMD; echo; echo 'bench finished, press Enter to close'; read -r" &
        ;;
      alacritty|xterm|konsole|terminator)
        "$TERM_BIN" -e bash -lc "$BENCH_CMD; echo; echo 'bench finished, press Enter to close'; read -r" &
        ;;
      *)
        # fallback
        "$TERM_BIN" -- bash -lc "$BENCH_CMD; echo; echo 'bench finished, press Enter to close'; read -r" &
        ;;
    esac
  else
    echo "No GUI terminal emulator found; running benchmark in background:" 
    echo "$BENCH_CMD &> logs/benchmark_${BASE_PORT}.log &"
    bash -c "$BENCH_CMD" &> logs/benchmark_${BASE_PORT}.log &
    echo "Benchmark running in background, logs/benchmark_${BASE_PORT}.log"
  fi
else
  echo "bombardier is not installed. To run the benchmark manually, install bombardier and then run:" 
  echo "  $BENCH_CMD"
fi
