/**
 * Adapter: CardProgramFull (component comparison).
 *
 * Projects one canonical program-card description into:
 *   - toClient → card-program-full.vue via the ComponentCapture island
 *   - toIphone → CardProgramFull.swift via the component.CardProgramFull case
 *
 * The iPhone side takes the raw shared fields (it computes weeks, formats the
 * relative date, and picks SF Symbols itself). The web side is purely visual, so
 * it receives the pre-resolved presentation: inline-SVG metadata icons, the
 * computed weeks count, and the already-formatted relative date string.
 */

// Inline SVGs mirroring the SF Symbols the iOS card uses:
//   calendar → calendar, clock → clock, person.2 → people glyph.
const WEB_ICONS = {
  calendar:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
  clock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  users:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
};

/**
 * Approximates iOS RelativeDateTimeFormatter (.full) — "1 week ago", "5 days
 * ago", etc. relative to now, matching the iPhone render which formats against
 * the real current date at capture time.
 */
function relativeDate(iso) {
  if (!iso) return '';
  const then = new Date(iso).getTime();
  const now = Date.now();
  const diffSec = Math.round((now - then) / 1000);
  const past = diffSec >= 0;
  const abs = Math.abs(diffSec);
  const units = [
    ['year', 31536000],
    ['month', 2592000],
    ['week', 604800],
    ['day', 86400],
    ['hour', 3600],
    ['minute', 60],
    ['second', 1],
  ];
  for (const [name, secs] of units) {
    const value = Math.floor(abs / secs);
    if (value >= 1) {
      const label = `${value} ${name}${value === 1 ? '' : 's'}`;
      return past ? `${label} ago` : `in ${label}`;
    }
  }
  return 'now';
}

export default {
  toClient(shared) {
    const {
      title,
      description,
      coverImageUrl,
      coverUrl,
      tags = [],
      days = 0,
      enrollmentCount,
      authorName,
      createdAt,
      isPublished,
    } = shared ?? {};

    const weeks = Math.ceil(days / 7);
    const dataItems = [
      { icon: WEB_ICONS.calendar, value: String(days) },
      { icon: WEB_ICONS.clock, value: `${weeks} weeks` },
    ];
    if (enrollmentCount && enrollmentCount > 0) {
      dataItems.push({ icon: WEB_ICONS.users, value: String(enrollmentCount) });
    }

    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardProgramFull',
        componentProps: {
          title: title ?? '',
          description: description ?? '',
          tags,
          dataItems,
          authorName: authorName ?? '',
          relativeDate: relativeDate(createdAt),
          published: !!isPublished,
          coverUrl: coverImageUrl ?? coverUrl ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardProgramFull',
      state: { component: shared },
    };
  },
};
