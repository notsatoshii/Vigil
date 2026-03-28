# Vigil Deployment Guide

## Prerequisites

- **Server**: Linux (Ubuntu 22.04+ recommended), 16 GB RAM minimum, 4+ cores
- **Node.js**: v22+ (`node --version`)
- **npm**: v10+ (`npm --version`)
- **Python**: 3.12+ (`python3 --version`)
- **Claude Code**: Installed and authenticated (`claude auth status`)
- **Claude Max subscription**: Required for claude-cli provider (20x recommended for concurrent sessions)
- **Telegram Bot**: Created via @BotFather, token available
- **Telegram API credentials**: api_id and api_hash from https://my.telegram.org (for local Bot API server)

## Step 0: System Setup

### Create the lever user (if not exists)
```bash
useradd -m -s /bin/bash lever
```

### Grant sudo access (required for service management)
```bash
echo "lever ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/lever
chmod 440 /etc/sudoers.d/lever
```

### Set Claude Code permissions for headless operation
All tools must be pre-approved since there is no interactive TTY:

```bash
mkdir -p /home/lever/.claude
cat > /home/lever/.claude/settings.json << 'SETTINGSEOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebFetch(*)",
      "WebSearch(*)",
      "Agent(*)",
      "Skill(*)",
      "NotebookEdit(*)"
    ]
  },
  "skipDangerousModePermissionPrompt": true
}
SETTINGSEOF
chown -R lever:lever /home/lever/.claude
```

Also create per-project permission files for each workspace:
```bash
for ws in "" build verify secure research operate ceo advisor improve; do
    dir="/home/lever/.claude/projects/-home-lever-command-workspaces${ws:+-}${ws}"
    mkdir -p "$dir"
    cp /home/lever/.claude/settings.json "$dir/settings.json"
done
chown -R lever:lever /home/lever/.claude
```

## Step 1: Install Dependencies

### Bun (required by gstack)
```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
bun --version
```

### OpenClaw
```bash
npm install -g openclaw@2026.3.24
openclaw --version
```

### Scrapling
```bash
python3 -m venv /home/lever/command/venv
/home/lever/command/venv/bin/pip install "scrapling[fetchers]"
/home/lever/command/venv/bin/scrapling install
```

### gstack
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git /home/lever/command/gstack
cd /home/lever/command/gstack && ./setup
mkdir -p ~/.claude/skills
ln -sf /home/lever/command/gstack ~/.claude/skills/gstack
```

### Telegram Bot API Local Server (removes 20MB file limit)
```bash
# Install build dependencies
apt-get install -y make git zlib1g-dev libssl-dev gperf cmake g++

# Build from source (takes 15-20 minutes)
git clone --recursive https://github.com/tdlib/telegram-bot-api.git /opt/telegram-bot-api-build
cd /opt/telegram-bot-api-build
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..
cmake --build . --target install -j$(nproc)

# Verify
telegram-bot-api --version
```

## Step 2: Initialize OpenClaw

```bash
openclaw onboard --non-interactive --accept-risk --workspace /home/lever/command/workspaces --skip-health
```

### Configure Model Provider

Vigil uses Claude Code CLI as its model backend (not direct API keys):

```bash
openclaw config set agents.defaults.model.primary "claude-cli/claude-sonnet-4-6"
openclaw config set agents.defaults.maxConcurrent 5
openclaw config set agents.defaults.timeoutSeconds 7200
openclaw config set agents.defaults.cliBackends.claude-cli.command claude
```

### Set Watchdog Timeouts (critical for long-running tasks)

The default 180-second no-output timeout is too short. Set to 60 minutes:

```bash
openclaw config set agents.defaults.cliBackends.claude-cli.reliability.watchdog.fresh.noOutputTimeoutMs 3600000
openclaw config set agents.defaults.cliBackends.claude-cli.reliability.watchdog.fresh.minMs 300000
openclaw config set agents.defaults.cliBackends.claude-cli.reliability.watchdog.fresh.maxMs 3600000
openclaw config set agents.defaults.cliBackends.claude-cli.reliability.watchdog.resume.noOutputTimeoutMs 3600000
openclaw config set agents.defaults.cliBackends.claude-cli.reliability.watchdog.resume.minMs 300000
openclaw config set agents.defaults.cliBackends.claude-cli.reliability.watchdog.resume.maxMs 3600000
```

Without these settings, agent sessions that take more than 3 minutes to produce output
will be killed by the watchdog. Claude Code sessions routinely spend 3-10 minutes reading
context files and thinking before producing output.

### Disable OpenClaw's Native Telegram (our custom gateway handles it)
```bash
openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"
openclaw config set channels.telegram.enabled false
```

### Register Agents

```bash
openclaw agents add build --workspace /home/lever/command/workspaces/build --model "claude-cli/claude-sonnet-4-6" --non-interactive
openclaw agents add verify --workspace /home/lever/command/workspaces/verify --model "claude-cli/claude-sonnet-4-6" --non-interactive
openclaw agents add secure --workspace /home/lever/command/workspaces/secure --model "claude-cli/claude-sonnet-4-6" --non-interactive
openclaw agents add research --workspace /home/lever/command/workspaces/research --model "claude-cli/claude-sonnet-4-6" --non-interactive
openclaw agents add operate --workspace /home/lever/command/workspaces/operate --model "claude-cli/claude-sonnet-4-6" --non-interactive
openclaw agents add ceo --workspace /home/lever/command/workspaces/ceo --model "claude-cli/claude-sonnet-4-6" --non-interactive
openclaw agents add advisor --workspace /home/lever/command/workspaces/advisor --model "claude-cli/claude-opus-4-6" --non-interactive
openclaw agents add improve --workspace /home/lever/command/workspaces/improve --model "claude-cli/claude-sonnet-4-6" --non-interactive
```

## Step 3: Install Services

### OpenClaw Gateway

Create `/etc/systemd/system/openclaw-gateway.service`:

```ini
[Unit]
Description=OpenClaw Gateway (Vigil)
After=network.target

[Service]
Type=simple
User=lever
Group=lever
WorkingDirectory=/home/lever/command
ExecStart=/usr/bin/node /usr/lib/node_modules/openclaw/openclaw.mjs gateway run --port 18789
Restart=always
RestartSec=5
Environment=HOME=/home/lever
Environment=PATH=/home/lever/.bun/bin:/usr/local/bin:/usr/bin:/bin:/home/lever/.local/bin
Environment=OPENCLAW_CONFIG_PATH=/home/lever/.openclaw/openclaw.json
Environment=OPENCLAW_STATE_DIR=/home/lever/.openclaw

[Install]
WantedBy=multi-user.target
```

### Telegram Bot API Local Server

Create `/etc/systemd/system/telegram-bot-api.service`:

```ini
[Unit]
Description=Telegram Bot API Local Server
After=network.target

[Service]
Type=simple
User=lever
Group=lever
ExecStart=/usr/local/bin/telegram-bot-api --local --dir=/home/lever/command/telegram-api-data --http-port=8081
Restart=always
RestartSec=5
Environment=TELEGRAM_API_ID=YOUR_API_ID
Environment=TELEGRAM_API_HASH=YOUR_API_HASH

[Install]
WantedBy=multi-user.target
```

### Vigil Telegram Gateway

Create `/etc/systemd/system/vigil-telegram.service`:

```ini
[Unit]
Description=Vigil Telegram Gateway (file downloads + message routing)
After=network.target openclaw-gateway.service telegram-bot-api.service

[Service]
Type=simple
User=lever
Group=lever
WorkingDirectory=/home/lever/command
ExecStart=/usr/bin/python3 /home/lever/command/inbox/telegram-gateway.py
Restart=always
RestartSec=5
Environment=HOME=/home/lever
Environment=PATH=/home/lever/.bun/bin:/usr/local/bin:/usr/bin:/bin:/home/lever/.local/bin

[Install]
WantedBy=multi-user.target
```

### Dashboard

Create `/etc/systemd/system/vigil-dashboard.service`:

```ini
[Unit]
Description=Vigil Dashboard (port 8080)
After=network.target

[Service]
Type=simple
User=lever
Group=lever
WorkingDirectory=/home/lever/command/dashboard
ExecStart=/usr/bin/npx serve -s . -l 8080 --no-clipboard
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Create `/etc/systemd/system/vigil-dashboard-gen.timer`:

```ini
[Unit]
Description=Regenerate Vigil Dashboard every 60 seconds

[Timer]
OnBootSec=10s
OnUnitActiveSec=60s
AccuracySec=5s

[Install]
WantedBy=timers.target
```

### Inbox Watcher

Create `/etc/systemd/system/vigil-inbox.service`:

```ini
[Unit]
Description=Vigil Inbox Watcher (knowledge ingestion pipeline)
After=network.target openclaw-gateway.service

[Service]
Type=simple
User=lever
Group=lever
WorkingDirectory=/home/lever/command
ExecStart=/bin/bash /home/lever/command/inbox/watcher.sh
Restart=always
RestartSec=10
Environment=HOME=/home/lever
Environment=PATH=/home/lever/.bun/bin:/usr/local/bin:/usr/bin:/bin:/home/lever/.local/bin

[Install]
WantedBy=multi-user.target
```

### Start All Services

```bash
systemctl daemon-reload
systemctl enable openclaw-gateway telegram-bot-api vigil-telegram vigil-dashboard vigil-dashboard-gen.timer vigil-inbox
systemctl start openclaw-gateway telegram-bot-api vigil-telegram vigil-dashboard vigil-dashboard-gen.timer vigil-inbox
```

## Step 4: Set Up Heartbeat

### System crontab (health check)
```bash
echo "0 */4 * * * /bin/bash /home/lever/command/heartbeat/health-escalate.sh >> /home/lever/command/heartbeat/health-check.log 2>&1" | crontab -
```

### OpenClaw cron (workstream schedules)
```bash
openclaw cron add --name "research-morning-scan" --agent research --cron "0 8 * * *" --message "Run your morning market scan." --timeout-seconds 1800 --announce
openclaw cron add --name "research-evening-scan" --agent research --cron "0 20 * * *" --message "Run your evening market scan." --timeout-seconds 1800 --announce
openclaw cron add --name "advisor-daily-brief" --agent advisor --cron "0 6 * * *" --message "Run your full daily cycle." --timeout-seconds 3600 --announce
openclaw cron add --name "secure-weekly-audit" --agent secure --cron "0 3 * * 1" --message "Run your weekly security audit." --timeout-seconds 3600 --announce
openclaw cron add --name "ceo-weekly-brief" --agent ceo --cron "0 7 * * 1" --message "Produce your weekly CEO brief." --timeout-seconds 1800 --announce
openclaw cron add --name "improve-weekly-review" --agent improve --cron "0 9 * * 3" --message "Run your weekly product review." --timeout-seconds 1800 --announce
```

## Step 5: Pair Telegram

Send any message to the bot on Telegram. The gateway will forward it to OpenClaw.
If OpenClaw requires pairing:
```bash
openclaw pairing approve telegram YOUR_CODE
```

## Step 6: Verify

```bash
# Gateway
openclaw health

# Agents
openclaw agents list

# Cron schedule
openclaw cron list

# Health check
bash /home/lever/command/heartbeat/health-check.sh

# Dashboard
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:8080

# Telegram gateway
systemctl status vigil-telegram

# Inbox watcher
systemctl status vigil-inbox

# Telegram Bot API server
systemctl status telegram-bot-api
```

## Step 7: Git Backup

```bash
# Create backup script
cat > /root/backup-vigil.sh << 'EOF'
#!/bin/bash
cd /home/lever/command
git add -A 2>/dev/null
git diff --quiet --cached 2>/dev/null || git commit -m "auto-backup: $(date -u +%Y-%m-%d-%H%M)" 2>/dev/null
git push origin main 2>/dev/null
EOF
chmod +x /root/backup-vigil.sh

# Add to crontab (runs every hour at :45)
echo "45 * * * * /root/backup-vigil.sh >> /var/log/vigil-backup.log 2>&1" | crontab -a
```

## Troubleshooting

### Agent sessions timing out
If you see "CLI produced no output for Xs and was terminated":
```bash
# Check the watchdog config
openclaw config get agents.defaults.cliBackends.claude-cli.reliability.watchdog
```
The `maxMs` values must be high enough (3600000 = 60 min). If they are at defaults
(180000 for resume), the watchdog kills sessions before they produce output.

### Gateway will not start
```bash
openclaw doctor
systemctl status openclaw-gateway --no-pager
journalctl -u openclaw-gateway --no-pager -n 50
```

### Telegram files not downloading
Check the Telegram gateway log:
```bash
cat /home/lever/command/inbox/telegram-gateway.log
```
If files over 20MB fail without the local Bot API server, either install the local
server or use SCP:
```bash
scp "file.pdf" lever@SERVER:/home/lever/command/inbox/incoming/
```

### Claude Code permission prompts hanging
The headless Claude Code sessions need all tools pre-approved. Check:
```bash
cat /home/lever/.claude/settings.json
```
Must include `Bash(*)`, `Read(*)`, `Write(*)`, `Edit(*)`, `Glob(*)`, `Grep(*)` etc.
Also check per-project settings in `/home/lever/.claude/projects/`.

### Dashboard not updating
```bash
systemctl status vigil-dashboard-gen.timer
bash /home/lever/command/dashboard/generate.sh
```

### Health check false positives
Check thresholds in `/home/lever/command/heartbeat/health-check.sh`:
- Disk warning: 85%
- RAM warning: 90%
- Stuck session: 6 hours
