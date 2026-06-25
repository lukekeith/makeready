/**
 * Adapter: GroupCard (component comparison).
 *
 * Projects one canonical group-card description into:
 *   - toClient → card-group.vue via the ComponentCapture island
 *   - toIphone → CardGroup / CardGroupMini via the component.GroupCard ViewRegistry case
 *
 * The two layouts (Row / Mini) and the selected state are the real iPhone
 * variants (CardGroup vs CardGroupMini × isSelected), so `size` and `selected`
 * travel in `shared` and each adapter forwards them to its platform.
 *
 * The web CardGroup builds its own member-count chip (people icon + "N members")
 * internally from the `memberCount` prop, so the client side just forwards the
 * number. The iPhone CardGroup takes a `[DataItem]` metadata array, so we
 * pre-build the matching chip here (person.2.fill + the same pluralized label)
 * to keep the two renders identical.
 */
function memberLabel(count) {
  return `${count} ${count === 1 ? 'member' : 'members'}`;
}

export default {
  toClient(shared) {
    const { name, imageUrl, initials, memberCount = 0, selected, size } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardGroup',
        componentProps: {
          name,
          imageUrl: imageUrl ?? '',
          initials: initials ?? '',
          memberCount,
          selected: selected === true,
          size: size ?? 'Row',
        },
      },
    };
  },

  toIphone(shared) {
    const { name, imageUrl, memberCount = 0, selected, size } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'component.GroupCard',
      state: {
        component: {
          name: 'CardGroup',
          title: name,
          coverUrl: imageUrl ?? null,
          selected: selected === true,
          size: size ?? 'Row',
          metadata: [{ icon: 'person.2.fill', value: memberLabel(memberCount) }],
        },
      },
    };
  },
};
