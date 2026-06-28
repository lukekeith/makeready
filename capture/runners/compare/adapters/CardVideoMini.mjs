/**
 * Adapter: CardVideoMini (component comparison).
 *
 * Projects one canonical video-card description into:
 *   - toClient → card-video-mini.vue via the ComponentCapture island
 *   - toIphone → CardVideoMini.swift via the component.CardVideoMini ViewRegistry case
 *
 * The canonical `shared` block IS the iPhone prop bag, so toIphone passes it
 * straight through (unchanged from the prior generic iphoneCard adapter). For the
 * web twin, the SF Symbol metadata icons are mapped to inline SVG, and the photo
 * URL is dropped (isolated /compare snapshots never resolve the remote image, so
 * the iPhone reference shows the gray CardLoadingPlaceholder — the web twin
 * matches it). The mini card renders only the first metadata item.
 */
const WEB_METADATA_ICONS = {
  eye:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
};

// Centered well glyph for the `.icon` image style (iOS falls back to a white
// play.circle.fill when no photo is set).
const WELL_PLAY =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7L8 5Z"/></svg>';

export default {
  toClient(shared) {
    const { title, description, imageStyle = {}, metadata = [] } = shared ?? {};
    const kind = imageStyle.kind === 'photo' ? 'photo' : 'icon';
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardVideoMini',
        componentProps: {
          title,
          description: description ?? '',
          imageStyle:
            kind === 'photo'
              ? // Omit the url so the web twin renders the gray placeholder that
                // the iPhone reference shows (the component renders a real <img>
                // when handed a url in normal use).
                { kind: 'photo', url: '' }
              : { kind: 'icon', icon: WELL_PLAY },
          metadata: metadata.map((m) => ({
            icon: WEB_METADATA_ICONS[m.icon] ?? '',
            value: m.value,
          })),
        },
      },
    };
  },

  // Unchanged from the prior iphoneCard('component.CardVideoMini') passthrough:
  // the canonical `shared` block IS the SwiftUI prop bag (metadata icons like
  // "eye" are already SF Symbol names).
  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardVideoMini',
      state: { component: shared ?? {} },
    };
  },
};
