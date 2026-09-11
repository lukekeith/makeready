/**
 * Smallest annotated rect containing a point — the shared hit test for both
 * things a UI 2.0 render gets pointed at: a comment target, and (on a screen) a
 * component selection.
 *
 * Extracted from Ui2Layout's inline callback so it can be tested without a DOM
 * and so the screen path can read the `ref` the component maps carry
 * (docs/features/ui2-component-notes/07-capture.md §4.1). Its RULE is unchanged.
 *
 * Ties are real and common: a slot holding exactly one control has that control's
 * rect exactly, and the useful label is the inner one. The tie rule is **the entry
 * that comes FIRST in the map wins**, which a stable sort preserves — so both
 * producers emit the innermost of an equal-area pair first. The iOS harness does
 * it naturally (`transformAnchorPreference` appends the ancestor to its subtree's
 * value); the screen backfill sorts for it explicitly, because document order puts
 * a parent frame BEFORE its identically-sized child.
 *
 * (The suite's D8 originally said the LATER entry wins. Corrected 2026-09-10 in
 * build phase 4: the shipped behaviour this reuses is first-wins, and only the
 * harness's ordering made that look like "later".)
 *
 * @param {Array|null} elements  `{ x, y, w, h, name, ref? }` in fractions of the render
 * @param {number} fx  pointer x as a fraction of the render
 * @param {number} fy  pointer y as a fraction of the render
 * @returns {{ ref: string|null, label: string, path: string[], selector: string,
 *             rect: { x: number, y: number, w: number, h: number } } | null}
 */
export function hitTest(elements, fx, fy) {
  if (!elements?.length) return null;
  const hits = elements.filter((e) => fx >= e.x && fx <= e.x + e.w && fy >= e.y && fy <= e.y + e.h);
  if (!hits.length) return null;
  const inward = [...hits].sort((a, b) => (a.w * a.h) - (b.w * b.h)); // deepest first
  const el = inward[0];
  const path = [...inward].reverse().map((e) => e.name);              // outermost → innermost
  return {
    // Screen maps resolve each instance to a registry row; the iOS harness's maps
    // have no need for one, and null is how the caller tells them apart.
    ref: el.ref ?? null,
    label: el.name,
    path,
    selector: path.join(' › '),
    rect: { x: el.x, y: el.y, w: el.w, h: el.h },
  };
}

/**
 * Was this press a click, or the end of a pan?
 *
 * The 2.0 render pane pans on drag whenever comment mode is off, which is exactly
 * when component selection is live — so the two share a gesture and the only
 * thing separating them is movement. 4px is the threshold: enough to absorb the
 * shake of a physical click, small enough that a deliberate drag never selects
 * (07 §4.2).
 */
export function isClick(down, up, threshold = 4) {
  if (!down || !up) return false;
  return Math.abs(up.x - down.x) <= threshold && Math.abs(up.y - down.y) <= threshold;
}
