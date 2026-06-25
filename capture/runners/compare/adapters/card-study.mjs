/**
 * Adapter: card-study (component comparison).
 *
 * Projects one canonical study-card description into:
 *   - toClient → CardStudy.vue via the ComponentCapture island
 *   - toIphone → CardStudy.swift via the component.card-study ViewRegistry case
 *
 * Icons are declared semantically in `shared.metadata` (e.g. "clock") and each
 * adapter maps them to its platform's icon system (inline SVG vs SF Symbol),
 * so the same logical data drives both renders.
 */
const WEB_ICONS = {
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  users:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/></svg>',
  calendar:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
};

const SF_ICONS = {
  clock: 'clock',
  users: 'person.2.fill',
  calendar: 'calendar',
};

export default {
  toClient(shared) {
    const { title, description, coverUrl, status, metadata = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardStudy',
        componentProps: {
          size: 'Row',
          title,
          description,
          coverUrl: coverUrl ?? '',
          dataItems: metadata.map((m) => ({ icon: WEB_ICONS[m.icon] ?? '', value: m.value })),
          unconfirmed: status === 'unconfirmed',
          pending: status === 'pending',
        },
      },
    };
  },

  toIphone(shared) {
    const { title, description, coverUrl, status, metadata = [] } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'component.card-study',
      state: {
        component: {
          name: 'CardStudy',
          title,
          description,
          type: null,
          status: status ?? 'confirmed',
          coverUrl: coverUrl ?? null,
          iconSystemName: 'book.fill',
          metadata: metadata.map((m) => ({ icon: SF_ICONS[m.icon] ?? 'circle', value: m.value })),
        },
      },
    };
  },
};
