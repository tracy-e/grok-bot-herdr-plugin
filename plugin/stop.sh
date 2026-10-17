#!/usr/bin/env bash
# Stop the background grok-bot bridge (waits up to 5 s for it to exit).
HUB="${GROK_BOT_HUB:-$HOME/.grok-bot}"
pid=$(cat "$HUB/bridge.pid" 2>/dev/null)
if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || { echo "grok-bot stopped"; exit 0; }; sleep 0.5; done
  echo "grok-bot (pid $pid) did not exit in time"; exit 1
fi
echo "grok-bot is not running"
