/**
 * Backfill screen element maps from saved Figma metadata dumps
 * (docs/features/ui2-component-notes/07-capture.md §1.1).
 *
 *   node capture/scripts/ui2-screen-elements.mjs <screen-id> <metadata.xml> \
 *        [--snapshot <stem>] [--write]
 *   node capture/scripts/ui2-screen-elements.mjs --batch <manifest.json> [--write]
 *
 * BATCH IS THE REAL ENTRY POINT. A layer name is only evidence of a component
 * once some node-id match has confirmed it, and the registry cites exactly one
 * instance per row — usually on whichever screen minted it. Run screen-by-screen,
 * "Navigation" resolves to C-019 TopNav on home-dashboard (whose instance the
 * registry cites) and resolves to NOTHING on the four other screens that render
 * the same nav. So the batch learns across every dump first, then maps each
 * screen against the union. The Figma file is one namespace; the §4 closed-list
 * gate is still applied per screen, so a name learned elsewhere can never smuggle
 * a component into a screen that does not render it.
 * (Added during phase 3 — 07 §1.1.)
 *
 * A MIGRATION TOOL, not a runtime dependency. Ten screens were specced before
 * element maps existed; from here on /ui2-screen phase 2 writes the map as part
 * of decomposition, because that walk already pairs every instance with a
 * registry row — the map IS that pairing written down.
 *
 * Input is a saved dump rather than a live fetch because `get_metadata` is an MCP
 * tool only the agent can call; /ui2-screen already works from saved dumps for
 * the same reason.
 *
 * The resolution ladder, per instance:
 *   1. its own node id against every node id cited in a registry row's Figma-ref
 *      column (rows minted from this screen cite the instance itself);
 *   2. else its case-folded layer name against the parenthesised Figma name in
 *      that column;
 *   3. and the result is KEPT ONLY IF the screen spec's §4 closed list contains
 *      it. That is D5's hand-check, mechanised: the spec already states which rows
 *      the screen renders, so a match outside the list is wrong by construction.
 *
 * Anything unresolved goes to scripts/out/<stem>.unmapped.json — the operator's
 * worklist — never into the map. An unmapped area simply has no box; a WRONG box
 * would attribute a note or a comment to the wrong component, which is the one
 * outcome worse than none.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { buildUi2Index, buildUi2Screens, screenAssetsDir } from '../lib/ui2-index.mjs';

const OUT_DIR = path.resolve(import.meta.dirname, 'out');

/** One element in the dump. Rects are PARENT-relative — only the root carries a
 *  canvas position — so the walk accumulates offsets (07 §1.1 step 1). */
function parseMetadata(xml) {
  const TAG = /<(\w+)\s+([^>]*?)(\/?)>|<\/(\w+)>/g;
  const attrs = (raw) => Object.fromEntries(
    [...raw.matchAll(/(\w[\w-]*)="([^"]*)"/g)].map((m) => [m[1], m[2]]),
  );
  const nodes = [];
  const stack = [];
  let root = null;

  for (const m of xml.matchAll(TAG)) {
    if (m[4]) { stack.pop(); continue; }           // closing tag
    const tag = m[1];
    const a = attrs(m[2]);
    const selfClosing = m[3] === '/';
    const x = Number(a.x ?? 0);
    const y = Number(a.y ?? 0);
    const w = Number(a.width ?? 0);
    const h = Number(a.height ?? 0);

    if (!root) {
      // The root's own x/y are canvas coordinates; everything below is relative
      // to it, so the origin of the frame space is (0,0).
      root = { id: a.id, name: a.name, w, h };
      if (!selfClosing) stack.push({ ox: 0, oy: 0 });
      continue;
    }

    const parent = stack[stack.length - 1] ?? { ox: 0, oy: 0 };
    const node = { tag, id: a.id, name: a.name ?? '', ox: parent.ox + x, oy: parent.oy + y, w, h };
    nodes.push(node);
    if (!selfClosing) stack.push(node);
  }
  return { root, nodes };
}

/** Registry Figma-ref column → lookups. A cell can cite several nodes and carry
 *  prose ("set 3555:32772 (Top navigation; owner-designated … node 3622:5499 is a
 *  home-frame instance)"), so every node id in it keys the row, and the
 *  parenthesised name up to the first `;` or em dash is the name key. */
/** A layer name can legitimately mean more than one component — this file has a
 *  32×40 "Day" chip (C-052) and a 131×192 "Day" card (C-025) — so a name maps to
 *  a LIST of candidates and the screen's §4 closed list picks between them. */
/** Names are compared on a normalised form — lowercased, non-alphanumerics
 *  dropped — so the registry's `FieldGroup` matches the layer "Field group" and
 *  `Chevron--down` matches `chevron down`. Still EXACT matching, just on a form
 *  that ignores the spacing and punctuation a Figma layer name and a registry
 *  name disagree about. It is deliberately not fuzzy: "Top navigation" still does
 *  not match "Navigation". */
const normName = (s) => String(s ?? '').toLowerCase().replace(/[^a-z0-9]+/g, '');

function addName(map, key, ref) {
  const k = normName(key);
  if (!k) return;
  const list = map.get(k) ?? [];
  if (!list.includes(ref)) list.push(ref);
  map.set(k, list);
}

function buildLookups(index) {
  const byNode = new Map();
  const byName = new Map();
  for (const section of index.sections) {
    for (const row of section.rows) {
      const ref = row.figma ?? row.figmaRef ?? '';
      for (const m of String(ref).matchAll(/\b(\d+:\d+)\b/g)) {
        if (!byNode.has(m[1])) byNode.set(m[1], row.id);
      }
      // The parenthesised Figma name, minus the qualifiers the column carries:
      // `(sheet, Day; owner-designated …)` → `day`, `(main, "Percent indicator",
      // property1=Default)` → `percent indicator`, `(in 3622:5487)` → nothing (it
      // is a provenance note, not a layer name).
      // EVERY parenthesised group, not just the first: C-048's cell is
      // `sets 3517:29389 (Green/Red) + 3547:31761 (sheet, Page buton ×2 — hyphen…)`,
      // and the layer name lives in the second one.
      for (const m of String(ref).matchAll(/\(([^)]+)\)/g)) {
        for (const seg of m[1].split(/[;—,]/)) {
          const name = seg
            .replace(/^\s*(sheet|main|set|sets|frame|frames|node)\s*/i, '')
            .replace(/[×x]\s*\d+\s*$/, '')
            .replace(/^["“']|["”']$/g, '')
            .trim();
          if (name && !/^in\s+\d+:\d+$/.test(name) && !/^\d+:\d+$/.test(name)) addName(byName, name, row.id);
        }
      }
      // The registry NAME itself is a legitimate key: several Figma layers are
      // named for the component rather than for the sheet entry.
      const rowName = String(row.name ?? '').split('(')[0].trim().toLowerCase();
      if (rowName) addName(byName, rowName, row.id);
    }
  }
  return { byNode, byName };
}

const clamp01 = (n) => Math.min(1, Math.max(0, n));
const round4 = (n) => Math.round(n * 10000) / 10000;

/** One screen's map + report, given the shared lookups. */
async function mapScreen({ screenId, stem, dump, pad = 0 }, { index, byNode, lookupName, write }) {
  const screens = await buildUi2Screens();
  const row = screens.byId.get(screenId);
  if (!row) throw new Error(`unknown screen: ${screenId}`);
  const closed = new Set(row.componentIds);
  if (!closed.size) throw new Error(`${screenId} has no §4 closed list — nothing to gate against`);

  const { root, nodes } = parseMetadata(await fs.readFile(dump, 'utf-8'));
  if (!root?.w || !root?.h) throw new Error(`${dump}: could not read the root frame size`);

  // `pad` is export padding the root's own bounds do not include. A SECTION export
  // carries it: `shared-edit-field`'s section is 1096×3206 in Figma and its PNG is
  // 1176×3286 — 40pt of margin on every side. The map describes the IMAGE's
  // coordinate space (09 §G-5), so the space is the padded box and every child
  // shifts into it. Without this the aspect guard rejects the map at 4.5%
  // divergence, and with a naive fix every rect would sit 40pt off.
  const space = { w: root.w + pad * 2, h: root.h + pad * 2 };

  const elements = [];
  const unmapped = [];
  for (const n of nodes) {
    if (n.tag !== 'instance' && n.tag !== 'frame') continue;
    if (n.ox + n.w <= 0 || n.oy + n.h <= 0) continue;           // wholly off-frame
    if (n.ox >= root.w || n.oy >= root.h) continue;

    const ref = byNode.get(n.id) ?? lookupName(n.name.trim().toLowerCase(), closed);
    const via = byNode.has(n.id) ? 'node' : (ref ? 'name' : null);
    if (!ref) {
      // A frame that matches nothing is almost always a layout container, not a
      // missed component — reporting every one would bury the real misses.
      if (n.tag === 'instance') unmapped.push({ instance: n.id, name: n.name, reason: 'no registry match' });
      continue;
    }
    if (!closed.has(ref)) {
      unmapped.push({ instance: n.id, name: n.name, tag: n.tag, reason: `matched ${ref} via ${via}, but it is not in this screen's §4 closed list` });
      continue;
    }
    elements.push({
      ref,
      name: index.byId.get(ref)?.name ?? n.name,
      instance: n.id,
      x: round4(clamp01((n.ox + pad) / space.w)),
      y: round4(clamp01((n.oy + pad) / space.h)),
      w: round4(clamp01(n.w / space.w)),
      h: round4(clamp01(n.h / space.h)),
    });
  }

  const map = {
    screen: screenId,
    snapshot: `${stem}.png`,
    node: root.id,
    size: space,
    generatedBy: `backfill@${new Date().toISOString().slice(0, 10)}`,
    elements,
  };

  const covered = new Set(elements.map((e) => e.ref));
  const report = {
    screen: screenId, snapshot: map.snapshot, node: root.id,
    closedList: [...closed], covered: [...covered],
    missingFromMap: [...closed].filter((id) => !covered.has(id)),
    unmapped,
  };

  await fs.mkdir(OUT_DIR, { recursive: true });
  await fs.writeFile(path.join(OUT_DIR, `${stem}.unmapped.json`), `${JSON.stringify(report, null, 2)}\n`, 'utf-8');
  if (write) {
    await fs.writeFile(path.join(screenAssetsDir, `${stem}.elements.json`), `${JSON.stringify(map, null, 2)}\n`, 'utf-8');
  }
  return { map, report };
}

async function main() {
  const argv = process.argv.slice(2);
  const write = argv.includes('--write');
  let jobs;

  if (argv[0] === '--batch') {
    // [{ screenId, stem, dump }, …] — one entry per SNAPSHOT, so a screen with two
    // frozen frames gets two maps (03 §1.2).
    jobs = JSON.parse(await fs.readFile(argv[1], 'utf-8'));
  } else {
    const [screenId, dump] = argv;
    if (!screenId || !dump) {
      console.error('usage: ui2-screen-elements.mjs <screen-id> <metadata.xml> [--snapshot <stem>] [--write]');
      console.error('       ui2-screen-elements.mjs --batch <manifest.json> [--write]');
      process.exit(1);
    }
    const stem = argv.includes('--snapshot') ? argv[argv.indexOf('--snapshot') + 1] : screenId;
    jobs = [{ screenId, stem, dump }];
  }

  const index = await buildUi2Index();
  const { byNode, byName } = buildLookups(index);

  // Pass 1 — learn layer names from node-id matches across EVERY dump, instances
  // only. An instance's layer name is the component's name by construction; a
  // frame's is whatever the designer typed for a container, and this file has four
  // different frames called "Details". Learning from the one the registry cites
  // mapped all four to C-028 InlineDropdown, three of them wrongly. Frames still
  // match by node id, and by a registry paren name, which an author wrote
  // deliberately ("(Title)" for C-020 SectionHeader).
  const learned = new Map();
  for (const job of jobs) {
    const { nodes } = parseMetadata(await fs.readFile(job.dump, 'utf-8'));
    for (const n of nodes) {
      if (n.tag !== 'instance') continue;
      const ref = byNode.get(n.id);
      const key = n.name.trim().toLowerCase();
      if (ref && key) addName(learned, key, ref);
    }
  }
  // Candidates in priority order — names confirmed on a real frame first, then the
  // registry's parenthesised ones ("Text metadata" is both C-022 and C-064). The
  // SCREEN's §4 closed list then picks: a name that means two things resolves to
  // whichever one this screen actually renders. Without that step home-dashboard's
  // four DayActivityCards resolved to C-052 DayChip — learned from the day rail on
  // study-program-home — and were then thrown away by the gate.
  const lookupName = (key, closed) => {
    const k = normName(key);
    const candidates = [...(learned.get(k) ?? []), ...(byName.get(k) ?? [])];
    return candidates.find((ref) => closed.has(ref)) ?? candidates[0] ?? null;
  };

  // Pass 2 — map each snapshot.
  let totalEls = 0;
  for (const job of jobs) {
    const { map, report } = await mapScreen(job, { index, byNode, lookupName, write });
    totalEls += map.elements.length;
    const line = `${job.stem}: ${map.elements.length} mapped, ${report.covered.length}/${report.closedList.length} of §4`;
    console.log(write ? `✓ ${line}` : line);
    if (report.missingFromMap.length) console.log(`    no instance on this frame: ${report.missingFromMap.join(', ')}`);
    if (report.unmapped.length) console.log(`    ${report.unmapped.length} unmapped — scripts/out/${job.stem}.unmapped.json`);
  }
  console.log(`\n${jobs.length} snapshot(s), ${totalEls} instances, ${learned.size} layer names learned`);
}

await main();
