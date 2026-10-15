#!/usr/bin/env bash
# Install grok-bot: create hub dirs, link bin/grok-bot into ~/.local/bin, seed webhook.env.
set -eu
REPO="$(cd "$(dirname "$0")" && pwd)"
HUB="${GROK_BOT_HUB:-$HOME/.grok-bot}"
BIN="$HOME/.local/bin"
mkdir -p "$HUB/inbox" "$HUB/outbox" "$HUB/done" "$HUB/failed" "$BIN"
TARGET="$BIN/grok-bot"
if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  BAK="$TARGET.bak.$(date +%Y%m%d%H%M%S)"
  mv "$TARGET" "$BAK"; echo "Backed up existing grok-bot to $BAK"
fi
ln -sfn "$REPO/bin/grok-bot" "$TARGET"; echo "Linked $TARGET -> $REPO/bin/grok-bot"
if [ ! -f "$HUB/webhook.env" ]; then
  cp "$REPO/webhook.env.example" "$HUB/webhook.env"; chmod 600 "$HUB/webhook.env"
  echo "Created $HUB/webhook.env - fill in your webhook URL and key"
else
  echo "Keeping existing $HUB/webhook.env"
fi
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Note: add $BIN to your PATH";; esac
echo "Done. Run grok-bot (or let the herdr plugin start it)."
