/**
 * Adapter: CardMember (component comparison).
 *
 * Projects one canonical member-card description into:
 *   - toClient → card-member.vue via the ComponentCapture island
 *   - toIphone → CardMember.swift via the component.CardMember ViewRegistry case
 *
 * The real variant axis is whether the row carries a trailing "Invite" button.
 * iOS expresses this by passing an `ActionButton` as the card's trailingContent
 * when `variant === 'invite'`; the web twin renders the same pill internally
 * from a `showInvite` prop. Metadata (label/value pairs) and group badges travel
 * verbatim in `shared` — no icons to map, so both platforms forward them as-is.
 */
export default {
  toClient(shared) {
    const { variant, firstName, lastName, avatarUrl, metadata = [], groups = [] } =
      shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardMember',
        componentProps: {
          firstName,
          lastName,
          avatarUrl: avatarUrl ?? '',
          metadata: metadata.map((m) => ({ label: m.label, value: m.value })),
          groups,
          showInvite: variant === 'invite',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardMember',
      state: { component: shared },
    };
  },
};
