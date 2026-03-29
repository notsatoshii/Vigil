#!/usr/bin/env node
'use strict';

// Allow require() to find puppeteer-core from any working directory
module.paths.unshift('/home/lever/command/gstack/node_modules');

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME_PRIMARY = '/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome';
const CHROME_FALLBACK = '/home/lever/local-libs/standalone-chrome/chrome';

function getChromePath() {
  if (fs.existsSync(CHROME_PRIMARY)) return CHROME_PRIMARY;
  if (fs.existsSync(CHROME_FALLBACK)) return CHROME_FALLBACK;
  if (process.env.PUPPETEER_EXECUTABLE_PATH) return process.env.PUPPETEER_EXECUTABLE_PATH;
  throw new Error('Chrome not found. Set PUPPETEER_EXECUTABLE_PATH or install Chrome.');
}

const VIEWPORTS = [
  { name: 'desktop', width: 1920, height: 1080 },
  { name: 'tablet',  width: 768,  height: 1024 },
  { name: 'mobile',  width: 375,  height: 812 },
];

async function takeScreenshots(url, outputDir) {
  outputDir = outputDir || '/tmp/verify-screenshots';
  fs.mkdirSync(outputDir, { recursive: true });

  const consoleMessages = [];
  const chromePath = getChromePath();

  console.log(`Chrome: ${chromePath}`);
  console.log(`URL: ${url}`);
  console.log(`Output: ${outputDir}`);

  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
    ],
  });

  try {
    for (const vp of VIEWPORTS) {
      console.log(`\nViewport: ${vp.name} (${vp.width}x${vp.height})`);
      const page = await browser.newPage();

      // Collect console messages
      page.on('console', (msg) => {
        const entry = `[${vp.name}] [${msg.type().toUpperCase()}] ${msg.text()}`;
        consoleMessages.push(entry);
        console.log(entry);
      });

      page.on('pageerror', (err) => {
        const entry = `[${vp.name}] [PAGE_ERROR] ${err.message}`;
        consoleMessages.push(entry);
        console.log(entry);
      });

      await page.setViewport({ width: vp.width, height: vp.height });
      await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });

      // Wait for any animations/lazy loads
      await new Promise(r => setTimeout(r, 2000));

      // Above-the-fold screenshot (clip to viewport height)
      const foldPath = path.join(outputDir, `${vp.name}-fold.png`);
      await page.screenshot({
        path: foldPath,
        clip: { x: 0, y: 0, width: vp.width, height: vp.height },
      });
      console.log(`  Saved: ${foldPath}`);

      // Full-page screenshot
      const fullPath = path.join(outputDir, `${vp.name}-full.png`);
      await page.screenshot({
        path: fullPath,
        fullPage: true,
      });
      console.log(`  Saved: ${fullPath}`);

      await page.close();
    }
  } finally {
    await browser.close();
  }

  // Write console log to file
  const logPath = path.join(outputDir, 'console.log');
  fs.writeFileSync(logPath, consoleMessages.join('\n') + '\n');
  console.log(`\nConsole log: ${logPath}`);

  // Print overflow summary
  const overflowLines = consoleMessages.filter(l =>
    l.toLowerCase().includes('overflow') ||
    l.toLowerCase().includes('scroll') ||
    l.toLowerCase().includes('layout')
  );
  if (overflowLines.length > 0) {
    console.log('\n[OVERFLOW/LAYOUT HINTS]');
    overflowLines.forEach(l => console.log(l));
  }

  console.log('\nDone. Screenshots saved to:', outputDir);
  console.log('Files:');
  fs.readdirSync(outputDir).forEach(f => console.log('  ' + path.join(outputDir, f)));
}

// Main
const args = process.argv.slice(2);
if (args.length < 1) {
  console.error('Usage: node screenshot.js <url> [output-dir]');
  console.error('Example: node screenshot.js http://localhost:3001 /tmp/verify-screenshots');
  process.exit(1);
}

const [url, outputDir] = args;
takeScreenshots(url, outputDir).catch(err => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
