// Unit tests for the note composer's typeahead placement
// (capture/src/lib/caret-position.js).
//
// Only the pure half is tested here: `caretCoordinates` needs a real layout
// engine, but `placeTypeahead` — which side to open on, how tall to allow, how
// far to shift — is the part that decides whether the popup lands on top of the
// text being typed, which is exactly the bug it was written to fix.
import test from 'node:test';
import assert from 'node:assert/strict';
import { placeTypeahead } from '../src/lib/caret-position.js';

/** A caret one line tall at (left, top). */
const caretAt = (top, left = 0) => ({ top, left, height: 18 });
const PAD = { width: 320, height: 480 };

test('opens BELOW the caret line — the whole point is not covering what is typed', () => {
  const p = placeTypeahead(caretAt(12), PAD);
  assert.equal(p.top, 12 + 18 + 4);
  assert.equal(p.bottom, 'auto');
});

test('caps its height to the room below rather than running off the pad', () => {
  // 480 - (250 + 18) - 4 - 8 = 200px of room: usable, but under the 220 default.
  const p = placeTypeahead(caretAt(250), PAD);
  assert.equal(p.bottom, 'auto');
  assert.equal(p.maxHeight, 200);
});

test('a cramped gap below loses to a roomy one above', () => {
  // 50px below vs 388 above — opening below would be a two-row menu.
  const p = placeTypeahead(caretAt(400), PAD);
  assert.equal(p.top, 'auto');
  assert.equal(p.maxHeight, 220);
});

test('flips ABOVE only when the room below is both short and worse than above', () => {
  const p = placeTypeahead(caretAt(440), PAD);
  assert.equal(p.top, 'auto');
  assert.equal(p.bottom, 480 - 440 + 4);
  assert.equal(p.maxHeight, 220);           // 428 of room, capped at the default
});

test('stays below at the top of the pad even with little room, since above has less', () => {
  const p = placeTypeahead(caretAt(0), { width: 320, height: 130 });
  assert.equal(p.bottom, 'auto');
  assert.equal(p.top, 22);
  assert.equal(p.maxHeight, 100);
});

test('never runs past the right edge, and never goes negative', () => {
  assert.equal(placeTypeahead(caretAt(12, 300), PAD).left, 320 - 220 - 8);
  assert.equal(placeTypeahead(caretAt(12, 40), PAD).left, 40);
  // A pad narrower than the menu clamps to the left edge rather than off it.
  assert.equal(placeTypeahead(caretAt(12, 40), { width: 180, height: 480 }).left, 0);
});
