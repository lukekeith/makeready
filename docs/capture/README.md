# Capture Screen Manifest

Per-screen documentation of every iPhone screen and the custom components (with the
specific **variants**) each one composes. This is the source-of-truth checklist for what
must exist in the `/compare` capture tool to reach iPhone ↔ Web parity.

- **One file per screen**, named by screen (e.g. [`home-dashboard.md`](home-dashboard.md)).
- Each file lists the custom MakeReady components used on that screen, the variant(s) in
  use, and the screen-level states (loading / empty / populated / role splits).
- Component variants are derived from each component's own Swift definition (style enums,
  init shapes, `#Preview` cases).
- For the comparison build-status todo list, see [`manifest.md`](manifest.md).

Scope: real product screens under `iphone/MakeReady/Pages/`. Dev-only `Pages/Demo/*`
screens are intentionally excluded.

## Screens by area

### Main tabs
- [Home Dashboard](home-dashboard.md) — `MainHome`
- [Calendar](calendar.md) — `MainCalendar` (the live Schedule tab)
- [Groups List](groups-list.md) — `MainGroups` → `MemberHomePage`
- [Media Library](media-library.md) — `MainLibrary` + `MediaLibraryGrid`
- [Study Program Home](study-program-home.md) — `StudyProgramHome` / `MainPrograms`

### Groups
- [Group Home](group-home.md) — `GroupHomePage`
- [Create Group](create-group.md) — `CreateGroupPage`
- [Edit Group](edit-group.md) — `EditGroupPage`
- [Group Invite](group-invite.md) — `GroupInvitePage`
- [Group Members](group-members.md) — `GroupMembersPage`
- [Select Enroll Date](select-enroll-date.md) — `SelectEnrollDatePage`

### Enrollment
- [Enrollment Flow](enrollment-flow.md) — `EnrollmentFlowModal`
- [Confirm Enrollment](confirm-enrollment.md) — `ConfirmEnrollmentPage`
- [Edit Enrollment Day](edit-enrollment-day.md) — `EditEnrollmentDay`
- [Enrollment Schedule](enrollment-schedule.md) — `EnrollmentSchedulePage`
- [Enrollments List](enrollments-list.md) — `EnrollmentsListPage`
- [Select Group](select-group.md) — `SelectGroupPage`
- [Select Study Program](select-study-program.md) — `SelectStudyProgramPage`
- [Study Invite](study-invite.md) — `StudyInvitePage`
- [Unenroll Options](unenroll-options.md) — `UnenrollOptionsModal`

### Members
- [Member Home](member-home.md) — `MemberHomePage`
- [Member Overview](member-overview.md) — `MemberOverview`
- [Member Profile](member-profile.md) — `MemberProfilePage`
- [Member Request Profile](member-request-profile.md) — `MemberRequestProfilePage`
- [Member Requests](member-requests.md) — `MemberRequestsPage`
- [Member Request Respond](member-request-respond.md) — `MemberRequestRespondModal`
- [Change Membership](change-membership.md) — `ChangeMembershipModal`

### Programs & Org
- [Program Home](program-home.md) — `ProgramHomePage`
- [Create Program](create-program.md) — `CreateProgramPage`
- [Edit Day](edit-day.md) — `EditDay`
- [Edit Exegesis Activity](edit-exegesis-activity.md) — `EditExegesisActivityPage`
- [Edit Read Activity](edit-read-activity.md) — `EditReadActivityPage`
- [Edit User-Input Activity](edit-user-input-activity.md) — `EditUserInputActivityPage`
- [Edit YouTube Activity](edit-youtube-activity.md) — `EditYouTubeActivityPage`
- [Exegesis Highlight](exegesis-highlight.md) — `ExegesisHighlightModal`
- [Read Activity Preview](read-activity-preview.md) — `ReadActivityPreviewModal`
- [Org Home](org-home.md) — `OrgHomePage`

### Search, Notifications & Profile
- [Global Search](global-search.md) — `GlobalSearchPage`
- [Event Detail](event-detail.md) — `EventDetailPage`
- [Lesson Detail](lesson-detail.md) — `LessonDetailPage` (delegates to `EditDay`)
- [Post Detail](post-detail.md) — `PostDetailPage`
- [Notification Feed](notification-feed.md) — `NotificationFeedPage`
- [Profile](profile.md) — `ProfilePage`

### Video
- [Video Library](video-library.md) — `VideoLibraryPage`
- [Video Recorder](video-recorder.md) — `VideoRecorderPage` / `CustomVideoRecorder`
- [Video Player](video-player.md) — `VideoPlayerPage` / `ActivityVideoPlayer`
- [Select Video](select-video.md) — `SelectVideoPage`
- [Video Activity Picker](video-activity-picker.md) — `VideoActivityPicker`
- [Teleprompter](teleprompter.md) — `TeleprompterOverlay`
- [Video Preview](video-preview.md) — `VideoPreviewOverlay`
- [Video Source Menu](video-source-menu.md) — `VideoSourceMenu`

### Bible, Media & Contacts
- [Bible Reader](bible-reader.md) — `BibleReaderOverlay`
- [Bible Version Menu](bible-version-menu.md) — `BibleVersionMenu`
- [Media Detail](media-detail.md) — `MediaDetailOverlay`
- [Invite Contacts](invite-contacts.md) — `InviteContactsPage`
- [Search Contacts](search-contacts.md) — `SearchContactsPage`
- [Schedule](schedule.md) — `SchedulePage` (stub; real UI is `MainCalendar`)

## Cross-screen findings worth knowing

- **`PageTitle` and `PageHeader` are the universal chrome** — nearly every screen uses one,
  across `PageTitle` variants `.iconTitle` / `.iconTitleLink` / `.linkTitleLink` /
  `.iconTitleIcons`.
- **Several screens are hand-rolled or pure UIKit**, reusing few/no inventory components —
  notably the Bible reader, version menu, media detail (UIKit), `SelectEnrollDatePage`
  (bespoke calendar), and the two full-screen member modals. These are flagged per file as
  parity risks because their web twins can't reuse existing components.
- **Camera/AVFoundation surfaces** (recorder, player, live preview) won't render in static
  captures; the video docs note which chrome/states are capturable.
- **Wrapper screens** delegate their real UI elsewhere: `MainGroups` → `MemberHomePage`,
  `LessonDetailPage` → `EditDay`, `SchedulePage` → `MainCalendar`.
