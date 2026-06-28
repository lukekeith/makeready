/**
 * Adapter: SkeletonEnrollmentCard (component comparison).
 *
 * Projects one canonical skeleton-enrollment description into:
 *   - toClient → skeleton-enrollment-card.vue via the ComponentCapture island
 *   - toIphone → SkeletonEnrollmentCard.swift via the
 *     component.SkeletonEnrollmentCard ViewRegistry case
 *
 * The `shared` block is the component's prop bag verbatim
 * (programName / programImageUrl / programDays). The iPhone side forwards it
 * unchanged; the web side maps it onto the Vue props and supplies the book.fill
 * placeholder glyph as inline SVG (the iOS SF Symbol). The program image URL is
 * deliberately forwarded only when present — in the isolated snapshot iOS's
 * AsyncImage never resolves it, so both sides render the book placeholder.
 */

// SF Symbol "book.fill" → inline SVG (open filled book), matching the iOS glyph.
// Two symmetric page shapes meeting at a center-spine gap so it reads as an open
// book rather than a single solid blob.
const BOOK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor">' +
  '<path d="M11 6.6C9.4 5.4 7.3 4.7 5 4.7c-.95 0-1.9.12-2.8.36A1.5 1.5 0 0 0 1 6.5v10.8c0 .98.92 1.68 1.86 1.43A9.6 9.6 0 0 1 5 18.4c2 0 3.9.58 5.5 1.66.3.2.5-.02.5-.36V7.2c0-.24-.1-.46-.3-.6Z"/>' +
  '<path d="M13 6.6C14.6 5.4 16.7 4.7 19 4.7c.95 0 1.9.12 2.8.36A1.5 1.5 0 0 1 23 6.5v10.8c0 .98-.92 1.68-1.86 1.43A9.6 9.6 0 0 0 19 18.4c-2 0-3.9.58-5.5 1.66-.3.2-.5-.02-.5-.36V7.2c0-.24.1-.46.3-.6Z"/>' +
  '</svg>';

export default {
  toClient(shared) {
    const { programName, programImageUrl, programDays } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'SkeletonEnrollmentCard',
        componentProps: {
          programName,
          programDays: programDays ?? 0,
          programImageUrl: programImageUrl ?? null,
          bookIcon: BOOK_FILL,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.SkeletonEnrollmentCard',
      state: { component: shared ?? {} },
    };
  },
};
