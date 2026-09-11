/**
 * URL helpers for the UI 2.0 browser.
 *
 * `?c=<C-###>` carries the selected component (suite D9), and the layout
 * navigates for its own reasons — landing on the first state, canonicalising a
 * state slug, following a state click. Every one of those built a bare path, so
 * the selection was dropped before anything could read it: even
 * `/components/2.0/home-dashboard?c=C-023`, the exact form someone pastes, was
 * rewritten to `…/default` on mount (suite 09 §G-9).
 *
 * One helper, one rule: navigation WITHIN a screen carries the query; navigation
 * to a different screen or component does not, because a selection is meaningless
 * somewhere else.
 */
export function withSearch(path, search) {
  if (!search) return path;
  const q = String(search).startsWith('?') ? String(search) : `?${search}`;
  return q === '?' ? path : `${path}${q}`;
}

/** The selected component id in a location's search string, or null. Unknown or
 *  malformed values are treated as absent rather than rendered as a selection. */
export function selectedRef(search) {
  const c = new URLSearchParams(search ?? '').get('c');
  return c && /^C-\d{3}$/i.test(c) ? c.toUpperCase() : null;
}
