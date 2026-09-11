// Pure helpers behind screen element targeting: the hit test and the URL rules
// (docs/features/ui2-component-notes/08-testing.md §2, tests H-1…H-3, H-6…H-8).
//
// These run without a DOM because they are the parts that must be RIGHT rather
// than merely look right: a hit test that picks the wrong rect silently attributes
// a comment to the wrong component, and a URL helper that drops a query silently
// loses a selection someone shared.
import test from 'node:test';
import assert from 'node:assert/strict';
import { hitTest } from '../src/lib/hit-test.js';
import { withSearch, selectedRef } from '../src/lib/ui2-url.js';

/** A row with a chip inside it, plus a card that overlaps neither. */
const ROW = { ref: 'C-037', name: 'ListResultRow', x: 0.0, y: 0.10, w: 1.0, h: 0.10 };
const CHIP = { ref: 'C-043', name: 'MetaChip', x: 0.60, y: 0.13, w: 0.20, h: 0.04 };
const CARD = { ref: 'C-023', name: 'KpiCard', x: 0.0, y: 0.40, w: 0.44, h: 0.10 };
const MAP = [ROW, CHIP, CARD];

test('H-1: the smallest containing rect wins — a chip inside a row selects the chip', () => {
  const hit = hitTest(MAP, 0.65, 0.15);
  assert.equal(hit.ref, 'C-043');
  assert.equal(hit.label, 'MetaChip');
  // The path reads outermost → innermost, which is what a comment records.
  assert.deepEqual(hit.path, ['ListResultRow', 'MetaChip']);
  assert.equal(hit.selector, 'ListResultRow › MetaChip');
  assert.deepEqual(hit.rect, { x: 0.60, y: 0.13, w: 0.20, h: 0.04 });

  // Inside the row but outside the chip: the row.
  assert.equal(hitTest(MAP, 0.10, 0.15).ref, 'C-037');
});

test('H-2: an equal-area tie resolves to the entry that comes FIRST', () => {
  const slot = { ref: 'C-040', name: 'Leading', x: 0, y: 0, w: 0.1, h: 0.1 };
  const inner = { ref: 'C-021', name: 'GlyphButton', x: 0, y: 0, w: 0.1, h: 0.1 };
  // Both producers emit the innermost of an equal-area pair first, so first-wins
  // IS innermost-wins. The suite said "later wins" until this test was written
  // against the shipped behaviour (09 §G-19).
  assert.equal(hitTest([inner, slot], 0.05, 0.05).label, 'GlyphButton');
  assert.equal(hitTest([slot, inner], 0.05, 0.05).label, 'Leading');
});

test('H-3: an empty, null or missed map returns null and never throws', () => {
  assert.equal(hitTest(null, 0.5, 0.5), null);
  assert.equal(hitTest([], 0.5, 0.5), null);
  assert.equal(hitTest(undefined, 0.5, 0.5), null);
  assert.equal(hitTest(MAP, 0.99, 0.99), null);   // outside every rect
  assert.equal(hitTest(MAP, -0.2, 0.15), null);   // outside the render entirely
});

test('H-8: `ref` comes back for screen maps and is null for harness maps', () => {
  assert.equal(hitTest(MAP, 0.2, 0.45).ref, 'C-023');
  // The iOS capture harness emits parts with names and no registry ids.
  const harness = [{ name: 'Leading', x: 0, y: 0, w: 1, h: 1 }];
  const hit = hitTest(harness, 0.5, 0.5);
  assert.equal(hit.ref, null);
  assert.equal(hit.label, 'Leading');
});

test('H-6: withSearch carries the selection across state navigation', () => {
  assert.equal(withSearch('/components/2.0/home-dashboard/default', '?c=C-023'),
    '/components/2.0/home-dashboard/default?c=C-023');
  // The canonicalising replace and the state click both go through this, so a
  // pasted `/components/2.0/home-dashboard?c=C-023` keeps its selection.
  assert.equal(withSearch('/components/2.0/invite-home/linked', '?c=C-034&x=1'),
    '/components/2.0/invite-home/linked?c=C-034&x=1');
  assert.equal(withSearch('/components/2.0/home-dashboard/default', 'c=C-023'),
    '/components/2.0/home-dashboard/default?c=C-023');
  // Navigating to a different screen passes no search: the selection is dropped.
  assert.equal(withSearch('/components/2.0/groups-home', ''), '/components/2.0/groups-home');
  assert.equal(withSearch('/components/2.0/groups-home', '?'), '/components/2.0/groups-home');
  assert.equal(withSearch('/components/2.0/groups-home', null), '/components/2.0/groups-home');
});

test('selectedRef reads a valid id and treats anything else as no selection', () => {
  assert.equal(selectedRef('?c=C-037'), 'C-037');
  assert.equal(selectedRef('?c=c-037'), 'C-037');      // case-folded
  assert.equal(selectedRef('?x=1&c=C-052&y=2'), 'C-052');
  assert.equal(selectedRef('?c=nonsense'), null);
  assert.equal(selectedRef('?c='), null);
  assert.equal(selectedRef(''), null);
  assert.equal(selectedRef(null), null);
});

test('H-7: click-vs-drag discrimination is a pure predicate', async () => {
  // The ZoomPane rule, isolated: a press that moved more than 4px in either axis
  // was a pan, not a click, so it must not select (07 §4.2).
  const { isClick } = await import('../src/lib/hit-test.js');
  assert.equal(isClick({ x: 100, y: 100 }, { x: 102, y: 103 }), true);
  assert.equal(isClick({ x: 100, y: 100 }, { x: 104, y: 104 }), true);   // exactly 4px
  assert.equal(isClick({ x: 100, y: 100 }, { x: 105, y: 100 }), false);  // 5px across
  assert.equal(isClick({ x: 100, y: 100 }, { x: 100, y: 120 }), false);  // a vertical pan
  assert.equal(isClick(null, { x: 100, y: 100 }), false);
});

// ── Mention helpers (08 §2, tests H-4, H-5) ───────────────────────────────────

const { filterMentions, activeMention, commitToken } = await import('../src/lib/mentions.js');

const INDEX = [
  { kind: 'component', id: 'C-019', name: 'TopNav' },
  { kind: 'component', id: 'C-052', name: 'DayChip' },
  { kind: 'component', id: 'C-025', name: 'DayActivityCard' },
  { kind: 'screen', id: 'home-dashboard', name: 'Home (leader dashboard)' },
  { kind: 'screen', id: 'groups-home', name: 'Groups' },
];

test('H-4: the typeahead filter matches id and name, case-insensitively, id-prefix first', () => {
  // by name
  assert.deepEqual(filterMentions(INDEX, 'day').map((i) => i.id), ['C-052', 'C-025']);
  assert.deepEqual(filterMentions(INDEX, 'DAY').map((i) => i.id), ['C-052', 'C-025']);
  // by id prefix — the C-05x block, which is C-052 and NOT C-025 (a C-02x row)
  assert.deepEqual(filterMentions(INDEX, 'c-05').map((i) => i.id), ['C-052']);
  // screens too
  assert.deepEqual(filterMentions(INDEX, 'home').map((i) => i.id), ['home-dashboard', 'groups-home']);
  // an id-prefix hit outranks a name hit
  assert.equal(filterMentions(INDEX, 'c-019')[0].id, 'C-019');
  // no query returns everything; no match returns nothing
  assert.equal(filterMentions(INDEX, '').length, 5);
  assert.deepEqual(filterMentions(INDEX, 'zzz'), []);
});

test('activeMention finds the token being typed and ignores everything else', () => {
  assert.deepEqual(activeMention('pins like @day', 14), { start: 10, query: 'day' });
  assert.deepEqual(activeMention('@', 1), { start: 0, query: '' });
  // an email address is not a mention
  assert.equal(activeMention('mail a@b', 8), null);
  // whitespace closes the token
  assert.equal(activeMention('@day chip', 9), null);
  // the caret has moved out of the token
  assert.deepEqual(activeMention('@day and more', 4), { start: 0, query: 'day' });
  assert.equal(activeMention('no mention here', 15), null);
});

test('H-5: committing a token replaces only the active query', () => {
  const before = 'the rail pins like @day';
  const { text, caret } = commitToken(before, before.length, '@C-052');
  assert.equal(text, 'the rail pins like @C-052 ');
  assert.equal(caret, text.length);

  // surrounding text on BOTH sides survives, and the caret lands after the token
  const mid = 'see @day for the rail';
  const r = commitToken(mid, 8, '@C-052');
  assert.equal(r.text, 'see @C-052  for the rail');
  assert.equal(r.caret, 11);

  // nothing to commit leaves the text alone
  assert.deepEqual(commitToken('plain text', 5, '@C-052'), { text: 'plain text', caret: 5 });
});
