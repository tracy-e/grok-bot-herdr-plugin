# grok-bot-herdr-plugin

A small bridge between **Grok Bot** and coding agents running in **[herdr](https://herdr.dev)**.

- Grok Bot drops task files into a hub directory (`~/.grok-bot/inbox/`).
- `grok-bot`, running inside a herdr pane, picks them up, starts the requested agent in a new herdr tab (or reuses an existing one), and sends it the prompt.
- When the agent finishes, `grok-bot` writes the result to `~/.grok-bot/outbox/<id>.md` and wakes Grok Bot through a routine webhook, so Grok Bot can read the result and report back.

You keep watching every agent live in herdr; Grok Bot handles dispatch and follow-up.

Inspired by [joelhooks/herdr-grok-bot](https://github.com/joelhooks/herdr-grok-bot).

## Requirements

- herdr 0.9+ (with the `herdr agent` CLI)
- `jq`, `curl`, `bash`

## Install

### As a herdr plugin (recommended)

```bash
herdr plugin install tracy-e/grok-bot-herdr-plugin
```

Every time the herdr server starts, the plugin's startup hook opens a workspace labeled `grok-bot` and runs the bridge in it (skipped if a `grok-bot` bridge is already running). You can also start it by hand with the **Grok Bot: start bridge** action (`herdr plugin action invoke tracy-e.grok-bot.start`).

### Manual

```bash
git clone https://github.com/tracy-e/grok-bot-herdr-plugin.git
cd grok-bot-herdr-plugin
./install.sh             # creates ~/.grok-bot/*, links bin/grok-bot into ~/.local/bin
herdr plugin link "$PWD" # optional: enable auto-start from your checkout
```

Set `GROK_BOT_HUB` to use a hub directory other than `~/.grok-bot`, and `GROK_BOT_WORKSPACE_LABEL` to change the auto-start workspace name.

## Set up the webhook

### 1. Get a webhook URL and key from Grok Bot

Paste this into a chat with your Grok Bot (the configure popup can also copy it for you: press `c`; it lives in `plugin/setup-prompt.txt`):

```text
Create a webhook-triggered routine named "herdr agent reports". When it fires, the payload is JSON from the grok-bot herdr bridge with fields id, agent, state, and file (a result markdown path on my computer). Read that file on my computer and give me a short summary of what the agent did and whether it finished, failed, or is waiting on me. Never answer an agent's confirmation prompts for me; just tell me. After creating it, give me the routine's Webhook URL and Webhook key links so I can copy them.
```

Grok Bot creates the routine and replies with links to the routine's **Webhook URL** and **Webhook key**. Open them and copy both values. The key is a secret, so it is shown through the link rather than in the chat.

### 2. Save them

Run the **Grok Bot: configure webhook** action in herdr:

```bash
herdr plugin action invoke tracy-e.grok-bot.configure
```

A popup asks for the URL and key (the key is hidden while typing), saves them to `webhook.env` in the plugin config dir (`herdr plugin config-dir tracy-e.grok-bot`, mode 600), and can send a test ping. Restart the bridge afterwards.

Without herdr, run `bash plugin/configure.sh`, or write `~/.grok-bot/webhook.env` yourself (see `webhook.env.example`). `grok-bot` reads the plugin config dir first, then `~/.grok-bot/webhook.env`. Optional `GROK_WEBHOOK_HEADER` (default `Authorization`) and `GROK_WEBHOOK_PREFIX` (default `Bearer `) change how the key is sent.

Never commit `webhook.env`. Without a URL, `grok-bot` still runs and writes results, but does not notify anyone.

The webhook receives JSON like:

```json
{"source":"grok-bot","id":"hello","agent":"hello-cursor","state":"done","file":"/Users/you/.grok-bot/outbox/hello.md"}
```

## Usage

With the plugin installed the bridge starts on its own. Otherwise open a pane in herdr and run:

```bash
grok-bot
```

It must run inside herdr (`HERDR_ENV=1`); new tabs are created in that pane's workspace. Then drop a task:

```bash
cp examples/hello.task ~/.grok-bot/inbox/hello.task
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
