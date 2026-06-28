/**
 * Adapter: CardEvent (component comparison).
 *
 * Projects one canonical event-row description into:
 *   - toClient → card-event.vue via the ComponentCapture island
 *   - toIphone → CardEvent.swift via the component.CardEvent ViewRegistry case
 *
 * The canonical `shared` block matches the SwiftUI prop bag (title, subtitle,
 * imageStyle, metadata) so the iPhone side passes it straight through. For the
 * web twin we flatten the `dateDisplay` / `timeDisplay` image style into
 * day/month or time/period props and map each metadata item's semantic icon
 * (e.g. "mappin") to inline SVG.
 */
const WEB_ICONS = {
  // SF Symbol "mappin" is a pushpin: a round head over a thin tapering stem.
  mappin:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="7" r="3.25"/><path d="M12 10.25V21"/></svg>',
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  calendar:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
};

export default {
  toClient(shared) {
    const { title, subtitle, imageStyle = {}, metadata = [] } = shared ?? {};
    const block =
      imageStyle.kind === 'timeDisplay'
        ? { time: imageStyle.time, period: imageStyle.period }
        : { day: imageStyle.day, month: imageStyle.month };
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardEvent',
        componentProps: {
          title,
          subtitle,
          ...block,
          dataItems: metadata.map((m) => ({ icon: WEB_ICONS[m.icon] ?? '', value: m.value })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardEvent',
      state: { component: shared ?? {} },
    };
  },
};
