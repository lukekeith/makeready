/**
 * Adapter: CardEventMini (component comparison).
 *
 * Projects one canonical mini-event-card description into:
 *   - toClient → card-event-mini.vue via the ComponentCapture island
 *   - toIphone → CardEventMini.swift via the component.CardEventMini ViewRegistry case
 *
 * The canonical `shared` block matches the SwiftUI prop bag (title, imageStyle,
 * metadata) so the iPhone side passes it straight through. For the web twin we
 * flatten the `dateDisplay` image style into day/month props and map each
 * metadata item's semantic icon (e.g. "clock") to inline SVG.
 */
const WEB_ICONS = {
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  calendar:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
  pin:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
};

export default {
  toClient(shared) {
    const { title, imageStyle = {}, metadata = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardEventMini',
        componentProps: {
          title,
          day: imageStyle.day ?? 1,
          month: imageStyle.month ?? '',
          dataItems: metadata.map((m) => ({ icon: WEB_ICONS[m.icon] ?? '', value: m.value })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardEventMini',
      state: { component: shared ?? {} },
    };
  },
};
