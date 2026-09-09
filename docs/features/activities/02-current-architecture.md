# 02 — Current Architecture (what exists, what carries over, what dies)

Survey of the lesson stack as of 2026-08-09 (`main` @ 1647dc8). File references are exact.

## 1. Server data model (`server/prisma/schema.prisma`, generated from `server/schema/schema.yaml`)

### Activity types
```prisma
enum TemplateActivityType {   // schema.prisma:47-53
  USER_INPUT  READ  VIDEO  YOUTUBE  EXEGESIS
}
```
One enum shared by the curriculum table (`LessonActivity` :931) and the member-facing copy
(`ScheduledLessonActivity` :1362, carrying `sourceLessonActivityId`, `versionId`, `lineageKey`).
(The unrelated `Activity` model :1656 is an audit feed — ignore it.)

### Content & theming
- `ActivityReadBlock` (:1454) — paginated blocks within READ/EXEGESIS: `orderNumber`, `title`,
  `content` + `contentFormat`, `isLocked` (Bible text), `themeId`, `backgroundImageUrl/Color`,
  `backgroundOverlayOpacity`, `fontSize` (xs…xl), and derived `selections` JSON (regenerated from
  highlights — never write directly, see :1469).
- `ContentHighlight` (:1484) — source of truth for highlight spans: `start`/`end`, `noteMarkdown`,
  `style` (`highlight`|`bold`), `orderNumber`. (Renamed from `ExegesisHighlight`; consumers
  dual-read during the migration window — `docs/features/highlighting/03-data-and-api.md §2.5`.)
- `ActivitySourceReference` (:1407) — Scripture ref metadata feeding locked blocks.
- `TextTheme` (:1430) — theme catalog: `slug`, `definition` Json, `fontScale` (fraction of
  container width, cqw-style), `maxCharacters` (modeled but **consumed nowhere** in any client),
  `isSystem`/`organizationId`.

### Progress & completion
- `MemberActivityProgress` (:1269) — `startedAt`/`completedAt` + `exegesisVisitedHighlightIds`.
- `MemberVideoProgress` (:1294) — `watchedSeconds`, `watchPercentage`, complete at ≥90%.
- `MemberLessonProgress` (:1321) — rollup `completedAt` + `pinnedVersionId` (completed members
  keep their version forever).
- Endpoints: `server/src/routes/member-lessons.ts` (list / full lesson / summary),
  `server/src/routes/activity-progress.ts` (`POST …/submit` :443-708 incl. SOAP note steps,
  `…/video-progress` :1056, `…/exegesis-visit` :1277-1391 which flips completion when all
  highlights are visited).

### Preview machinery (to be retired — see 07)
`PreviewToken` / `PreviewState` (:1608/:1623) — token-scoped synthetic progress so leaders can
walk a lesson without touching member data; one active token per user.

## 2. Web member player (the thing this feature replaces)

- Route: `GET /member/groups/{g}/lessons/{ls}/{step?}` → `client/routes/web.php:132` →
  `lesson.blade.php` → **`lesson-island.vue`**
  (`client/resources/js/components/domain/lesson-island/`).
- `use-lesson-state.ts` builds a flat `steps` array from activities (:209-232) + a synthetic
  `complete` step. Navigation is **button/URL-driven step paging** (`goToStep` :296 rewrites the
  URL; chevrons live in `member-lesson-header.vue:104-136`), gated per-step by `canProceed`.
- Step components in `steps/`: `video-step.vue`, `youtube-step.vue`, `read-step.vue`,
  `exegesis-step.vue`, `input-step.vue`, `complete-step.vue`.
- Progress calls from `lesson-island.vue`: `saveVideoProgress` :128-140, `markActivityComplete`
  :145-155, `visitExegesisHighlight` :157-174; SOAP notes via `input-step` → `state.saveNote()`.
- `--lesson-vh` CSS var (:90-124) works around WKWebView `dvh` staleness — keep this trick.

### The two coexisting theme players (both replaced by 04)
1. **`ActivityPreviewPlayer.vue`** (`client/resources/js/preview/`, 983 lines) — the canonical
   clock-driven slide player (RAF clock, 0-1 scrub, drag-to-scrub, tap-to-pause, per-block
   `ThemePlayer.vue` in `externalClock` mode, timeline from
   `islands/slides-island/useSlideTimeline.ts`). `read-step.vue` delegates to it.
2. **`themed-content/`** (`components/domain/themed-content/`: `ThemedContent.vue`,
   `ThemedSequencePlayer.vue`, `useTheme.ts`, standalone entry `themed-content-standalone.ts`) —
   a newer parallel renderer; iPhone's `ThemedContentView.swift` loads its bundled HTML (that
   Swift wrapper currently has **no call sites**).
- Theme classes: `client/resources/js/themes/{bold-slide,dramatic-reveal,gentle-fade,no-theme,star-wars,typewriter}/`
  extending `ThemeBase.ts` (which also implements scroll-mode teleprompter helpers :212-304).
- Theme sources on disk: `server/themes/{slug}/theme.json` + `styles.css`, seeded by
  `server/src/scripts/load-themes.ts`. `bible-reader` is scroll-mode, `readBlockSequencing:
  "all-at-once"`, uncapped characters.

### Exegesis member view
`steps/exegesis-step.vue` — verse rows with tappable highlight spans (:271-364, dual-reads legacy
`exegesisHighlights` :100); tapping opens a **bottom-sheet overlay** (`.ExegesisStep__overlay`
:729-743) with ‹/Done/› nav — this is the "split screen" the redesign eliminates.

## 3. iPhone reality

**No native member player exists.** Evidence:
- "Open Lesson" (leader menu) opens the web app in Safari —
  `iphone/MakeReady/Pages/Main/MainHome.swift:509-517`.
- Leader preview embeds the same web player in a WKWebView —
  `Pages/Manage/Program/ReadActivityPreviewModal.swift` (doc comment :1-15 declares the web
  player the single source of truth; auth via short-lived preview token, :10-14).
- All native lesson UI under `Pages/Manage/Program/` is **leader editing** (EditDay,
  EditExegesisActivityPage + `ExegesisVerseView`/`HighlightableTextView` machinery, etc.).

**Consequence:** the native member player is a **green-field build** (09) — there is no legacy
native player to migrate, only the Safari-handoff entry point to replace. The web player is a
rebuild of the existing Vue stack. Both implement the same server contract; the WKWebView
preview modal and Safari handoff are retired rather than extended (the app's direction is 100%
native, WebView avoided).

Reusable native building blocks that already exist for the player:
- `HighlightableTextView` + `TextSelectionController` / `HighlightRenderer` / `HighlightSnapping`
  (`iphone/MakeReady/Components/Content/`) — the exegesis page's text machinery.
- The typed Route/overlay presentation system (present-overlay conventions), `AppState` +
  Actions pattern for progress calls, and the Bible reader's UIKit text stack.

## 4. Edit vs preview today

- Web edit = form panes (`islands/leader-app/components/edit-{read,exegesis,user-input,youtube}-activity-pane.vue`,
  `edit-day-pane.vue`) writing through `activity-editor-actions.ts`.
- Preview = separate tab/URL → `PreviewController.php` (3-strategy auth cascade :222-274,
  `pvw-{token}` synthetic sessions, action proxy :281-296) rendering the same `lesson-island.vue`
  with `isPreview=true`.
- iPhone edit = native SwiftUI forms; preview = the WKWebView modal above.

## 5. Carry-over verdict

| Keep as-is | Adapt | Replace / retire |
|---|---|---|
| Enrollment/schedule/version pipeline (`LessonSchedule*`, sync, lineage) | `TemplateActivityType` (add types, 06) | Step-button navigation (`use-lesson-state` URL paging) |
| Progress endpoints + models (submit / video-progress / exegesis-visit) | `ActivityReadBlock` (gains presentation fields; long-term one block per TEXT page) | Both theme players + timed-slide themes as the member experience (04) |
| `ContentHighlight` + highlighting service (just shipped) | `TextTheme` → token themes (04); `fontScale` concept survives | Exegesis bottom-sheet overlay (06 §exegesis) |
| `--lesson-vh` handling (web/Safari members) | `complete-step` → completion page w/ streak + up-next (03 §7) | `PreviewController` + `PreviewToken`/`PreviewState` (07) |
| Native `HighlightableTextView` stack (exegesis page reuse, 09) | Leader edit panes → edit-in-place layer (07) | `member-lesson-header.vue` chevron chrome |
| Route/overlay system + Actions pattern (hosts the native player, 09) | iPhone leader editors → native edit-in-place (07 §6) | Safari member handoff + `ReadActivityPreviewModal.swift` WKWebView (09) |
