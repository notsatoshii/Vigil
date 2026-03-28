#!/usr/bin/env node
/**
 * Vigil Mission Control - Real-time Dashboard Server
 *
 * WebSocket-powered live dashboard. Pushes updates to browser as they happen.
 * Watches: file system changes, service states, OpenClaw events, gateway logs.
 *
 * Port: 8080
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync, exec } = require('child_process');
const { WebSocketServer } = require('ws');

const PORT = 8080;
const BRAIN = '/home/lever/command/shared-brain';
const HANDOFFS = '/home/lever/command/handoffs';
const KNOWLEDGE = '/home/lever/command/knowledge';
const INBOX_LOG = '/home/lever/command/inbox/telegram-gateway.log';
const HEALTH_JSON = '/home/lever/command/heartbeat/last-health-check.json';
const SESSION_COSTS = `${BRAIN}/SESSION_COSTS.md`;
const DASHBOARD_DIR = path.join(__dirname);

// State
let currentData = {};
let clients = new Set();

// ============================================================
// DATA COLLECTION
// ============================================================

function sh(cmd) {
  try { return execSync(cmd, { timeout: 5000, encoding: 'utf-8' }).trim(); }
  catch { return ''; }
}

function shNum(cmd) {
  const r = sh(cmd);
  const n = parseInt(r, 10);
  return isNaN(n) ? 0 : n;
}

function collectSystemData() {
  const memInfo = sh("free -m | awk '/Mem:/ {print $2, $3}'").split(' ');
  const ramTotal = parseInt(memInfo[0]) || 1;
  const ramUsed = parseInt(memInfo[1]) || 0;

  return {
    health: sh("cat " + HEALTH_JSON + " 2>/dev/null | python3 -c \"import json,sys; print(json.load(sys.stdin)['status'])\" 2>/dev/null") || 'unknown',
    healthTime: sh("cat " + HEALTH_JSON + " 2>/dev/null | python3 -c \"import json,sys; print(json.load(sys.stdin)['timestamp'])\" 2>/dev/null") || '',
    ramUsed, ramTotal,
    ramPct: Math.round(ramUsed * 100 / ramTotal),
    diskPct: shNum("df / --output=pcent | tail -1 | tr -d ' %'"),
    diskUsed: sh("df -h / --output=used | tail -1 | tr -d ' '"),
    diskTotal: sh("df -h / --output=size | tail -1 | tr -d ' '"),
    cpuLoad: sh("cat /proc/loadavg | awk '{print $1}'"),
    uptime: sh("uptime -p | sed 's/up //'")
  };
}

function collectServices() {
  const svcs = {
    'frontend': 'lever-frontend',
    'oracle': 'lever-oracle',
    'accrue': 'lever-accrue-keeper',
    'gateway': 'openclaw-gateway',
    'inbox': 'vigil-inbox',
    'telegram': 'vigil-telegram',
    'dashboard': 'vigil-dashboard',
    'caddy': 'caddy'
  };
  const result = {};
  for (const [name, svc] of Object.entries(svcs)) {
    result[name] = sh(`systemctl is-active ${svc} 2>/dev/null`) === 'active';
  }
  return result;
}

function collectSessions() {
  const today = new Date().toISOString().split('T')[0];
  return {
    active: shNum("su - lever -c \"openclaw health 2>/dev/null\" | grep 'Session store' | grep -o '[0-9]* entries' | grep -o '[0-9]*'"),
    today: shNum(`grep -c "Session #" "${SESSION_COSTS}" 2>/dev/null`),
    pendingApprovals: shNum(`grep -c "^[^#*-].*PENDING" "${BRAIN}/INTENTIONS.md" 2>/dev/null`) + shNum(`grep -c "^[^#*-].*PENDING" "${BRAIN}/ADVISOR_BRIEFS.md" 2>/dev/null`),
    deadLetters: shNum("find /home/lever/command/inbox/failed-messages/ -name '*.json' 2>/dev/null | wc -l"),
    gatewayErrors: shNum(`grep -c "ERROR" "${INBOX_LOG}" 2>/dev/null`)
  };
}

function collectKanban() {
  function getSection(section) {
    try {
      const content = fs.readFileSync(`${BRAIN}/KANBAN.md`, 'utf-8');
      const regex = new RegExp(`## ${section.replace(/[()]/g, '\\$&')}\\n([\\s\\S]*?)(?=\\n## |$)`);
      const match = content.match(regex);
      if (!match) return [];
      return match[1].split('\n').filter(l => l.startsWith('- ')).map(l => l.replace(/^- /, '').trim()).slice(0, 5);
    } catch { return []; }
  }
  const kanban = {
    backlog: getSection('BACKLOG'),
    planned: getSection('PLANNED'),
    inProgress: getSection('IN PROGRESS'),
    inReview: getSection('IN REVIEW'),
    done: getSection('DONE (last 10)'),
    blocked: getSection('BLOCKED')
  };

  // Merge live scheduler state for pipeline tasks
  try {
    const stateFile = '/home/lever/command/heartbeat/scheduler-state.json';
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf-8'));
    const tasks = state.tasks || {};
    for (const [tid, task] of Object.entries(tasks)) {
      if (task.stage === 'planning' || task.stage === 'critiquing' || task.stage === 'building') {
        if (!kanban.inProgress.some(i => i.includes(tid))) {
          kanban.inProgress.push(`${tid} [${task.stage.toUpperCase()}]`);
        }
      } else if (task.stage === 'verifying') {
        if (!kanban.inReview.some(i => i.includes(tid))) {
          kanban.inReview.push(`${tid} [VERIFYING]`);
        }
      } else if (task.stage === 'blocked') {
        if (!kanban.blocked.some(i => i.includes(tid))) {
          kanban.blocked.push(`${tid} [BLOCKED after ${task.attempts} attempts]`);
        }
      }
    }
  } catch {}

  // Merge live running agent processes (support tasks)
  try {
    const psResult = sh("ps aux | grep 'openclaw agent' | grep -v grep | sed 's/.*--agent //' | cut -d' ' -f1 | sort -u");
    const running = psResult.split('\n').filter(Boolean);
    for (const agent of running) {
      const upper = agent.toUpperCase();
      if (!['PLAN', 'CRITIQUE', 'BUILD', 'VERIFY'].includes(upper)) {
        if (!kanban.inProgress.some(i => i.toUpperCase().includes(upper))) {
          kanban.inProgress.push(`${upper} [ACTIVE]`);
        }
      }
    }
  } catch {}

  return kanban;
}

function collectRecentActivity() {
  // Handoffs (most recent first)
  const handoffs = [];
  try {
    const files = fs.readdirSync(HANDOFFS).filter(f => f.endsWith('.md')).map(f => ({
      name: f.replace('.md', ''),
      time: fs.statSync(path.join(HANDOFFS, f)).mtimeMs / 1000,
      path: path.join(HANDOFFS, f)
    })).sort((a, b) => b.time - a.time).slice(0, 8);

    for (const f of files) {
      try {
        const lines = fs.readFileSync(f.path, 'utf-8').split('\n');
        const summary = lines.find(l => /^[A-Z]/.test(l) && !l.startsWith('#')) || lines[2]?.replace(/[#*]/g, '') || '';
        handoffs.push({ name: f.name, time: Math.floor(f.time), summary: summary.trim().slice(0, 80) });
      } catch { handoffs.push({ name: f.name, time: Math.floor(f.time), summary: '' }); }
    }
  } catch {}

  // Recent sessions from RECENT_SESSIONS.md
  const sessions = [];
  try {
    const content = fs.readFileSync(`${BRAIN}/RECENT_SESSIONS.md`, 'utf-8');
    const lines = content.split('\n').filter(l => l.startsWith('### ')).slice(-8);
    for (const l of lines) {
      sessions.push(l.replace('### ', ''));
    }
  } catch {}

  return { handoffs, sessions };
}

function collectIntentions() {
  try {
    const content = fs.readFileSync(`${BRAIN}/INTENTIONS.md`, 'utf-8');
    const match = content.match(/## ACTIVE\n([\s\S]*?)(?=\n---)/);
    if (!match) return [];
    return match[1].split('\n').filter(l => /^\d+\./.test(l.trim())).map(l => l.trim()).slice(0, 5);
  } catch { return []; }
}

function collectAdvisor() {
  try {
    const content = fs.readFileSync(`${BRAIN}/ADVISOR_BRIEFS.md`, 'utf-8');
    const match = content.match(/## Latest Brief\n([\s\S]*?)(?=\n---)/);
    if (!match) return 'First brief runs at 6:00 UTC.';
    const text = match[1].trim();
    return text.startsWith('*') ? 'First brief runs at 6:00 UTC.' : text.slice(0, 500);
  } catch { return 'First brief runs at 6:00 UTC.'; }
}

function collectUpcoming() {
  try {
    const raw = sh("su - lever -c \"openclaw cron list 2>/dev/null\" | tail -n +2 | head -7");
    return raw.split('\n').filter(Boolean).map(line => {
      const parts = line.trim().split(/\s{2,}/);
      const name = parts[1] || '';
      const nextMatch = line.match(/in\s+(\d+[hmd])/);
      return { name, next: nextMatch ? nextMatch[0] : 'pending' };
    });
  } catch { return []; }
}

function collectKnowledge() {
  return {
    sources: shNum(`find ${KNOWLEDGE}/sources/ -name '*.json' 2>/dev/null | wc -l`),
    entities: shNum(`find ${KNOWLEDGE}/entities/ -name '*.json' 2>/dev/null | wc -l`)
  };
}

function collectAll() {
  return {
    timestamp: new Date().toISOString(),
    epoch: Math.floor(Date.now() / 1000),
    system: collectSystemData(),
    services: collectServices(),
    sessions: collectSessions(),
    knowledge: collectKnowledge(),
    kanban: collectKanban(),
    intentions: collectIntentions(),
    advisorSummary: collectAdvisor(),
    activity: collectRecentActivity(),
    upcoming: collectUpcoming(),
    projects: {
      lever: { status: 'testnet', bugsTotal: 12 },
      landing: { status: 'active' }
    }
  };
}

// ============================================================
// FILE WATCHING (real-time updates)
// ============================================================

function watchFiles() {
  const watchPaths = [
    BRAIN,
    HANDOFFS,
    '/home/lever/command/inbox',
    '/home/lever/command/heartbeat'
  ];

  for (const dir of watchPaths) {
    try {
      fs.watch(dir, { recursive: false }, (event, filename) => {
        if (filename && (filename.endsWith('.md') || filename.endsWith('.json') || filename.endsWith('.log'))) {
          setTimeout(() => pushUpdate(), 500); // debounce
        }
      });
    } catch {}
  }

  // Also watch gateway log for live activity
  try {
    let lastSize = 0;
    try { lastSize = fs.statSync(INBOX_LOG).size; } catch {}

    fs.watchFile(INBOX_LOG, { interval: 2000 }, (curr, prev) => {
      if (curr.size > prev.size) {
        // New log lines, push update
        setTimeout(() => pushUpdate(), 300);
      }
    });
  } catch {}
}

// ============================================================
// PERIODIC COLLECTION (for data that does not trigger file watches)
// ============================================================

let lastPush = 0;
function pushUpdate() {
  const now = Date.now();
  if (now - lastPush < 3000) return; // throttle to max 1 update per 3 seconds
  lastPush = now;

  try {
    currentData = collectAll();
    const msg = JSON.stringify({ type: 'update', data: currentData });
    for (const ws of clients) {
      if (ws.readyState === 1) ws.send(msg);
    }
  } catch (e) {
    console.error('Push error:', e.message);
  }
}

// ============================================================
// HTTP SERVER
// ============================================================

const server = http.createServer((req, res) => {
  // Serve static files
  let filePath;
  if (req.url === '/' || req.url === '/index.html') {
    filePath = path.join(DASHBOARD_DIR, 'mission-control.html');
  } else if (req.url === '/data.json') {
    // Legacy support
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify(currentData));
    return;
  } else {
    filePath = path.join(DASHBOARD_DIR, req.url.split('?')[0]);
  }

  const ext = path.extname(filePath);
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml' };

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': types[ext] || 'text/plain' });
    res.end(data);
  });
});

// ============================================================
// WEBSOCKET SERVER
// ============================================================

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  clients.add(ws);
  // Send current state immediately
  ws.send(JSON.stringify({ type: 'update', data: currentData }));

  ws.on('close', () => clients.delete(ws));
  ws.on('error', () => clients.delete(ws));
});

// ============================================================
// START
// ============================================================

// Initial data collection
currentData = collectAll();

// Watch for file changes
watchFiles();

// Periodic full refresh every 30 seconds (catches things file watches miss)
setInterval(pushUpdate, 30000);

// Service state check every 10 seconds
setInterval(() => {
  const newServices = collectServices();
  const oldServices = currentData.services || {};
  let changed = false;
  for (const [k, v] of Object.entries(newServices)) {
    if (oldServices[k] !== v) { changed = true; break; }
  }
  if (changed) pushUpdate();
}, 10000);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Vigil Mission Control running on port ${PORT}`);
  console.log(`WebSocket ready for real-time updates`);
  console.log(`Watching: ${BRAIN}, ${HANDOFFS}, inbox, heartbeat`);
});
