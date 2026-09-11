/**
 * `@` mention helpers for the note composer (suite 07 §5.4).
 *
 * Pure text functions, kept out of the component so the matching and the caret
 * arithmetic can be tested without a DOM — they are the parts that silently ruin
 * a note when they are subtly wrong.
 */

/**
 * Filter the mention index for a typeahead query.
 *
 * Matches on id AND name, because both are how a person refers to a component:
 * `@day` should find `C-052 DayChip` and `@C-05` should find the C-05x block.
 * Ranking puts an id-prefix match first (someone typing `C-0…` knows the id they
 * want), then a name-prefix match, then anything containing the query — inside
 * each tier the index's own order (components then screens, by id) survives.
 */
export function filterMentions(items, query) {
  const q = String(query ?? '').trim().toLowerCase();
  if (!q) return items ?? [];
  const tier = (item) => {
    const id = item.id.toLowerCase();
    const name = (item.name ?? '').toLowerCase();
    if (id.startsWith(q)) return 0;
    if (name.startsWith(q)) return 1;
    if (id.includes(q) || name.includes(q)) return 2;
    return 3;
  };
  return (items ?? [])
    .map((item, i) => ({ item, i, t: tier(item) }))
    .filter((e) => e.t < 3)
    .sort((a, b) => a.t - b.t || a.i - b.i)
    .map((e) => e.item);
}

/**
 * The active `@query` at the caret, or null.
 *
 * A mention token starts at a word boundary — `@` after a letter is an email
 * address, not a mention — and ends at whitespace. Returning the token's start
 * index is what lets a commit replace exactly the typed query and nothing else.
 */
export function activeMention(text, caret) {
  const s = String(text ?? '');
  const pos = Math.max(0, Math.min(caret ?? s.length, s.length));
  const before = s.slice(0, pos);
  const at = before.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0 && /[A-Za-z0-9_@/-]/.test(before[at - 1])) return null;  // a@b.com
  const query = before.slice(at + 1);
  if (/\s/.test(query)) return null;                                   // closed by whitespace
  if (!/^[A-Za-z0-9-]*$/.test(query)) return null;
  return { start: at, query };
}

/**
 * Replace the active `@query` with a canonical token plus one trailing space.
 *
 * The canonical token is what gets stored (D10), so a later rename never rots the
 * note: the renderer resolves the token to the CURRENT display name at read time.
 */
export function commitToken(text, caret, token) {
  const active = activeMention(text, caret);
  if (!active) return { text, caret };
  const s = String(text ?? '');
  const pos = Math.max(0, Math.min(caret ?? s.length, s.length));
  const insert = `${token} `;
  const next = s.slice(0, active.start) + insert + s.slice(pos);
  return { text: next, caret: active.start + insert.length };
}
