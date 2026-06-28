/**
 * Adapter: UpcomingLessonCard (component comparison).
 *
 * Projects one canonical "next upcoming lesson" description into:
 *   - toClient → upcoming-lesson-card.vue via the ComponentCapture island
 *   - toIphone → UpcomingLessonCard.swift via the component.UpcomingLessonCard
 *               ViewRegistry case (unchanged passthrough from the scaffold).
 *
 * The iPhone derives each activity glyph from its `type` (ActivityStyle.icon —
 * an asset-catalog SVG), ignoring the fixture's raw `icon` field, and renders it
 * template-tinted white@50% on a white@10% well. The web twin can't reach the
 * asset catalog, so this adapter maps `type` → the same glyph as inline SVG
 * (currentColor) and hands the Vue component ready-to-render icons.
 *
 * The date is formatted here (weekday, short month, day, year) in the LOCAL
 * timezone to mirror the iOS DateFormatter "EEEE, MMM d, yyyy" — UTC-midnight
 * fixture dates otherwise shift a day on the iPhone's local-tz formatter.
 */

// Activity glyphs (currentColor) mirroring ActivityStyle asset catalog icons.
const READ =
  '<svg viewBox="0 0 32 32" fill="none" aria-hidden="true"><path d="M16 28L15.8666 27.8C14.9404 26.4107 14.4773 25.716 13.8655 25.2131C13.3238 24.7679 12.6997 24.4339 12.0288 24.2301C11.271 24 10.4362 24 8.76645 24H6.93335C5.43988 24 4.69314 24 4.12271 23.7094C3.62094 23.4537 3.21299 23.0457 2.95733 22.544C2.66669 21.9735 2.66669 21.2268 2.66669 19.7333V8.26667C2.66669 6.77319 2.66669 6.02646 2.95733 5.45603C3.21299 4.95426 3.62094 4.54631 4.12271 4.29065C4.69314 4 5.43988 4 6.93335 4H7.46669C10.4536 4 11.9471 4 13.088 4.5813C14.0915 5.09262 14.9074 5.90852 15.4187 6.91205C16 8.05291 16 9.54639 16 12.5333M16 28V12.5333M16 28L16.1334 27.8C17.0596 26.4107 17.5227 25.716 18.1346 25.2131C18.6762 24.7679 19.3003 24.4339 19.9712 24.2301C20.729 24 21.5639 24 23.2336 24H25.0667C26.5602 24 27.3069 24 27.8773 23.7094C28.3791 23.4537 28.787 23.0457 29.0427 22.544C29.3334 21.9735 29.3334 21.2268 29.3334 19.7333V8.26667C29.3334 6.77319 29.3334 6.02646 29.0427 5.45603C28.787 4.95426 28.3791 4.54631 27.8773 4.29065C27.3069 4 26.5602 4 25.0667 4H24.5334C21.5464 4 20.0529 4 18.9121 4.5813C17.9085 5.09262 17.0926 5.90852 16.5813 6.91205C16 8.05291 16 9.54639 16 12.5333" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

// IconRecordVideo — concentric record circle (outer ring + center dot).
const RECORD =
  '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M10 1.25C8.26942 1.25 6.57769 1.76318 5.13876 2.72464C3.69983 3.6861 2.57832 5.05267 1.91606 6.65152C1.25379 8.25037 1.08051 10.0097 1.41813 11.707C1.75575 13.4044 2.58911 14.9635 3.81282 16.1872C5.03653 17.4109 6.59563 18.2442 8.29296 18.5819C9.9903 18.9195 11.7496 18.7462 13.3485 18.0839C14.9473 17.4217 16.3139 16.3002 17.2754 14.8612C18.2368 13.4223 18.75 11.7306 18.75 10C18.75 7.67936 17.8281 5.45376 16.1872 3.81282C14.5462 2.17187 12.3206 1.25 10 1.25ZM10 17.5C8.51664 17.5 7.0666 17.0601 5.83323 16.236C4.59986 15.4119 3.63856 14.2406 3.07091 12.8701C2.50325 11.4997 2.35473 9.99168 2.64411 8.53682C2.9335 7.08197 3.64781 5.74559 4.6967 4.6967C5.7456 3.64781 7.08197 2.9335 8.53683 2.64411C9.99168 2.35472 11.4997 2.50325 12.8701 3.0709C14.2406 3.63856 15.4119 4.59985 16.236 5.83322C17.0601 7.06659 17.5 8.51664 17.5 10C17.5 11.9891 16.7098 13.8968 15.3033 15.3033C13.8968 16.7098 11.9891 17.5 10 17.5Z" fill="currentColor"/><path d="M10 6.25C9.25832 6.25 8.5333 6.46993 7.91662 6.88199C7.29993 7.29404 6.81928 7.87971 6.53546 8.56494C6.25163 9.25016 6.17737 10.0042 6.32206 10.7316C6.46675 11.459 6.82391 12.1272 7.34835 12.6517C7.8728 13.1761 8.54099 13.5333 9.26842 13.6779C9.99584 13.8226 10.7498 13.7484 11.4351 13.4645C12.1203 13.1807 12.706 12.7001 13.118 12.0834C13.5301 11.4667 13.75 10.7417 13.75 10C13.75 9.00544 13.3549 8.05161 12.6517 7.34835C11.9484 6.64509 10.9946 6.25 10 6.25Z" fill="currentColor"/></svg>';

// IconActivityPrayer — heart outline.
const HEART =
  '<svg viewBox="0 0 32 32" fill="none" aria-hidden="true"><path d="M16 28C16 28 4 18 4 11.3334C4 8.66669 6 5.33335 10 5.33335C12.48 5.33335 14.5467 6.72002 16 8.66669C17.4534 6.72002 19.52 5.33335 22 5.33335C26 5.33335 28 8.66669 28 11.3334C28 18 16 28 16 28Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

// type → glyph (mirrors ActivityStyle.icon(forRawType:)).
const WEB_ACTIVITY_ICONS = {
  READ: READ,
  SCRIPTURE: READ,
  SOAP: READ,
  OIA: READ,
  DBS: READ,
  HEAR: READ,
  VIDEO: RECORD,
  PRAYER: HEART,
};

const DATE_FMT = new Intl.DateTimeFormat('en-US', {
  weekday: 'long',
  month: 'short',
  day: 'numeric',
  year: 'numeric',
});

function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return DATE_FMT.format(d);
}

export function toClient(shared) {
  const { programName, dayNumber, date, coverUrl, activities = [] } = shared ?? {};
  return {
    platform: 'client',
    view: 'components.component-capture',
    // Tight-crop the web shot to the component wrapper so it matches the
    // iPhone sizeThatFits snapshot (both = component + 16px gutters).
    clip: '.capture-wrap',
    data: {
      component: 'UpcomingLessonCard',
      componentProps: {
        programName: programName ?? '',
        dayNumber: dayNumber ?? '',
        dateText: formatDate(date),
        coverUrl: coverUrl ?? '',
        activities: activities.map((a) => ({
          iconSvg: WEB_ACTIVITY_ICONS[a.type] ?? READ,
        })),
      },
    },
  };
}

export function toIphone(shared) {
  return {
    platform: 'iphone',
    view: 'component.UpcomingLessonCard',
    state: { component: shared ?? {} },
  };
}

export default { toClient, toIphone };
