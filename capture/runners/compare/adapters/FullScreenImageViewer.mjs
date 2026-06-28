/**
 * Adapter: FullScreenImageViewer (component comparison).
 *
 * Projects one canonical full-screen-image-viewer description into:
 *   - toClient → card/full-screen-image-viewer/full-screen-image-viewer.vue via
 *     the ComponentCapture island
 *   - toIphone → component.FullScreenImageViewer ViewRegistry case
 *     (Components/Display/FullScreenImageViewer.swift)
 *
 * Image handling: in the isolated /compare snapshot the iPhone viewer is fed a
 * stand-in `photo.fill` SF Symbol (ViewRegistry can't load a remote fixture URL
 * synchronously). That template symbol renders near-black over Color.black, so the
 * reference is effectively a pure-black canvas with only the close button visible.
 * To match it exactly the client side OMITS the imageURL — the Vue twin then
 * renders the same black canvas + close button (same pattern as Avatar, where the
 * iPhone snapshot shows the fallback rather than the photo). The iPhone side still
 * receives the full shared block unchanged (its snapshot does the placeholder
 * itself).
 *
 * The close glyph is semantic on iOS (xmark.circle.fill SF Symbol); the web maps
 * it to an inline SVG here — a filled circle with the X knocked out (fill-rule
 * evenodd) so the black canvas shows through, exactly like the symbol.
 */

// iOS xmark.circle.fill — filled circle with the X cut out (evenodd), so the
// background shows through the strokes. Colored via currentColor (CSS sets it to
// white@0.8 to match foregroundColor(.white.opacity(0.8))).
// The visible circle nearly fills the 32-unit box (iOS renders it at ~31.7pt for
// a 32pt font), so radius ≈ 15.8. The X spans the middle of the circle.
const XMARK_CIRCLE_FILL_SVG =
  '<svg viewBox="0 0 32 32" aria-hidden="true">' +
  '<path fill="currentColor" fill-rule="evenodd" d="' +
  'M16 0.2a15.8 15.8 0 1 0 0 31.6 15.8 15.8 0 0 0 0-31.6z' +
  'M11.2 9.7 16 14.5l4.8-4.8 1.5 1.5L17.5 16l4.8 4.8-1.5 1.5L16 17.5l-4.8 4.8-1.5-1.5L14.5 16 9.7 11.2z' +
  '"/></svg>';

export default {
  toClient(/* shared */) {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (full-bleed 440×480pt canvas).
      clip: '.capture-wrap',
      data: {
        component: 'FullScreenImageViewer',
        componentProps: {
          // Omit imageURL — the iPhone snapshot shows the invisible placeholder,
          // not the photo, so the twin renders a pure-black canvas to match.
          closeIcon: XMARK_CIRCLE_FILL_SVG,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.FullScreenImageViewer',
      state: { component: shared },
    };
  },
};
