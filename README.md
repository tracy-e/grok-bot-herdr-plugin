# grok-bot-herdr-plugin

A small bridge between **Grok Bot** and coding agents running in **[herdr](https://herdr.dev)**.

- Grok Bot drops task files into a hub directory (`~/ai-hub/inbox/`).
- `grok-bot`, running inside a herdr pane, picks them up, starts the requested agent in a new herdr tab (or reuses an existing one), and sends it the prompt.
- When the agent finishes, `grok-bot` writes the result to `~/ai-hub/outbox/<id>.md` and wakes Grok Bot through a routine webhook, so Grok Bot can read the result and report back.

You keep watching every agent live in herdr; Grok Bot handles dispatch and follow-up.

Inspired by [joelhooks/herdr-grok-bot](https://github.com/joelhooks/herdr-grok-bot).

## Requirements

- herdr 0.9+ (with the `herdr agent` CLI)
- `jq`, `curl`, `bash`

## Install

```bash
git clone https://github.com/tracy-e/grok-bot-herdr-plugin.git
cd grok-bot-herdr-plugin
./install.sh
```

`install.sh` creates `~/ai-hub/{inbox,outbox,done,failed}`, symlinks `bin/grok-bot` into `~/.local/bin` (backing up any existing file), and copies `webhook.env.example` to `~/ai-hub/webhook.env` only if it does not exist yet.

Set `GROK_BOT_HUB` to use a hub directory other than `~/ai-hub`.

## Set up the webhook

1. In Grok Bot, create a routine with a **webhook** trigger (e.g. "herdr agent finished").
2. Copy its webhook URL and key into `~/ai-hub/webhook.env`:

   ```bash
   GROK_WEBHOOK_URL="..."
   GROK_WEBHOOK_KEY="..."
   # optional, defaults shown
   # GROK_WEBHOOK_HEADER="Authorization"
   # GROK_WEBHOOK_PREFIX="Bearer "
   ```

Never commit this file. Without a URL, `grok-bot` still works but does not notify anyone.

The webhook receives JSON like:

```json
{"source":"grok-bot","id":"hello","agent":"hello-cursor","state":"done","file":"/Users/you/ai-hub/outbox/hello.md"}
```

## Usage

Open a pane in herdr and run:

```bash
grok-bot
```

It must run inside herdr (`HERDR_ENV=1`); new tabs are created in that pane's workspace. Then drop a task:

```bash
cp examples/hello.task ~/ai-hub/inbox/hello.task
```

Task lifecycle: `inbox/<id>.task` → `inbox/<id>.running` → `done/<id>.task` (or `failed/<id>.task`), with the result in `outbox/<id>.md`.

## Task format

```
agent=<name> kind=<kind> cwd=<project path>
<prompt, may span multiple lines>
```

- `agent` (required): herdr agent name; also the tab label. If an agent with this name already exists, it is reused.
- `kind`: required only when the agent does not exist yet.
- `cwd`: working directory for a new tab (`~` is expanded; defaults to `$HOME`).
- Prompt: optional. If empty, the agent is just started.

The outbox file contains the agent status (`.result.agent.agent_status`, e.g. `done`, `blocked`, `working`) and the last 200 lines of the agent's screen.

## Supported kinds

From `herdr agent start --help`:

`pi, claude, codex, gemini, cursor, devin, agy, cline, omp, mastracode, opencode, copilot, kimi, kiro, droid, amp, grok, hermes, kilo, qodercli, qwen, letta, maki, muse`

## Tips

- **Workspace trust prompt:** the first time an agent (e.g. cursor-agent) opens a new directory it may ask whether to trust the workspace. Answer it once in the herdr tab (or via `herdr agent send-keys`); later runs won't ask.
- **Switching models:** in grok, cursor, claude and pi, type `/model`, pick with the arrow keys, press Enter. In Claude Code, Enter changes the default and `s` changes only the session; in pi, Ctrl+S sets the default.
- Grok Bot can also drive herdr directly (`herdr agent prompt/read/get`) from your terminal; `grok-bot` mainly handles queueing and webhook notifications.

## Limitations

- Polls the inbox every 3 seconds; tasks run in parallel, one background job each.
- No auth / sandboxing of task files: anything that can write to the inbox can prompt your agents.
- Interactive prompts (trust, login, billing dialogs) are not answered automatically; the agent shows up as `blocked` or times out.
- Prompt wait timeout is 1 hour; agent start timeout is 2 minutes.
- macOS/Linux only; tested with herdr 0.9.

## License

MIT © 2026 Tracy Yi
