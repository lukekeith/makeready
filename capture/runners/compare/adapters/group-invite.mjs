/**
 * Adapter: group-invite (page comparison, group Group) — WEB-ONLY.
 *
 * GroupInvitePage.swift is the trailing SlideStack pane behind the private
 * `rightScreen` @State inside pages.group-home — unreachable by the iPhone
 * harness, so toIphone returns null (same precedent as edit-group). The web
 * side renders the GroupInvite twin full-bleed via pages.leader-twin; the
 * fixture embeds the REAL server QR (pre-generated for the fixed code) so the
 * bitmap is deterministic.
 */
export default {
  toClient(shared) {
    const { invite = null, error = '', toast = false } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'GroupInvite',
        componentProps: invite
          ? {
              groupName: invite.groupName ?? '',
              code: invite.code ?? '',
              qrCode: invite.qrCode ?? '',
              toast: Boolean(toast),
            }
          : { errorMessage: error || 'Something went wrong' },
      },
    };
  },

  // No iPhone side — the pane is private @State-gated inside pages.group-home.
  toIphone() {
    return null;
  },
};
