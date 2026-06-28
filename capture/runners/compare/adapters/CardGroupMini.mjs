/**
 * Adapter: CardGroupMini (component comparison).
 *
 * Projects one canonical mini-group-card description into:
 *   - toClient → card-group-mini.vue via the ComponentCapture island
 *   - toIphone → CardGroupMini.swift via the component.CardGroupMini ViewRegistry case
 *
 * The shared block carries the same fields the iOS CardGroupData uses (title,
 * imageStyle, metadata, isSelected). The iOS metadata is a [DataItem] array of
 * `.number` items; the Vue twin renders the same value/label inline, so we just
 * forward the array shape each platform expects.
 *
 * `imageStyle.kind === 'icon'` means the group-icon fallback well — there's no
 * per-platform icon to map (the Vue twin bakes the people glyph into the
 * fallback), so nothing extra travels for the icon case.
 */
export default {
  toClient(shared) {
    const { title, metadata = [], imageStyle, isSelected } = shared ?? {};
    const imageUrl = imageStyle?.kind === 'photo' ? imageStyle.imageURL ?? '' : '';
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardGroupMini',
        componentProps: {
          title,
          imageUrl,
          selected: isSelected === true,
          metadata: metadata.map((m) => ({ number: m.number, label: m.label })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardGroupMini',
      state: { component: shared },
    };
  },
};
