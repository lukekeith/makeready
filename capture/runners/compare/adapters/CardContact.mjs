/**
 * Adapter: CardContact (component comparison).
 *
 * Projects one canonical contact-card description into:
 *   - toClient → card-contact.vue via the ComponentCapture island
 *   - toIphone → CardContact.swift via the component.CardContact ViewRegistry case
 *
 * The single real variant axis is whether the row carries a trailing "Invite"
 * button. iOS expresses this by passing an `ActionButton` as the card's
 * trailingContent when `variant === 'invite'`; the web twin renders the same
 * pill internally from a `showInvite` prop. The `variant` field travels in
 * `shared` and each adapter forwards it to its platform.
 */
export default {
  toClient(shared) {
    const { variant, firstName, lastName, avatarUrl } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardContact',
        componentProps: {
          firstName,
          lastName,
          avatarUrl: avatarUrl ?? '',
          showInvite: variant === 'invite',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardContact',
      state: { component: shared },
    };
  },
};
