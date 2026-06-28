#!/usr/bin/env node
/**
 * build-twins.mjs — batch-build the Vue web twins for every compare component
 * that has an iPhone capture but no web version yet.
 *
 * For each candidate it: fetches the same build prompt the "Generate prompt"
 * button produces, appends a headless execution contract, and runs it through a
 * fresh non-interactive `claude` process (clean context per component). Runs are
 * SEQUENTIAL — every build does `cd client && npm run build` + captures, which
 * share the client bundle and git tree, so parallel runs would race.
 *
 * It's safe to re-run: a component that already renders on web is skipped, and a
 * failed component never stops the batch.
 *
 *   node capture/scripts/build-twins.mjs [options]
 *
 * Options:
 *   --limit N            only the first N candidates (pilot a few first!)
 *   --group <Name>       only candidates in this category group (e.g. Cards)
 *   --ids a,b,c          only these comparison ids (comma-separated)
 *   --model <name>       model for the headless runs (default: claude CLI default)
 *   --permission <mode>  claude permission flag (default: skip)
 *                          skip   → --dangerously-skip-permissions (headless-reliable)
 *                          accept → --permission-mode acceptEdits (will hang on Bash prompts)
 *   --timeout <min>      per-component kill timeout (default: 25)
 *   --commit             git-commit after each component that succeeds
 *   --run                actually run (without it, this is a DRY RUN: prints the plan)
 *
 * Examples:
 *   node capture/scripts/build-twins.mjs                 # dry run — show the plan
 *   node capture/scripts/build-twins.mjs --group Cards --limit 3 --run
 *   node capture/scripts/build-twins.mjs --run --commit
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '../..');
const logsDir = path.join(__dirname, 'logs');

const API = process.env.CAPTURE_API ?? 'http://localhost:5951';
const CLIENT = process.env.CAPTURE_CLIENT_URL ?? 'http://localhost:8001';

// Live, machine-readable progress — updated on every state transition so the
// monitor (twins-status.mjs) and any watcher can see where the batch is in real
// time. One run owns this file; re-running overwrites it.
const STATE_PATH = path.join(logsDir, '_state.json');
let state = null;
async function saveState() {
  if (!state) return;
  state.updatedAt = new Date().toISOString();
  await fs.writeFile(STATE_PATH, JSON.stringify(state, null, 2));
}
function setComp(id, patch) {
  state.components[id] = { ...(state.components[id] ?? {}), ...patch };
}

// ── args ──
function arg(name, fallback = null) {
  const i = process.argv.indexOf(name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const flag = (name) => process.argv.includes(name);
const opts = {
  limit: Number(arg('--limit', '0')) || 0,
  group: arg('--group'),
  ids: arg('--ids')?.split(',').map((s) => s.trim()).filter(Boolean) ?? null,
  model: arg('--model'),
  permission: arg('--permission', 'skip'),
  timeoutMin: Number(arg('--timeout', '25')) || 25,
  commit: flag('--commit'),
  run: flag('--run'),
};

const permArgs = opts.permission === 'accept'
  ? ['--permission-mode', 'acceptEdits']
  : ['--dangerously-skip-permissions'];

async function getJson(url, init) {
  const res = await fetch(url, init);
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return res.json();
}

/** Has this comparison a web twin yet? (any variant projects to web) */
async function webCount(id) {
  try {
    const v = await getJson(`${API}/api/compare/comparison/${id}/variants`);
    return v.counts?.web ?? 0;
  } catch { return 0; }
}

/** Candidates: iPhone shots captured, zero web variants. */
async function candidates() {
  const m = await getJson(`${API}/api/compare/manifest`);
  const out = [];
  for (const t of m.types ?? []) {
    for (const c of t.comparisons ?? []) {
      if (c.error) continue;
      const comp = c.completion ?? {};
      if ((comp.iphoneCaptured ?? 0) > 0 && (comp.webBuilt ?? 0) === 0) {
        out.push({ id: c.id, group: c.group, title: c.title, variants: comp.total ?? 0 });
      }
    }
  }
  return out;
}

const HEADLESS_CONTRACT = (id) => `

---
## Execution mode: AUTONOMOUS / HEADLESS
You are running non-interactively in a batch. Do NOT ask questions — make the best
call and proceed. You MUST actually build and verify, not just write files. Slash
commands are unavailable here.

After writing the Vue component + SCSS (registered in client/resources/css/app.scss),
registering it in the ComponentCapture island, and wiring the adapter into
capture/runners/compare/adapters/index.mjs:
1. Rebuild the client (the compare pane serves the BUILT bundle, not HMR; the capture
   server hot-reloads the adapter on its own — do NOT restart it):
     cd client && npm run build
2. Capture the web side for every variant, then wait for it to finish:
     curl -s -X POST ${API}/api/compare/capture -H 'Content-Type: application/json' \\
       -d '{"id":"${id}","viewport":"pro-max","platform":"client","variant":"*"}'
   (stream ${API}/api/capture/stream/<runId> until the done event).
3. Read the produced web PNGs under capture/fixtures/compare/_shots/${id}/pro-max/client/
   and the iPhone references under capture/fixtures/compare/_shots/${id}/pro-max/iphone/,
   compare them, and refine the Vue/SCSS + re-capture until they match (or surface a
   genuine parity gap honestly).

Hard rules: do NOT git commit. Do NOT start/stop/restart any dev server. Do NOT modify
iPhone (Swift) code. Success = the web variants capture to non-empty PNGs that match
the iPhone references.`;

async function preflight() {
  const checks = [];
  for (const [label, url] of [['capture server', `${API}/api/compare/manifest`], ['client app', CLIENT]]) {
    try { await fetch(url); checks.push(`✓ ${label} (${url})`); }
    catch { checks.push(`✗ ${label} UNREACHABLE (${url})`); }
  }
  return checks;
}

async function runClaude(id, prompt, logPath) {
  // Open a real fd for the child's stdout/stderr (a WriteStream's fd is null
  // until 'open', which spawn rejects). Close it once the child exits.
  const fh = await fs.open(logPath, 'w');
  return new Promise((resolve) => {
    const child = spawn('claude', ['-p', prompt, ...permArgs, ...(opts.model ? ['--model', opts.model] : [])], {
      cwd: repoRoot,
      env: process.env,
      stdio: ['ignore', fh.fd, fh.fd],
    });
    const killer = setTimeout(() => child.kill('SIGKILL'), opts.timeoutMin * 60_000);
    const done = async (code) => { clearTimeout(killer); await fh.close().catch(() => {}); resolve(code); };
    child.on('close', (code) => done(code ?? 0));
    child.on('error', (err) => { fh.write(`\nspawn error: ${err.message}\n`).catch(() => {}); done(1); });
  });
}

async function gitCommit(id) {
  await new Promise((resolve) => {
    const c = spawn('bash', ['-lc', `git add -A && git commit -m "capture: build web twin for ${id}" --no-verify`], { cwd: repoRoot, stdio: 'ignore' });
    c.on('close', resolve); c.on('error', () => resolve());
  });
}

async function main() {
  await fs.mkdir(logsDir, { recursive: true });

  console.log('Preflight:');
  for (const line of await preflight()) console.log('  ' + line);

  let list = await candidates();
  if (opts.group) list = list.filter((c) => (c.group ?? '').toLowerCase() === opts.group.toLowerCase());
  if (opts.ids) list = list.filter((c) => opts.ids.includes(c.id));
  if (opts.limit) list = list.slice(0, opts.limit);

  console.log(`\n${list.length} component(s) to build (iPhone shots present, no web twin):`);
  for (const c of list) console.log(`  · ${c.id}  [${c.group}]  ${c.variants} variant(s)`);

  if (!opts.run) {
    console.log(`\nDRY RUN. Re-run with --run to execute (model: ${opts.model ?? 'cli default'}, permission: ${opts.permission}, timeout: ${opts.timeoutMin}m${opts.commit ? ', commit per component' : ''}).`);
    console.log('Tip: pilot a few first, e.g.  --limit 3 --run');
    return;
  }

  // Seed live state (all pending) so the monitor shows the full plan immediately.
  state = {
    startedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
    model: opts.model ?? 'cli-default', permission: opts.permission, timeoutMin: opts.timeoutMin,
    total: list.length, current: null,
    components: Object.fromEntries(list.map((c) => [c.id, { group: c.group, variants: c.variants, status: 'pending' }])),
  };
  await saveState();

  const passed = [], failed = [], skipped = [];
  const started = Date.now();
  for (let i = 0; i < list.length; i++) {
    const c = list[i];
    const tag = `[${i + 1}/${list.length}] ${c.id}`;
    state.current = c.id;
    if (await webCount(c.id) > 0) {
      console.log(`${tag} — already has web twin, skipping`);
      skipped.push(c.id); setComp(c.id, { status: 'skipped' }); await saveState(); continue;
    }

    let prompt;
    try { prompt = (await getJson(`${API}/api/compare/comparison/${c.id}/build-prompt`)).prompt + HEADLESS_CONTRACT(c.id); }
    catch (err) {
      console.log(`${tag} — prompt fetch failed: ${err.message}`);
      failed.push(c.id); setComp(c.id, { status: 'failed', issue: `prompt fetch: ${err.message}` }); await saveState(); continue;
    }

    const logPath = path.join(logsDir, `${c.id}.log`);
    console.log(`${tag} — building… (log: ${path.relative(repoRoot, logPath)})`);
    const t0 = Date.now();
    setComp(c.id, { status: 'running', startedAt: new Date().toISOString(), log: path.relative(repoRoot, logPath) });
    await saveState();

    const code = await runClaude(c.id, prompt, logPath);
    const mins = Number(((Date.now() - t0) / 60_000).toFixed(1));
    const timedOut = mins >= opts.timeoutMin;

    const built = await webCount(c.id) > 0;
    if (built) {
      console.log(`${tag} — ✅ web twin built in ${mins}m`);
      passed.push(c.id);
      setComp(c.id, { status: 'passed', durationMin: mins, exitCode: code });
      await saveState();
      if (opts.commit) await gitCommit(c.id);
    } else {
      const issue = timedOut ? `timed out after ${opts.timeoutMin}m` : `no web twin produced (exit ${code})`;
      console.log(`${tag} — ❌ ${issue} (${mins}m) — see log`);
      failed.push(c.id);
      setComp(c.id, { status: 'failed', durationMin: mins, exitCode: code, issue });
      await saveState();
    }
  }
  state.current = null;
  await saveState();

  const totalMin = ((Date.now() - started) / 60_000).toFixed(1);
  console.log(`\n──────── done in ${totalMin}m ────────`);
  console.log(`✅ passed (${passed.length}): ${passed.join(', ') || '—'}`);
  console.log(`❌ failed (${failed.length}): ${failed.join(', ') || '—'}`);
  console.log(`↷ skipped (${skipped.length}): ${skipped.join(', ') || '—'}`);
  console.log(`logs: ${path.relative(repoRoot, logsDir)}/`);
}

main().catch((err) => { console.error(err); process.exit(1); });
