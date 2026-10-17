#!/usr/bin/env python3
"""Isolated shell regressions; only synthetic config and mocked herdr/curl."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BRIDGE = (ROOT / "bin/grok-bot").read_text()
FUNCTIONS = BRIDGE[BRIDGE.index("log(){"):BRIDGE.index("# Interrupted tasks")]
STARTUP = (ROOT / "plugin/startup.sh").read_text()
CONFIGURED = STARTUP[STARTUP.index("configured()("):STARTUP.index("if ! configured;")]


class Regressions(unittest.TestCase):
    def run_shell(self, body, prefix=""):
        hub = pathlib.Path(tempfile.mkdtemp(prefix="grok-bot-test-"))
        try:
            script = f'''set -u
unset GROK_WEBHOOK_URL GROK_WEBHOOK_KEY GROK_WEBHOOK_HEADER GROK_WEBHOOK_PREFIX HERDR_PANE_ID HERDR_WORKSPACE_ID
HUB={str(hub)!r}
mkdir -p "$HUB"/{{inbox,outbox,done,failed}}
{FUNCTIONS}
{prefix}
{body}
'''
            result = subprocess.run(["bash"], input=script, text=True,
                                    capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            subprocess.run(["trash", str(hub)], check=True)

    def test_placeholder_setup(self):
        self.run_shell('''
HERDR=false
HERDR_PLUGIN_CONFIG_DIR="$HUB/config"
mkdir -p "$HERDR_PLUGIN_CONFIG_DIR"
printf 'GROK_WEBHOOK_URL="https://example.invalid/demo"\n' > "$HUB/webhook.env"
configured && exit 1
printf 'GROK_WEBHOOK_URL="https://test.local/hook"\nGROK_WEBHOOK_KEY="your-webhook-key"\n' > "$HUB/webhook.env"
configured && exit 2
printf 'GROK_WEBHOOK_URL="https://test.local/hook"\n' > "$HUB/webhook.env"
configured || exit 3
# The first existing config wins, including an empty plugin config.
: > "$HERDR_PLUGIN_CONFIG_DIR/webhook.env"
configured && exit 4
exit 0
''', CONFIGURED)

    def test_placeholder_never_sent(self):
        self.run_shell('''
curl(){ touch "$HUB/unexpected-request"; }
GROK_WEBHOOK_URL=https://example.invalid/demo
notify id agent done
GROK_WEBHOOK_URL=https://test.local/hook
GROK_WEBHOOK_KEY=your-webhook-key
notify id agent done
[ ! -f "$HUB/unexpected-request" ] || exit 1
''')

    def test_keyless_webhook(self):
        self.run_shell('''
GROK_WEBHOOK_URL=https://test.local/hook
curl(){ touch "$HUB/request"; }
notify id agent done
[ -f "$HUB/request" ]
''')

    def watcher(self, extra="", rounds=4, expected=2, stale=False):
        self.run_shell(f'''
cycle=0
GROK_BOT_WATCH_COOLDOWN=0
herdr(){{
  if [ "$1 $2" = 'agent list' ]; then
    case $(cat "$HUB/cycle") in 0|2) status=working;; *) status=done;; esac
    printf '{{"result":{{"agents":[{{"pane_id":"p1","agent_status":"%s","agent":"demo","terminal_title_stripped":"Demo"}}]}}}}\n' "$status"
  elif [ "$1 $2" = 'pane read' ]; then echo "screen $(cat "$HUB/cycle")"
  else return 1; fi
}}
notify(){{ echo "$1" >> "$HUB/notified"; }}
sleep(){{
  cycle=$((cycle+1)); echo "$cycle" > "$HUB/cycle"
  [ "$cycle" -lt {rounds} ] || exit 0
}}
echo 0 > "$HUB/cycle"
{extra}
{'printf "p1\\tworking\\tdemo\\tDemo\\n" > "$HUB/watch.state"; echo 1 > "$HUB/cycle"' if stale else ':'}
(watch_agents)
count=0
[ ! -f "$HUB/notified" ] || count=$(wc -l < "$HUB/notified")
[ "$count" -eq {expected} ] || {{ echo "expected {expected} reports, got $count"; exit 1; }}
''')

    def test_gnu_stat(self):
        stat = shutil.which("gstat") or shutil.which("stat")
        self.watcher(f'stat(){{ {stat!r} "$@"; }}')

    def test_invalid_stat(self):
        self.watcher("stat(){ echo 'File: polluted output'; return 1; }")

    def test_native_stat(self):
        self.watcher()

    def test_failed_hash(self):
        self.watcher("shasum(){ return 1; }")

    def test_no_shasum(self):
        self.watcher('''shasum(){ return 127; }
command(){
  [ "$*" != '-v shasum' ] || return 1
  builtin command "$@"
}''')

    def test_no_hash_utilities(self):
        self.watcher('''shasum(){ return 127; }
command(){
  case "$*" in '-v shasum'|'-v sha1sum'|'-v md5sum'|'-v cksum') return 1;; esac
  builtin command "$@"
}''')

    def test_stale_state(self):
        self.watcher(rounds=1, expected=0, stale=True)

    def test_task_completion_once(self):
        self.watcher('''
printf 'agent=demo\nTest prompt\n' > "$HUB/inbox/demo.task"
herdr(){
  case "$1 $2" in
    'agent list')
      status=working; [ "$(cat "$HUB/cycle")" = 0 ] || status=done
      printf '{"result":{"agents":[{"pane_id":"p1","agent_status":"%s","agent":"demo","terminal_title_stripped":"Demo"}]}}\n' "$status";;
    'agent get') echo '{"result":{"agent":{"pane_id":"p1","agent_status":"done"}}}';;
    'pane read'|'agent read') echo 'completed screen';;
    'agent prompt') :;;
    *) return 1;;
  esac
}
sleep(){
  cycle=$((cycle+1)); echo "$cycle" > "$HUB/cycle"
  if [ "$cycle" = 1 ]; then run_task "$HUB/inbox/demo.task"; else exit 0; fi
}
''', rounds=2, expected=1)




    def test_unknown_workspace(self):
        self.run_shell('''
herdr(){ echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"focused","focused":true}]}}'; }
pick_ws typo && exit 1
[ "$(pick_ws '')" = w1 ]
''')

    def test_interrupted_task(self):
        recovery = BRIDGE[BRIDGE.index("# Interrupted tasks"):BRIDGE.index('log "grok-bot started')]
        self.run_shell('''
printf 'agent=demo\\nAlready sent\\n' > "$HUB/inbox/interrupted.running"
''' + recovery + '''
[ -f "$HUB/failed/interrupted.task" ] && [ ! -f "$HUB/inbox/interrupted.running" ]
''')


if __name__ == "__main__":
    unittest.main()
