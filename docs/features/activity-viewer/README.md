# Activity viewer — the stitched, full-screen activity experience

A lesson's activities play as one full-screen vertical stack. The member moves freely up and down.
Short activities fill the screen, long ones scroll, and page boundaries snap. This folder is the
specification for rebuilding that experience natively on iOS and in HTML/React for mobile, so that
both feel the same, plus the content schema every activity type renders from.

**Status:** reference specification, written 2026-11-06 from a frame-by-frame analysis. The build is `docs/features/text-activity/SPEC.md`: the leader editor, iPhone viewer, new data model and cutover. The React member viewer here is documented for a later member rebuild, not being built yet. The
builder record is `.builder/text-activity/brainstorm.md` (local, git-ignored).

## Files

| File | Read it for |
|---|---|
| [`01-experience.md`](01-experience.md) | **Normative.** Navigation, gesture ownership, snapping, the rail, chrome, video, actions, exit, and the platform notes for iOS and React |
| [`02-content-schema.md`](02-content-schema.md) | **Normative.** The activity document: background layer vs content layer, the coordinate space that works on every phone, parallax, actions, and how each activity type fits |
| [`03-gaps.md`](03-gaps.md) | What must change in the d2m text-activity screens, the built components, the server, and the clients |
| [`04-recording-analysis.md`](04-recording-analysis.md) | The evidence: timestamped outline, measurements and their limits |
| [`05-data-model.md`](05-data-model.md) | **Normative.** Storage designed from scratch, versions, group customization, progress, and the one-time export |
| `assets/` | Stills from the recording, named by timestamp |

## How to read a value

- **measured**: read from the recording's frames, with the method in `04`.
- **observed**: seen in the recording but not numerically measured.
- ***(default)***: the recording cannot show it, so this is an exact ruling that can be vetoed. A
  build takes it as written.

Anything else that differs from these documents on either platform is a defect.

## What this replaces

| Earlier document | Status |
|---|---|
| `docs/features/activities/01-video-analysis.md`, `03`, `05`, `09` | Still valid as analysis of two earlier recordings. Where they differ, this folder wins. Its pager recommendation (CSS scroll-snap, custom `ScrollTargetBehavior`) is replaced by `01` §12 |
| `docs/features/activities/08-open-questions.md` Q12 (no member access from the iPhone app) | Reopened by this work; see the owner calls below |
| `docs/features/activities/` Vue pager as the member runtime | Replaced: the member experience is being rebuilt in React + MobX (ruling below) |
| d2m `activities-editor` §5 `objects` + `background` shape | Replaced by `02`; the change is listed in `03` |

## Requirement provenance

The owner's request, 2026-11-06, and where each part became acceptance criteria.

| Request | Criteria |
|---|---|
| "vertically stitched, some are full screen activities and some extend beyond the size of the screen" | `01` §2, §3 |
| "freely navigate up and down" | `01` §4, §5 |
| "the way it snaps and when it snaps" | `01` §6, test vectors in §13 |
| "scrolling navigation element" | `01` §8 |
| "the video player, and the close button top left" | `01` §7, §9 |
| "action button ... add to prayer list ... Write your thoughts" | `01` §10, `02` §7 |
| "text layer vs background layer so it works well on every phone" | `02` §3, §4, §5 |
| "effects like parallax" | `02` §5 |
| "video, text, bible verse, poll, write, and more in the future" | `02` §2, §8, §9 |
| "gaps in the d2m text activity screens or built implementation" | `03` |

## Owner rulings, 2026-11-06

| # | Question | Ruling |
|---|---|---|
| 1 | Who uses the native iOS viewer? | **Leaders now, members later.** Members start on web. The native viewer writes no member progress and is built to member quality, so opening it to members later is a small step |
| 2 | Web stack? | **React + MobX.** The member experience will be rebuilt on it (the framework may still change), so it isn't added to the Vue client. The gesture core stays framework-free, which limits the cost if it does change |
| 3 | The rail's side? | **Bottom right**, as recorded |
| 4 | Is the rail tappable? | **Indicator only** for now; touches pass through. Adding interaction later changes no content |
| 5 | What about 1.0? | **No legacy support.** New app, zero users. The 1.0 UI/UX and schema aren't constraints; production content moves once by export (`05` §6) |
| 7 | Member experience now? | **Not touched yet.** No React or member work in the current build; `client/` isn't edited, and its lesson pages stop at cutover |
| 8 | Cutover? | **In the current build**, even though React comes later |
| 6 | The new data model? | **`05` as written.** Group edits go live on Done. The Vue lesson and leader screens stop at cutover until React replaces them. The export carries content only |
