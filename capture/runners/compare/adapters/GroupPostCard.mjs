/**
 * Adapter: GroupPostCard (component comparison).
 *
 * Projects one canonical group-post description into:
 *   - toClient → group-post-card.vue via the ComponentCapture island
 *   - toIphone → GroupPostCard.swift via the component.GroupPostCard ViewRegistry case
 *
 * The iPhone side passes `shared` straight through (the ViewRegistry rebuilds a
 * GroupPost from it). For the web twin we mirror the iOS render exactly:
 *
 *  - Timestamp: the ViewRegistry builds createdAt as a FIXED base epoch
 *    (1_700_000_000) minus `createdSecondsAgo`, then GroupPostCard formats it as
 *    a two-tone relative time against "now". We replicate that math here so the
 *    twin shows the same "<n> days ago" value+unit split.
 *  - Avatar: iOS AsyncImage falls back to initials in isolated snapshots, so we
 *    pass initials (computed like GroupPostCard.initials(from:)) and omit the URL.
 *  - Media: iOS AsyncImage renders its placeholder in isolated snapshots, so we
 *    signal a placeholder (`media: 'photo'`) instead of forwarding the image URL.
 *  - Event date/time: formatted to match DateFormatters.weekdayFullMonthDayTime
 *    ("Tuesday October 28 - 7:00pm"), built in local tz from the event parts.
 */

// Matches the fixed base epoch used by ViewRegistry.swift for capture stability.
const BASE_EPOCH_SECONDS = 1_700_000_000;

const MONTHS_ABBR = {
  JAN: 0, FEB: 1, MAR: 2, APR: 3, MAY: 4, JUN: 5,
  JUL: 6, AUG: 7, SEP: 8, OCT: 9, NOV: 10, DEC: 11,
};

const MONTHS_FULL = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const WEEKDAYS_FULL = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

// GroupPostCard.initials(from:) — first letters of the first two words, else the
// first two characters of a single word. Uppercased, max 2.
function initialsFor(name) {
  const parts = String(name ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return '?';
}

// GroupPostCard.relativeTimeComponents(from:) — largest non-zero unit of
// (now - createdAt), or "Just now".
function relativeTime(createdSecondsAgo) {
  const createdAtMs = (BASE_EPOCH_SECONDS - (createdSecondsAgo ?? 0)) * 1000;
  const seconds = Math.floor((Date.now() - createdAtMs) / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return { value: String(days), unit: days === 1 ? 'day ago' : 'days ago' };
  if (hours > 0) return { value: String(hours), unit: hours === 1 ? 'hour ago' : 'hours ago' };
  if (minutes > 0) return { value: String(minutes), unit: minutes === 1 ? 'minute ago' : 'minutes ago' };
  return { value: 'Just', unit: 'now' };
}

// DateFormatters.weekdayFullMonthDayTime → "Tuesday October 28 - 7:00pm"
function formatEventDateTime(shared) {
  const month = MONTHS_ABBR[String(shared.month ?? '').toUpperCase()] ?? 0;
  const year = shared.dayNumber ?? 2025;
  const day = shared.day ?? 1;
  const [h12raw, minRaw] = String(shared.time ?? '0:00').split(':');
  const hour12 = parseInt(h12raw, 10) || 0;
  const minute = parseInt(minRaw, 10) || 0;
  const isPM = String(shared.period ?? '').toLowerCase() === 'pm';
  const hour24 = isPM && hour12 < 12 ? hour12 + 12 : hour12;
  const date = new Date(year, month, day, hour24, minute);
  const weekday = WEEKDAYS_FULL[date.getDay()];
  const fullMonth = MONTHS_FULL[date.getMonth()];
  const time = `${shared.time ?? ''}${(shared.period ?? '').toLowerCase()}`;
  return `${weekday} ${fullMonth} ${date.getDate()} - ${time}`;
}

export default {
  toClient(shared) {
    const s = shared ?? {};
    const type =
      s.type === 'event' ? 'event' : s.type === 'welcome' ? 'welcome' : 'announcement';
    const { value: timeValue, unit: timeUnit } = relativeTime(s.createdSecondsAgo);
    const hasImage = Array.isArray(s.images) && s.images.length > 0;

    const componentProps = {
      type,
      authorName: s.authorName ?? '',
      initials: initialsFor(s.authorName),
      timeValue,
      timeUnit,
      text: s.text ?? '',
    };

    if (type === 'event') {
      componentProps.eventTitle = s.subtitle ?? '';
      componentProps.eventDay = String(s.day ?? '');
      componentProps.eventMonth = String(s.month ?? '');
      componentProps.eventDateTime = formatEventDateTime(s);
      componentProps.attendeeCount = s.memberCount ?? 0;
    } else {
      componentProps.media = hasImage ? 'photo' : null;
      componentProps.viewCount = s.count ?? 0;
      componentProps.shareCount = parseInt(s.value ?? '0', 10) || 0;
    }

    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'GroupPostCard',
        componentProps,
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.GroupPostCard',
      state: { component: shared ?? {} },
    };
  },
};
