# OMNIX-Shield

Agentic AI Sanitizer Proxy — reliable Antigravity model access from third-party coding agents via Prompt Surgery.

## What It Does

Antigravity's backend detects and blocks requests from competing coding agents (Hermes, Claude Code, OpenCode, etc.) by recognizing **structural patterns in system prompts** — not just keywords.

OMNIX-Shield solves this with **Prompt Surgery**: it moves the agent's personality (soul), memory, skills, and context from the `system` message (where detection happens) into a `user` message (which passes through), while replacing the system prompt with a neutral one.

**Result**: Your agent keeps its full identity, memory, skills, and context — Antigravity sees a clean request.

## Features

- **System prompt surgery** — replaces structural fingerprints that trigger detection
- **Soul/identity preservation** — agent personality moved to user message, not deleted
- **Memory preservation** — persistent memory context survives the rewrite
- **Skills listing preservation** — agent knows its available skills
- **Environment context** — CWD, OS, paths, shell info preserved
- **Configurable assistant name** — set via dashboard, CLI, or config file
- **Per-section toggles** — choose exactly what to preserve or strip
- **Web dashboard** (`/ui`) — real-time traffic logs, config editor, section toggles
- **Tool schema simplifier** — strips `strict`, `$schema`, `additionalProperties`, `anyOf`
- **Title mocker** — handles `session_title` requests locally (saves quota)
- **User-Agent spoofing** — masks client identity headers
- **429 retry with backoff** — automatic retry on rate limits
- **Reasoning effort control** — strip or remap `reasoning_effort` field
- **Interactive launcher** — arrow-key menu: Web UI / Terminal / Background / Tray
- **Windows system tray** — background operation with tray icon & dashboard access
- **Autostart** — Windows startup shortcut, Linux systemd
- **CLI management** — `stop`, `restart`, `status` commands
- **Config persistence** — settings saved to JSON, survives restarts
- **SSE event stream** — live dashboard updates via Server-Sent Events
- **File logging** — optional traffic log with auto-rotate at 10MB

## Quick Start

### Windows

```bash
# Clone
git clone https://github.com/bieeins/ag-shield-omnix.git
cd ag-shield-omnix

# Interactive launcher (recommended)
node start.js

# Or direct run (zero dependencies)
node index.js

# Custom port and assistant name
node index.js --port 20129 --name "My Assistant"
```

### macOS

```bash
# Install Node.js if not installed
brew install node

# Clone
git clone https://github.com/bieeins/ag-shield-omnix.git
cd ag-shield-omnix

# Set API key (add to ~/.zshrc for permanent)
export NINE_ROUTER_API_KEY="your-api-key-here"

# Run
node index.js
```

**macOS notes:**
- System tray (`tray.ps1`) is Windows-only — ignore on Mac
- Autostart: add to Login Items or use `launchctl`

### Linux

```bash
# Clone
git clone https://github.com/bieeins/ag-shield-omnix.git
cd ag-shield-omnix

# Set API key
export NINE_ROUTER_API_KEY="your-api-key-here"

# Run
node index.js

# Optional: run as systemd service
sudo cp omnix-shield.service /etc/systemd/system/
sudo systemctl enable --now omnix-shield
```

### Requirements

- **Node.js** 18+ (no npm install needed — zero dependencies)
- **Upstream gateway** running on port 20128 (e.g., 9Router)

## Launcher

```bash
node start.js           # Interactive menu
node start.js tray      # Launch directly to system tray (used by autostart)
node start.js status    # Show running instance status
node start.js stop      # Stop running instance
```

## Usage with Hermes Agent

1. Start OMNIX-Shield:
   ```bash
   node start.js
   ```

2. Configure Hermes config:

   **Windows** (`%LOCALAPPDATA%\hermes\config.yaml`):
   ```yaml
   model:
     default: "ag/gemini-2.5-flash"
     provider: "ag-shield"
     base_url: "http://localhost:20129/v1"
     api_key_env: "NINE_ROUTER_API_KEY"
   ```

   **Linux** (`~/.hermes/config.yaml`):
   ```yaml
   model:
     default: "ag/gemini-2.5-flash"
     provider: "ag-shield"
     base_url: "http://localhost:20129/v1"
     api_key_env: "NINE_ROUTER_API_KEY"
   ```

3. Run Hermes:
   ```bash
   hermes -m ag/gemini-2.5-flash
   ```

## CLI

```
node index.js [flags]

Flags:
  --port <port>         Listen port (default: 20129)
  --target-port <port>  Upstream port (default: 20128)
  --name <name>         Assistant name (default: OMNIX Assistant)
  --log, -l             Write traffic log to file
  --no-tools            Strip tools array (debug)
  stop                  Stop running instance
  restart               Restart
  status                Show live status
  --version, -v         Show version
  --help, -h            Show help
```

## Configuration

Settings are saved to `omnix-shield.config.json` and can be edited via:
- **Dashboard UI** at `/ui`
- **CLI flags** (override saved config)
- **Environment variables**: `PORT`, `TARGET_PORT`, `TARGET_API_KEY`, `ASSISTANT_NAME`

### Key Config Options

| Option | Default | Description |
|--------|---------|-------------|
| `promptSurgery` | `true` | Enable v10 prompt surgery |
| `assistantName` | `"OMNIX Assistant"` | Name injected into soul identity |
| `assistantMaker` | `"the development team"` | Maker name replacement |
| `preserveSoul` | `true` | Keep agent personality/identity |
| `preserveMemory` | `true` | Keep persistent memory |
| `preserveSkills` | `true` | Keep skills listing |
| `preserveEnvironment` | `true` | Keep runtime environment context |
| `rewriteKeywords` | `true` | Rewrite agent-specific keywords |
| `simplifyToolSchemas` | `true` | Simplify JSON schemas for tools |
| `mockLocalTitles` | `true` | Mock title generation locally |
| `spoofUserAgent` | `true` | Spoof User-Agent header |
| `retryOn429` | `true` | Auto-retry on 429 rate limits |
| `defaultMaxTokens` | `8192` | Inject max_tokens if missing |

## How Prompt Surgery Works

```
┌─────────────────────────────────────────────────────────┐
│ BEFORE (blocked by Antigravity)                         │
├─────────────────────────────────────────────────────────┤
│ System: "You are Hermes Agent, built by Nous Research.  │
│          Be direct: match the length of your reply..."  │
│          [+ skills, memory, environment, instructions]  │
│ User:   "siapa kamu?"                                   │
│                                                         │
│ Result: HANG / no response (detected as competing agent)│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ AFTER (passes through)                                  │
├─────────────────────────────────────────────────────────┤
│ System: "You are a helpful AI coding assistant.         │
│          Be direct and concise. Use tools..."           │
│          [+ environment context only]                   │
│ User:   "[CONTEXT] Background context: You are OMNIX    │
│          Assistant, built by the development team..."   │
│          [+ soul, memory, skills — keyword-rewritten]   │
│ Asst:   "Understood. I will follow these guidelines."   │
│ User:   "siapa kamu?"                                   │
│                                                         │
│ Result: 200 OK — "OMNIX Assistant" (identity preserved) │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
omnix-shield/
├── index.js                    # Main proxy server (zero deps)
├── start.js                    # Interactive launcher
├── ui.html                     # Web dashboard (self-contained)
├── tray.ps1                    # Windows system tray script
├── package.json                # npm package metadata
├── omnix-shield.config.json    # Saved configuration (auto-generated)
└── README.md                   # This file
```

## Disclaimer

> [!WARNING]
> This tool modifies API requests to work around client detection mechanisms. Use at your own risk. The authors are not responsible for any terms of service violations or account actions that may result from its use.

## License

MIT
