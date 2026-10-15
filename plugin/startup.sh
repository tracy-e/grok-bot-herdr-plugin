#!/usr/bin/env bash
# herdr startup hook: make sure exactly one grok-bot bridge is running, silently in the background.
# Log: $GROK_BOT_HUB/bridge.log. If no webhook is configured yet, opens the setup popup once.
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
HERDR="${HERDR_BIN_PATH:-herdr}"
HUB="${GROK_BOT_HUB:-$HOME/.grok-bot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE="$(command -v grok-bot || echo "$ROOT/bin/grok-bot")"
mkdir -p "$HUB"/{inbox,outbox,done,failed}

configured(){
  local d f
  d="${HERDR_PLUGIN_CONFIG_DIR:-$("$HERDR" plugin config-dir tracy-e.grok-bot 2>/dev/null || true)}"
  for f in "${d:+$d/webhook.env}" "$HUB/webhook.env"; do
    [ -n "$f" ] && [ -f "$f" ] && grep -Eq '^(export +)?GROK_WEBHOOK_URL=["'\'']?[^"'\'' ]+' "$f" && return 0
  done
  return 1
}
if ! configured; then
  "$HERDR" plugin pane open --plugin tracy-e.grok-bot --entrypoint configure >/dev/null 2>&1 \
    || echo "no webhook configured: run the 'Grok Bot: configure webhook' action"
fi

if [ -f "$HUB/bridge.pid" ] && kill -0 "$(cat "$HUB/bridge.pid")" 2>/dev/null; then
  echo "grok-bot already running (pid $(cat "$HUB/bridge.pid"))"; exit 0
fi
# Detach from the hook: own session, no pane env, output to the log.
env -u HERDR_PANE_ID -u HERDR_WORKSPACE_ID nohup "$BRIDGE" >>"$HUB/bridge.log" 2>&1 </dev/null &
disown || true
sleep 1
if [ -f "$HUB/bridge.pid" ] && kill -0 "$(cat "$HUB/bridge.pid")" 2>/dev/null; then
  echo "grok-bot started in background (pid $(cat "$HUB/bridge.pid")), log: $HUB/bridge.log"
else
  echo "grok-bot failed to start, see $HUB/bridge.log"; exit 1
fi
