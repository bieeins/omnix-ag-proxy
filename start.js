#!/usr/bin/env node
'use strict';

const { execSync, spawn } = require('child_process');
const readline = require('readline');
const path = require('path');

const PORT = 20129;
const SCRIPT = path.join(__dirname, 'index.js');
const VERSION = require('./package.json').version || '1.0.0';

// Colors
const R = '\x1b[0m', G = '\x1b[32m', Y = '\x1b[33m', C = '\x1b[36m', M = '\x1b[35m', B = '\x1b[1m', D = '\x1b[2m';

function banner() {
  console.clear();
  console.log(`${D}=========================================${R}`);
  console.log(`  ${B}Choose Interface${R} (v${VERSION})`);
  console.log(`  ${M}🛡${R} Server: ${C}http://localhost:${PORT}${R}`);
  console.log(`${D}=========================================${R}`);
}

function isRunning() {
  try {
    if (process.platform === 'win32') {
      const out = execSync(
        `powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort ${PORT} -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess"`,
        { encoding: 'utf8', timeout: 5000 }
      ).trim();
      return out ? parseInt(out.split(/\r?\n/)[0], 10) : null;
    } else {
      const out = execSync(`lsof -ti:${PORT} 2>/dev/null || true`, { encoding: 'utf8' }).trim();
      return out ? parseInt(out.split('\n')[0], 10) : null;
    }
  } catch (_) { return null; }
}

function stopExisting() {
  const pid = isRunning();
  if (pid && pid !== process.pid) {
    try { process.kill(pid); } catch (_) {}
    console.log(`${Y}Stopped existing process (PID ${pid})${R}`);
    // Wait a moment
    execSync(process.platform === 'win32' ? 'ping -n 2 127.0.0.1 >nul' : 'sleep 1');
  }
}

function openBrowser(url) {
  try {
    if (process.platform === 'win32') execSync(`start ${url}`, { stdio: 'ignore' });
    else if (process.platform === 'darwin') execSync(`open ${url}`, { stdio: 'ignore' });
    else execSync(`xdg-open ${url} 2>/dev/null || true`, { stdio: 'ignore' });
  } catch (_) {}
}

function startForeground(openUI) {
  stopExisting();
  const args = ['--port', String(PORT)];
  const child = spawn(process.execPath, [SCRIPT, ...args], {
    stdio: 'inherit',
    cwd: __dirname,
  });
  if (openUI) {
    setTimeout(() => openBrowser(`http://localhost:${PORT}/ui`), 1500);
  }
  child.on('exit', (code) => {
    console.log(`\n${Y}OMNIX-Shield exited (code ${code})${R}`);
    process.exit(code || 0);
  });
  process.on('SIGINT', () => { child.kill('SIGINT'); });
  process.on('SIGTERM', () => { child.kill('SIGTERM'); });
}

function startBackground() {
  stopExisting();
  const args = ['--port', String(PORT)];
  const out = require('fs').openSync(path.join(__dirname, 'omnix-shield.log'), 'a');
  const child = spawn(process.execPath, [SCRIPT, ...args], {
    detached: true,
    stdio: ['ignore', out, out],
    cwd: __dirname,
  });
  child.unref();
  console.log(`\n${G}✓${R} OMNIX-Shield running in background (PID ${child.pid})`);
  console.log(`  Dashboard: ${C}http://localhost:${PORT}/ui${R}`);
  console.log(`  Log file:  ${D}${path.join(__dirname, 'omnix-shield.log')}${R}`);

  // Launch system tray icon (Windows only)
  if (process.platform === 'win32') {
    const trayScript = path.join(__dirname, 'tray.ps1');
    if (require('fs').existsSync(trayScript)) {
      execSync(`start /B powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "${trayScript}" -NodePid ${child.pid} -Port ${PORT}`, { stdio: 'ignore', shell: true });
      console.log(`  Tray icon: ${G}active${R}`);
    }
  }

  console.log(`\n  Stop: ${Y}node start.js stop${R}`);
  setTimeout(() => process.exit(0), 500);
}

// CLI shortcuts: node start.js stop / status
const cmd = process.argv[2];
if (cmd === 'stop') {
  const pid = isRunning();
  if (pid) {
    try { process.kill(pid); } catch (_) {}
    console.log(`${G}Stopped${R} OMNIX-Shield (PID ${pid})`);
  } else {
    console.log(`${Y}Not running${R}`);
  }
  process.exit(0);
}
if (cmd === 'tray') {
  // Called by autostart shortcut — start background + tray silently
  startBackground();
}
if (cmd === 'status') {
  const pid = isRunning();
  if (pid) {
    console.log(`${G}●${R} OMNIX-Shield is ${G}running${R} (PID ${pid}) on port ${PORT}`);
  } else {
    console.log(`${Y}○${R} OMNIX-Shield is ${Y}not running${R}`);
  }
  process.exit(0);
}

// Interactive menu
banner();

const options = [
  { label: 'Web UI (Open in Browser)', action: () => startForeground(true) },
  { label: 'Terminal UI (Interactive CLI)', action: () => startForeground(false) },
  { label: 'Hide to Tray (Background)', action: () => startBackground() },
  { label: 'Exit', action: () => process.exit(0) },
];

let selected = 0;

function renderMenu() {
  // Move cursor up to redraw menu
  process.stdout.write(`\x1b[${options.length}A`);
  options.forEach((opt, i) => {
    const prefix = i === selected ? `${G}>${R} ` : '  ';
    const text = i === selected ? `${B}${opt.label}${R}` : `${D}${opt.label}${R}`;
    process.stdout.write(`\x1b[2K${prefix}${text}\n`);
  });
}

// Initial render
console.log('');
options.forEach((opt, i) => {
  const prefix = i === selected ? `${G}>${R} ` : '  ';
  const text = i === selected ? `${B}${opt.label}${R}` : `${D}${opt.label}${R}`;
  console.log(`${prefix}${text}`);
});

// Key handling
if (process.stdin.isTTY) {
  readline.emitKeypressEvents(process.stdin);
  process.stdin.setRawMode(true);
  process.stdin.on('keypress', (str, key) => {
    if (key.name === 'up') { selected = (selected - 1 + options.length) % options.length; renderMenu(); }
    else if (key.name === 'down') { selected = (selected + 1) % options.length; renderMenu(); }
    else if (key.name === 'return') { process.stdin.setRawMode(false); console.log(''); options[selected].action(); }
    else if (key.name === 'escape' || (key.ctrl && key.name === 'c')) { process.stdin.setRawMode(false); process.exit(0); }
  });
} else {
  // Non-TTY: just start in foreground
  startForeground(false);
}
