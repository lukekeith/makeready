/**
 * Adapter: CardMediaFull (component comparison).
 *
 * Projects one canonical media-library tile into:
 *   - toClient → card-media-full.vue via the ComponentCapture island
 *   - toIphone → CardMediaFull.swift via the component.CardMediaFull ViewRegistry case
 *
 * The tile is thumbnail-only: an image (or a faint placeholder + media-type
 * glyph) with the usage count overlaid top-left and the formatted duration
 * bottom-right. The three variants (Video / Photo / Audio) differ only in
 * `type`, `count`, and `durationSeconds`.
 *
 * The iPhone side takes the raw shared fields (it formats the duration and picks
 * the SF Symbol itself, via MediaType.icon + formattedDuration). The web side
 * receives the pre-resolved presentation: an inline SVG for the media glyph and
 * the already-formatted duration string, since the Vue tile is purely visual.
 */

// Inline SVGs mirroring the SF Symbols the iOS MediaType.icon maps to:
//   video → play.fill, audio → waveform. Photos render no glyph.
const WEB_ICONS = {
  video: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>',
  audio:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 10v4M8 7v10M12 3v18M16 8v8M20 11v2"/></svg>',
  document:
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 2h8l4 4v16H6z" opacity="0.9"/></svg>',
};

/** Mirrors MediaLibraryItem.formattedDuration in MediaModels.swift. */
function formatDuration(seconds) {
  if (seconds == null || seconds <= 0) return '';
  const minutes = Math.floor(seconds / 60);
  const secs = seconds % 60;
  const pad = (n) => String(n).padStart(2, '0');
  if (minutes >= 60) {
    const hours = Math.floor(minutes / 60);
    const remMinutes = minutes % 60;
    return `${hours}:${pad(remMinutes)}:${pad(secs)}`;
  }
  return `${minutes}:${pad(secs)}`;
}

export default {
  toClient(shared) {
    const { title, type = 'video', count = 0, durationSeconds } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardMediaFull',
        componentProps: {
          title: title ?? '',
          icon: type === 'photo' ? '' : WEB_ICONS[type] ?? '',
          count,
          duration: formatDuration(durationSeconds),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardMediaFull',
      state: { component: shared },
    };
  },
};
