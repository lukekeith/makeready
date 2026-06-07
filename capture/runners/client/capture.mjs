#!/usr/bin/env node
/**
 * Screenshot capture runner.
 *
 * Discovers capture/*\/[screen].json fixtures, navigates Playwright to the
 * matching /_capture/{workflow}/{screen} Laravel route (see CaptureController),
 * and writes PNGs to capture/{workflow}/screenshots/.
 *
 * Usage:
 *   node runners/client/capture.mjs                         # all workflows
 *   node runners/client/capture.mjs join-group              # single workflow
 *   node runners/client/capture.mjs join-group 03-phone     # single screen
 *   CAPTURE_BASE_URL=http://localhost:8000 npm run capture:client
 */
import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getViewport, getViewportName } from './devices.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const captureRoot = path.resolve(__dirname, '../../fixtures/client');
const BASE_URL = process.env.CAPTURE_BASE_URL ?? 'http://localhost:8001';
const workflowFilter = process.argv[2];
const screenFilter = process.argv[3]?.replace(/\.json$/, '');

async function findSpecs() {
  const entries = await fs.readdir(captureRoot, { withFileTypes: true });
  const specs = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (entry.name.startsWith('_')) continue;
    if (workflowFilter && entry.name !== workflowFilter) continue;
    const files = await fs.readdir(path.join(captureRoot, entry.name));
    for (const file of files) {
      if (!file.endsWith('.json')) continue;
      if (screenFilter && path.basename(file, '.json') !== screenFilter) continue;
      specs.push({ workflow: entry.name, file });
    }
  }
  return specs.sort((a, b) =>
    a.workflow === b.workflow
      ? a.file.localeCompare(b.file)
      : a.workflow.localeCompare(b.workflow),
  );
}

async function captureOne(browser, { workflow, file }) {
  const jsonPath = path.join(captureRoot, workflow, file);
  const spec = JSON.parse(await fs.readFile(jsonPath, 'utf-8'));
  const screen = path.basename(file, '.json');
  const output = spec.output ?? `${screen}.png`;
  const rawDevices = spec.devices ?? ['iphone-14'];
  const deviceSpecs = Array.isArray(rawDevices) ? rawDevices : [rawDevices];
  const url = `${BASE_URL}/_capture/${workflow}/${screen}`;

  for (const viewportSpec of deviceSpecs) {
    const contextOptions = getViewport(viewportSpec);
    const viewportName = getViewportName(viewportSpec);
    const context = await browser.newContext(contextOptions);
    const page = await context.newPage();

    const titleSuffix = spec.title ? `  — ${spec.title}` : '';
    console.log(`→ ${workflow}/${screen}  (${viewportName})${titleSuffix}`);
    page.on('pageerror', (err) => console.warn(`   [page error] ${err.message}`));

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 20000 });
    } catch {
      // Vite's HMR websocket can prevent networkidle from firing; fall back.
      await page.goto(url, { waitUntil: 'load', timeout: 20000 });
    }

    await page.evaluate(() => document.fonts?.ready).catch(() => {});

    if (spec.wait?.selector) {
      await page.waitForSelector(spec.wait.selector, {
        timeout: spec.wait.timeoutMs ?? 5000,
      });
    } else {
      // Generic settle — covers Vue island hydration.
      await page.waitForTimeout(500);
    }

    const outDir = path.join(captureRoot, workflow, 'screenshots', viewportName);
    await fs.mkdir(outDir, { recursive: true });
    const outPath = path.join(outDir, output);
    await page.screenshot({ path: outPath, fullPage: spec.fullPage !== false });

    await context.close();
    console.log(`   ✓ ${path.relative(process.cwd(), outPath)}`);
  }
}

async function main() {
  const specs = await findSpecs();
  if (specs.length === 0) {
    const filterDesc = [workflowFilter, screenFilter].filter(Boolean).join('/');
    console.log(`No capture fixtures found${filterDesc ? ` for "${filterDesc}"` : ''}.`);
    process.exit(0);
  }
  console.log(`Capturing ${specs.length} screen(s) from ${BASE_URL}`);

  const browser = await chromium.launch();
  const failures = [];
  try {
    for (const spec of specs) {
      try {
        await captureOne(browser, spec);
      } catch (err) {
        failures.push({ spec, err });
        console.error(`   ✗ ${spec.workflow}/${spec.file}: ${err.message}`);
      }
    }
  } finally {
    await browser.close();
  }

  if (failures.length) {
    console.error(`\n${failures.length} failure(s).`);
    process.exit(1);
  }
  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
