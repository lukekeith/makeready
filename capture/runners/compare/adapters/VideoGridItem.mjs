/**
 * Adapter: VideoGridItem (component comparison).
 *
 * Projects one canonical video-picker grid-cell description into:
 *   - toClient → video-grid-item.vue via the ComponentCapture island
 *   - toIphone → VideoGridItem.swift via the component.VideoGridItem ViewRegistry case
 *
 * The two types (camera / video), the selected wash, and the square size are the
 * real iOS variants, so `type`, `isSelected`, `sizePx`, and `thumbnailUrl` travel
 * in `shared` and each adapter forwards them to its platform. The camera/play
 * glyphs are intrinsic to the component (drawn inline on each platform), so they
 * are not part of the shared data.
 */
export default {
  toClient(shared) {
    const { type = 'camera', isSelected = false, sizePx = 100, thumbnailUrl } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'VideoGridItem',
        componentProps: {
          type,
          selected: isSelected === true,
          sizePx,
          thumbnailUrl: thumbnailUrl ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.VideoGridItem',
      state: { component: shared },
    };
  },
};
