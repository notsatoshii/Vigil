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

async function screenshotSection(url, selector, outputPath) {
  outputPath = outputPath || '/tmp/verify-screenshots/section.png';

  // Ensure output directory exists
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });

  const chromePath = getChromePath();
  console.log(`Chrome: ${chromePath}`);
  console.log(`URL: ${url}`);
  console.log(`Selector: ${selector}`);
  console.log(`Output: ${outputPath}`);

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
    const page = await browser.newPage();

    // Collect console messages
    page.on('console', (msg) => {
      console.log(`[${msg.type().toUpperCase()}] ${msg.text()}`);
    });

    page.on('pageerror', (err) => {
      console.error(`[PAGE_ERROR] ${err.message}`);
    });

    // Desktop viewport by default
    await page.setViewport({ width: 1920, height: 1080 });
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });

    // Wait for any animations/lazy loads
    await new Promise(r => setTimeout(r, 2000));

    // Find the element
    const element = await page.$(selector);
    if (!element) {
      throw new Error(`Element not found: ${selector}`);
    }

    // Screenshot just the element
    await element.screenshot({ path: outputPath });
    console.log(`\nSaved: ${outputPath}`);

    // Also log element dimensions for reference
    const box = await element.boundingBox();
    if (box) {
      console.log(`Element dimensions: ${Math.round(box.width)}x${Math.round(box.height)} at (${Math.round(box.x)}, ${Math.round(box.y)})`);
    }

    await page.close();
  } finally {
    await browser.close();
  }

  console.log('\nDone.');
}

// Main
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: node screenshot-section.js <url> <css-selector> [output.png]');
  console.error('Example: node screenshot-section.js http://localhost:3001 ".hero-section" /tmp/verify-screenshots/hero.png');
  process.exit(1);
}

const [url, selector, outputPath] = args;
screenshotSection(url, selector, outputPath).catch(err => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
