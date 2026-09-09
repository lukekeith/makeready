# 05 — Animations & Transitions (motion spec)

All timings measured from the recordings (±35ms at 15fps) and rounded to implementation-friendly
values. **This spec is platform-neutral — both the native player (09) and the Vue twin implement
these numbers**; CSS/JS mechanics below name the web techniques, with SwiftUI equivalents in
09 §4. Every animation must honor reduced-motion (§8: `prefers-reduced-motion` /
`accessibilityReduceMotion`).

## 1. Page-to-page transition

Native scroll physics — **no custom transition animation on the pages themselves**.
- Finger-tracked, interruptible, rubber-bands at the ends (browser/WKWebView default).
- Snap settle: whatever momentum + `scroll-snap` gives; programmatic `goTo` uses smooth scroll
  ≈450ms with the platform curve.
- Backgrounds: lesson backdrop `position: fixed` (does not move, no parallax); page panels are
  in-flow (move with content). No opacity games during transit — panels are opaque.
- Fling-skip prevention: `scroll-snap-stop: always`.
- Gated page nudge (attempt to pass a locked page): clamp scroll at the page bottom, then settle
  back 250ms ease-out — communicates "not yet" without chrome.

## 2. Page entrance choreography (`revealMode: GROUPS`)

Triggers on `settled` (snap complete + ~80ms scroll idle), runs once per entry:

| t (ms) | What | Values |
|---|---|---|
| 0 | Page is bare (content pre-laid-out but `opacity: 0`) | — |
| 0–120 | Quote rule stub (SCRIPTURE role only): rule scales `scaleY 0→.25` | ease-out |
| 120–520 | **Primary group** (main text + rule to full height): `opacity 0→1`, `translateY 12px→0`, `scale .97→1` | 400ms, cubic-bezier(.22,.61,.36,1) |
| 420–720 | **Secondary group** (eyebrow, citation, guidance lines): same move, 300ms, 60ms internal stagger | starts 300ms after primary begins |
| 620–900 | **Actions group** (buttons): `opacity 0→1`, `translateY 8px→0` | 280ms |

- Groups are declarative per page type (06 lists each type's group assignment).
- A page can schedule a group **late** (MY CONCERNS pattern: verse alone → guidance + button fade
  in on a `delay` or narration cue). Model: each group has `trigger: settle | delay(ms) | cue(id)`.
- Re-entry from above: no replay (content stays visible). Exception: completion badge (§5).

## 3. Intra-page reveal is NOT scroll-linked

Long pages scroll plainly (article page shows fully-rendered text scrolling). Do not build
scroll-progress-linked opacity — reveal is time-based after settle, then the page is static.

## 4. Word-by-word reveal (`revealMode: WORDS`)

- Tokenize into words; each word `opacity .35→1` over 200ms, launched sequentially.
- Cadence: from `narrationCues` (word timestamps) when the page has audio; fallback fixed
  180ms/word. Observed range 130–260ms/word.
- Un-revealed words occupy no space (layout grows; reflow left-aligned) — matches reference.
  Implementation: all words rendered `display: none` → flipped incrementally (rAF batch), or a
  clipped-inline approach if reflow proves janky; decide in build.
- Skippable: first tap reveals all instantly (accessibility + impatience).

## 5. Completion checkmark

SVG, two strokes, `stroke-dasharray` draw:

| t (ms) | What | Curve |
|---|---|---|
| 0–300 | Tick draws left→right | ease-in-out |
| 300–380 | Hold | — |
| 380–700 | Circle draws clockwise from 12 o'clock | ease-out |
| 700–850 | Spring settle: badge `rotate -4°→0`, `scale 1.04→1` | spring(mass .8, stiffness 220, damping 18) |

Then title/streak badge (fade+rise 300ms), up-next card (+120ms), swipe-hint (+240ms, then idle
pulse: `translateY 0→-4→0` every 2.4s). Badge **re-draws on every entry** to this page.

## 6. Motion presets

Palette token `motion` scales the whole system (05 §2 numbers = `gentle`):
- `gentle` — as specified.
- `crisp` — durations ×0.7, no scale component.
- `still` — entrance = 200ms plain fade; for orgs that want minimal motion.

## 7. Overlays

- Bottom sheets (prayer save, write input): 300ms ease-out up, 250ms ease-in down, scrim
  `opacity 0→.5`; standard sheet behavior, host page does not scroll behind.
- Exegesis floating note card (06): appears near tap point `opacity 0→1` + `scale .92→1` 220ms;
  drag = direct manipulation (no lag filter); release momentum none; reposition on
  highlight-switch = 250ms ease-out translate; dismiss `scale→.94, opacity→0` 180ms.
- Lesson dismissal: pager `translateY 0→100%` 400ms ease-in (gesture-driven start: over-scroll
  distance maps 1:1 until the 80px threshold, then animates out). X button uses the same exit.

## 8. Reduced motion

`prefers-reduced-motion: reduce` → all entrances become 150ms opacity fades, word reveal renders
instantly, checkmark appears pre-drawn with a single fade, idle pulses off, smooth scrolling
replaced by instant `scrollTo`. Snap and gesture physics (native) remain.

## 9. Performance rules

- Animate only `opacity` and `transform`; every animated node gets its own compositor layer
  (`will-change` applied at `approaching`, removed at `passed`).
- No IntersectionObserver work during active scroll frames beyond bookkeeping; entrance starts
  only after scroll idle (rAF-debounced 80ms).
- Backdrop video: `preload="metadata"`, play only while any transparent page is on screen.
- Target: 60fps on iPhone 12-class hardware — native player on device, web player in
  mobile Safari; verify with the existing capture harness device set.
