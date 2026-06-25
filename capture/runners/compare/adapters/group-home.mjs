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
  toClient(shared) {
    const { user = {}, group = {}, studies = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.group-home',
      data: {
        groupId: group.id,
        member: {
          id: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          phoneNumber: user.phoneNumber,
        },
        memberGroups: [{ id: group.id, name: group.name }],
        groupData: {
          id: group.id,
          name: group.name,
          coverImageUrl: group.coverImageUrl ?? null,
          isPrivate: Boolean(group.isPrivate),
          memberCount: group.memberCount,
          createdAt: group.createdAt ?? '2024-07-17T00:00:00Z',
          organizationName: group.organizationName,
          creator: { name: group.creatorName, picture: group.creatorPicture ?? null },
        },
        enrollments: studies.map((st) => ({
          id: st.id,
          studyTitle: st.title,
          studyDescription: st.description,
          coverImageUrl: st.coverImageUrl ?? null,
          nextLesson: st.nextLessonTitle
            ? {
                id: st.nextLessonId,
                title: st.nextLessonTitle,
                dayNumber: st.nextLessonDay,
                scheduledDate: st.nextLessonDate,
              }
            : null,
        })),
        postsData: [],
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
