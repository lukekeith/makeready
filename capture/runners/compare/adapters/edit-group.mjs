/**
 * Adapter: edit-group (page comparison, group Group) — WEB-ONLY.
 *
 * The iOS side is the INLINE `editGroupContent` form in GroupHomePage.swift
 * (:381-529), gated by the private `showSettings` @State — the capture harness
 * can't reach it, so toIphone returns null (the comparison stays navigable
 * web-only; see the fixture note). The web side renders the EditGroup twin
 * full-bleed via pages.leader-twin.
 */
export default {
  toClient(shared) {
    const { group = {} } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditGroup',
        componentProps: {
          groupName: group.name ?? '',
          groupDescription: group.description ?? '',
          isPrivate: Boolean(group.isPrivate),
          allowInvites: Boolean(group.allowInvites),
          memberDirectory: Boolean(group.memberDirectory),
          ageMin: group.ageMin ?? '18',
          ageMax: group.ageMax ?? '34',
          maxMembers: group.maxMembers ?? 'Unlimited',
        },
      },
    };
  },

  // No iPhone side — the form is private @State-gated inside pages.group-home.
  toIphone() {
    return null;
  },
};
