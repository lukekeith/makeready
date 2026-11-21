# 01 — Video Analysis: iPhone Notes app

**Source:** `/Users/lukekeith/Makeready/Notes/Notes.MP4` — 55.92 s, 60 fps, 1320×2868 (3× of
440×956 pt, iPhone 16/17 Pro Max class), **dark mode**, iOS 26 generation ("Liquid Glass").
**Method:** 4 fps contact sheets end-to-end (±0.25 s), full-resolution single frames at every
state change, 10–15 fps windows over the two interactions that involve motion (list popover,
select-then-bold).

> A first pass over this same recording exists at
> [`docs/features/activities/11-notes-editor-analysis.md`](../activities/11-notes-editor-analysis.md).
> That pass looked at the recording narrowly — as the reference for the *WRITE activity's input
> surface*. This doc re-analyzes it as **a complete note-taking feature**: the list screen, the
> note lifecycle, and the editor, at the level of detail needed to rebuild it.

---

## 1. Screen inventory

Two screens, one push transition between them.

| Screen | Role |
|---|---|
| **Note list** (`All iCloud`) | Browse / search / create. Entered from a folder list one level up (a back chevron is present). |
| **Note editor** | The note itself. Full-screen document, keyboard up. |

There is no third screen. Everything else — text styles, list types, the note menu — is a
**popover or menu drawn over one of these two**. Nothing pushes, nothing modally covers the
document.

---

## 2. The note list

Measured from the frame at t = 0.30 s (full resolution, 1320×2868).

### 2.1 Chrome

- **Top-left:** back chevron in a ~40 pt translucent dark circle (returns to the folder list).
- **Top-right:** `⋯` in a matching circle (list-level menu: sort, view as gallery, select notes…).
- **No opaque navigation bar.** Both buttons float directly over the scrolling content; content
  scrolls *under* them.
- **Large title block:** `All iCloud` (~34 pt bold) with a secondary line `469 Notes`
  (~17 pt, secondary gray) beneath it. The title is part of the scroll content, not the chrome.

### 2.2 List structure

Notes are grouped by recency into **date sections**, each rendered as an inset-grouped card:

```
Today                      ← section header, ~22 pt bold, flush left at the page margin
┌──────────────────────────┐
│ OneTouch                 │  ← row: title, 17 pt semibold, white
│ 2:16 PM  $1.75M cash …   │  ← row: time-or-date + first-line preview, 15 pt, gray
│ 🗀 Notes                 │  ← row: folder glyph + folder name, 13 pt, gray
├──────────────────────────┤  ← hairline separator, inset to the title's left edge
│ Kono prompt              │
│ 1:53 AM  There's only …  │
│ 🗀 Notes                 │
└──────────────────────────┘

Previous 7 Days
┌──────────────────────────┐  ← Milton Friedman / truesheet / Car investment
…
Previous 30 Days
```

Observed section labels: **Today**, **Previous 7 Days**, **Previous 30 Days** (Notes also emits
`Yesterday`, month names, and years for older content). The date column adapts: same-day rows
show a **time** (`2:16 PM`), rows inside the last week show a **weekday** (`Wednesday`,
`Monday`), older rows show a **short date** (`8/6/26`, `8/3/26`).

Card geometry: ~14 pt horizontal page margin, ~18 pt corner radius, row background one step
lighter than the page black, ~26 pt gap between section cards.

### 2.3 The floating bottom bar

Two separate floating elements over the content (the row behind them, "USPS", is visible and
dimmed by a scrim gradient):

1. A wide, fully-rounded **search capsule**: magnifier glyph + placeholder `Search` + a
   **microphone** glyph at its trailing end (dictation into search).
2. A separate **circular compose button** (square-and-pencil glyph) to the right of the capsule.

They are *not* in a toolbar — no bar background, no divider. The two shapes float ~14 pt from the
bottom safe area and are separated by a ~10 pt gap. Search is the primary target by width;
compose is the primary target by affordance.

---

## 3. The note editor

### 3.1 Entry

Compose is tapped at **t ≈ 1.0–1.5 s** and the editor is *already fully live* on the next
sampled frame: note open, **keyboard up, format strip docked, amber caret blinking at the top
left**. Zero taps between "I want to write" and "I am writing". There is no intermediate
"tap the body to begin" state and no visible push animation cost.

### 3.2 The canvas — a page, not a field

The whole screen below the chrome is the document. No border, no background tint, no inner
container, no placeholder box.

| Metric | Value (3× measured / pt) |
|---|---|
| Horizontal text margin | 88 px → **~29 pt**, both sides |
| Title line | ~28 pt bold, white |
| Body line | 17 pt regular, white (SF Pro Text) |
| Bullet glyph x-position | ~47 pt; bullet item text at ~64 pt |
| Caret | 2 px hairline, **amber** (`tintColor`), full line height |
| Paragraph rhythm | Title → one blank line → body; blank line between paragraphs |

**The first line is the title.** Typing "Note" at t = 2.3–5.0 s renders large and bold *as it is
typed*; pressing return drops to Body for the next line. There is no separate title field, and
the note's name in the list is literally this first line.

### 3.3 Nav chrome while editing (t = 55.0 s, full res)

Left to right, all floating over the document:

| Element | Shape | Notes |
|---|---|---|
| Back chevron | ~40 pt dark circle | Returns to the list. **The note is already saved** — there is no Save anywhere. |
| Undo `↩` | ~40 pt dark circle, standalone | **Absent on a fresh note**; appears on the first keystroke, i.e. it is bound to the undo stack being non-empty. |
| Share `⇧` + `⋯` | one **capsule** holding two glyphs, divided by nothing but spacing | Note-level actions (share/collaborate; pin, lock, move, find in note, lines & grids, delete). |
| **Done** | ~56 pt **yellow filled circle with a white checkmark** | Only present while editing. Dismisses the keyboard + strip and exits edit mode. |

The grouping is meaningful: *destructive-free navigation* is a bare circle, *note actions* are a
capsule cluster, *the single primary action* is a filled accent circle at the trailing edge.

### 3.4 The format strip — the core pattern

One **horizontally scrollable capsule** docked immediately above the keyboard: ~43 pt tall,
~13 pt from both screen edges, fully-rounded ends, dark translucent fill. This is the iOS 26
replacement for the old `Aa` half-sheet: **all formatting lives inline in the strip; only option
pickers open popovers.** The document is never covered and never moves.

Contents, in scroll order (7 visible at rest on a Pro Max):

| # | Glyph | Function | Seen in video |
|---|---|---|---|
| 1 | `Aa` | Text-style menu (Title / Heading / Subheading / Body / Monostyled) | visible |
| 2 | ☑︎ list | Checklist | visible |
| 3 | table | Insert table | visible |
| 4 | paperclip | Attach (scan / photo / file) | visible |
| 5 | pen-in-circle | Markup / drawing | visible |
| 6 | AI sparkle | Apple Intelligence writing tools | visible |
| 7 | **B** | Bold | **applied t ≈ 40.0 s** |
| 8 | *I* | Italic | visible |
| 9 | U̲ | Underline | visible |
| 10 | S̶ | Strikethrough | visible |
| 11 | marker pen | Highlight | visible |
| 12 | chain link | Add link | visible |
| 13 | ≡ | paragraph-group divider | visible |
| 14 | ▶≡ | Increase indent | visible |
| 15 | ↑▔ | Move line up | visible |
| 16 | ↓▁ | Move line down | visible |
| 17 | ▏■ | Block quote | visible |
| 18 | ≡ list | **List menu** → popover | **opened t ≈ 20.3 s** |

Mechanics worth copying exactly:

- **Scrolls like content, not like tabs.** Free momentum scroll, no paging, no snapping. Scroll
  position persists across typing; at t ≈ 42 s the user swipes it back to the leading edge
  manually.
- **Buttons are stateful.** When the caret or selection carries a style, that button becomes a
  **filled accent circle with a dark glyph** (~37 pt). Measured on B at 10 fps: tap → circle pops
  in slightly oversized → settles; toggling off fades white → gray → plain glyph over **~200 ms**
  (t ≈ 41.0–41.2 s).
- **Popovers, not sheets.** The list button opens a dark rounded-rect menu of three rows
  (icon + label, no checkmarks) anchored **above the button, over the strip**. It does not dim
  the document, does not move the keyboard, and dismisses the instant an option is chosen.
  Note: while the popover is open the strip itself is **hidden behind it** — the popover
  visually replaces the strip's row and extends upward.
- **The strip is the keyboard's accessory view.** It appears and disappears with the keyboard as
  one unit and sits flush above the QuickType / Writing-Tools row when that row is present.

### 3.5 The system Writing Tools row (not Notes UI)

From ~t = 13 s a second row appears between strip and keys: `🔍 Proofread │ ⟳ Rewrite │ (AI)`.
This is the **system keyboard's** iOS 18+ Writing Tools surface, not Notes chrome — it comes and
goes on its own (present ≈13–36 s, absent during selection callouts and near the end). Any
`UITextView`-based editor gets it free on device. **Do not rebuild it.**

### 3.6 Formatting behaviors demonstrated

1. **Title auto-style** — first line is Title, live, no commit step (§3.2).
2. **Lists** — caret on an empty body line → list button → popover → **Bulleted** inserts a
   bullet on that line immediately (t ≈ 21.7 s). Return inside a list continues the list.
   **Return on an empty item exits the list**, dropping the caret to a flush-left Body line
   (t ≈ 30.5–31.5 s). The classic notepad escape hatch — no toolbar round-trip.
3. **Selection styling** — double-tap selects a word: translucent **amber wash + round amber
   lollipop handles**, plus the standard edit callout `Cut │ Copy │ Paste │ Delete │ ›` in a
   dark capsule above the selection (`Delete` is the only red item). Tapping **B** with the
   strip scrolled to the inline group applies bold in place, dismisses the callout, keeps the
   word selected, and lights the B button (t ≈ 40.0 s).
4. **Style state follows the caret** — B stays lit while the caret is inside bold text and
   clears when it leaves (t ≈ 41.0 s). Typing after toggling off produces plain text.
5. **No mode switches, ever.** At no point does the document change appearance, position, or
   inset while formatting. There is no preview/commit split and no "formatting mode".

### 3.7 Final document state (t = 55 s)

```
Note                                    ← Title
                                        ← blank
Here are my thoughts on the lesson      ← Body
  •  this is a bullet list
  •  here is another
                                        ← blank
This is bold                            ← "bold" is bold
                                        ← blank
Just typing, watch the UI for styles|   ← caret
```

---

## 4. Timestamped outline

Sampled at 4 fps (±0.25 s); **bold** rows were re-extracted at 10–15 fps (±0.1 s).

| t (s) | What happens |
|---|---|
| 0.0–1.0 | **Note list.** `All iCloud`, 469 Notes; sections Today / Previous 7 Days / Previous 30 Days; floating search capsule + compose circle at bottom |
| ~1.0–1.5 | Compose tapped → editor opens with keyboard + format strip already presented, amber caret at top-left |
| 2.3–5.0 | Types `Note` — renders live in Title style; **undo button appears** in the nav on the first keystroke |
| ~5.5 | Return → style drops to Body |
| 5.5–12.5 | Types `Here are my thoughts on the lesson` |
| ~13.0 | System Writing Tools row (Proofread / Rewrite / AI) appears above the keyboard |
| 14.0–19.5 | User swipes the format strip left, revealing **B I U S̶** · highlight · link · ¶-group (indent, move ↑/↓, block quote, list) |
| **20.3** | Taps the **list** button → popover above it: `Bulleted / Dashed / Numbered`; the strip is hidden behind the popover |
| **21.7** | Taps **Bulleted** → bullet inserted on the current line, popover dismisses instantly |
| 22–26 | Types `this is a bullet list`; Return continues the list |
| 26–30 | Types `here is another` |
| 30.5–31.5 | Return on an empty third bullet → **exits the list**; caret returns flush-left as Body |
| 33.0–36.5 | Types `This is bold` (plain) |
| **37.0** | Double-tap selects `bold`: amber wash + amber lollipop handles + callout `Cut│Copy│Paste│Delete│›` |
| **40.0** | Taps **B** → accent circle pops in oversized then settles lit; the word becomes bold; the callout dismisses |
| **41.0–41.2** | B active state clears over **~200 ms** (white → gray → plain) as the caret leaves the bold run |
| 42.0–42.5 | Strip swiped back to its leading (`Aa`) position |
| 42.5–53 | Types `Just typing, watch the UI for styles` — plain body (`123` layer used for punctuation) |
| 53–55.9 | Idle on the finished document |

---

## 5. What the recording does *not* show

Flagged so nothing here is mistaken for observation:

- The `Aa` text-styles menu, the checklist behavior, tables, attachments, markup, highlight, and
  links — **buttons visible, never opened**.
- The list-level `⋯` menu and the editor's `⋯` menu.
- Search, folders, pinning, swipe actions on a row, delete, share/collaboration.
- Whether the strip auto-returns to its leading position when the caret exits a list, or whether
  the user swiped it back (ambiguous at t ≈ 31 s and 42 s). **Treat manual swipe as the baseline
  and auto-return as optional.**
- Light mode. Everything above is measured in dark mode.

See [02-under-the-hood.md](02-under-the-hood.md) for what is known about these from the platform
rather than from the video.
