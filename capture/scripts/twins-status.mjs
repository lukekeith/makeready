#!/usr/bin/env node
/**
 * twins-status.mjs — monitor a build-twins.mjs batch.
 *
 * Reads the live state file build-twins writes and prints a dashboard: per-
 * component status, timings, the component currently building, and the tail of
 * each failed component's log so you can triage without hunting through files.
 *
 *   node capture/scripts/twins-status.mjs            # one snapshot
 *   node capture/scripts/twins-status.mjs --watch    # refresh every 5s
 *   node capture/scripts/twins-status.mjs --failed   # only failures + log tails
 *   node capture/scripts/twins-status.mjs --log <id> # full tail of one component
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const logsDir = path.join(__dirname, 'logs');
const STATE_PATH = path.join(logsDir, '_state.json');

const flag = (n) => process.argv.includes(n);
const arg = (n) => { const i = process.argv.indexOf(n); return i !== -1 ? process.argv[i + 1] : null; };

const ICON = { passed: '✅', failed: '❌', running: '⏳', skipped: '↷', pending: '·' };

async function tail(rel, n = 14) {
  try {
    const txt = await fs.readFile(path.join(__dirname, '..', '..', rel), 'utf8');
    return txt.split('\n').filter(Boolean).slice(-n);
  } catch { return []; }
}

async function render() {
  let state;
  try { state = JSON.parse(await fs.readFile(STATE_PATH, 'utf8')); }
  catch { console.log('No batch state yet — start one with: node capture/scripts/build-twins.mjs --run'); return false; }

  const comps = Object.entries(state.components);
  const by = (s) => comps.filter(([, c]) => c.status === s);
  const passed = by('passed'), failed = by('failed'), running = by('running'), skipped = by('skipped'), pending = by('pending');
  const done = passed.length + failed.length + skipped.length;

  // Single-component full log mode
  const one = arg('--log');
  if (one) {
    const c = state.components[one];
    console.log(`── ${one} (${c?.status ?? 'unknown'}) ──`);
    for (const line of await tail(c?.log ?? `capture/scripts/logs/${one}.log`, 60)) console.log(line);
    return true;
  }

  const elapsed = ((Date.now() - new Date(state.startedAt).getTime()) / 60_000).toFixed(1);
  console.log(`MakeReady web-twin batch · ${state.model} · ${elapsed}m elapsed`);
  console.log(`progress: ${done}/${state.total}   ✅ ${passed.length}  ❌ ${failed.length}  ⏳ ${running.length}  ↷ ${skipped.length}  · ${pending.length} pending`);
  if (state.current) console.log(`now building: ${state.current}`);

  if (!flag('--failed')) {
    console.log('');
    for (const [id, c] of comps) {
      const dur = c.durationMin != null ? `${c.durationMin}m` : '';
      console.log(`  ${ICON[c.status] ?? '?'} ${id.padEnd(28)} ${(c.group ?? '').padEnd(12)} ${dur}`);
    }
  }

  if (failed.length) {
    console.log(`\n──── ${failed.length} failure(s) ────`);
    for (const [id, c] of failed) {
      console.log(`\n❌ ${id}${c.issue ? ` — ${c.issue}` : ''}`);
      for (const line of await tail(c.log ?? `capture/scripts/logs/${id}.log`)) console.log(`   │ ${line}`);
    }
  }
  return running.length > 0 || pending.length > 0;
}

if (flag('--watch')) {
  // Re-render until the batch has no running/pending left.
  // eslint-disable-next-line no-constant-condition
  while (true) {
    process.stdout.write('\x1b[2J\x1b[H'); // clear
    const ongoing = await render();
    if (!ongoing) break;
    await new Promise((r) => setTimeout(r, 5000));
  }
} else {
  await render();
}
