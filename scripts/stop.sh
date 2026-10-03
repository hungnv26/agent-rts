#!/usr/bin/env bash
# Stop the adapter, Mission Control (if started by start.sh) and the Hermes containers.
#   scripts/stop.sh           stop everything
#   scripts/stop.sh --keep-hermes
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

for name in adapter mission-control; do
  pidfile=".data/$name.pid"
  if [[ -f $pidfile ]]; then
    pid=$(cat "$pidfile")
    # pnpm dev spawns next as a child; stop the whole group.
    pkill -TERM -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null && echo "stopped $name"
    rm -f "$pidfile"
  fi
done

if [[ "${1:-}" != "--keep-hermes" && -d vendor/hermes-synapse ]]; then
  docker compose -p agentrts -f vendor/hermes-synapse/docker-compose.yml -f infra/hermes.override.yml stop >/dev/null 2>&1 && echo "stopped Hermes"
fi
