# Lesson Activities Architecture

Cross-app reference for how lesson activities work across server, client, and iPhone.

---

## Activity Types

There are **three** activity types today (with YOUTUBE as the planned fourth):

| Type | Purpose | Key Fields |
|------|---------|------------|
| `READ` | Scripture/text reading with rich content blocks | readBlocks[], sourceReferences[], themeId |
| `VIDEO` | Uploaded video (Cloudflare Stream) | videoId (FK), videoUrl (HLS playback URL) |
| `USER_INPUT` | Study prompts with optional help panel | title, helpTitle, helpDescription, helpIcon, isHelpEnabled, passageReference |
| `YOUTUBE` | External YouTube video (planned) | youtubeUrl, youtubeVideoId, youtubeStartSeconds, youtubeEndSeconds |

**Note:** SOAP, OIA, DBS, and HEAR are study method variants within `USER_INPUT`, not separate activity types. They use the `passageReference` field and differ only in how help text/prompts are configured.

### Where Types Are Defined

| Location | File | Notes |
|----------|------|-------|
| Server (Prisma) | `server/prisma/schema.prisma` line 47 | `enum TemplateActivityType { USER_INPUT, READ, VIDEO }` |
| Client (Admin UI) | `client/resources/js/components/admin/admin-activity-list/admin-activity-list.vue` line 35 | activityTypes array (includes SOAP/OIA/DBS/HEAR as UI labels for USER_INPUT) |
| iPhone | `iphone/MakeReady/Pages/Manage/Program/Models/StudyModels.swift` line 744 | `enum ActivityType` with all cases |

---

## Data Flow

### Lifecycle of an Activity

```
LessonTemplate
└── LessonTemplateActivity (defines structure: type, orderNumber, title)
        │
        │ (program created → template activities copied)
        ▼
StudyProgram
└── Lesson (one per day)
    └── LessonActivity (editable by leader)
            │
            │ (enrollment created → activities snapshotted)
            ▼
        ScheduledLessonActivity (per-group copy)
            │
            │ (member progresses through lesson)
            ▼
        MemberActivityProgress (startedAt, completedAt)
        MemberVideoProgress (watchedSeconds, watchPercentage, completedAt at 90%)
```

### Key Relationships

- **LessonActivity** belongs to a **Lesson** (via `lessonId`)
- **LessonActivity** optionally belongs to a **Video** (via `videoId`) for VIDEO type
- **LessonActivity** has many **ActivityReadBlock** records (for READ type)
- **LessonActivity** has many **ActivitySourceReference** records (scripture passages)
- **ScheduledLessonActivity** mirrors LessonActivity but is tied to a **LessonSchedule** (enrollment-specific)

---

## CRUD Endpoints

### Admin Activity Management

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/admin/api/programs/:programId/lessons/:lessonId/activities` | Create activity |
| PATCH | `/admin/api/activities/:activityId` | Update activity fields |
| DELETE | `/admin/api/activities/:activityId` | Delete activity |
| POST | `/admin/api/programs/:programId/lessons/:lessonId/reorder-activities` | Reorder activities |
| POST | `/admin/api/activities/:activityId/reset` | Reset activity content |

### Read Blocks (READ type sub-resource)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/admin/api/activities/:activityId/read-blocks` | Add block |
| PATCH | `/admin/api/activities/:activityId/read-blocks/:blockId` | Update block |
| DELETE | `/admin/api/activities/:activityId/read-blocks/:blockId` | Delete block |
| PATCH | `/admin/api/activities/:activityId/read-blocks/reorder` | Reorder blocks |

### Source References (scripture passages)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/admin/api/activities/:activityId/source-references` | Add reference |

### Member Progress

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/member/lessons` | List member's lessons |
| GET | `/api/member/lessons/:lessonScheduleId` | Lesson detail with activities |
| POST | `/api/member/activities/:activityId/progress` | Save progress + notes |
| GET | `/api/member/activities/:activityId/progress` | Get progress |
| POST | `/api/member/activities/:activityId/submit` | Submit response (start, complete) |
| POST | `/api/member/activities/:activityId/video-progress` | Save video watch progress |
| GET | `/api/member/activities/:activityId/video-progress` | Get video watch progress |

### Create Activity Payload

```json
{
  "activityType": "READ | VIDEO | USER_INPUT | YOUTUBE",
  "title": "Activity title"
}
```

### Update Activity Payload (type-specific fields)

```json
{
  "title": "string",
  "isHelpEnabled": "boolean",
  "helpTitle": "string?",
  "helpDescription": "string?",
  "helpIcon": "string? (SF Symbol name)",

  "readContent": "string? (READ type)",
  "videoUrl": "string? (VIDEO type)",
  "videoId": "string? (VIDEO type)",
  "passageReference": "string? (USER_INPUT study methods)",
  "youtubeUrl": "string? (YOUTUBE type)",
  "youtubeStartSeconds": "number? (YOUTUBE type)",
  "youtubeEndSeconds": "number? (YOUTUBE type)"
}
```

---

## Rendering by App

### Client — Member Lesson Flow

**File:** `client/resources/js/components/domain/lesson-island/lesson-island.vue`

Builds a step array from lesson activities, then renders type-specific components:

| Activity Type | Step Component | Behavior |
|---------------|---------------|----------|
| `VIDEO` | `video-step.vue` | HLS video player, emits progress at 90%, emits `next` on end |
| `READ` | `read-step.vue` | ActivityPreviewPlayer with themed blocks, scripture fetch |
| `USER_INPUT` | `input-step.vue` | Textarea prompt with help panel, submits notes |
| `YOUTUBE` | `youtube-step.vue` (planned) | YouTube iframe embed with progress tracking |
| (final) | `complete-step` | Lesson completion screen |

### Client — Admin Editor

**File:** `client/resources/js/components/admin/admin-activity-list/admin-activity-list.vue`

Accordion-based list with:
- Drag-to-reorder (VueDraggable)
- Type selector dropdown
- Title input
- Type-specific fields (video URL, read blocks, passage reference, etc.)
- Help panel toggle (title, description, icon)

### iPhone — Leader Editor

**File:** `iphone/MakeReady/Pages/Manage/Program/EditDay.swift`

Switches on activity type to show type-specific editor:
- `.read` → `EditReadActivityPage` (multi-block editor with Bible selection)
- `.userInput` → `EditUserInputActivityPage` (title + help text form)
- `.video` → `VideoActivityPicker` (select from video library)
- `.youtube` → `EditYouTubeActivityPage` (planned — URL paste + preview)

**Add menu:** `iphone/MakeReady/Components/Navigation/AddActivityMenu.swift` — bottom sheet with activity type cards.

### iPhone — Member Lesson Flow

Activities rendered within scheduled lesson views using the `ScheduledActivity` model. Video activities use AVPlayer (Cloudflare HLS). YouTube will need WKWebView or deep-link to YouTube app.

---

## Key Files

### Server

| File | Purpose |
|------|---------|
| `server/prisma/schema.prisma` | Database models: LessonActivity, ScheduledLessonActivity, Video, progress models |
| `server/src/routes/programs.ts` | Program + lesson + activity creation |
| `server/src/routes/activity-progress.ts` | Member progress, video progress, note submission |
| `server/src/routes/member-lessons.ts` | Member lesson list/detail |
| `server/src/services/activity.ts` | Activity ledger tracking |
| `server/src/services/member-progress.service.ts` | Progress + completion logic |
| `server/src/services/notes.service.ts` | Study notes linked to activities |

### Client

| File | Purpose |
|------|---------|
| `client/resources/js/components/admin/admin-activity-list/admin-activity-list.vue` | Admin activity CRUD UI |
| `client/resources/js/islands/admin-island/stores/domain/programs.domain.ts` | Activity CRUD store + API calls |
| `client/resources/js/islands/admin-island/stores/ui/activity-detail.ui.ts` | Editor UI state |
| `client/resources/js/components/domain/lesson-island/lesson-island.vue` | Member lesson step builder |
| `client/resources/js/components/domain/lesson-island/steps/video-step.vue` | VIDEO player |
| `client/resources/js/components/domain/lesson-island/steps/read-step.vue` | READ renderer |
| `client/resources/js/components/domain/lesson-island/steps/input-step.vue` | USER_INPUT prompt |

### iPhone

| File | Purpose |
|------|---------|
| `iphone/MakeReady/Pages/Manage/Program/Models/StudyModels.swift` | Activity models + ActivityType enum |
| `iphone/MakeReady/Pages/Manage/Program/EditDay.swift` | Lesson editor (switches on type) |
| `iphone/MakeReady/Components/Navigation/AddActivityMenu.swift` | Add activity type menu |
| `iphone/MakeReady/State/Actions/ProgramActions.swift` | Activity CRUD actions |
| `iphone/MakeReady/Components/Card/CardLessonActivity.swift` | Activity card display |

---

## Checklist: Adding a New Activity Type

When adding a new activity type, update all of the following:

### 1. Server (Database + API)
- [ ] Add to `TemplateActivityType` enum in `server/prisma/schema.prisma`
- [ ] Add type-specific fields to `LessonActivity` model
- [ ] Add same fields to `ScheduledLessonActivity` model
- [ ] Run Prisma migration
- [ ] Handle new type in activity create/update routes
- [ ] Add any new service logic (e.g., metadata fetching)
- [ ] Ensure scheduled activity copy includes new fields

### 2. Client (Admin + Member)
- [ ] Add to `activityTypes` array in `admin-activity-list.vue`
- [ ] Add type-specific editor fields in admin UI
- [ ] Add `isNewType` computed in `activity-detail.ui.ts`
- [ ] Create step component in `lesson-island/steps/`
- [ ] Add case to step builder in `lesson-island.vue`
- [ ] Handle save payload for new type fields in `handleSaveActivity()`

### 3. iPhone (Leader + Member)
- [ ] Add case to `ActivityType` enum in `StudyModels.swift`
- [ ] Add option to `AddActivityMenu.swift`
- [ ] Create editor page (e.g., `EditNewTypeActivityPage.swift`)
- [ ] Add case to `EditDay.swift` switch statement
- [ ] Handle in member lesson flow rendering
- [ ] Add to `ProgramActions.swift` if new API calls needed

### 4. Progress Tracking
- [ ] Determine completion criteria (e.g., 90% video watched, block finished)
- [ ] Ensure `MemberActivityProgress` or `MemberVideoProgress` handles it
- [ ] Update `checkAndUpdateLessonCompletion()` if needed

---

## YouTube Activity Specification

### Leader Settings

| Setting | Required | Default | Purpose |
|---------|----------|---------|---------|
| YouTube URL | Yes | — | Any youtube.com or youtu.be link |
| Start Time | No | 0 (beginning) | Skip intro, jump to content |
| End Time | No | None (full video) | Stop before irrelevant content |
| Loop | No | OFF | Repeat for meditation/worship |

**Always applied (not configurable):**
- `rel=0` — no related video suggestions
- `modestbranding=1` — minimize YouTube branding
- Privacy-enhanced mode (`youtube-nocookie.com`) — no viewer tracking

### Auto-populated from oEmbed (server-side)

When leader pastes a YouTube URL, the server fetches metadata:
- Video title → used as activity title if leader doesn't set one
- Thumbnail URL → stored for card display
- Channel name → shown as attribution

**oEmbed endpoint:** `https://youtube.com/oembed?url={url}&format=json` (no API key needed)

### URL Formats to Support

```
https://www.youtube.com/watch?v=VIDEO_ID
https://youtu.be/VIDEO_ID
https://www.youtube.com/embed/VIDEO_ID
https://youtube.com/watch?v=VIDEO_ID&t=90  (extract start time)
```

### Completion Criteria

Same as VIDEO: mark complete when member has watched >= 90% of the video duration (respecting start/end time bounds).

### Mobile Considerations

- **Web client:** Standard YouTube iframe embed works fine
- **iPhone:** Use WKWebView with `youtube-nocookie.com` embed. If playback fails (Error 150/153), fall back to opening in YouTube app via `youtube://` deep link or Safari
- **Progress tracking:** YouTube IFrame Player API `onStateChange` events + `getCurrentTime()` method, bridged to native via JavaScript message handlers
