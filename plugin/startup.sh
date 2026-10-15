#!/usr/bin/env bash
# herdr startup hook: make sure exactly one grok-bot bridge is running.
# Opens (or reuses) a workspace labeled "grok-bot" and runs the bridge in it.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
HERDR="${HERDR_BIN_PATH:-herdr}"
LABEL="${GROK_BOT_WORKSPACE_LABEL:-grok-bot}"
HUB="${GROK_BOT_HUB:-$HOME/.grok-bot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE="$(command -v grok-bot || echo "$ROOT/bin/grok-bot")"

if pgrep -f "bash .*bin/grok-bot\$" >/dev/null; then
  echo "grok-bot already running"; exit 0
fi
mkdir -p "$HUB"/{inbox,outbox,done,failed}

ws=$("$HERDR" workspace list | jq -r --arg l "$LABEL" '.result.workspaces[]|select(.label==$l)|.workspace_id' | head -1)
if [ -n "$ws" ]; then
  pane=$("$HERDR" tab create --workspace "$ws" --cwd "$HUB" --label bridge --no-focus | jq -r '.result.root_pane.pane_id')
else
  pane=$("$HERDR" workspace create --label "$LABEL" --cwd "$HUB" --no-focus | jq -r '.result.root_pane.pane_id')
fi
sleep 1
"$HERDR" pane run "$pane" "$BRIDGE" >/dev/null
echo "grok-bot started in pane $pane"
