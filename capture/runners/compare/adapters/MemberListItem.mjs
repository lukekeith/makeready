/**
 * Adapter: MemberListItem (component comparison).
 *
 * Projects one canonical member/contact description into:
 *   - toClient → member-list-item.vue via the ComponentCapture island
 *   - toIphone → MemberListItem.swift via the component.MemberListItem
 *     ViewRegistry case (unchanged from the iPhone-first scaffold).
 *
 * The iPhone formats the join date with a local-tz DateFormatter ("MMM d,
 * yyyy"), and the fixture's "2025-01-01" decodes to UTC midnight — which on the
 * capture machine's local tz shifts back to "Dec 31, 2024". We pre-format the
 * label here in LOCAL tz so the Vue twin reproduces that exact shift (same
 * approach as the other date-bearing twins).
 */
function formatJoinDate(iso) {
  if (!iso) return '';
  const d = new Date(iso); // "2025-01-01" → UTC midnight
  if (Number.isNaN(d.getTime())) return '';
  // Local tz, "MMM d, yyyy" — matches DateFormatters.monthDayYear on the iPhone.
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export default {
  toClient(shared) {
    const { variant, firstName, lastName, age, joinDate, groups = [] } =
      shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'MemberListItem',
        componentProps: {
          variant: variant ?? 'memberWithInvite',
          firstName: firstName ?? '',
          lastName: lastName ?? '',
          age: age ?? null,
          joinDateLabel: formatJoinDate(joinDate),
          groups,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.MemberListItem',
      state: { component: shared ?? {} },
    };
  },
};
