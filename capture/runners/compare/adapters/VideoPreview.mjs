/**
 * Adapter: VideoPreview (component comparison).
 *
 * Projects one canonical video-preview description into:
 *   - toClient → video-preview.vue via the ComponentCapture island
 *   - toIphone → VideoPreview.swift via the component.VideoPreview ViewRegistry case
 *
 * `thumbnailUrl` is the only real variant axis (Empty omits it; WithThumbnail
 * supplies a cover URL). It travels in `shared` and the web adapter forwards it.
 *
 * NB: the iPhone side can only render the empty "Select a video" placeholder —
 * the ViewRegistry forces selectedAsset/recordedVideoURL nil (a PHAsset/AVAsset
 * thumbnail can't be injected in the isolated snapshot), so both fixture variants
 * produce the same placeholder reference. The toIphone projection therefore
 * carries the shared data unchanged (the Swift case ignores it), and the web twin
 * renders the real thumbnail for WithThumbnail — a surfaced parity gap, not a
 * faked match.
 */
export default {
  toClient(shared) {
    const { thumbnailUrl } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'VideoPreview',
        componentProps: {
          thumbnailUrl: thumbnailUrl ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.VideoPreview',
      state: { component: shared },
    };
  },
};
