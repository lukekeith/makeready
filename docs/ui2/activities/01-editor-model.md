# 01 — Editor model: the text object, the four modes, the chrome

## 1. The text object

Every piece of text on the canvas is one object with the properties below. The editing tools in
`02`–`06` each write a subset; canvas gestures in `07` write the transform. Properties marked
**observed** were seen changing in the recording; **inferred** are required for the observed
behavior to work but were never shown changing.

| Property | Type | Default (observed on a fresh object) | Written by |
|---|---|---|---|
| `text` | string, multi-line | `""` (placeholder "Type something…" shown while empty) | keyboard (`02`) |
| `font` | one of the font chips (`03` §4) | `Classic` | font chips (`03`) |
| `size` | continuous | slider thumb at ≈64 % down the track; renders ≈24–26 pt for "Test content" | size slider (`02` §5) |
| `color` | RGB | white | swatches / eyedropper (`04`) |
| `alignment` | `center` \| `left` \| `right` | `center` | alignment tool (`05` §1) |
| `label` | `none` \| `solid-dark` \| `solid-light` | `none` | label tool (`05` §2) |
| `animation` | `none` \| one of the animation chips | `none` | animation chips (`06` §1) |
| `effect` | `none` \| one of the effect chips | `none` | effect chips (`06` §2) |
| `transform.position` | canvas point (object center) | canvas default slot — the object appears where the edit slot was, see `08` §2 | one-finger drag (`07` §1) |
| `transform.scale` | float, 1.0 = size as typed | 1.0 | pinch (`07` §2) |
| `transform.rotation` | degrees | 0 | two-finger rotate (`07` §3) |

Rules that follow from what was observed:

- **`size` and `transform.scale` are independent.** Pinching on the canvas changes `scale`, the
  slider changes `size`. When the object is re-opened for editing it is shown at `size` with
  `scale` = 1 and `rotation` = 0 (see `08` §3); on Done the canvas transform is re-applied.
  Observed at 13.0 s (object pinched to ≈2× at 10 s is shown at base size while editing) and
  54.5 s (grows back on Done).
- **Animation and effect are independent slots**, not one "style" slot: Pixel effect + Typewriter
  animation were never shown together, but switching from the animation strip to the effect
  strip kept the animation chip's selection (32.0 s → 41.25 s: Typewriter stays selected when the
  strip returns to animations). Treat them as two properties.
- **Label is drawn behind the effect.** Pixel effect + solid label (48.5 s) renders the label box
  behind the pixelated glyphs.
- **Alignment is a property of the object**, not of the editor: a left-aligned object stays
  left-aligned on the canvas after Done (not demonstrated for left — the final committed object was
  center; inferred from alignment surviving re-entry at 48.0 s → 57.5 s where the object re-opened
  centered after being set to center at 53.25 s).

## 2. The four modes

```
                    tap blank canvas                      Done
   ┌──────────┐ ───────────────────────▶ ┌──────────┐ ──────────────▶ ┌──────────┐
   │  IDLE    │                          │ EDITING  │                 │ COMMITTED│
   │ (canvas) │ ◀─────────────────────── │ (text    │ ◀────────────── │ (object  │
   └──────────┘   Done with empty text    │  tool)   │   tap object    │  on      │
        ▲          (inferred: deletes)    └──────────┘                 │  canvas) │
        │                                                               └────┬─────┘
        │                      release                                       │ touch-down + move
        └──────────────────────────────── ┌──────────────┐ ◀─────────────────┘
                                          │ MANIPULATING │   (1 finger: drag; 2 fingers: pinch/rotate)
                                          └──────────────┘
```

| Mode | What the canvas shows | What the user can do | Entered by | Left by |
|---|---|---|---|---|
| **Idle** | Canvas background, committed objects at their transforms, full composer chrome | Tap blank canvas (→ Editing, new object); tap an object (→ Editing, that object); touch-and-move an object (→ Manipulating) | app start; Done; gesture release | see "entered by" of the others |
| **Editing** | Canvas **dimmed** (≈50 % black scrim over everything), the edited object alone rendered undimmed at the **edit slot** (fixed y ≈ 244 pt from the top, see §3), slider on the left, chip strip + tool row + keyboard at the bottom, Done top-right | Type; use any tool in `03`–`06`; drag slider | canvas tap; object tap | Done |
| **Committed** | Same as Idle — this is Idle with the object present | — | Done | — |
| **Manipulating** | Canvas not dimmed; composer chrome hidden; for one-finger drag a "Drag to delete" target at the bottom; a center guide when near x-center | Drag; pinch; rotate; drop on the delete target | touch-down + movement on an object | all fingers up |

Not demonstrated, but required and marked **inferred**: Done on an object whose `text` is empty
removes the object (otherwise an invisible object would persist).

A second committed object was never created; multi-object behavior (z-order, selecting among
overlapping objects, dimming of *other* objects in Editing) is **not demonstrated** — `OQ-01-1`.

## 3. Chrome per mode (reference app, 440×956 pt)

Only the elements that carry text-editor behavior are listed; the rest is Instagram composer
chrome (see README scope boundary).

### Editing mode

| Element | Position (measured at 0.5–7 s and 13–54 s) | Notes |
|---|---|---|
| Done | top-right, nav-bar height | Labelled **Next** during the very first edit session of a new story (0.75–7.5 s) and **Done** in every later session — this is the composer's own flow, not the editor's; the MakeReady control is Done (`10` §2). |
| Edit slot | object centered at y ≈ 244 pt; horizontally per `alignment` with ≈24 pt side margins for left/right | Fixed regardless of the object's canvas position; the object animates to/from it (`08`). |
| Size slider | x ≈ 26 pt (thumb center), track y ≈ 138–429 pt (≈290 pt long), wedge wider at the top | Vertical; thumb default ≈64 % down. `02` §5. |
| Chip strip | y ≈ 512 pt center, chips ≈28 pt tall, horizontally scrolling, selected chip always at x-center | Contents depend on the selected category: fonts / animations / effects. `03`, `06`. |
| Tool row | y ≈ 566 pt center, six 40 pt targets evenly spaced | Order: **Aa** (fonts) · **color** · **//A** (animations) · **✦** (effects) · **≡** (alignment) · **A▢** (label). The first four are *category* tools (they swap the strip and get a light highlight pill); the last two are *instant-action* tools (they act on tap and never take the highlight). |
| Keyboard | top edge y ≈ 630 pt (326 pt tall incl. the globe/mic bar) | System keyboard; the chip strip + tool row sit directly on top of it and ride with it. |
| Scrim | full canvas | ≈50 % black, under the edited object. |

### Idle / Committed mode

| Element | Notes |
|---|---|
| Blank canvas | Tapping anywhere that is not an object enters Editing with a new object. |
| Committed object | Rendered with its full transform and its animation looping (`06` §1). Tap → Editing; touch-and-move → Manipulating. |
| "Aa" button (top-right rail) | Alternate entry to a new text object; not used in this recording. |

### Manipulating mode

| Element | Notes |
|---|---|
| Delete target | "Drag to delete" caption + trash-can circle at bottom center (y ≈ 88 % of height), one-finger drag only. `07` §4. |
| Center guide | 1 px white vertical line at x-center while the object's center is within snap range. `07` §5. |

## 4. Rendering notes a rebuild must honor

- The chip strip and the tool row **both render over the dimmed canvas with no panel background**
  (they sit on the scrim directly; the keyboard provides the only opaque region).
- The edited object is rendered **undimmed, in front of the scrim, with its animation looping
  while editing** (the Typewriter animation plays over the live text at 38.25–38.75 s while the
  caret is visible). Effects also render live while editing (Sparkle 42.75 s, Pixel 44.25 s).
- The caret is the system blue caret, positioned at the end of the text; with effects that
  re-rasterize glyphs the caret was seen floating above the text (57.5 s, 59.0 s) — an artifact,
  not a behavior to reproduce.

## Open questions

- **OQ-01-1** Multi-object: is every other object dimmed under the scrim in Editing, and what
  decides which object a tap hits when they overlap? Not demonstrated.
- **OQ-01-2** Done with empty text: delete the object (inferred here) or keep an empty object?
