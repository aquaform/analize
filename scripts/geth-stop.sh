#!/usr/bin/env bash
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="$ROOT/.geth/geth.pid"

if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE")"
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" || true
        for i in $(seq 1 20); do
            kill -0 "$PID" 2>/dev/null || break
            sleep 0.2
        done
        kill -9 "$PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
    echo "geth stopped"
else
    echo "geth not running"
fi
