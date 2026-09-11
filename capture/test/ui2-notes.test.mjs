// Unit tests for the UI 2.0 notes store (capture/lib/ui2-notes.mjs).
//
// The note FILE is the contract three readers share — the capture server, and
// both /ui2-component commands via the `read` CLI — so the format is pinned here
// rather than trusted to any one caller
// (docs/features/ui2-component-notes/08-testing.md §2, tests N-1…N-8).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  parseNotes, formatNote, notesPath, extractMentions, readNotes, appendNote,
  componentNotesDir, targetsWithNotes,
} from '../lib/ui2-notes.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

/** A target id no real registry row will ever use, so the tests write into the
 *  real notes directory without colliding with a note the owner wrote. Each test
 *  that writes cleans up after itself. */
const SCRATCH = 'C-999';
const scratchFile = path.join(componentNotesDir, 'C-999.md');
const cleanup = async () => { try { await fs.unlink(scratchFile); } catch { /* none */ } };

test('N-1: parseNotes returns notes oldest-first with exact bodies, blank lines preserved', () => {
  const md = `# C-052 DayChip — notes

preamble prose that is not a note

## 2026-09-01T10:00:00.000Z

first note

with a blank line inside

## 2026-09-02T11:30:00.500Z

second note
`;
  const notes = parseNotes(md);
  assert.equal(notes.length, 2);
  assert.equal(notes[0].id, '2026-09-01T10:00:00.000Z');
  assert.equal(notes[0].body, 'first note\n\nwith a blank line inside');
  assert.equal(notes[1].body, 'second note');
});

test('N-2: a `##` heading that is not an ISO instant is body text, not a boundary', () => {
  const md = `# C-052 — notes

## 2026-09-01T10:00:00.000Z

the rail pins its active chip

## Not a timestamp

and this line belongs to the same note
`;
  const notes = parseNotes(md);
  assert.equal(notes.length, 1);
  assert.match(notes[0].body, /## Not a timestamp/);
  assert.match(notes[0].body, /belongs to the same note/);
});

test('N-3: formatNote output round-trips through parseNotes unchanged', () => {
  const at = '2026-09-03T08:15:00.250Z';
  const body = 'line one\n\nline three with @C-021 in it';
  const notes = parseNotes(`# X — notes\n${formatNote(at, body)}`);
  assert.equal(notes.length, 1);
  assert.equal(notes[0].id, at);
  assert.equal(notes[0].body, body);
});

test('N-4: appendNote on a missing file creates title + preamble + one note', async () => {
  await cleanup();
  const note = await appendNote(SCRATCH, '  the first thing  ', new Date('2026-09-04T09:00:00.000Z'), 'Scratch');
  const raw = await fs.readFile(scratchFile, 'utf-8');

  assert.equal(note.at, '2026-09-04T09:00:00.000Z');
  assert.equal(note.body, 'the first thing');
  assert.match(raw, /^# C-999 Scratch — notes\n/);
  assert.match(raw, /Append-only, oldest first/);
  assert.match(raw, /\n## 2026-09-04T09:00:00\.000Z\n\nthe first thing\n$/);
  await cleanup();
});

test('N-5: appendNote twice in the same millisecond produces two distinct ids 1ms apart', async () => {
  await cleanup();
  const when = new Date('2026-09-04T09:00:00.000Z');
  const a = await appendNote(SCRATCH, 'first', when);
  const b = await appendNote(SCRATCH, 'second', when);

  assert.notEqual(a.id, b.id);
  assert.equal(new Date(b.id) - new Date(a.id), 1);
  const notes = parseNotes(await fs.readFile(scratchFile, 'utf-8'));
  assert.deepEqual(notes.map((n) => n.body), ['first', 'second']); // file order = oldest first
  await cleanup();
});

test('N-6: notesPath maps both id shapes and throws on anything else', () => {
  assert.match(notesPath('C-052'), /docs\/ui2\/design-system\/components\/notes\/C-052\.md$/);
  assert.match(notesPath('c-052'), /notes\/C-052\.md$/); // case-folded
  assert.match(notesPath('home-dashboard'), /docs\/ui2\/screens\/notes\/home-dashboard\.md$/);
  // The traversal guard is the id shape itself: neither pattern admits / or ..
  assert.throws(() => notesPath('nonsense/../etc'), /not a note target/);
  assert.throws(() => notesPath('../../etc/passwd'), /not a note target/);
  assert.throws(() => notesPath(''), /not a note target/);
  assert.throws(() => notesPath(undefined), /not a note target/);
});

test('N-7: extractMentions finds both id shapes and ignores non-mentions', () => {
  const found = extractMentions('see @C-052 and @home-dashboard, mail a@b.com, trailing @');
  assert.deepEqual(found.map((m) => m.id), ['C-052', 'home-dashboard']);
  assert.deepEqual(extractMentions('@C-052 twice @C-052').map((m) => m.token), ['@C-052']);
  assert.deepEqual(extractMentions(''), []);
});

test('N-8: a corrupt file yields notes: [] plus a parseError rather than throwing', async () => {
  await cleanup();
  await fs.mkdir(componentNotesDir, { recursive: true });
  await fs.writeFile(scratchFile, 'this file has no headings at all\n', 'utf-8');

  const res = await readNotes(SCRATCH);
  assert.equal(res.exists, true);
  assert.deepEqual(res.notes, []);
  assert.match(res.parseError, /no note headings/);
  await cleanup();
});

test('N-8b: an absent file is exists:false with no error — not a failure', async () => {
  await cleanup();
  const res = await readNotes(SCRATCH);
  assert.equal(res.exists, false);
  assert.equal(res.parseError, null);
  assert.deepEqual(res.notes, []);
});

test('R-9: the read CLI prints the same shape the module returns, with no server', async () => {
  await cleanup();
  await appendNote(SCRATCH, 'cli check', new Date('2026-09-05T12:00:00.000Z'));

  const out = execFileSync('node', [path.join(here, '../lib/ui2-notes.mjs'), 'read', SCRATCH], { encoding: 'utf-8' });
  const parsed = JSON.parse(out);
  const direct = await readNotes(SCRATCH);
  assert.deepEqual(parsed, JSON.parse(JSON.stringify(direct)));
  assert.equal(parsed.notes[0].body, 'cli check');
  await cleanup();
});

test('targetsWithNotes is one readdir per directory and skips the README', async () => {
  await cleanup();
  await appendNote(SCRATCH, 'present', new Date('2026-09-06T12:00:00.000Z'));
  const ids = await targetsWithNotes();
  assert.ok(ids.has('C-999'));
  assert.ok(!ids.has('README'));
  await cleanup();
});
