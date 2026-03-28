# Vigil Deployment Guide

## Prerequisites

- **Server**: Linux (Ubuntu 22.04+ recommended), 16 GB RAM minimum, 4+ cores
- **Node.js**: v22+ (`node --version`)
- **npm**: v10+ (`npm --version`)
- **Python**: 3.12+ (`python3 --version`)
- **Claude Code**: Installed and authenticated (`claude auth status`)
- **Claude Max subscription**: Required for claude-cli provider (20x recommended for concurrent sessions)
- **Telegram Bot**: Created via @BotFather, token available

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

## Step 2: Initialize OpenClaw

```bash
openclaw onboard --non-interactive --accept-risk --workspace /home/lever/command/workspaces --skip-health
```

### Add Telegram Channel
```bash
openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

### Configure Model Provider

Vigil uses Claude Code CLI as its model backend (not direct API keys):

```bash
openclaw config set agents.defaults.model.primary "claude-cli/claude-sonnet-4-6"
openclaw config set agents.defaults.maxConcurrent 5
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

### Bind Telegram to Commander
```bash
openclaw agents bind --agent main --bind telegram
```

### Pair Your Telegram Account
Send any message to the bot on Telegram. It will respond with a pairing code. Then:
```bash
openclaw pairing approve telegram YOUR_CODE
```

## Step 3: Install Gateway Service

### Option A: OpenClaw built-in installer
```bash
openclaw gateway install --force
openclaw gateway start
```

### Option B: Manual systemd service (recommended for production)

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

```bash
systemctl daemon-reload
systemctl enable openclaw-gateway
systemctl start openclaw-gateway
```

## Step 4: Install Dashboard

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

```bash
systemctl daemon-reload
systemctl enable vigil-dashboard vigil-dashboard-gen.timer
systemctl start vigil-dashboard vigil-dashboard-gen.timer
```

## Step 5: Set Up Heartbeat Cron Jobs

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

## Step 6: Verify

```bash
# Check gateway
openclaw health

# Check Telegram
openclaw channels status --probe

# Check agents
openclaw agents list

# Check cron
openclaw cron list

# Check health
bash /home/lever/command/heartbeat/health-check.sh

# Check dashboard
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:8080
```

## Step 7: Git Backup

Create backup scripts and add to crontab:

```bash
# /root/backup-vigil.sh
cd /home/lever/command
git add -A 2>/dev/null
git diff --quiet --cached 2>/dev/null || git commit -m "auto-backup: $(date -u +%Y-%m-%d-%H%M)" 2>/dev/null
git push origin main 2>/dev/null
```

```bash
echo "45 * * * * /root/backup-vigil.sh >> /var/log/vigil-backup.log 2>&1" >> /etc/crontab
```

## Troubleshooting

### Gateway will not start
```bash
openclaw doctor
systemctl status openclaw-gateway --no-pager
journalctl -u openclaw-gateway --no-pager -n 50
```

### Telegram not connecting
```bash
openclaw channels status --probe
openclaw channels logs
```

### Agent sessions failing
Check the model provider:
```bash
openclaw agent --agent main --message "hello" --timeout 30
```

If it fails with auth errors, verify Claude Code is authenticated:
```bash
su - lever -c "claude auth status"
```

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
