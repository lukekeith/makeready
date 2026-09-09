/**
 * UI 2.0 spec index (`docs/ui2/`) — the 2.0 half of the component browser.
 *
 * The 1.0 half (lib/fs-index.mjs) indexes real Swift files under
 * iphone/MakeReady/Components/. UI 2.0 has no code yet: its components exist as
 * SPECS — rows in `design-system/registry.md` (the exhaustive component
 * universe, UI2 D6), a subset of which have a full contract doc
 * `design-system/components/C-###-<slug>.md` + a frozen Figma snapshot under
 * `components/assets/` (written by /ui2-component, D10).
 *
 * So this module is the 2.0 analogue of the fs walk: it parses those docs into
 * the same shape the browser already renders (sections → components → variants),
 * where a "variant" is a designed state from the contract's state matrix and the
 * "render" is the frozen Figma snapshot rather than a simulator capture.
 *
 * Parsing is deliberately tolerant: the state-matrix tables differ per doc
 * (3 or 4 columns, `state` / `Axis|Value` / `Unit|Axis|Values` headers), so we
 * keep the header row and treat the FIRST column(s) as the state label and the
 * LAST as its consumption status. When a doc crosses several axes into separate
 * columns the first column repeats across rows, so the label is widened with
 * the columns that tell the colliding rows apart (see `disambiguate`) — a
 * variant's label is its DB key and its URL, so it has to be unique.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { makereadyRoot } from './fs-index.mjs';

export const ui2Root = path.resolve(makereadyRoot, 'docs/ui2');
export const registryPath = path.join(ui2Root, 'design-system/registry.md');
export const contractsDir = path.join(ui2Root, 'design-system/components');
export const assetsDir = path.join(contractsDir, 'assets');
export const repoRelative = (abs) => path.relative(makereadyRoot, abs);

/** DB key for a registry row. Lowercased so it is URL- and path-safe like the
 *  fixture-backed ids ("card-study"), and prefixed so 1.0 and 2.0 comparisons
 *  can never collide. */
export const ui2ComparisonId = (id) => `ui2-${id.toLowerCase()}`;

const REGISTRY_ROW = /^\|\s*(C-\d{3})\s*\|/;
const CONTRACT_FILE = /^(C-\d{3})-(.+)\.md$/;

/** Split a markdown row on UNESCAPED pipes — a §4 type cell writes a union as
 *  `a \| b \| c`, which a naive split would tear into extra columns. */
const cells = (line) => line.split(/(?<!\\)\|/).slice(1, -1).map((c) => c.replace(/\\\|/g, '|').trim());
/** Display text: strip inline code/bold/links, keep the words. */
export const stripMd = (s) => (s ?? '')
  .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
  .replace(/[`*]/g, '')
  .trim();

// ── registry.md ────────────────────────────────────────────────────────────

/** Names carry dated rename notes: "DayChip (renamed from DayCell 2026-09-02; …)". */
function splitName(raw) {
  const text = stripMd(raw);
  const m = /^([^(]+?)\s*\((.+)\)$/.exec(text);
  return m ? { name: m[1].trim(), note: m[2].trim() } : { name: text, note: null };
}

export function parseRegistry(md) {
  const sections = [];
  let section = null;
  for (const line of md.split('\n')) {
    const heading = /^##\s+(.+?)\s*$/.exec(line);
    if (heading) {
      section = { name: stripMd(heading[1]), rows: [] };
      sections.push(section);
      continue;
    }
    if (!REGISTRY_ROW.test(line)) continue;
    const c = cells(line);
    const { name, note } = splitName(c[1]);
    section?.rows.push({
      id: c[0],
      name,
      nameNote: note,
      status: stripMd(c[2]) || 'new',
      platform: stripMd(c[3]),
      figmaRef: c[4] ?? '',
      variantsProse: c[5] ?? '',
      props: c[6] ?? '',
      definedIn: c[7] ?? '',
      consumedBy: c[8] ?? '',
      section: section?.name ?? 'Other',
    });
  }
  // Only sections that actually hold rows (Rules / Row format carry none).
  return sections.filter((s) => s.rows.length > 0);
}

// ── components/C-###-<slug>.md ─────────────────────────────────────────────

/** Split a doc into its `## ` sections, keeping raw bodies. */
function docSections(md) {
  const out = [];
  let cur = { title: null, lines: [] };
  for (const line of md.split('\n')) {
    const h = /^##\s+(.+?)\s*$/.exec(line);
    if (h) { out.push(cur); cur = { title: h[1].trim(), lines: [] }; }
    else cur.lines.push(line);
  }
  out.push(cur);
  return out.map((s) => ({ title: s.title, body: s.lines.join('\n').trim() }));
}

/** First markdown table in a body → { columns, rows: [[cell,…]] }. */
function parseTable(body) {
  const lines = body.split('\n');
  const start = lines.findIndex((l) => l.trim().startsWith('|'));
  if (start === -1) return null;
  const rows = [];
  for (let i = start; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line.startsWith('|')) break;
    if (/^\|[\s:-]+\|/.test(line)) continue; // separator row
    rows.push(cells(line));
  }
  if (rows.length < 2) return null;
  return { columns: rows[0].map(stripMd), rows: rows.slice(1) };
}

/**
 * The state matrix → browser variants. The label is the first column, joined
 * with the second when the table is an axis table ("Axis | Value | …"), which
 * is how the chart contracts express their variants.
 */
function statesFromTable(table, propRows = []) {
  if (!table) return [];
  const head0 = (table.columns[0] ?? '').toLowerCase();
  const axisShaped = table.columns.length >= 4 && (head0 === 'axis' || head0 === 'unit');
  // Node refs belong in the contract, not in a nav label: "center (`3672:9688`
  // et al.)" → "center".
  const label1 = (c) => stripMd(c).replace(/\s*\((?=[^)]*\d+:\d+)[^)]*\)\s*$/, '').trim();
  const base = table.rows.map((cellsRow, i) => {
    const label = axisShaped
      ? [cellsRow[0], cellsRow[1]].map(label1).filter((s) => s && s !== '—').join(' · ')
      : label1(cellsRow[0]);
    return label || `state ${i + 1}`;
  });
  const names = disambiguate(base, table, axisShaped ? 2 : 1);
  const slugs = uniqueSlugs(names);
  // Which matrix columns are PROPS rather than prose? Axis columns are authored
  // as the LEADING run of the table, so walk from the left and stop at the first
  // header that doesn't name a §4 prop. Matching by name anywhere would misread
  // prose: C-034's `Text` column describes what the state renders, and its §4
  // happens to declare a `text` prop.
  const propColumns = new Map();
  for (let c = 0; c < table.columns.length - 1; c += 1) {
    const header = stripMd(table.columns[c]);
    const prop = propRows.find((p) => p.name.toLowerCase() === header.toLowerCase());
    if (!prop) break;
    propColumns.set(c, prop.name);
  }

  /**
   * What this state sets. An `undesigned` row sets nothing — there is no design,
   * so listing values would be inventing the ruling its OQ is waiting for. When
   * no column names a prop the matrix is expressing the Figma axis instead, so
   * say that (`axisOnly`) rather than guessing a prop name.
   */
  const assignments = (row, i, consumptionState) => {
    if (consumptionState === 'undesigned') return [];
    if (propColumns.size) {
      const out = [];
      for (const [c, name] of propColumns) {
        const value = stripMd(row[c] ?? '');
        if (!EMPTY_CELL.test(value)) out.push({ name, value });
      }
      return out;
    }
    if (axisShaped) return [{ name: label1(row[0]), value: label1(row[1]), axisOnly: true }];
    return [{ name: stripMd(table.columns[0]), value: base[i], axisOnly: true }];
  };
  // Not every §3 row denotes a STATE. The matrix is also where a contract
  // records that a state does NOT exist, and those rows must not become
  // browsable variants — each one would otherwise get a version timeline, a
  // comment thread and a DB key for something there is nothing to render.
  // Two markers, both read off the consumption cell:
  //
  //   `n/a …`            — the row annotates the design rather than naming a
  //                        state (C-024: "state · Activity 1 / Activity 2 —
  //                        n/a (samples)", i.e. those two symbols are sample
  //                        data, not distinct behaviors).
  //   `none proposed …`  — the state is ruled OUT, not pending (C-024/026/029/
  //                        030: "loading / error / pressed — none proposed —
  //                        display-only").
  //
  // An `undesigned` row whose consumption offers a "proposed default" is the
  // opposite case and stays a state: it is a real prospective state waiting on
  // an owner ruling, and hiding it would hide the open question.
  const isNonState = (consumption) => /^(n\/a\b|none proposed\b)/i.test(consumption);

  return table.rows.map((cellsRow, i) => {
    const consumption = stripMd(cellsRow[cellsRow.length - 1] ?? '');
    // The delta column(s) describe the state itself; the consumption column
    // describes its use. "undesigned" in a DELTA means the frozen snapshot does
    // not show this state (C-042 `pressed / disabled`, C-024 `align=top`) —
    // whereas C-042 `Multiline` is designed and only its wrap bound is open, so
    // the consumption prefix has to win over a stray mention there.
    const delta = cellsRow.slice(1, -1).join(' ');
    let state = 'unknown';
    if (/^consumed/i.test(consumption)) state = 'consumed';
    else if (/designed-unconsumed/i.test(consumption)) state = 'designed-unconsumed';
    else if (/^unconsumed/i.test(consumption)) state = 'unconsumed';
    else if (/\bundesigned\b/i.test(delta)) state = 'undesigned';
    return {
      name: names[i],
      slug: slugs[i],
      propValues: assignments(cellsRow, i, state),
      consumption,
      consumptionState: state,
      nonState: isNonState(consumption),
      cells: cellsRow.map(stripMd),
    };
  });
}

const BOOL_TRUE = /^(true|yes|on|✓|✔)$/i;
const BOOL_FALSE = /^(false|no|off|✗|✘)$/i;
const EMPTY_CELL = /^(—|–|-|n\/a|na)?$/i;

/** A colliding row is told apart by a column's value, read in that column's
 *  terms: a boolean reads as its header ("showIcons" / "no showIcons"), anything
 *  else as the value itself ("Single"), and an inapplicable cell adds nothing. */
function qualifier(header, raw) {
  const v = stripMd(raw ?? '');
  if (EMPTY_CELL.test(v)) return '';
  if (BOOL_TRUE.test(v)) return header;
  if (BOOL_FALSE.test(v)) return `no ${header}`;
  return v;
}

/**
 * A state matrix has one row per COMBINATION, so a table with separate axis
 * columns repeats its first column — C-040's `style × showTitle × showIcons`
 * lists "Two icons" four times. The first column is therefore not a name.
 *
 * That collision is not cosmetic: the label is the variant's DB key (its design
 * versions and its pinned comments) and its URL, so four "Two icons" rows shared
 * one version and one comment thread. Widen only the labels that actually
 * collide, one column at a time, stopping as soon as they separate — which is
 * why the prose "Renders"/delta columns are never reached in practice.
 */
function disambiguate(labels, table, firstQualifierCol) {
  const out = labels.slice();
  const duplicateGroups = () => {
    const by = new Map();
    out.forEach((l, i) => by.set(l, [...(by.get(l) ?? []), i]));
    return [...by.values()].filter((g) => g.length > 1);
  };
  for (let c = firstQualifierCol; c < table.columns.length - 1; c += 1) {
    const groups = duplicateGroups();
    if (!groups.length) break;
    for (const group of groups) {
      const distinct = new Set(group.map((i) => stripMd(table.rows[i][c] ?? '')));
      if (distinct.size < 2) continue; // this column doesn't separate them
      for (const i of group) {
        const q = qualifier(table.columns[c], table.rows[i][c]);
        if (q) out[i] = `${out[i]} · ${q}`;
      }
    }
  }
  return numbered(out, (l, n) => `${l} (${n})`);
}

/** Last-resort uniqueness. A key that repeats silently merges two variants'
 *  history, so the invariant is enforced rather than assumed. */
function numbered(values, fmt) {
  const seen = new Map();
  return values.map((v) => {
    const n = (seen.get(v) ?? 0) + 1;
    seen.set(v, n);
    return n === 1 ? v : fmt(v, n);
  });
}

/** URL-safe variant key: lowercase, every run of punctuation/space collapsed to
 *  a single dash. "Two icons · no showIcons" → "two-icons-no-showicons", so a
 *  variant link is readable and needs no percent-encoding. */
export const variantSlug = (name) => (name ?? '')
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-+|-+$/g, '') || 'state';

/** Distinct names can still slug alike ("Has value + focused" vs "Has value
 *  focused"); the slug is a route key, so it gets the same guarantee. */
const uniqueSlugs = (names) => numbered(names.map(variantSlug), (s, n) => `${s}-${n}`);

/**
 * Open questions are a table (`| OQ | Question | Blocks? | …`) in every current
 * contract; older prose sections used a list, so fall back to list items.
 */
function parseOpenQuestions(body) {
  const table = parseTable(body);
  if (table) {
    return table.rows.map((r) => ({
      id: stripMd(r[0]),
      question: stripMd(r[1] ?? ''),
      blocks: stripMd(r[2] ?? ''),
      blocking: !/^no\b/i.test(stripMd(r[2] ?? '')),
    }));
  }
  return listItems(body).map((text) => ({
    id: /OQ-[\w-]+/.exec(text)?.[0] ?? null,
    question: text,
    blocks: '',
    blocking: false,
  }));
}

function listItems(body) {
  return body
    .split('\n')
    .filter((l) => /^\s*(?:[-*]|\d+\.)\s+/.test(l))
    .map((l) => stripMd(l.replace(/^\s*(?:[-*]|\d+\.)\s+/, '')))
    .filter(Boolean);
}

/**
 * §4 is a `| Prop | Type | Purpose |` table in most contracts and prose in the
 * rest (C-042, C-045, C-066 write it as a sentence). A prose §4 yields no rows —
 * which is also what tells the state matrix it cannot match columns by name.
 */
// Swift/TS type names a §4 Type cell may spell. A cell that separates these is
// stating a type union, not enumerating the values a prop may take.
const TYPE_WORDS = /^(string|int|double|float|bool|boolean|void|date|nil|null|any|action|callback|tab|mode|pt|glyph)$/i;

/**
 * The closed set of values a prop may take, when §4's Type cell enumerates one.
 *
 * A contract writes an enum as `default | textButtons | twoIcons` or
 * `top ⊕ / center / bottom` — bare tokens separated by `|` or `/`. Anything else
 * is a TYPE (`[Double]`, `Int?`, `Binding<String>`, `() -> Void`, `mode`) and
 * yields no options, which is the honest answer: a prop whose contract never
 * enumerates its values must not be offered a dropdown that silently omits a
 * legal one. Those contracts are fixed by a `/ui2-component` re-run that gives
 * §4 a real prop table, not by guessing here.
 */
function enumOptions(type) {
  if (!type || !/[|/]/.test(type)) return null;
  const parts = type.split(/\s*[|/]\s*/).map((p) => p.replace(/⊕/g, '').trim()).filter(Boolean);
  if (parts.length < 2) return null;
  // Every part must be a bare token, and at least one must not be a type word —
  // otherwise `String / null` would read as an enumeration of two values.
  if (!parts.every((p) => /^[A-Za-z][A-Za-z0-9 _-]*$/.test(p))) return null;
  if (parts.every((p) => TYPE_WORDS.test(p))) return null;
  return parts;
}

/**
 * A §4 Type cell that DELEGATES its value set to another registry row, rather
 * than restating it: `C-021 glyph` (single) or `[C-021 glyph]` (list).
 *
 * This is the single-source-of-truth mechanism. A component that takes an icon
 * must never re-list the glyph names — it names C-021 and the option set is
 * resolved from that contract at parse time, so adding a glyph to C-021's §3
 * updates every consumer at once and no copy can drift. The cell must be JUST
 * the reference, so an incidental `C-###` mention in prose is not mistaken for
 * a delegation.
 *
 * The second word names WHICH prop of the provider supplies the set; omitted,
 * the provider's first enumerated prop is used.
 */
function optionsRef(type) {
  const m = /^\[?\s*(C-\d{3})(?:[.\s]+([A-Za-z][A-Za-z0-9_]*))?\s*\]?$/.exec((type ?? '').trim());
  if (!m) return null;
  return { id: m[1], prop: m[2] ?? null, isList: /^\s*\[/.test(type ?? '') };
}

function parsePropRows(body) {
  const table = parseTable(body);
  if (!table || !/^prop$/i.test(table.columns[0] ?? '')) return [];
  // A row may name sibling props together ("`onExport`, `onSettings`") — they
  // share a type and a purpose, but each is its own prop at the call site.
  return table.rows.flatMap((r) => {
    const type = stripMd(r[1] ?? '');
    const purpose = stripMd(r[2] ?? '');
    return stripMd(r[0] ?? '')
      .split(',')
      .map((name) => name.trim())
      .filter(Boolean)
      // `key` is the name as a FIXTURE writes it — §4 marks owner-specified
      // props with ⊕, which is annotation, never part of the prop's name.
      .map((name) => ({
        name,
        key: name.replace(/⊕/g, '').trim(),
        type,
        purpose,
        options: enumOptions(type),
        // Resolved across contracts by `resolveOptionRefs` — the parse of one
        // file cannot see another, so this stays a reference until then.
        optionsRef: optionsRef(type),
      }));
  });
}

export function parseContract(md, { file }) {
  const titleLine = /^#\s+(.+)$/m.exec(md)?.[1] ?? '';
  const titleMatch = /^(C-\d{3})\s+(\S+)\s*(?:—\s*(.+))?$/.exec(stripMd(titleLine));
  const sections = docSections(md);
  const find = (re) => sections.find((s) => s.title && re.test(s.title));

  const matrix = find(/variant|state/i);
  const table = matrix ? parseTable(matrix.body) : null;
  const propsBody = find(/props/i)?.body ?? '';
  const propRows = parsePropRows(propsBody);

  return {
    file,
    id: titleMatch?.[1] ?? null,
    name: titleMatch?.[2] ?? null,
    summary: titleMatch?.[3] ?? '',
    statusLine: (/^Status:.*$/m.exec(md)?.[0] ?? '').trim(),
    figmaUrl: /https:\/\/www\.figma\.com\/\S+/.exec(md)?.[0]?.replace(/[.,)]+$/, '') ?? null,
    snapshotFile: /Frozen snapshot:\s*`assets\/([^`]+)`/.exec(md)?.[1] ?? null,
    stateTable: table,
    // `states` is the browsable/buildable set — real states only. The rows that
    // merely record a state's ABSENCE are kept as `matrixNotes` so nothing the
    // contract says is dropped; `stateTable` above still carries every row
    // verbatim for anything that wants the matrix as authored.
    states: statesFromTable(table, propRows).filter((s) => !s.nonState),
    matrixNotes: statesFromTable(table, propRows).filter((s) => s.nonState),
    props: propsBody,
    propRows,
    /** True when the matrix's LEADING column names a §4 prop — i.e. the states
     *  can be read as prop assignments rather than as a Figma variant axis. */
    propsAreNamed: propRows.length > 0 && propRows.some(
      (p) => p.name.toLowerCase() === stripMd(table?.columns[0] ?? '').toLowerCase(),
    ),
    composition: find(/composition/i)?.body ?? '',
    anatomy: find(/anatomy|geometry/i)?.body ?? '',
    normativeSource: find(/normative/i)?.body ?? '',
    openQuestions: parseOpenQuestions(find(/open question/i)?.body ?? ''),
    sections: sections.filter((s) => s.title),
  };
}

// ── The index (cached on the inputs' mtimes) ───────────────────────────────

async function mtime(p) {
  try { return (await fs.stat(p)).mtimeMs; } catch { return 0; }
}

/**
 * Directory mtime only moves when an entry is added/removed/renamed — editing a
 * file's CONTENT leaves it untouched. Stamping the cache on the directory alone
 * therefore served a stale parse after any contract edit (observed 2026-09-05
 * re-shaping C-019's contract). Stat the files themselves.
 */
async function dirStamp(dir, filter = () => true) {
  try {
    const names = (await fs.readdir(dir)).filter(filter).sort();
    const stamps = await Promise.all(names.map(async (n) => `${n}:${await mtime(path.join(dir, n))}`));
    return stamps.join(',');
  } catch { return ''; }
}

/**
 * Second pass over every parsed contract: resolve delegated option sets, and
 * attach the artwork that previews them.
 *
 * Runs once all contracts are in hand, because a delegation crosses files. Two
 * things happen here, and both are keyed on the PROVIDER (the row that owns the
 * value set), never on the consumer — that is what makes one inventory serve
 * every component:
 *
 *   1. `C-021 glyph` on a consumer's prop resolves to C-021's own `glyph`
 *      options. Add a glyph to C-021's §3 and every consumer gains it, with no
 *      edit anywhere else.
 *   2. Any prop with a value set gets `optionAssets` — `<provider>-<prop>-
 *      <value>.svg` in the components assets dir, checked on disk. A value with
 *      no file simply has no preview, so a half-exported set degrades to plain
 *      labels rather than broken images.
 */
export async function resolveOptionRefs(contracts) {
  let assetFiles = new Set();
  try { assetFiles = new Set(await fs.readdir(assetsDir)); } catch { /* no assets yet */ }

  for (const contract of contracts.values()) {
    for (const prop of contract.propRows ?? []) {
      let providerId = contract.id;
      let providerProp = prop.key;

      const ref = prop.optionsRef;
      if (ref) {
        const provider = contracts.get(ref.id);
        const providedBy = provider?.propRows?.find(
          (p) => (ref.prop ? p.key.toLowerCase() === ref.prop.toLowerCase() : p.options?.length),
        );
        if (providedBy?.options?.length) {
          prop.options = providedBy.options;
          prop.optionsFrom = { id: ref.id, prop: providedBy.key, isList: ref.isList };
          providerId = ref.id;
          providerProp = providedBy.key;
        } else {
          // A delegation that resolves to nothing is a spec defect worth seeing
          // rather than a silently empty dropdown.
          prop.optionsUnresolved = ref;
        }
      }

      if (!prop.options?.length) continue;
      const assets = {};
      for (const value of prop.options) {
        const file = `${providerId}-${providerProp}-${value}.svg`;
        if (assetFiles.has(file)) assets[value] = file;
      }
      if (Object.keys(assets).length) {
        prop.optionAssets = assets;
        prop.optionAssetsFrom = { id: providerId, prop: providerProp };
      }
    }
  }
}

async function sha1(p) {
  try { return crypto.createHash('sha1').update(await fs.readFile(p)).digest('hex'); }
  catch { return null; }
}

let cache = null;

/**
 * { sections: [{ name, rows: [row] }], byId: Map<C-###, row> }
 *
 * Each row carries its registry fields plus, when specced:
 *   contract      the parsed C-###-<slug>.md
 *   snapshot      { file, repoPath, sha, capturedAt } for the frozen Figma PNG
 *   variants      designed states (falls back to a single `set` state when a
 *                 contract exists without a parsable matrix)
 */
export async function buildUi2Index() {
  const stamp = [
    await mtime(registryPath),
    await dirStamp(contractsDir, (n) => n.endsWith('.md')),
    await dirStamp(assetsDir),
  ].join('|');
  if (cache?.stamp === stamp) return cache.index;

  const sections = parseRegistry(await fs.readFile(registryPath, 'utf8'));

  // Contract docs, keyed by C-### (a row without one is registry-only).
  const contracts = new Map();
  let files = [];
  try { files = await fs.readdir(contractsDir); } catch { /* no contracts yet */ }
  for (const f of files) {
    const m = CONTRACT_FILE.exec(f);
    if (!m) continue;
    const abs = path.join(contractsDir, f);
    contracts.set(m[1], parseContract(await fs.readFile(abs, 'utf8'), { file: repoRelative(abs) }));
  }

  await resolveOptionRefs(contracts);

  const byId = new Map();
  for (const section of sections) {
    for (const row of section.rows) {
      const contract = contracts.get(row.id) ?? null;
      let snapshot = null;
      if (contract?.snapshotFile) {
        const abs = path.join(assetsDir, contract.snapshotFile);
        const sha = await sha1(abs);
        if (sha) {
          snapshot = {
            file: contract.snapshotFile,
            repoPath: repoRelative(abs),
            sha,
            capturedAt: new Date(await mtime(abs)),
          };
        }
      }
      // States are the browser's variants. A specced component with no parsable
      // matrix still gets one variant so it can be viewed and commented on.
      const variants = contract
        ? (contract.states.length ? contract.states : [{ name: 'set', consumption: '', consumptionState: 'unknown', cells: [] }])
        : [];
      row.contract = contract;
      row.snapshot = snapshot;
      row.variants = variants;
      row.comparisonId = ui2ComparisonId(row.id);
      byId.set(row.id, row);
    }
  }

  const index = { sections, byId };
  cache = { stamp, index };
  return index;
}

export function ui2Counts(index) {
  let total = 0; let specced = 0; let withSnapshot = 0;
  for (const s of index.sections) {
    for (const r of s.rows) {
      total += 1;
      if (r.contract) specced += 1;
      if (r.snapshot) withSnapshot += 1;
    }
  }
  return { total, specced, withSnapshot };
}
