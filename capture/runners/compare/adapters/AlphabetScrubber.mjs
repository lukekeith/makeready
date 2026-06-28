/**
 * Adapter: AlphabetScrubber (component comparison).
 *
 * Projects one canonical scrubber description into:
 *   - toClient → alphabet-scrubber.vue via the ComponentCapture island
 *   - toIphone → AlphabetScrubber.swift via the component.AlphabetScrubber
 *     ViewRegistry case (unchanged from the iPhone-first passthrough)
 *
 * The shared block is the raw `AlphabetScrubber` prop bag: just `letters`, the
 * column of labels rendered top→bottom. No icons to map.
 */
export default {
  toClient(shared) {
    const { letters = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = scrubber + 16px gutters; the harness's
      // .padding(16) is mirrored by .capture-wrap's gutter).
      clip: '.capture-wrap',
      data: {
        component: 'AlphabetScrubber',
        componentProps: {
          letters,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.AlphabetScrubber',
      state: { component: shared ?? {} },
    };
  },
};
