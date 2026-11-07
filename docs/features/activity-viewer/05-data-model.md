# 05 — The data model and one-time export

The storage for the new app, designed as if 1.0 didn't exist (owner ruling 2026-11-06: zero users, no
legacy support, production content moves once by export). `02` defines what's inside a document; this
file defines where documents live and how they change.

**Status:** ruled by the owner, 2026-11-06, including group edits going live on Done, the Vue cutover in §7 and the export scope in §6. The build in `docs/features/text-activity/SPEC.md` narrows it: `Prayer`, `ActivityResponse`, member endpoints and group forking wait for the member rebuild.

## 1. What the product has to do

Read from today's behavior as requirements, not as a structure to keep:

| Need | Why |
|---|---|
| Leaders draft a program without members seeing edits | Publish is an explicit step |
| A group can follow program updates automatically, on approval, or not at all | `syncMode` AUTO, APPROVAL, OFF |
| A leader can customize a lesson for one group | Includes group-only activities |
| A member who finished a lesson keeps seeing what they finished | Pinned at completion |
| A member's progress survives a content update | Today this needs a copy-forward step |
| Leaders see what changed between versions | Change summary and per-lesson drift |
| Media stays deletable only when unused | `MediaUsage` |

## 2. The model

Three ideas do the work:

1. **A lesson's content is a sequence of immutable versions.** Only a draft can be edited.
2. **A group points at a version.** Updating a group moves a pointer. Nothing is copied.
3. **An activity has a stable `activityKey` across versions.** Progress hangs off the key, so it
   survives updates with no carry-forward step.

```
StudyProgram
 ├─ ProgramVersion ──< ProgramVersionLesson >─┐      what "version 7" contains
 └─ Lesson (identity, position)               │
     └─ LessonVersion (DRAFT or PUBLISHED) ◄──┘
         └─ Activity (activityKey, position, kind, document)
                ▲
Enrollment      │ currentVersionId moves on sync
 └─ ScheduledLesson ──► LessonVersion
     ├─ LessonProgress (pinnedVersionId)
     ├─ ActivityProgress (by activityKey)
     └─ ActivityResponse (by activityKey)
```

```prisma
model Lesson {
  id        String @id @default(uuid())
  programId String
  position  Int              // day number
  versions  LessonVersion[]
  @@unique([programId, position])
}

model LessonVersion {
  id               String   @id @default(uuid())
  lessonId         String?  // null once the curriculum lesson is deleted; groups keep their version
  enrollmentId     String?  // set = this group's own customized version; null = the program's
  number           Int      // per lesson + enrollmentId, starts at 1
  status           LessonVersionStatus   // DRAFT | PUBLISHED
  title            String?
  contentHash      String   // lets publish skip a lesson that didn't change
  estimatedSeconds Int?     // computed on publish
  basedOnVersionId String?  // what it was forked or edited from
  publishedAt      DateTime?
  publishedById    String?
  activities       Activity[]
  @@unique([lessonId, enrollmentId, number])
}

model Activity {
  id               String @id @default(uuid())
  lessonVersionId  String
  activityKey      String // stable across versions; new key only when a leader adds an activity
  position         Int
  kind             String // text | bible | video | youtube | write | poll | …
  title            String
  document         Json   // 02
  estimatedSeconds Int?
  @@unique([lessonVersionId, activityKey])
  @@unique([lessonVersionId, position])
}

model ProgramVersion {
  id            String @id @default(uuid())
  programId     String
  number        Int
  changeSummary String? @db.Text
  publishedAt   DateTime @default(now())
  publishedById String?
  lessons       ProgramVersionLesson[]
  @@unique([programId, number])
}

model ProgramVersionLesson {
  programVersionId String
  lessonId         String
  lessonVersionId  String
  position         Int
  @@id([programVersionId, lessonId])
}

model ScheduledLesson {
  id               String @id @default(uuid())
  code             String? @unique
  enrollmentId     String
  lessonId         String?
  scheduledDate    DateTime
  currentVersionId String    // the version members see
  removedAt        DateTime? // removed by sync after a member had progress
  @@unique([enrollmentId, lessonId])
}

model LessonProgress {
  memberId          String
  scheduledLessonId String
  startedAt         DateTime @default(now())
  completedAt       DateTime?
  pinnedVersionId   String?  // set at completion; that member keeps this version
  @@id([memberId, scheduledLessonId])
}

model ActivityProgress {
  memberId          String
  scheduledLessonId String
  activityKey       String
  startedAt         DateTime @default(now())
  completedAt       DateTime?
  state             Json?    // by kind: { watchedSeconds, totalSeconds } · { visitedHighlightIds } · …
  @@id([memberId, scheduledLessonId, activityKey])
}

model ActivityResponse {
  id                String @id @default(uuid())
  memberId          String
  scheduledLessonId String
  activityKey       String
  actionId          String?  // set when a page's action wrote it; null for the kind's own input
  kind              String   // write | poll | …
  body              Json
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt
  @@index([scheduledLessonId, activityKey])
}

model Prayer {
  id                String @id @default(uuid())
  memberId          String
  title             String
  body              String @db.Text
  scheduledLessonId String?  // where it came from, when it came from a lesson
  activityKey       String?
  answeredAt        DateTime?
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt
  @@index([memberId])
}
```

## 3. How each operation works

| Operation | What happens |
|---|---|
| Open a lesson to edit | Reads the lesson's draft. If none exists, copies the latest published version into a new draft, keeping every `activityKey` |
| Add an activity | New row in the draft, new `activityKey`. Tile tap creates it; an untouched one is deleted on backing out |
| Done in the editor | Replaces that activity's whole `document` in the draft, validated against `02` |
| Reorder or delete | Changes rows in the draft |
| Publish | For each lesson with a draft: if `contentHash` matches the latest published version, discard the draft. Otherwise freeze it. Then write one `ProgramVersion` listing every lesson's version |
| Enroll a group | Creates `ScheduledLesson` rows pointing at the program version's lessons. No content copied |
| Sync | `currentVersionId` moves to the new version. Lessons absent from the new version: deleted if no member progress, otherwise `removedAt` |
| Leader customizes for one group | Same draft flow with `enrollmentId` set, forked from the group's current version. **Done publishes it at once**, so group edits are live right away, and `currentVersionId` moves |
| Sync on a customized lesson | Skipped for that lesson and reported to the leader, who can reset it to the program's version |
| Member opens a lesson | Sees `pinnedVersionId` if set, otherwise `currentVersionId` |
| Member finishes | `pinnedVersionId` is set to what they saw |
| Compare versions | Diff `Activity` rows of two versions by `activityKey`. No stored snapshot needed |

**The editor, API and progress code are shared by program and group content.** A group's lesson is a
`LessonVersion` like any other, so one set of endpoints replaces two:

```
GET    /api/lessons/:id/draft
POST   /api/lesson-versions/:id/activities
PUT    /api/activities/:id                  whole document
DELETE /api/activities/:id
PATCH  /api/lesson-versions/:id/activities/order
POST   /api/programs/:id/publish
GET    /api/scheduled-lessons/:id           resolved for the current member
PUT    /api/scheduled-lessons/:id/progress/:activityKey
POST   /api/scheduled-lessons/:id/responses
```

Group customization starts with `POST /api/scheduled-lessons/:id/fork`, and then uses the same routes.
Authorization is decided from the version's owner: the program's organization, or the enrollment's
group.

## 4. Media and scripture inside documents

JSON can't hold a foreign key, so on every save the server extracts what the document names:

- **Media:** `background.image.mediaId`, `posterMediaId`, `avatarMediaId` and `videoId` become
  `MediaUsage` rows with `usageType: ACTIVITY` and `resourceId` = the activity's id. A media item in use by any
  version can't be deleted.
- **Scripture:** `bible` documents carry `passages: [{ bookNumber, chapterStart, verseStart, chapterEnd, verseEnd }]`.
  Search, share previews and AI summaries read that list. If a query ever needs an index, it gets a
  table derived on save; the document stays the source.

Size is cheap: a new version copies only JSON, at most 256 KB per activity. Versions aren't deduplicated
by content, because the storage saved isn't worth a second layer of indirection.

## 5. Removed

| Removed | Replaced by |
|---|---|
| `LessonActivity`, `ScheduledLessonActivity` | `Activity` |
| `ActivityReadBlock` and its derived `selections` | `document` |
| `ContentHighlight` and its 16 routes (program and scheduled, each with an `exegesis-` alias) | `highlights` inside the document, saved whole |
| `ActivitySourceReference` | `passages` inside the document |
| `TextTheme` and animated themes | Per-object styling (`02` §3) |
| `LessonSchedule`, `LessonScheduleVersion` | `ScheduledLesson` + `LessonVersion` |
| `MemberActivityProgress`, `MemberVideoProgress` | `ActivityProgress` |
| `MemberLessonProgress` | `LessonProgress` |
| `StudyProgramVersion.snapshot`, `lessonHashes`, `changedLessonIds` | `ProgramVersionLesson`, diffed on demand |
| `StudyNote` type `PRAYER`, and polymorphic `NoteLink` for these | `Prayer`, `ActivityResponse` |
| `TemplateActivityType` | `kind` as validated text, so a new kind needs no database migration |
| `EnrollmentSyncRun` | Kept only if fan-out stays asynchronous; moving a pointer is fast enough to do it in a transaction |

**Why `Prayer` is its own table:** a prayer has its own life after the lesson (answered, and sharing
later), and the recording's sheet edits it as a personal item. A generic note with a type string can't
express that. `StudyNote` stays for notes.

**Also changing:** `LessonTemplateActivity` gains `kind` + a starter `document`. `Event`,
`AiLessonSummary` and the analytics materialized view move to `ScheduledLesson` and `activityKey`.

## 6. The one-time export

**Scope (owner ruling):** programs, lessons, activities, templates and media, with the organizations and
users that own them staying where they are. Not carried: members, enrollments, progress, notes,
analytics, since there are no users.

**How it runs:** a script reads a production dump, never production itself, and writes a reviewable
report, then imports into the new tables. It's safe to re-run, because `activityKey` = the old
`LessonActivity.id`. Files stay in R2, so media URLs don't move.

| Old type | Becomes |
|---|---|
| `VIDEO` | `video` |
| `YOUTUBE` | `youtube` |
| `USER_INPUT` | `write`. Prompt from the title and help text; placeholder kept |
| `EXEGESIS` | `bible`, with highlights and notes moved into its text object |
| `READ`, locked scripture block | `bible` |
| `READ`, one or more unstyled text blocks | `text`, one long object, markdown converted to `weight` and `marks` |
| `READ`, a block with its own background | Its own `text` activity, since a document has one background |

Details:

- Each program's latest published content becomes version 1, `PUBLISHED`. Unpublished edits become its draft.
- A `backgroundImageUrl` with no `Media` row gets one registered on import.
- Themes are dropped, and each block's font scale converts to a `size`. Animated themes import as static.
- **Layout:** imported text lands in a single column at the top of the canvas (`verticalAnchor: top`),
  with 24u margins. It's a reasonable start, not a designed composition, so leaders may want to adjust some.

**The report** lists, per program, activity counts by old type and new kind, plus everything dropped or
converted with loss: animated themes, HTML the converter can't map, and blocks split into separate
activities. Nothing goes to production until the owner has read it.

## 7. Cutover

There are no users to protect, so old and new don't run side by side for long. The only sequencing
need is keeping the leader app working during development.

```
1. Server: new tables, new endpoints, export script. Old tables still there.
2. iPhone: Actions and models move to the new endpoints. Only 5 UI2 files touch activities today.
3. Dry-run export against a production dump; owner reads the report.
4. Cut: export, import, deploy. Delete the old tables, routes and services.
```

**What stops working at step 4:** the Vue client's member lesson screens and leader pages, which read
the old endpoints, until the React member app replaces them. The owner has accepted this.
