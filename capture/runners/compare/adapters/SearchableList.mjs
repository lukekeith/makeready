/**
 * Adapter: SearchableList (component comparison, two-sided twin).
 *
 * Projects one canonical searchable-list description into:
 *   - toClient → searchable-list.vue via the ComponentCapture island
 *   - toIphone → SearchableList.swift via the component.SearchableList
 *     ViewRegistry case (unchanged from the iPhone-first passthrough)
 *
 * The fixture's `shared` block carries `{ placeholder, showAlphabetScrubber,
 * items: [{ name, hasPhone }] }`. The Vue twin consumes those fields directly.
 *
 * ── Parity note (IMPORTANT) ──────────────────────────────────────────────────
 * In the isolated capture BOTH iPhone variants render the EMPTY "No results"
 * state — even Default, which carries 12 contacts. The iPhone ViewRegistry case
 * decodes its rows from `state.component.searchItems`, but the canonical `shared`
 * block (and therefore this passthrough) provides `items`, so the Swift side sees
 * zero rows and falls through to `defaultEmptyState`. This is the same data-key
 * artifact as HeatMapChart (fixture `dataPoints` vs Swift `heatMapPoints`). The
 * Vue twin stays genuinely data-driven, so the Empty variant matches the iPhone
 * empty reference while the Default variant renders the designed populated list
 * (the surfaced gap against the frozen-empty iPhone reference).
 *
 * `toIphone` forwards `shared` unchanged — the iPhone side owns decoding, and the
 * frozen reference is captured as-is (matching the HeatMapChart precedent).
 */
export default {
  toClient(shared = {}) {
    const {
      placeholder = 'Search',
      showAlphabetScrubber = false,
      items = [],
    } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper; the twin cancels the harness gutter
      // internally to reproduce the iPhone's full-bleed 440×640pt frame.
      clip: '.capture-wrap',
      data: {
        component: 'SearchableList',
        componentProps: {
          placeholder,
          showAlphabetScrubber,
          items: (items ?? []).map((it) => ({
            name: it.name ?? '',
            hasPhone: it.hasPhone ?? false,
          })),
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.SearchableList',
      state: { component: shared },
    };
  },
};
