#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Stop master and any recorded child PIDs in logs/children.pids

if [ -f logs/master.pid ]; then
  master_pid=$(cat logs/master.pid)
  echo "Stopping master pid=${master_pid}"
  kill ${master_pid} 2>/dev/null || true
  rm -f logs/master.pid
fi

if [ -f logs/children.pids ]; then
  echo "Stopping children listed in logs/children.pids"
  # kill each pid; ignore failures
  xargs -a logs/children.pids -r -n1 -I{} sh -c 'kill {} 2>/dev/null || true'
  rm -f logs/children.pids
fi

# also attempt to kill any leftover hikari_server processes (best-effort)
pkill -f bin/hikari_server 2>/dev/null || true

echo "stop complete"
