#!/usr/bin/env bash
# herdr startup hook: make sure exactly one grok-bot bridge is running, silently in the background.
# Log: $GROK_BOT_HUB/bridge.log. If no webhook is configured yet, opens the setup popup once.
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
HERDR="${HERDR_BIN_PATH:-herdr}"
HUB="${GROK_BOT_HUB:-$HOME/.grok-bot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE="$ROOT/bin/grok-bot"
mkdir -p "$HUB"/{inbox,outbox,done,failed}

configured()(
  local d f
  unset GROK_WEBHOOK_URL GROK_WEBHOOK_KEY
  d="${HERDR_PLUGIN_CONFIG_DIR:-$("$HERDR" plugin config-dir tracy-e.grok-bot 2>/dev/null || true)}"
  for f in "${d:+$d/webhook.env}" "$HUB/webhook.env"; do
    if [ -n "$f" ] && [ -f "$f" ]; then
      # Same precedence and shell syntax as the bridge; never print config values.
      # shellcheck disable=SC1090
      . "$f"
      break
    fi
  done
  case "${GROK_WEBHOOK_URL:-}" in http://*|https://*) ;; *) return 1;; esac
  case "${GROK_WEBHOOK_URL:-}|${GROK_WEBHOOK_KEY:-}" in *example.invalid*|*your-webhook-key*) return 1;; esac
  return 0
)
if ! configured; then
  "$HERDR" plugin pane open --plugin tracy-e.grok-bot --entrypoint configure >/dev/null 2>&1 \
    || echo "no webhook configured: run the 'Grok Bot: configure webhook' action"
fi

if [ -f "$HUB/bridge.pid" ] && kill -0 "$(cat "$HUB/bridge.pid")" 2>/dev/null; then
  echo "grok-bot already running (pid $(cat "$HUB/bridge.pid"))"; exit 0
fi
# Background with stdin closed, pane variables unset, and output sent to the log.
env -u HERDR_PANE_ID -u HERDR_WORKSPACE_ID nohup "$BRIDGE" >>"$HUB/bridge.log" 2>&1 </dev/null &
disown || true
sleep 1
if [ -f "$HUB/bridge.pid" ] && kill -0 "$(cat "$HUB/bridge.pid")" 2>/dev/null; then
  echo "grok-bot started in background (pid $(cat "$HUB/bridge.pid")), log: $HUB/bridge.log"
else
  echo "grok-bot failed to start, see $HUB/bridge.log"; exit 1
fi
