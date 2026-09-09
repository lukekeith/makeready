# 10 — Text Editing Analysis (Instagram post + story editors)

**Purpose:** a complete behavioral spec of Instagram's two text-editing experiences, captured
frame-by-frame from two recordings (`text editing 1.mov` = post/reel media editor, 70.7s;
`text editing 2.MP4` = story editor, 62.3s), detailed enough to translate a Figma design of the
same patterns into a working implementation without re-deriving behavior. **The preferred
pattern for MakeReady is video 2's story editor** — one persistent control row with a contextual
options strip that appears directly above it. This doc intentionally ignores what MakeReady
currently supports; it documents the reference behavior + the requirements to build it.

Analysis method: 2fps full-run contact sheets for both videos + 15fps crops of the toolbar
region at every menu-switch moment.

---

## 1. The text object model (both editors)

Every piece of text is a free **text object** on the canvas with these independent properties,
all live-previewed while editing:

| Property | Values observed | Notes |
|---|---|---|
| content | multi-line string | placeholder "Type something…" (story) / empty (post) |
| fontStyle | named style, see §4.2 | chip label rendered in its own typeface |
| color | swatch or custom (eyedropper / HSB) | applies to ink; with label bg active, recolors the pair (§4.5) |
| background ("label") | none → white label → black label → translucent tinted label | rounded-rect ribbon behind each text line |
| alignment | center / left / right | cycling control |
| size | continuous | left-edge vertical slider, §3.2 |
| transform | x/y, scale, rotation | canvas gestures, §5 |
| animation (story only) | none ⊗, Typewriter, Pop, Jump | loops on canvas while selected |
| effect (story only) | none ⊗, Sparkle, Neon, Shimmer, Pixel | visual treatment; also loops (Sparkle glints, Shimmer sweep) |

Multiple text objects per canvas; each keeps its own full property set. Tapping an existing
object re-enters the editor with its state restored.

---

## 2. The two editors at a glance

| | Video 1 — post editor | Video 2 — story editor (**preferred**) |
|---|---|---|
| Entry | media edit screen → `Text` tool | Create story → tap canvas / `Aa` |
| Commit button | `Done` (top-right) | `Next` (new) / `Done` (re-edit) |
| Control surface | icon toolbar above keyboard; tapping an icon **replaces the keyboard** with a full panel | single control row above keyboard; tapping a control swaps a **chip strip directly above the row**; keyboard never leaves |
| Font picker | full-height 2-column grid of chips (scrolls vertically) | single horizontal chip strip |
| Color picker | eyedropper + 10 round swatches + **Hue/Saturation/Brightness sliders** | eyedropper + square swatches + **page dots (3 pages)**; no sliders |
| Animation/effects | none | `//A` animations + effects category |
| Keyboard visible while styling | no (panel replaces it) | **yes — always** |

The story editor's core virtue: styling never costs the keyboard; you can keep typing at any
moment. All categories are one tap away and their options appear in the same predictable slot.

---

## 3. Shared editing chrome

### 3.1 Layout anatomy (editing mode, portrait)

```
┌──────────────────────────────┐
│ (Next / Done — top-right)    │  canvas: media or gradient bg,
│                              │  dimmed slightly while editing
│  ▲                           │
│  ║  ← size slider (left)     │  text object centered in upper third,
│  ▼                           │  cursor visible, live styled
│                              │
│  [chip strip — options]      │  ← contextual to selected control (story)
│  [control row — categories]  │  ← single persistent row (story)
│  [suggestion row @ Mention ⊙ Location]  (re-edit only)
│  [keyboard]                  │
└──────────────────────────────┘
```

### 3.2 Size slider (measured at 30fps)

**Existence & entry motion**
- The slider exists **only while a text object is editable** (keyboard up). Committed/composing
  states have no slider at all.
- On entering edit mode it **slides in from off-screen at the left edge, moving rightward to an
  inset resting position ≈24pt from the edge**, fading from ~0 to its resting opacity as it
  travels — ≈200ms, ease-out, synchronized with the keyboard/strip rise. (This is the
  "hugs the left, then moves right when editable" behavior: flush/clipped at the edge → settles
  fully visible and grabbable at the inset.) It exits the same way, reversed, on commit.

**Geometry**
- Vertical, centered in the canvas area's height, well above the chip strip.
- Track: an elongated needle/teardrop — **wide at the top (~10pt), tapering to a point at the
  bottom** (~180–220pt tall), translucent white.
- Knob: solid white circle (~22pt) riding the track.

**States**
- Idle (finger off, still editing): dimmed/semi-transparent, knob visible.
- Dragging: track and knob brighten to full opacity and the track reads slightly larger/longer;
  reverts on release.
- The knob **initializes to the object's current size** when re-editing an existing object
  (small text → knob low), not to a fixed default. New text starts near the middle.

**Mapping & text scaling behavior**
- Knob top = largest, bottom = smallest; the needle's tapering width is the size metaphor.
- Scaling is **continuous and live during the drag**: the text re-renders every frame around
  its **center anchor** (both axes — the block stays centered on its position while growing),
  and **re-wraps as it scales** (large sizes reduce characters per line rather than clipping;
  a word can end up alone on a line mid-drag). The label background ribbon (§4.2) re-fits
  every frame as well.
- Range is wide: from caption-small to a single word filling the canvas width.
- The slider adjusts the *editing* text size property; pinch-scaling a committed object (§5) is
  a separate transform on top of it.

### 3.3 Entering / committing
- Entering: canvas dims behind the text (media stays visible), keyboard + control surfaces rise
  together; placeholder shows if empty.
- Commit (`Done`/`Next` or tapping empty canvas): keyboard + strips dismiss; the text object
  remains at its transform on the canvas; compose chrome returns (story: right tool rail
  Aa/sticker/music/@/color + caption bar + audience pills; post: Audio/Text/Overlay/Filter/Edit
  toolbar + blue Next).
- Re-edit: tap a placed object → same editor, `Done` header, properties restored, suggestion
  row (@ Mention / ⊙ Location) present.

---

## 4. The story editor menu pattern (the one to replicate)

### 4.1 Structure

Two stacked bars between canvas and keyboard:

1. **Control row** (persistent, never scrolls): 6 icon controls, evenly spaced, in a rounded
   translucent dark bar:
   `Aa` (font style) · 🎨 color wheel (color) · `//A` (text animation) · ✦ (text effects) ·
   ☰ (alignment, cycling) · `A▢` (label background, cycling)
   - Selected category = lighter pill highlight behind its icon (like a segmented control
     thumb). Cycling controls (align, background) don't hold selection — they flash and apply.
   - The `A▢` icon fills/uncolors to mirror the current background mode (shows green/tinted
     when a colored label is active).
2. **Options strip** (contextual): one horizontally scrollable row of chips sitting directly
   **above** the control row, bottom-aligned to it, same width. Content depends on the selected
   category (§4.2–4.4). Fade/dim gradient at both ends when scrollable.

### 4.2 Options per category

- **Aa — font styles:** chips labeled with the style name **rendered in that style's typeface**
  (Modern, Classic, Signature, Editor, Poster, Bubble, Deco, Squeeze, Typewriter, Strong, …).
  Selected chip = solid white, black label; others translucent dark with white label. Tapping
  restyles the text instantly. (The post editor's full catalog adds: Classic Light, Modern
  Bold, Meme, Elegant, DIRECTIONAL, HALLOWEEN, Crimson Text, Doto, Fraunces, Literature,
  Petit Formal, Raleway, Slabo, Syne.)
- **Color:** leftmost eyedropper button (circular, opens the OS-style loupe color sampler),
  then ~10 **rounded-square** swatches: white, black, blue, green, yellow, orange, red, rose,
  magenta, purple. **Page dots centered below the swatches** — 3 pages (base / pastel / muted
  sets), swiped horizontally. Current color = white ring around its swatch. Selection recolors
  ink instantly (and the label pair when a background is active).
- **`//A` — animations:** `⊗` (none) + `⌶ Typewriter` + `✳ Pop` + `⤻ Jump` — each chip has a
  small icon + label. Selecting plays the animation **immediately and on loop** on the canvas
  text while editing (Typewriter re-types, Pop pops letters in, Jump bounces). `⊗` stops it.
- **✦ — effects:** `⊗` (none) + `✦ Sparkle` + `Neon` + `Shimmer` + `◯ Pixel`. Live, looping:
  Sparkle = drifting gold glints over the text; Neon = soft outer glow; Shimmer = light sweep;
  Pixel = hard pixel-outline treatment. Effects compose with label backgrounds (glints render
  above the label).
- **☰ — alignment:** no strip; each tap cycles center → left → right, icon updates, text
  realigns in place.
- **`A▢` — label background:** no strip; each tap cycles
  `none → white label + colored text → black label + white text → translucent tinted label
  (color-derived) → none`. Label = per-line rounded rectangle, ~8px padding, corners joined
  across lines (contiguous ribbon shape), background follows text width per line.

### 4.3 Switching behavior (measured at 15fps)

- Tapping a control: its highlight pill moves **instantly** (≤1 frame).
- The options strip **crossfades** to the new category's chips in ~1–2 frames (**≈80–130ms**) —
  no slide, no height change, no layout shift; the strip slot is constant-height.
- **Per-category state is retained**: returning to a category restores its scroll offset and
  shows the current selection; strips open scrolled so the selected chip is visible.
- Keyboard stays put through every switch; typing works at all times.
- Selection semantics: fonts/colors/animations/effects are radio groups (exactly one active;
  `⊗` is the none-option for animation/effects). Align/background are stateless cyclers.

### 4.4 Chip anatomy (for Figma)

- Chip: rounded-rect (full radius), ~34pt tall, horizontal padding ~14pt, 8pt gaps.
- Unselected: ~25% white-on-black translucency, white label. Selected: solid white, black
  label. Animation/effect chips lead with a 14pt icon.
- Control row: ~44pt tall bar, full-width, ~10pt side margins, rounded ~14pt; icons ~22pt;
  selection pill = lighter translucent rounded-rect behind the icon.
- Swatches: ~28pt rounded squares (6pt radius), 8pt gaps; eyedropper = 28pt circle button;
  page dots 5pt, 6pt gaps, centered beneath.

### 4.5 Live preview semantics

Everything applies to the canvas text **immediately on tap** — there is no confirm step
anywhere. Color + background interact as a pair (choosing blue with a white label yields blue
text on tinted-blue label in the translucent mode). Animations/effects keep looping during
editing so the user always sees the final result; they persist in the posted story.

---

## 5. Canvas manipulation (committed objects, both editors)

- **Drag** to reposition (direct manipulation, no inertia).
- **Pinch** to scale, **two-finger rotate** — simultaneous, around the gesture centroid.
- **Snap guides**: cyan hairlines appear when the object's center crosses canvas center-X or
  center-Y (video 1 also showed rule-of-thirds verticals); light haptic-style pause at the
  snap, guides vanish on release.
- **Drag-to-delete**: while dragging, a "Drag to delete" label + trash circle appears bottom
  center; hovering scales the object down toward it; release deletes.
- **Tap** a placed object → re-enter editor (§3.3).
- Story right-rail `Aa` adds a **new** object (empty label placeholder box at center).

---

## 6. Post editor specifics (video 1, for completeness)

- Toolbar (icons, above keyboard): keyboard-return, `Aa`, color wheel, `A▢`, align. Tapping
  one **replaces the keyboard region** with its panel; the keyboard icon returns to typing.
- **Font panel**: full keyboard-height, vertically scrolling **2-column grid** of chips
  (scrollbar visible), same chip anatomy at ~40pt.
- **Color panel**: eyedropper + 10 round swatches in a row, then three labeled sliders —
  **Hue** (rainbow track), **Saturation** (white→current hue), **Brightness** (black→current
  color). Tracks re-render live as the color changes; knob = white circle. Custom color lands
  in the eyedropper well.
- Commit returns to the media editor toolbar (Audio/Text/Overlay/Filter/Edit + Next); the
  editing panel visibly collapses toward the placed text.
- No animation/effect categories in this editor.

---

## 7. Timestamped outlines (for future re-analysis)

Source files (as analyzed): `~/Makeready/text editing 1.mov` (60fps, 70.7s) and
`~/Makeready/text editing 2.MP4` (60fps, 62.3s); originals in Dropbox
`…/work/MakeReady.org/Video/`. Overview sampled at 2fps, so timestamps are ±0.5s except the
re-measured moments (menu switches, slider entry/drag) which were captured at 15–30fps.

### Video 1 — post editor (70.7s)

| t (s) | What's demonstrated |
|---|---|
| 0–2.5 | New-post media picker (Recents grid, POST/STORY/REEL/LIVE tabs), photo selection |
| 2.5–4.5 | Media edit screen (Audio/Text/Overlay/Filter/Edit toolbar, suggested-audio pill); tap `Text` → editor entry (slider slides in, keyboard rises) |
| 4.5–9 | Typing "Testing text"; toolbar anatomy (keyboard-return, Aa, color, `A▢`, align) |
| 9–13 | **Color panel replaces keyboard**: eyedropper + round swatches + Hue/Sat/Brightness sliders; text → green |
| 13–18 | Hue/Sat/Bright slider behavior (tracks re-render from current hue) |
| 18–30 | **Font panel** (2-column scrolling grid): browsing, Signature (~24–27), HALLOWEEN (~28–30); chips render own typefaces |
| 30–36 | More font styles; return toward Classic; selected-chip outline state |
| 36–42 | Color re-tuning via HSB sliders (green→teal→blue→purple); custom color lands in eyedropper well |
| 42–46 | `Done` commit — panel collapses toward placed text; mini toolbar moment; text object on photo |
| 46–54 | Re-edit + **size slider drag** (live rescale); canvas **drag with cyan center/thirds snap guides**; "Drag to delete" target |
| 54–60 | **Pinch-scale + two-finger rotate** (diagonal placement); crosshair snap at canvas center |
| 60–66 | **`A▢` label background cycles** (white pill → translucent) on rotated text |
| 66–70.7 | Font panel with label active (Classic Light selected); final placed state |

### Video 2 — story editor (62.3s) — the preferred pattern

| t (s) | What's demonstrated |
|---|---|
| 0–3 | Story Create screen: gradient bg, center `Aa`, left rail Create/Boomerang/Layout/Hands-free, POST/STORY/REEL/LIVE selector |
| 3–4.5 | Camera-mode flash (Boomerang/Layout menus over camera), back to Create |
| 4.5–5.5 | **Editor entry** (30fps-measured): slider slides in from left edge to ~24pt inset; "Type something…"; chip strip (Squeeze selected) + control row + keyboard rise together |
| 5.5–11 | Typing "Adding text"; chip strip + control row anatomy |
| 11–15.5 | **Font chips**: Deco, Poster, Editor, Classic, Signature, Modern selections; live restyle; per-chip self-rendered typefaces |
| 15.5–17 | **Category switch Aa → `//A`** (15fps-measured ~100ms crossfade; highlight moves instantly) |
| 17–23.5 | **Animations live-looping**: Typewriter (~17–19), Pop (~19–21), Jump (~21–23) |
| 23.5–25 | **Switch → ✦ effects** (second measured crossfade) |
| 25–33 | **Effects**: Neon glow (~25–27), Shimmer sweep (~27–29), Pixel outline (~29–31), Sparkle glints (~31–33) |
| 33–35 | **`A▢` background cycles**: black label, white label (icon mirrors mode) |
| 35–42 | Label + effect combinations (Sparkle over black label); translucent tinted label mode |
| 42–44 | **Switch → color** (measured): eyedropper + square swatches + **page dots**; blue selection recolors label pair |
| 44–48 | Swatch pages swiped; final blue-on-tinted-label look |
| 48–54 | `Next` → compose; **tap-to-re-edit** (Done header, @ Mention / ⊙ Location row, state restored) |
| 54–58 | **Size slider drag** (10fps-measured): knob init from current size; center-anchored per-frame rescale with live re-wrap, caption-size → canvas-filling |
| 58–62.3 | Commit; **pinch/rotate to diagonal**; compose chrome (right rail, caption, Your stories/Close Friends); Sparkle still animating on placed object |

## 8. Requirements to support this (engineering model)

What a faithful implementation needs, independent of platform:

1. **Style catalog**: a `TextStyle` registry (name, font family/weight, case treatment,
   letterspacing, optional per-style label-background affinity) driving both the chip labels
   (self-rendered) and the canvas rendering. Chips must render their own typeface — the
   catalog must be loadable by the menu itself.
2. **Text object schema** (serializable):
   `{ id, content, styleId, color, backgroundMode: none|solid-light|solid-dark|tinted,
   align, sizeFraction, transform: {x, y, scale, rotation}, animationId?, effectId? }` —
   coordinates normalized to canvas so rendering is resolution-independent.
3. **Label background renderer**: per-line rounded rects joined into a contiguous ribbon
   (union of line boxes with corner radii resolved at the joins), padding constant, recomputed
   on every content/size/align change. This is the hardest drawing piece; it must follow live
   typing.
4. **Menu framework**: control row (radio categories + stateless cyclers) with a
   constant-height contextual strip slot above it; ≈100ms crossfade on category switch;
   per-category scroll/selection retention; strips never affect keyboard or layout.
5. **Color system**: paged swatch strips + eyedropper (canvas pixel sampling with loupe);
   optionally the HSB slider panel (post-editor style) as an "advanced" surface. Track
   gradients must re-render from the current hue.
6. **Animation engine**: per-object looping text animations (typewriter reveal, per-letter
   pop-in with overshoot, per-letter jump/bounce) that run during editing and playback, and
   restart on selection. Needs per-character/per-word timeline control of the rendered text.
7. **Effects engine**: composable visual treatments (outer glow, particle glints, light sweep,
   pixel outline) that stack with any style/color/background and keep animating in the
   committed/posted rendering.
8. **Gesture layer**: simultaneous drag+pinch+rotate on objects; center/thirds snap guides
   with haptic; drag-to-delete target; tap-to-edit hit-testing that wins over canvas taps.
9. **Size slider**: left-edge continuous control mapping to `sizeFraction` (wide min/max
   range), with the full behavior set from §3.2: slide-in-from-edge entry/exit tied to the
   editing session, idle-dim/drag-brighten states, knob initialized from the object's current
   size, and per-frame center-anchored rescale with live re-wrap (text layout must be cheap
   enough to re-measure every frame of the drag, label ribbon included).
10. **Multi-object canvas**: z-order = creation order; per-object editing sessions; placeholder
    object creation from the compose rail.
11. **Editing session state machine**: `composing → editing(objectId) → composing`, keyboard
    always up during `editing`, commit on Done/Next/canvas-tap, canvas dim during editing.
12. **Eyedropper** requires reading canvas pixels (media frame included) — plan for a
    render-to-texture/canvas readback path.

## 9. Figma translation contract

When the Figma designs come, name things with this taxonomy so translation is mechanical:

- `TextEditor/ControlRow` with variants per selected category (`style|color|animation|effects`)
  and the two cyclers' states (`align=center|left|right`, `bg=none|light|dark|tinted`).
- `TextEditor/OptionStrip/{Style|Color|Animation|Effects}` — chip components with
  `selected=true|false`; color page = `swatchPage=1|2|3`.
- `TextEditor/Chip` (label, optional icon, selected variant), `TextEditor/Swatch`,
  `TextEditor/SizeSlider`, `TextEditor/SnapGuide`, `TextEditor/DeleteTarget`.
- Canvas text component with the full property set from §8.2 as variants/props where feasible
  (styleId, backgroundMode, align).
- Provide the style catalog as actual text styles in Figma (one per chip) — those map 1:1 to
  the `TextStyle` registry.
