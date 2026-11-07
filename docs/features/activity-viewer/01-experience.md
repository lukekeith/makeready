# 01 — The experience

Points are on the recording's 440×956 pt screen. Scale rules for other phones are in `02` §4.
Evidence labels are defined in `README.md`; the numbers' sources are in `04`.

## 1. The experience in one paragraph

Opening a lesson presents a full-screen stack with no tab bar and no app chrome. The member drags
anywhere to move through it. Inside a long activity, content scrolls freely with no snap points.
Between activities, the next page is attached directly to the end of the current one, and the
finger moves both together, in either direction, for as long as it stays down. **Nothing snaps
while a finger is down.** On lift, the stack settles so one page fills the screen.

## 2. The stack

- Pages are stacked vertically in lesson order with **no gap, divider or margin** between them
  (observed, `assets/t24.0-drag-held-two-pages.jpg`).
- Each page owns an opaque background that travels with it. Mid-transition the boundary between
  two pages is a hard horizontal edge (observed, measured from it).
- The recorded lesson has 8 pages: video, long article, scripture, share-your-faith, prayer, video,
  long article with hero image, completion.
- The stack has no maximum page count. Pages render lazily: the active page and one neighbor on
  each side stay mounted *(default)*.

## 3. Page heights and vertical placement

| Content | Page height | Placement | Evidence |
|---|---|---|---|
| Shorter than the viewport | Exactly the viewport | Vertically centered in the viewport | Share page block center 480 pt, prayer page 485 pt, on a 478 pt midline (measured) |
| Taller than the viewport | Content height | Starts at its authored top, scrolls inside the page | "Think About It" heading rests at 277 pt (measured) |
| Video | Exactly the viewport | Full bleed | Observed |
| Completion | Exactly the viewport | Title group top, up-next group bottom | Observed |

A long page ends with **85 pt** of empty space below its last content line (measured: last line
rests at 871 pt). That space is the only separation from the next page.

`02` §4 gives the exact computation for authored canvas content.

## 4. The position model

The whole experience is described by this state. Both platforms implement exactly this; nothing
else may hold scroll position.

| State | Type | Meaning |
|---|---|---|
| `anchor` | page index | The page the stack is resting on or dragging away from |
| `drag` | points | Displacement from the anchor at rest. Positive moves toward the next page. `0` is at rest |
| `inner[i]` | points per page | That page's own scroll, from `0` to `pageHeight[i] − viewportHeight` |
| `owner` | `none`, `inner` or `pager` | Who owns the current touch |

A page is drawn as a **viewport-tall clipped window** onto its content at `inner[i]`. It never
un-clips. When the pager moves a long page mid-scroll, content above the window stays hidden; the
page does not reveal what is scrolled off (measured,
`assets/t55.1-article-frozen-under-video.jpg`: the video's bottom edge meets the article's section
divider, with the article's earlier text not shown).

Pages off the anchor are drawn adjacent: the next page's top edge at `viewportHeight − drag`, the
previous page's bottom edge at `−drag`.

`inner[i]` is **retained for the life of the session** (measured: article left at its end at
54.8 s, re-entered from above at 59.8 s at the same offset). First visit from above starts at `0`.
A long page first reached from below starts at its maximum *(default)*.

## 5. Who owns a touch

Decided once, when movement first passes the system's touch slop. **Held until the finger lifts.**

| Finger moves | Anchor page's `inner` | Owner |
|---|---|---|
| Up | Below its maximum | `inner` |
| Up | At its maximum (always true for a page that doesn't scroll) | `pager` |
| Down | Above `0` | `inner` |
| Down | At `0` | `pager` |
| On a control that claims the touch (video scrubber, any button) | Any | The control |

While `pager` owns the touch:

- `drag` follows the finger **1:1**, with no resistance at any boundary between pages (measured:
  dragged to 74 % of a page at 10.1 s, and across rest in both directions).
- The finger can reverse freely, cross rest and pull the other neighbor in, all in one touch
  (measured: 23.3–25.6 s).
- `inner` of every page is frozen, even when the reversal would naturally scroll the page. This is
  the behavior at 54.55–55.05 s: the article, already at its end, was pulled up, reversed, and the
  whole page slid down to the video without its text scrolling at all.
- When a neighbor fully covers the viewport, it becomes the anchor and the touch stays with `pager`
  *(default)*.

While `inner` owns the touch:

- `inner` follows the finger 1:1, then decelerates with momentum after lift.
- Reaching the limit ends the motion. **Neither a drag nor momentum spills into the next page.**
  The next page needs a new touch (measured once: the article stopped at its end at 16.70 s, and the
  next movement began 190 ms later; marked one sample in `04`).
- Hitting the limit in momentum stops without bounce *(default)*.

Momentum uses the iOS default deceleration on both platforms: velocity × 0.998 per millisecond
*(default)*.

Outer limits *(default)*: past the first page's top, `drag` follows the finger at 0.55× and returns
on lift. Past the completion page, see §11.

## 6. Snapping

**When:** only at finger lift while `pager` owned the touch, and only if `drag ≠ 0`. Holding a page
74 % of the way across never commits it (measured: 10.1 s, returned by the finger).

**Where to:** always exactly one page fully covering the viewport. The stack never rests with two
pages visible. One release moves at most one page (measured: every recorded commit is 900–976 pt).

**The decision** is a pure function, identical on both platforms:

```
v         = finger velocity at lift, in pt/s, positive toward the next page
projected = drag + v × 0.25
if projected >  viewportHeight / 2 and a next page exists      → commit to next
if projected < −viewportHeight / 2 and a previous page exists  → commit to previous
otherwise                                                      → return to anchor
```

The constant `0.25` is a *(default)* chosen inside the bracket the recording allows; the recording
can't show the finger, so an exact threshold can't be measured. What was measured:

| Release | Dragged | Velocity | Result |
|---|---|---|---|
| 32.7 s, scripture → share | 33 % | Flick, ≈3,600 pt/s | Commit |
| 11.95 s, video → article | ≈50 % | ≈1,400 pt/s | Commit |
| 38.0 s, share → prayer | ≈80 % | ≈1,000 pt/s | Commit |
| 57.2, 58.3, 59.4 s | ≈0 % | Pure flicks, 5,000–6,100 pt/s | Commit |
| 40.3 s, prayer page | ≈3 % | Slow | Returned |

Check the constant in the prototype before freezing it (§13).

**The motion:** a critically damped spring toward the target, starting at the release velocity.

| Parameter | Value |
|---|---|
| Angular frequency | ω = 20 rad/s, the same as a response of ≈0.31 s (measured: 19.6 and 20.4 on the two clean full-page fits) |
| Overshoot | None (measured: 0 pt on every clean fit) |
| Full-page duration from a flick | 0.42–0.45 s (measured) |
| Commit from a partial drag | ≈0.35 s after lift (measured) |
| End | Position within 0.5 pt and speed under 5 pt/s, then jump to the target *(default)* |

Position at time `t` after lift, where `x₀` is the remaining distance and `v₀` the speed toward the
target:

```
x(t) = (x₀ + (ωx₀ − v₀)·t) · e^(−ωt)
```

**Interrupting:** a touch during a settle stops the spring at once and the finger takes over with
`pager` ownership; `anchor` becomes whichever page covers the midline *(default)*.

## 7. The active page

**The active page is the one covering the viewport's horizontal midline.** It changes the instant
`|drag|` passes `viewportHeight / 2`, whether or not a finger is down (measured: video paused with
the boundary at 480 of 956 pt). Three things key off this single value, at the same moment:

1. Video and narration play or pause (§9).
2. The top-right button swaps (§9).
3. The rail's capsule moves (§8).

Reversing back across the midline undoes all three. Progress is different: an activity is recorded
as viewed only after a settle lands on it *(default)*, so a page glimpsed mid-drag doesn't count.

## 8. The rail

The position indicator. See `assets/rail-3x-crop.png`. It is fixed to the viewport and doesn't move
with pages.

**Geometry** (measured from 3× crops, ±0.5 pt):

| Part | Value |
|---|---|
| Container | 23 × 88 pt pill, right edge 28 pt from the screen's right edge, vertical center at 81 % of screen height (773 pt) |
| Container style | Black at ≈50 % fill, 1 pt stroke of white at ≈15 % |
| Capsule (active page) | 8 × 28 pt, white |
| Thumb (inside the capsule) | 4 × 8 pt, black. Only on a page with `inner` range |
| Dots by distance from the capsule | 1 away: 7 pt, ≈60 % white. 2 away: 6 pt, ≈45 %. 3 away: 5 pt, ≈30 %. 4 away: 4 pt, ≈20 % |
| Dot pitch | ≈10.5 pt |

**Which pages it shows.** At most five slots, always a consecutive window containing the active
page, so the capsule moves within the rail instead of always staying centered:

```
slots = min(5, pageCount)
start = clamp(active − 2, 0, pageCount − slots)
```

Measured against 8 pages: active 1 shows 1 + capsule + 3; active 2–5, 2 + capsule + 2; active 6,
3 + capsule + 1; active 7, 4 + capsule.

**Thumb position:** `inner[active] / maxInner[active]` across the capsule's interior, updated every
frame (measured: travels top to bottom through a long article). On a page with no `inner` range
there is no thumb and the capsule reads solid white.

**Changing page** (measured): at the midline crossing the outgoing capsule shrinks to a dot as the
incoming dot grows to a capsule, over ≈150 ms. Mid-morph both are visibly equal. The thumb fades in
over ≈100 ms when the morph ends.

**Visibility:**

| Page | Behavior |
|---|---|
| No playing media (text, article, completion) | Always visible (measured: 2.2 s and 2.5 s at rest, no fade) |
| Video or narrated page, playing | Visible while moving; 1.5 s after settling, fades out over 0.3 s (measured: 45.1 → 46.6 s, 68.0 → 69.4 s) |
| Hidden, then the pager moves | Fades in over ≈100 ms (measured: 8.1 s) |

It stays hidden during scrubbing (measured: 2.5–4.5 s).

**Touches:** indicator only; touches pass through to the page beneath (owner ruling). It's never
touched in the recording.

**Side:** bottom right, as recorded (owner ruling).

## 9. Chrome

Fixed to the viewport, above every page. Hidden only by a sheet (§10).

| Element | Geometry (measured) | Behavior |
|---|---|---|
| Close | 44 pt circle, center (41, 85), 1 pt tinted stroke, transparent fill | Closes the experience from any page (§11). Pressed: fills with a tint over ≈50 ms |
| Top-right action | 44 pt circle, center (397, 85) | Per page: **share** on text pages, **⋯** on video and article-with-CTA pages |
| Top scrim | Black, fading to transparent over ≈140 pt from the screen's top, tinted by the page beneath | Content scrolling up fades out beneath it; it isn't clipped at a hard line |

**Top-right swap** (measured): at the midline crossing the old icon fades, a blurred empty circle
holds, then the new icon fades in. ≈250 ms total.

### Video page

See `assets/t02.0-video-page.jpg`.

| Element | Spec |
|---|---|
| Video | Full-bleed, cover. Black beneath. Bottom gradient to black across ≈25 % of the screen so controls stay legible |
| Captions | Centered white text on a translucent dark rounded box, per line pair, ≈68 % down the screen. Rendered as a track, not baked in |
| Presenter row | 37 pt avatar with white ring at (17, 853) · bold name · reference subtitle · outlined Follow pill |
| Time | **Remaining** time, counting down, at left of the scrubber (measured: 1:49 → 1:36) |
| Scrubber | x 52 to 381, y 899, ≈6 pt tall, white progress and small thumb over gray track. Claims the touch: seeking doesn't move the pager (measured: 2.5–4.5 s, no page motion) |
| Play/pause | Large glyph at x ≈ 408, y 899. Toggles on tap |

Playback (all measured unless marked):

- Autoplays when the page becomes active. A spinner shows at center while buffering, over the
  poster frame (45.0 s).
- Pauses at the midline crossing on the way out, resumes at the midline crossing on the way back.
  The icon shows the state live.
- Keeps its position across leaving and returning: left at 0:22, resumed from 0:22.
- A member's own pause is kept across leaving and returning *(default)*.
- Reaching the end stops on the last frame with the play icon; it doesn't auto-advance *(default;
  the recording doesn't reach an end)*.

## 10. Actions

An action is a button that belongs to a page. Two placements exist, both observed.

| Placement | Behavior | Example |
|---|---|---|
| **Inline** | The last content item. Scrolls with the content | "Add to Prayer List" text row with a ⊕ glyph, centered (`assets/t38.5-inline-action.jpg`) |
| **Pinned** | Full-width white pill, 16 pt from each screen edge, ≈30 pt above the safe bottom. Stays put while the page's content scrolls under it, and moves with the page during pager motion | "Start Plan" (`assets/t50.0-pinned-action.jpg`) |

On a page with a pinned action the page's end space grows by the pill's height, so the last line
clears it (measured at the article's end: last line ≈774 pt, pill top ≈846 pt).

### Action sheet

Tapping an action that collects input presents a sheet **above the stack**; the stack stays where
it is underneath. See `assets/t42.0-action-sheet.jpg`.

| Step | Motion (measured) |
|---|---|
| Open | Rises over ≈0.45 s with a long ease-out tail; the page beneath dims to ≈50 % over ≈0.15 s; the chrome dims with it |
| Rest | Top edge ≈75 pt from the screen top, large top corners, dark fill |
| Close | Close button shows its press state, then the sheet falls in ≈0.27 s and the dim clears |

Contents as recorded for Add to Prayer List: close (left), centered title "Add Prayer", white Save
pill (right), editable title with a character count, editable body prefilled from the activity, and
a pinned privacy line. Save writes through the action's endpoint (`02` §7), closes the sheet, and
leaves the stack on the same page *(default)*.

## 11. Entering and leaving

| Event | Behavior |
|---|---|
| Open | Sheet rises from the bottom in ≈0.3 s over the home screen; background appears first, content fades in over ≈0.5 s (measured: 67.3–68.3 s) |
| Close button | Press state, then the whole stack slides down in ≈0.3 s, revealing the app beneath (measured: 69.75–70.05 s) |
| Past the last page | The completion page drags up 1:1. On lift past 150 pt, or a flick up, the whole stack slides **down** in ≈0.3 s (measured: pulled 158 pt, 65.9–66.97 s; threshold is a *(default)*) |

### Completion page

The last page in every stack: activity-type title, streak pill (teal, droplet glyph, count), "UP
NEXT" with a next-lesson card, "⌃ Swipe Up" hint. See `assets/t64.0-completion.jpg`. Its contents
are specified by the `activities-completion` screen.

## 12. Building it on both platforms

**Rejected: the platform pagers.** CSS `scroll-snap` and `UIScrollView` paging each snap with their
own curve, which the app can't set, so the two platforms wouldn't feel the same. Neither expresses
§5's ownership held across a reversal.

**Chosen: one engine, two thin renderers.** A pure state machine holds §4–§7. It takes touch samples
and clock ticks, and it outputs positions, the active page and the rail state. It contains no UI
code. It's written twice (TypeScript and Swift) and both must pass the same vectors (§13).

| Concern | iOS | HTML/React (mobile web) |
|---|---|---|
| Touch input | One `UIPanGestureRecognizer` on the stage, with velocity from the recognizer | Pointer events on the stage, `touch-action: none`, `overscroll-behavior: none`. Velocity by least-squares over the last 100 ms of samples |
| Frame clock | `CADisplayLink` | `requestAnimationFrame` |
| Moving content | Layer transforms | `transform: translate3d` with `will-change` on mounted pages only |
| Viewport height | The view's bounds | `100dvh`, measured once per orientation so the address bar can't resize pages mid-drag |
| Video | `AVPlayer`, active ±1 prepared | `<video playsinline>`, active ±1 preloaded. Sound requires a prior tap: the tap that opened the lesson counts; otherwise start muted with an unmute control |
| Controls claiming a touch | Hit-test before the recognizer begins | `pointerdown` on the control calls `stopPropagation` |
| Sheets | The app's overlay system, never a system sheet, so timings match | A positioned layer with the same timing, not a browser dialog |

**House rules on iOS:** the view lives under `iphone/MakeReadyUI/`, built through d2m. A SwiftUI
`DragGesture` here would hold the touch and fight the engine, so the stage hosts a UIKit view. The
native viewer is for leaders now (owner ruling): it plays the same stack but writes no member
progress, and an action's sheet opens with its save disabled and a "Preview" label *(default)*.

**React + MobX on web** (owner ruling):

| Layer | Holds | Rule |
|---|---|---|
| `viewer-core` | The engine above | Plain TypeScript. Imports neither React nor MobX |
| `ViewerStore` (MobX) | `activePage`, the rail's window, media state, sheet state, each page's measured height | Observable. Changes a few times per gesture |
| Frame loop | `drag`, `inner`, settle position, thumb position | **Never observable.** Each frame writes transforms directly to element refs. A React render per frame would drop frames |
| React components | `ActivityViewer`, `ActivityPage`, one renderer per `kind`, `ActivityRail`, `ViewerChrome`, `ActionSheet` | `observer` components reading `ViewerStore`. Each renderer takes the document (`02`) as props |

Keeping `viewer-core` free of both libraries also limits the rewrite if the member stack's framework
changes.

**Accessibility, both platforms:**

- Pages appear in lesson order in the accessibility tree, each announced as "Activity n of N". Only
  the active page and its neighbors are exposed.
- iOS: three-finger scroll via `accessibilityScroll` moves a page. Web: Up/Down, Page Up/Page Down
  and Space move through content and then commit a page.
- Reduce Motion: the settle becomes a 150 ms crossfade, parallax turns off (`02` §5), and looping
  text animations hold on their rest pose.

## 13. Proving they feel the same

**Shared vectors.** A JSON file of `(state, input) → (state, output)` cases is the contract. Both
engines' test suites load the same file. At minimum, for `viewportHeight = 956`:

| Case | Start | Input | Result |
|---|---|---|---|
| Hold never commits | `drag = 700`, finger down | No lift | Stays on anchor, no settle |
| Slow release under half | `drag = 400`, v = 0 | Lift | Return to anchor |
| Slow release over half | `drag = 500`, v = 0 | Lift | Commit next |
| Flick from rest | `drag = 30`, v = 5000 | Lift | Commit next |
| Weak flick | `drag = 30`, v = 500 | Lift | Return (30 + 125 < 478) |
| Flick against the drag | `drag = 400`, v = −3000 | Lift | Return (400 − 750 = −350) |
| One page per release | `drag = 900`, v = 9000 | Lift | Commit next only |
| No next page | Last page, `drag = 40`, v = 0 | Lift | Return |
| Ownership, long page mid-scroll | `inner = 300 of 900`, finger up | First movement | `inner` |
| Ownership at the end | `inner = 900 of 900`, finger up | First movement | `pager` |
| Reversal is held | `pager` owner at end of a long page | Finger reverses down | `drag` goes negative, `inner` stays 900 |
| Inner limit stops | `inner` owner, momentum 2000 at max | Tick | Stops at max, `drag` stays 0 |
| Midline flips active | `drag = 477` → `479` | Tick | Active page changes once |
| Midline flips back | `drag = 479` → `477` | Tick | Active page returns, video resumes |
| Rail window | active = 6, pageCount = 8 | — | start = 3, slots = 5 |
| Rail window, few pages | active = 1, pageCount = 3 | — | start = 0, slots = 3 |

**Feel check.** Before freezing the velocity constant and spring, run both builds on one phone with
the same 8-page fixture, and record both at 60 fps. Measure with the method in `04`. Each settle's
duration must agree within 50 ms and neither may overshoot.

## 14. Not in this spec

Narration audio, word-by-word reveal and the checkmark draw are in
`docs/features/activities/05-animations-and-transitions.md` and aren't in this recording. Comments,
reactions and landscape are out of scope. Tablet and desktop web render the mobile stage centered
at 440 pt wide *(default)*.
