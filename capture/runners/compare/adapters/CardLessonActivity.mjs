/**
 * Adapter: CardLessonActivity (component comparison).
 *
 * Projects one canonical lesson-activity description into:
 *   - toClient → card-lesson-activity.vue via the ComponentCapture island
 *   - toIphone → CardLessonActivity.swift via the component.CardLessonActivity case
 *
 * The canonical `shared` block matches the SwiftUI prop bag (type, title,
 * description, status, size, estimatedMinutes, imageStyle) so the iPhone side
 * passes it straight through. For the web twin the Vue component derives its
 * icon + accent color from `type`, so we just forward the fields and flatten a
 * `photo` imageStyle into a plain `imageUrl`.
 *
 * Note: iPhone snapshot tests have no network, so video thumbnails fall back to
 * a neutral box; the web pane loads the real remote image. That thumbnail
 * difference is a snapshot-network artifact, not a component mismatch.
 */
export default {
  toClient(shared) {
    const { type, title, description, status, size, estimatedMinutes, imageStyle } = shared ?? {};
    const imageUrl = imageStyle?.kind === 'photo' ? imageStyle.url : undefined;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardLessonActivity',
        componentProps: {
          type,
          title,
          description,
          status,
          size: size === 'small' ? 'small' : 'default',
          estimatedMinutes,
          imageUrl,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardLessonActivity',
      state: { component: shared ?? {} },
    };
  },
};
