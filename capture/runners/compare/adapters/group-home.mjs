/**
 * Adapter: group-home.
 *
 * Projects one canonical `shared` block (edited in the Compare UI's Data tab)
 * into the two platform fixture shapes:
 *   - toClient → Laravel `/_capture` `data` block for pages.group-home.blade.php
 *   - toIphone → AppState `state` + `auth` for the SwiftUI pages.group-home view
 *
 * Both consume the SAME `shared` values, so the two screenshots are a true
 * apples-to-apples comparison of the same group, studies, and member.
 */
export default {
  // The iPhone `pages.group-home` view is the LEADER screen
  // (Pages/Manage/Group/GroupHomePage.swift). Its web counterpart is the
  // capture-only GroupHomeLeader twin, NOT the production member group-home
  // page (resources/views/pages/group-home.blade.php) — those are different
  // screens for different roles. So the web side renders the leader twin
  // full-bleed via its own harness blade. Only the group identity drives the
  // default empty-posts state.
  toClient(shared) {
    const { group = {}, posts = [], nextLesson = null, requestBadge = false } = shared ?? {};

    // Pre-format the lesson date here (local parse — avoid UTC midnight
    // shifting the day; same convention as CardLesson.mjs).
    const formatDate = (iso) => {
      if (!iso) return undefined;
      const [y, m, d] = iso.split('-').map(Number);
      return new Date(y, (m ?? 1) - 1, d ?? 1).toLocaleDateString('en-US', {
        weekday: 'long',
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      });
    };

    return {
      platform: 'client',
      view: 'pages.group-home-leader',
      data: {
        component: 'GroupHomeLeader',
        componentProps: {
          groupName: group.name ?? 'Group',
          isPrivate: Boolean(group.isPrivate),
          memberCount: group.memberCount ?? 0,
          // Additive props (2026-07-04): all default to the original
          // empty-posts rendering when the variant omits them.
          showRequestBadge: Boolean(requestBadge),
          nextLesson: nextLesson
            ? {
                mode: 'lesson',
                day: nextLesson.day,
                title: nextLesson.title,
                date: formatDate(nextLesson.date),
                estimatedMinutes: nextLesson.estimatedMinutes,
                activities: (nextLesson.activities ?? []).map((a) => ({
                  activityType: a.type,
                  status: a.status ?? 'default',
                })),
              }
            : null,
          // Posts are already GroupPostCard prop bags (timeValue/timeUnit are
          // literal strings — deterministic by construction).
          posts,
          // Capture-only: match the iPhone DeviceChrome status-bar inset
          // (this comparison predates the statusBar convention — the old
          // accepted shots carried a constant ~60pt offset).
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, group = {}, studies = [] } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.group-home',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id,
          name: user.name,
          email: user.email,
          picture: user.picture ?? null,
        },
      },
      state: {
        groupId: group.id,
        screenIndex: 0,
        groups: [
          {
            id: group.id,
            code: group.code ?? 'ABC123',
            name: group.name,
            description: group.description ?? '',
            coverImageUrl: group.coverImageUrl ?? null,
            isPrivate: Boolean(group.isPrivate),
            allowInvites: true,
            memberDirectory: true,
            memberCount: group.memberCount,
            creatorId: user.id,
            createdAt: group.createdAt ?? '2026-01-01T00:00:00.000Z',
            updatedAt: '2026-05-01T00:00:00.000Z',
          },
        ],
        enrollments: studies.map((st, i) => ({
          id: `enroll-${i + 1}`,
          groupId: group.id,
          studyProgramId: st.programId ?? `prog-${i + 1}`,
          startDate: '2026-06-01T00:00:00.000Z',
          endDate: '2026-06-30T00:00:00.000Z',
          studyProgram: {
            id: st.programId ?? `prog-${i + 1}`,
            name: st.title,
            days: st.days ?? 30,
          },
          isActive: true,
        })),
      },
    };
  },
};
