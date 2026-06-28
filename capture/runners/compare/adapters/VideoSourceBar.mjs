/**
 * Adapter: VideoSourceBar (component comparison, group Video).
 *
 * Projects one canonical video-source description into:
 *   - toClient → video-source-bar.vue via the ComponentCapture island
 *   - toIphone → VideoSourceBar.swift via the component.VideoSourceBar
 *     ViewRegistry case
 *
 * Canonical `shared`:
 *   { currentSource: 'videos' | 'favorites' | 'makeReady' | 'allAlbums' }
 *
 * The iOS bar renders the source's display label (the enum rawValue) + a
 * chevron.down + the MakeReady logo. The source key → display label mapping is
 * the only data that varies between the four variants, so the adapter resolves
 * it here and forwards a single `label` prop to the web twin. The chevron and
 * MR logo are intrinsic to the component (drawn inline on each platform).
 *
 * NB: the iPhone side is left untouched (generic passthrough of `shared` into
 * `state.component`) — the ViewRegistry case binds `currentSource` to the
 * matching VideoSource case itself.
 */

// VideoSource enum rawValues (iphone/MakeReady/Components/Video/VideoSourceBar.swift).
const SOURCE_LABELS = {
  videos: 'Videos',
  favorites: 'Favorites',
  makeReady: 'MakeReady',
  allAlbums: 'All albums',
};

export default {
  toClient(shared = {}) {
    const { currentSource = 'videos' } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = bar + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'VideoSourceBar',
        componentProps: {
          label: SOURCE_LABELS[currentSource] ?? SOURCE_LABELS.videos,
        },
      },
    };
  },

  toIphone(shared = {}) {
    return {
      platform: 'iphone',
      view: 'component.VideoSourceBar',
      state: { component: shared },
    };
  },
};
