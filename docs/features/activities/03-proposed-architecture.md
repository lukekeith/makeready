# 03 — Proposed Architecture: the Vertical Pager

## 1. Shape of the thing

One **Lesson Pager** design, implemented twice against the same server contract:

- **Web**: the Vue pager — the **only member runtime** (members never use the iPhone app) —
  replaces `lesson-island.vue`'s step navigation, `ActivityPreviewPlayer.vue`, and the
  `themed-content` renderer.
- **iPhone**: the native SwiftUI/UIKit pager (09) — the leader's edit canvas + walkthrough,
  rendering identically but never writing member progress.

This doc specifies the shared contract (structure, lifecycle, data model, progression) using the
web component tree as the naming reference; §2's scroll mechanics are web-specific, with the
native equivalents in 09. Everything in §3-§7 is platform-neutral.

```
LessonPager.vue                     ← one native scroller, scroll-snap, owns gesture physics
├── LessonBackdrop.vue              ← z-0: lesson-shared fixed background (image/video/color + scrim)
├── ActivityPage.vue  × N           ← z-1: one per activity; min-height 100dvh; snap-align start
│   ├── PageBackground.vue          ← optional per-page opaque panel (overrides backdrop visually)
│   ├── PageContent (per type)      ← TextPage / BiblePage / VideoPage / ImagePage / WritePage /
│   │                                 YouTubePage / ExegesisPage  (see 06)
│   └── PageActions                 ← action buttons (add-to-prayer-list, …) → bottom sheets
├── CompletionPage.vue              ← synthetic final page: ✓ badge, streak, up-next, swipe-up hint
├── PagerRail.vue                   ← fixed right-edge dot rail (activity index + intra-page thumb)
├── PagerChrome.vue                 ← fixed X + contextual action (mute/share), top scrim
└── SheetHost.vue                   ← bottom sheets (prayer save, write input expansion, …)
```

## 2. Scrolling & gesture model

**Native scroll + CSS scroll-snap, not a JS-driven virtual pager.**

```css
.LessonPager { overflow-y: auto; scroll-snap-type: y mandatory; height: 100dvh; }
.ActivityPage { min-height: var(--lesson-vh, 100dvh); scroll-snap-align: start; scroll-snap-stop: always; }
```

- Short pages (≤ viewport): snap page-to-page exactly like the recordings.
- Long pages (article, long prayer): taller than the viewport, so native snap lets the user
  scroll freely through the middle and only snaps when the next page's edge approaches — this is
  precisely the observed "scroll to the bottom, then swipe beyond the sticky bottom" behavior,
  for free, with correct iOS physics, rubber-banding, and interruptibility.
- `scroll-snap-stop: always` prevents fling-skipping activities.
- Keep the existing `--lesson-vh` WKWebView workaround (`lesson-island.vue:90-124`) as the page
  height variable.
- **Advance gating** (video that must finish, write that requires input): a gated page sets
  `overscroll-behavior` trap + a scroll clamp on the pager (JS: prevent scrollTop passing the
  gated page's bottom edge; nudge-and-settle-back animation communicates the lock). The rail and
  a gentle bounce are the affordance — no visible "locked" chrome in the reference.
- Programmatic navigation (rail taps in edit mode, deep-link `?step=n`): `scrollTo` with
  `behavior: smooth`.

**Why not a transform-based pager (web):** the reference's feel *is* native scrolling
(finger-tracked, interruptible, no overshoot). Reimplementing that with pointer events + springs
is the expensive path. Everything custom in the reference happens *after* the scroll settles
(entrance choreography), which observers handle cleanly. The same principle drives the native
implementation: ride the platform scroller, never fake it (09 §2).

## 3. Page lifecycle state machine

Driven by one `IntersectionObserver` (thresholds `[0, .6, .99]`) + a scroll-idle detector:

```
offscreen → approaching (>0 visible; mount media, warm video)
          → settling   (≥60% visible; page is "current": rail updates, progress `startedAt` fires)
          → settled    (snap complete + scroll idle; entrance choreography runs — see 05)
          → passed     (scrolled beyond; passive types report complete — see §6)
```

- Entrance choreography runs **once per entry** (re-entry from above replays nothing by default;
  the checkmark badge on the completion page re-draws on every entry — per-component choice).
- `approaching` is the media-preload hook: next page's image decoded, video element created and
  buffering, YouTube iframe primed — so autoplay at `settled` is instant.
- The pager exposes a tiny store (Pinia): `pages[]`, `currentIndex`, `intraProgress` (0-1 within
  current page, from scroll math), `entranceState` per page. `PagerRail` and `PagerChrome` are
  pure consumers.

## 4. Data model changes (server)

Additive; existing lessons must render unchanged through a compatibility mapping.

### 4.1 New activity types
`TemplateActivityType` += `TEXT`, `IMAGE`, `BIBLE` (kept: `USER_INPUT`(=write), `READ`(legacy),
`VIDEO`, `YOUTUBE`, `EXEGESIS`). Details + per-type content shape in 06. Legacy `READ`
activities render as a sequence of TEXT/BIBLE pages derived from their `ActivityReadBlock`s
(one block = one page) — no data migration required on day one.

### 4.2 Presentation fields (on `LessonActivity` + `ScheduledLessonActivity`)
```yaml
# schema/schema.yaml additions (nullable, defaulted)
eyebrow:            String?     # "HONOR GOD" — small-caps label
layout:             enum? PageLayout { TOP, CENTER }        # default per type (text=CENTER, article=TOP)
background:         Json?       # { mode: 'inherit'|'color'|'image'|'video', value, overlayOpacity }
textRole:           enum? TextRole { SCRIPTURE, VOICE }     # serif vs sans; default per type
scale:              enum? TextScale { S, M, L, XL }         # reuses fontSize vocabulary
advanceRule:        enum? AdvanceRule { FREE, AFTER_MEDIA, AFTER_INPUT, AFTER_HIGHLIGHTS }
revealMode:         enum? RevealMode { GROUPS, WORDS }      # 05 §3/§4; GROUPS default
actions:            Json?       # [{ type: 'ADD_TO_PRAYER_LIST', label? }, …]
```

### 4.3 Lesson-level presentation (on `Lesson`, snapshotted into versions like everything else)
```yaml
backdrop:           Json?       # { mode: 'image'|'video'|'color', value, scrimOpacity } — video-1 style
chromeAction:       enum? { AUDIO, SHARE, NONE }
paletteThemeId:     String?     # token theme, see 04
```

### 4.4 Streak + up-next (completion page data)
- New rollup: `MemberStreak` (member × enrollment): `current`, `longest`, `lastCompletedDate` —
  maintained inside the existing `checkAndUpdateLessonCompletion` path
  (`server/src/routes/activity-progress.ts`), counting **consecutive scheduled lessons completed
  by their scheduled date** (exact rule = open question 08 §3).
- `GET /api/member/lessons/:id` response += `streak` and `upNext` (next `LessonSchedule` in the
  enrollment: title, description, coverUrl, code) so the completion page needs no second fetch.

## 5. Progression & completion wiring (mostly existing endpoints)

| Event | Call |
|---|---|
| Page `settling` first time | `POST …/submit { action: 'start' }` → `MemberActivityProgress.startedAt` |
| Passive page (TEXT/IMAGE/BIBLE) passed | `POST …/submit { action: 'complete' }` |
| VIDEO/YOUTUBE heartbeat (15s + on pass) | `POST …/video-progress` (≥90% rule unchanged) |
| WRITE saved (sheet or inline) | `POST …/submit { note: … }` (SOAP step mapping unchanged) |
| Exegesis highlight opened | `POST …/exegesis-visit` (unchanged) |
| All activities complete | server flips `MemberLessonProgress.completedAt`, updates streak |
| Completion page settled | client shows streak/up-next from initial payload |

Gating stays server-checkable (`advanceRule`) but is enforced client-side exactly as today's
`canProceed` — the server remains the source of truth for *completion*, not for *scroll position*.

## 6. Completion page & dismissal

- Synthetic final page appended by the pager (replaces `complete-step.vue`): entrance = checkmark
  draw (05 §5) → title/streak badge fade-up → up-next card → "^ Swipe Up" hint (idle-pulses).
- Over-scroll dismissal: at the last page, upward over-scroll past ~80px (or a flick) triggers
  sheet dismissal — the whole pager translates down 100% (400ms ease-in) revealing what's behind
  (iPhone: the native modal dismisses through the Route system, 09 §7; web: navigate back to the
  member group page).
- X button = same dismissal at any time (progress already persisted incrementally).

## 7. What happens to the existing player

`lesson-island.vue` mounts the new `LessonPager` behind a per-enrollment feature flag
(`lessonExperience: 'pager' | 'legacy'`) during rollout; the step components, header chevrons,
`ActivityPreviewPlayer`, `useSlideTimeline`, `ThemePlayer`, and `themed-content/*` are deleted
when the flag defaults on and the last legacy-only theme (star-wars, typewriter…) is either
ported as a `revealMode` variant or sunset (08 §2).

## 8. App impact summary

| App | Impact |
|---|---|
| server | enum + presentation fields + streak rollup + payload additions; zod schemas; version snapshot fields |
| client | the Vue pager (member runtime); web edit-in-place (07); retire preview routes |
| iphone | **native pager for leaders** (09): edit canvas + walkthrough; native edit-in-place (07 §6, phased); delete `ReadActivityPreviewModal.swift` + dead `ThemedContentView.swift` |
| capture | `/compare` fixtures pairing native pager pages with their Vue twins (the parity muscle); editor fixtures after 07 |
