# 10 — Mapping onto the MakeReady design frames

The four frames in `assets/design/` are the MakeReady lesson editor as designed so far. This
file maps every reference behavior in `02`–`08` onto a control in those frames, names what the
frames add that the reference does not have, and collects the rulings the `activities-editor`
screen spec needs before it can close. Everything here is read off the PNGs; nothing is a Figma
contract yet (`activities-editor` is `pending-figma` in `../README.md`).

## 1. The frames

| File | State it shows | Chrome |
|---|---|---|
| `blank-canvas.png` | Idle, empty page | nav: back chevron (purple) · "Edit lesson"; canvas: dark navy (≈ `#10131F`), full-bleed; bottom bar: page thumbnails (2 shown, selected one white-outlined) + purple **+** at the right |
| `edit-text.png` | Editing, color category open, no keyboard | nav: **Cancel** (gray) · "Edit lesson" · **Done** (purple); left size slider (white wedge + thumb, x ≈ 21 pt, track 37 %–65 % of height, thumb at 51 %); color row: eyedropper well (blue-filled = selected) + 9 rounded-square swatches (white, black, blue [outlined], green, yellow, orange, red, pink, purple) + 3 page dots; tool row (6 tools, see §2) |
| `edit-font.png` | Editing, font category open, no keyboard | same nav; chip row: **Poppins** (bold) · **SF Pro** · **Georgia** (serif) · **Typewriter** (mono, selected = white fill), left-aligned, outlined unselected chips; tool row with **a/a** highlighted |
| `edit-highlights.png` | Editing a **scripture block** (not a text object) | passage text with verse numbers over a purple-tinted image; yellow highlight spans; bottom: red-outlined trash + "**+ Add note**" button; tool row with **a/a** highlighted |

## 2. Tool row mapping

The reference tool row has six tools (`01` §3). The MakeReady frames also show six, in this
order: **sphere** · **image** · **≡** · **Aa** · **a/a** · **///**.

| MakeReady tool | Reads as | Maps to reference | Confidence | Note |
|---|---|---|---|---|
| sphere (gradient circle) | color | **color** category (`04`) | high — same icon idea; the color row is open in `edit-text.png` | the highlight pill in that frame sits on the *image* tool, not the sphere — see `OQ-10-1` |
| image | background image | **none** — new | high | MakeReady pages have a media background (`edit-highlights.png` shows one); the reference's gradient background has no tool |
| ≡ | alignment | **alignment** instant-action (`05` §1) | high — identical glyph (centered lines) | |
| Aa | ? | **fonts** category (`03`) *or* a size/style preset | low | the reference's Aa is fonts, but `edit-font.png` highlights **a/a** for fonts — `OQ-10-2` |
| a/a (two a's, split light/dark) | font | **fonts** category (`03`) | high — highlighted while the font chips are open | |
| /// | effects or animations | **✦ effects** and/or **//A animations** (`06`) | medium — glyph resembles the reference's **//A** | one tool for two reference categories, or animations only — `OQ-10-5` |

Not present in the frames: the **label background** tool (`05` §2). Either it is folded into
another tool, or the design drops it — `OQ-10-6`.

## 3. Feature-by-feature mapping

| Reference behavior | Spec | MakeReady control | Status |
|---|---|---|---|
| Tap blank canvas → new text object, keyboard up | `02` §1, `08` §1 | canvas tap in `blank-canvas.png` → `edit-text.png` state | designed (both states exist); the keyboard is not drawn in any frame — the frames show the panel states only |
| Placeholder "Type something…" | `02` §1 | — | not drawn; needs copy |
| Size slider (vertical wedge, left) | `02` §5 | identical wedge slider at x ≈ 21 pt | designed; note the design's track is shorter (≈ 28 % of height vs ≈ 30 %) and the default thumb is at 51 % (reference ≈ 64 %) — `OQ-10-7` |
| Done commits; Cancel | `02` §4 | **Done** (purple) and **Cancel** (gray) in the nav | designed; Cancel is **new** — its semantics (discard edits to an existing object; delete a new one) are not in the reference — `OQ-10-8` |
| Font chips, self-rendered, centered selection | `03` | four left-aligned chips, self-rendered, white-filled selection | designed with a different mechanic (no scroll/center) — `OQ-10-3` |
| Swatch row + eyedropper well + 3 pages | `04` | identical row, square swatches | designed; eyedropper shown selected — `OQ-10-4` |
| Alignment cycle | `05` §1 | **≡** | designed as an icon; cycle order not shown |
| Label cycle | `05` §2 | — | missing — `OQ-10-6` |
| Animations (Typewriter/Pop/Jump) | `06` §1 | **///** (?) | unclear — `OQ-10-5` |
| Effects (Sparkle/Neon/Shimmer/Pixel) | `06` §2 | **///** (?) | unclear — `OQ-10-5` |
| Drag / pinch / rotate, center guide, drag-to-delete | `07` | — | nothing drawn; behavior-only, reference applies as-is |
| Transitions | `08` | — | nothing drawn; reference timings apply as-is |
| Canvas scrim while editing | `01` §2 | not visible — the design canvas is already dark navy with no object | `OQ-10-9` |

## 4. What the MakeReady frames add (outside the reference)

| Addition | Where | Owning spec |
|---|---|---|
| Page strip + add page | `blank-canvas.png` bottom bar | `activities-editor` screen spec (pager surface, `features/activities/07` §6) |
| Background image tool | tool row | `activities-editor` — a page property, not a text-object property |
| Scripture block editing: highlight spans, delete block, "Add note" | `edit-highlights.png` | `activities-editor` + the existing exegesis block model (`features/activities/06-activity-types.md`); the text-object tools in this folder do **not** apply to scripture text (its highlighting is range-based, which `02` §2 rules out for text objects) |
| Nav bar with title and back chevron in Idle | `blank-canvas.png` | `activities-editor` |

## 5. Open questions needing an owner ruling

| Id | Question | Why it blocks |
|---|---|---|
| **OQ-10-1** | In `edit-text.png` the color row is open but the **image** tool carries the highlight pill. Is that a frame error, or does the image tool open a panel that shares the swatch row (e.g. background color)? | Decides whether the sphere or the image tool is the color category |
| **OQ-10-2** | What does **Aa** do, given **a/a** is fonts? Candidates: text-size presets (duplicating the slider), text style presets (heading/body), or the label tool. | Tool row has one unexplained slot |
| **OQ-10-3** | Once the font set grows past four, does the chip row become the reference's scrolling, always-centered strip? With four it is static and left-aligned. | Determines which strip mechanic (`03` §2) to build |
| **OQ-10-4** | The eyedropper well is drawn **selected** (blue fill). Is it a mode toggle (tap to arm the on-canvas picker), or is it just showing the "current color" state as in the reference? | Changes the well's behavior |
| **OQ-10-5** | Does **///** open animations, effects, or a single combined strip? Are both reference properties kept? | Two reference categories, one slot |
| **OQ-10-6** | Is the **label background** feature kept, and where does it live? | Missing from the frames |
| **OQ-10-7** | Slider default position (design 51 % vs reference 64 %) and its size range. | Default text size |
| **OQ-10-8** | **Cancel** semantics: revert the object to its pre-edit state; for a brand-new object, remove it. Confirm, and confirm whether the keyboard's return key or tapping outside also commits. | New control with no reference |
| **OQ-10-9** | Is the editing scrim (`01` §2) kept over MakeReady's dark canvas + background image? The frames cannot show it because no committed object exists in them. | Affects every transition in `08` |
| **OQ-10-10** | Page-level behaviors the reference has none of: does tapping the blank canvas *below the page's existing blocks* add text, or is text only one block type among scripture/media? | Entry gesture (`02` §1) |

Rulings go into `../DECISIONS.md` or the `activities-editor` screen spec's §Decisions; this file is
updated to point at them when they land.
