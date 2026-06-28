/**
 * Adapter: CardVideo (component comparison).
 *
 * Projects one canonical video-card description into:
 *   - toClient → card-video.vue via the ComponentCapture island
 *   - toIphone → CardVideo.swift via the component.CardVideo ViewRegistry case
 *
 * The canonical `shared` block IS the iPhone prop bag, so toIphone passes it
 * straight through (unchanged from the prior generic iphoneCard adapter). For the
 * web twin, the SF Symbol metadata icons are mapped to inline SVG, the photo URL
 * is dropped (isolated /compare snapshots never resolve the remote image, so the
 * iPhone reference shows the gray CardLoadingPlaceholder — the web twin matches
 * it), and the `.new` icon style maps to a centered white play glyph.
 */
const WEB_METADATA_ICONS = {
  eye:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  // square.and.arrow.up — iOS share glyph: a tray with an up arrow rising out of it.
  'square.and.arrow.up':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>',
};

// Centered well glyph for the `.new` icon style (iOS shows a 32pt white play.fill).
const WELL_PLAY =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7L8 5Z"/></svg>';

export default {
  toClient(shared) {
    const { title, description, status, imageStyle = {}, metadata = [] } = shared ?? {};
    const kind = imageStyle.kind === 'photo' ? 'photo' : 'icon';
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardVideo',
        componentProps: {
          title,
          description: description ?? '',
          status: status ?? 'confirmed',
          imageStyle:
            kind === 'photo'
              ? // Omit the url so the web twin renders the gray placeholder that the
                // iPhone reference shows (the component renders a real <img> when
                // handed a url in normal use).
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

  // Unchanged from the prior iphoneCard('component.CardVideo') passthrough: the
  // canonical `shared` block IS the SwiftUI prop bag (metadata icons like "eye"
  // are already SF Symbol names).
  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardVideo',
      state: { component: shared ?? {} },
    };
  },
};
