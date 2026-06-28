/**
 * Adapter: CardStudyMini (component comparison).
 *
 * Projects one canonical mini-study-card description into:
 *   - toClient → card-study-mini.vue via the ComponentCapture island
 *   - toIphone → CardStudyMini.swift via the component.CardStudyMini ViewRegistry case
 *
 * The shared block carries the same fields the iOS CardStudyData uses (title,
 * status, imageStyle, metadata). Semantic icons (e.g. "clock", "book.fill") are
 * mapped to inline SVG for the web twin and pass through as SF Symbol names for
 * iPhone. The icon-well `background: "orange"` maps to iOS system orange
 * (#FF9500) on web — there is no design-system token for it (iOS passes `.orange`).
 */
const WEB_METADATA_ICONS = {
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  users:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/></svg>',
  calendar:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
};

// Filled glyphs for the icon-well case (iOS shows a solid 32×32 SF Symbol).
const WEB_WELL_ICONS = {
  'book.fill':
    '<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-4.013 1.448a.5.5 0 0 0-.274.446v11a.5.5 0 0 0 .727.446c.93-.468 2.34-.948 3.658-1.08 1.323-.133 2.452.063 3.072.638a.5.5 0 0 0 .654 0c.62-.575 1.75-.771 3.072-.638 1.318.132 2.728.612 3.658 1.08A.5.5 0 0 0 16 13.834v-11a.5.5 0 0 0-.274-.446c-.97-.776-2.499-1.295-4.013-1.448C10.413.809 8.985.936 8 1.783"/></svg>',
};

// SwiftUI named colors → CSS (no DS token; mirrors iOS `.orange` etc.).
const WELL_BACKGROUNDS = {
  orange: '#ff9500',
};

export default {
  toClient(shared) {
    const { title, status, imageStyle = {}, metadata = [] } = shared ?? {};
    const kind = imageStyle.kind === 'photo' ? 'photo' : 'icon';
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardStudyMini',
        componentProps: {
          title,
          status: status ?? 'confirmed',
          imageStyle:
            kind === 'photo'
              ? // Isolated /compare snapshots never resolve the remote photo, so the
                // iPhone reference shows the gray CardLoadingPlaceholder. Omit the
                // url so the web twin matches that placeholder (the component still
                // renders a real <img> when handed a url in normal use).
                { kind: 'photo', url: '' }
              : {
                  kind: 'icon',
                  icon:
                    WEB_WELL_ICONS[imageStyle.systemName] ??
                    WEB_WELL_ICONS['book.fill'],
                  iconBackground: WELL_BACKGROUNDS[imageStyle.background] ?? '',
                },
          metadata: metadata.map((m) => ({
            icon: WEB_METADATA_ICONS[m.icon] ?? '',
            value: m.value,
          })),
        },
      },
    };
  },

  // Unchanged from the prior iphoneCard('component.CardStudyMini') passthrough:
  // the canonical `shared` block IS the SwiftUI prop bag (metadata icons like
  // "clock" are already SF Symbol names).
  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardStudyMini',
      state: { component: shared ?? {} },
    };
  },
};
