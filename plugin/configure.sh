#!/usr/bin/env bash
# Interactive setup for the Grok Bot webhook. Writes webhook.env (chmod 600)
# into the herdr plugin config dir (or ~/.grok-bot when run outside herdr).
# Press Esc at any prompt to close without changing anything.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DIR="${HERDR_PLUGIN_CONFIG_DIR:-$(herdr plugin config-dir tracy-e.grok-bot 2>/dev/null || echo "${GROK_BOT_HUB:-$HOME/.grok-bot}")}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$HERE/setup-prompt.txt"
mkdir -p "$DIR"; F="$DIR/webhook.env"

ESC=$'\e'

bye() { echo; echo "Closed, nothing changed."; exit 0; }

# read_input VAR PROMPT [hidden]: line input; Esc closes the popup.
read_input() {
  local __var=$1 prompt=$2 hidden=${3:-} buf="" c
  printf '%s' "$prompt"
  while IFS= read -r -s -n 1 c; do
    case "$c" in
      "$ESC") bye ;;
      "") echo; break ;;                       # Enter
      $'\x7f'|$'\b')                            # Backspace
        if [ -n "$buf" ]; then buf=${buf%?}; [ -z "$hidden" ] && printf '\b \b'; fi ;;
      *) buf+=$c; [ -z "$hidden" ] && printf '%s' "$c" ;;
    esac
  done
  printf -v "$__var" '%s' "$buf"
}

# read_key VAR PROMPT: single key; Esc closes the popup.
read_key() {
  local __var=$1 prompt=$2 c
  printf '%s' "$prompt"
  IFS= read -r -s -n 1 c || true
  [ "$c" = "$ESC" ] && bye
  echo "$c"
  printf -v "$__var" '%s' "$c"
}

copy_to_clipboard() {
  if command -v pbcopy >/dev/null 2>&1; then pbcopy
  elif command -v wl-copy >/dev/null 2>&1; then wl-copy
  elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then xsel --clipboard --input
  else return 1; fi
}

echo "Grok Bot webhook setup  (Esc to close)"
echo "Not sure where to get these? Paste the setup prompt into a Grok Bot chat."
if [ -f "$PROMPT_FILE" ]; then
  read_key k "Press c to copy the setup prompt, or any other key to continue: "
  if [[ "$k" == [cC] ]]; then
    if copy_to_clipboard < "$PROMPT_FILE"; then
      echo "Prompt copied. Paste it into Grok Bot, then come back with the URL and key."
    else
      echo "No clipboard tool found. Here is the prompt:"; echo; cat "$PROMPT_FILE"
    fi
  fi
fi
echo
[ -f "$F" ] && echo "Existing config found at $F (it will be replaced)."
read_input url "Webhook URL: "
[ -n "$url" ] || bye
read_input key "Webhook key (hidden): " hidden
umask 077
printf 'GROK_WEBHOOK_URL=%q\nGROK_WEBHOOK_KEY=%q\n' "$url" "$key" > "$F"
chmod 600 "$F"
echo "Saved to $F"
read_key a "Send a test ping to Grok Bot now? [y/N] "
if [[ "$a" =~ ^[Yy] ]]; then
  if curl -fsS -m 20 -X POST "$url" -H "Content-Type: application/json" \
       ${key:+-H "Authorization: Bearer $key"} \
       -d '{"source":"grok-bot","id":"setup-test","agent":"","state":"test","file":""}' >/dev/null; then
    echo "Test ping sent."
  else echo "Test ping failed: check the URL and key."; fi
fi
echo "Restart grok-bot to pick up the new config."
read_key _ "Press any key to close"
