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

/**
 * The selected SCREEN id — `?s=<screen-id>`, the mirror of `?c=` and carried by
 * the same `withSearch` rule.
 *
 * `?c=` lives on a screen page and names a component drawn on it; `?s=` lives on
 * a COMPONENT page and names a screen that renders it. The two never appear
 * together, because a page is one or the other.
 *
 * Validated by SHAPE only (a kebab word, never a `C-###`, since the two id spaces
 * are disjoint by construction — see `kindOf`). Whether the screen exists is the
 * fetch's answer, not the URL's: the pane renders "unknown screen" for a stale
 * link exactly as the component pane does for a retired ref.
 */
export function selectedScreenRef(search) {
  const s = new URLSearchParams(search ?? '').get('s');
  if (!s || /^C-\d{3}$/i.test(s)) return null;
  return /^[a-z0-9][a-z0-9-]*$/i.test(s) ? s.toLowerCase() : null;
}
