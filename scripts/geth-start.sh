#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATADIR="$ROOT/.geth"
PIDFILE="$DATADIR/geth.pid"
LOGFILE="$DATADIR/geth.log"
RPC_URL="http://127.0.0.1:8545"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "geth already running (pid $(cat "$PIDFILE"))"
    exit 0
fi

rm -rf "$DATADIR"
mkdir -p "$DATADIR"

GETH="${GETH:-$HOME/bin/geth}"

nohup "$GETH" \
    --dev \
    --dev.period 0 \
    --datadir "$DATADIR" \
    --http --http.addr 127.0.0.1 --http.port 8545 \
    --http.api eth,web3,net,debug,miner \
    --http.corsdomain '*' \
    --verbosity 2 \
    > "$LOGFILE" 2>&1 &

echo $! > "$PIDFILE"

for i in $(seq 1 60); do
    if curl -s -o /dev/null -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$RPC_URL"; then
        echo "geth dev node up at $RPC_URL (pid $(cat "$PIDFILE"))"
        exit 0
    fi
    sleep 0.25
done

echo "geth failed to start; see $LOGFILE" >&2
tail -30 "$LOGFILE" >&2 || true
exit 1
