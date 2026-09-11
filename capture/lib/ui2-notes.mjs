/**
 * UI 2.0 notes — durable, timestamped statements of intent, one append-only
 * markdown file per target
 * (docs/features/ui2-component-notes/03-data-and-api.md §1.1).
 *
 * A note is NOT a comment. A comment is pinned to a point on one render, says
 * "this is wrong versus Figma", and is closed by /ui2-resolve. A note is
 * unpinned, never resolved, outlives every render, and is NORMATIVE build
 * input: /ui2-component-build honours it and /ui2-component-update verifies
 * against it (suite D2/D3).
 *
 * Why a module rather than parsing in the route: three independent readers —
 * the capture server, /ui2-component-build and /ui2-component-update — must
 * agree about what a note file says, and the latter two run with no server and
 * no database. So the parser is one implementation with tests, exposed both as
 * ESM exports and as a `read` CLI the commands shell out to (suite 09 §X-2):
 *
 *   node capture/lib/ui2-notes.mjs read C-052
 *   node capture/lib/ui2-notes.mjs read home-dashboard
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { makereadyRoot } from './fs-index.mjs';
import { ui2Root, contractsDir, screensDir } from './ui2-index.mjs';

export const componentNotesDir = path.join(contractsDir, 'notes');
export const screenNotesDir = path.join(screensDir, 'notes');

/** A registry id: `C-052`. Case-folded to upper so `c-052` from a URL resolves. */
const COMPONENT_ID = /^[Cc]-\d{3}$/;
/** A screen id: kebab, as the README screen table writes them. D8 of the 2.0 program
 *  makes the FILENAME the id, so the same shape is a safe filename by construction. */
const SCREEN_ID = /^[a-z0-9][a-z0-9-]*$/;

/** ISO 8601 UTC instant with milliseconds — a note's id, its sort key, and what
 *  D3's "newer" means. Anchored: a `##` heading that is not exactly this is body
 *  text, not a note boundary. */
const NOTE_AT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

/** `@C-052` / `@home-dashboard`. Resolution against the registry happens in the
 *  server; here we only extract candidates. The leading char must not be part of
 *  a word, so an email address (`a@b.com`) yields nothing. */
const MENTION = /(^|[^A-Za-z0-9_@/-])@([A-Za-z0-9][A-Za-z0-9-]*)/g;

export function noteKind(target) {
  if (COMPONENT_ID.test(target ?? '')) return 'component';
  if (SCREEN_ID.test(target ?? '')) return 'screen';
  return null;
}

/**
 * Target → the file that holds its notes.
 *
 * Throws on anything that is neither shape. That is the path-traversal guard as
 * well as the typo guard: the two id patterns admit no `/`, no `.` and no `..`,
 * so a target can never address a file outside its notes directory.
 */
export function notesPath(target) {
  const kind = noteKind(target);
  if (kind === 'component') return path.join(componentNotesDir, `${target.toUpperCase()}.md`);
  if (kind === 'screen') return path.join(screenNotesDir, `${target}.md`);
  throw new Error(`not a note target: ${JSON.stringify(target)}`);
}

/**
 * The file's title + preamble, written once when the first note is appended.
 *
 * `title` is the target's display name when the caller has one (the route has the
 * registry index; the CLI and the tests do not), so the file reads
 * "# C-052 DayChip — notes" per 03 §1.1 rather than a bare id. It is a HEADING,
 * never parsed back — a rename must not rot a note file, which is why every
 * reference inside a note is a canonical token instead (D10).
 */
function notesPreamble(target, title) {
  const id = noteKind(target) === 'component' ? target.toUpperCase() : target;
  return `# ${title ? `${id} ${title}` : id} — notes

Append-only, oldest first. Newer notes supersede older ones where they conflict
(docs/features/ui2-component-notes/01-architecture.md D3). Written by the capture
browser's Component tab; hand-edit only to fix a typo.
`;
}

/** A note block, exactly as it is appended. The writer and the parser share this
 *  one function so they cannot disagree about the format. */
export function formatNote(at, body) {
  return `\n## ${at}\n\n${String(body).trim()}\n`;
}

/**
 * Markdown → notes, in FILE order (oldest first; the UI reverses for display).
 *
 * Splits only on a `## ` heading whose text parses as an ISO instant. A `##` that
 * does not is body text — a note may legitimately contain markdown-looking lines,
 * and swallowing one as a boundary would silently split a note in two.
 */
export function parseNotes(md) {
  const notes = [];
  let cur = null;
  for (const line of String(md ?? '').split('\n')) {
    const h = /^##\s+(.+?)\s*$/.exec(line);
    if (h && NOTE_AT.test(h[1])) {
      if (cur) notes.push(cur);
      cur = { id: h[1], at: h[1], body: [] };
      continue;
    }
    if (cur) cur.body.push(line);
  }
  if (cur) notes.push(cur);
  // Blank lines INSIDE a note are preserved; only the leading/trailing ones the
  // block format adds are trimmed.
  return notes.map((n) => ({ id: n.id, at: n.at, body: n.body.join('\n').trim() }));
}

/** Every `@token` in a body, with its id. Unresolvable ones stay literal text —
 *  the server drops them from `refs` after checking the mention index. */
export function extractMentions(body) {
  const out = [];
  const seen = new Set();
  for (const m of String(body ?? '').matchAll(MENTION)) {
    const id = m[2];
    const token = `@${id}`;
    if (seen.has(token)) continue;
    seen.add(token);
    out.push({ token, id });
  }
  return out;
}

/**
 * Read a target's notes. Never throws on content: a file that does not match the
 * format yields zero notes plus a `parseError`, which the UI shows as a banner
 * (suite 09 §G-13). Rendering a corrupt file as "no notes yet" would lose the
 * owner's words silently, which is the one outcome this store exists to prevent.
 */
export async function readNotes(target) {
  const file = notesPath(target);
  const rel = path.relative(makereadyRoot, file);
  let raw;
  try {
    raw = await fs.readFile(file, 'utf-8');
  } catch {
    return { exists: false, file: rel, notes: [], parseError: null };
  }
  const notes = parseNotes(raw);
  // A non-empty file that yielded nothing is the detectable corruption case: the
  // body is there, the headings are not.
  const parseError = notes.length === 0 && raw.trim().length > 0
    ? 'no note headings found — expected `## <ISO instant>` sections (03 §1.1)'
    : null;
  return { exists: true, file: rel, notes, parseError };
}

/**
 * Append one note and return it.
 *
 * Two properties worth the extra code:
 *   - **Distinct ids.** `id` is both the identity and D3's precedence key, so two
 *     notes may never share one. On a collision with the file's last heading the
 *     new note advances 1ms rather than overwriting or sorting ambiguously.
 *   - **Atomic write.** Appending is a read-modify-write of a repo file the owner
 *     may have open; temp-then-rename means a crash mid-write cannot leave half a
 *     note behind.
 */
export async function appendNote(target, body, now = new Date(), title = null) {
  const text = String(body ?? '').trim();
  if (!text) throw new Error('note body is empty');
  const file = notesPath(target);
  await fs.mkdir(path.dirname(file), { recursive: true });

  let existing = '';
  try { existing = await fs.readFile(file, 'utf-8'); } catch { /* first note */ }

  const prior = parseNotes(existing);
  let at = new Date(now).toISOString();
  const last = prior[prior.length - 1]?.id;
  if (last && at <= last) at = new Date(new Date(last).getTime() + 1).toISOString();

  const head = existing || notesPreamble(target, title);
  const next = `${head.replace(/\s*$/, '\n')}${formatNote(at, text)}`;

  const tmp = `${file}.${process.pid}.tmp`;
  await fs.writeFile(tmp, next, 'utf-8');
  await fs.rename(tmp, file);

  return { id: at, at, body: text };
}

/** `docs/ui2/...` relative path, for a response that names the file on disk. */
export const notesRepoPath = (target) => path.relative(makereadyRoot, notesPath(target));

/** Which targets have a note file, as one readdir per directory rather than a
 *  stat per registry row (suite 09 §G-15). The directories' own README.md is not
 *  a note file. */
export async function targetsWithNotes() {
  const read = async (dir) => {
    try { return await fs.readdir(dir); } catch { return []; }
  };
  const ids = new Set();
  for (const f of await read(componentNotesDir)) {
    if (/^C-\d{3}\.md$/i.test(f)) ids.add(f.replace(/\.md$/i, '').toUpperCase());
  }
  for (const f of await read(screenNotesDir)) {
    if (f.endsWith('.md') && f !== 'README.md') ids.add(f.replace(/\.md$/, ''));
  }
  return ids;
}

export { ui2Root };

// ── CLI ────────────────────────────────────────────────────────────────────
//
// `/ui2-component-build` and `/ui2-component-update` load notes by running this,
// never by reading the markdown by eye — that is what makes "one parser" true in
// practice rather than only in intent (suite 09 §X-2).
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  const [cmd, target] = process.argv.slice(2);
  if (cmd !== 'read' || !target) {
    console.error('usage: node capture/lib/ui2-notes.mjs read <C-### | screen-id>');
    process.exit(1);
  }
  if (!noteKind(target)) {
    console.error(`not a note target: ${target}`);
    process.exit(2);
  }
  console.log(JSON.stringify(await readNotes(target), null, 2));
}
