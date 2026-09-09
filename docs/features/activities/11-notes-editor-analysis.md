# 11 — Notes Editor Analysis (iPhone native Notes app)

**Purpose:** a behavioral spec of the current iPhone **Notes** app's note-writing experience,
captured frame-by-frame from a screen recording (`Notes.MP4`, 55.9s, 60fps, 1320×2868 = 3x
440×956pt, dark mode), plus context from the current app generation (iOS 18 → iOS 26 "Liquid
Glass"). **This is the reference UX for the WRITE activity's input surface**: not a field in a
box, but a full-width, full-height notepad you type straight into, with formatting living in a
horizontally scrollable strip docked above the keyboard.

Analysis method: 2fps full-run contact sheets → full-res crops of the format strip at every
state change → 10–15fps windows over the two key interactions (list creation via popover,
select-then-bold). Sister doc: [10-text-editing-analysis.md](10-text-editing-analysis.md)
documents Instagram's canvas-text editors — that pattern fits styled *display* text (TEXT/IMAGE
pages); **this** pattern fits document-style *writing* (WRITE pages).

---

## 1. The canvas — a page, not a field

The entire screen below the nav chrome is the document. There is no visible input container,
border, background tint, or placeholder box — the note is a black (dark mode) page with text
laid straight onto it.

| Metric | Value (measured at 3x) |
|---|---|
| Horizontal text margin | ~29pt both sides (text x=88px/1320) |
| First line style | **Title**: ~28pt bold, white |
| Body text | 17pt regular, white (SF Pro Text) |
| Bullet indent | bullet glyph at ~47pt, item text at ~64pt |
| Caret | 2px hairline, **amber/yellow** (Notes accent), full line height |
| Vertical rhythm | Title → one blank gap → body paragraphs; paragraph spacing ≈ half a line |

Behaviors that make it feel like paper rather than a form:

- **The keyboard is already up** when the note opens (compose → cursor blinking at the top
  left, zero taps to start typing).
- **The first line is automatically the Title style** — type, and it renders large/bold as you
  type. Press return and subsequent text is Body. (This is Notes' "New Notes Start With: Title"
  default; the style is applied live, not on commit.)
- Tapping anywhere in the page moves the caret there; tapping below the last line puts the
  caret at the end. The page scrolls naturally as content grows; the keyboard never covers the
  caret (the scroll view insets by the keyboard + strip height).
- Text wraps at the right margin; there is no horizontal scrolling ever.

## 2. Navigation chrome (iOS 26 Liquid Glass)

Frosted circular/capsule buttons floating over the content, not a solid bar:

- **Top left:** back chevron in a circle (returns to the list; the note auto-saves — there is
  no explicit save anywhere).
- **Top right cluster:** **undo** (↩ appears only once the undo stack is non-empty — it is
  absent on a fresh note), **share**, **ellipsis** (⋯ note-level menu), and a **prominent
  yellow-filled circle with a checkmark** = Done. Done dismisses the keyboard and exits editing;
  it exists only while editing.
- No title bar text — the note's title IS the first line of the document.

## 3. The format strip — the core pattern

A single **horizontally scrollable capsule strip** (~43pt tall, ~12pt from screen edges,
fully-rounded ends) docked immediately above the keyboard. This replaced the old iOS 17 "Aa
opens a half-sheet panel" design: **all formatting is inline in the strip; only pickers with
options open small popovers above it.**

### 3.1 Strip contents, in order (left → right)

| # | Glyph | Function | Demonstrated in video |
|---|---|---|---|
| 1 | `Aa` | Text styles menu (Title / Heading / Subheading / Body / Monostyled) | visible, not opened |
| 2 | ☑︎-list | Checklist (one tap converts line to a round-checkbox item) | visible |
| 3 | table | Insert table | visible |
| 4 | paperclip | Attach (scan document / photo / file) | visible |
| 5 | pen-in-circle | Markup / drawing canvas | visible |
| 6 | AI sparkle-loop + pencil | Apple Intelligence Writing Tools | visible |
| 7 | **B** | Bold toggle | **applied to selection at t≈40.0s** |
| 8 | *I* | Italic toggle | visible |
| 9 | U̲ | Underline toggle | visible |
| 10 | S̶ | Strikethrough toggle | visible |
| 11 | marker pen + underline | Highlight (text background color) | visible |
| 12 | chain link | Add link | visible |
| 13 | ≡ (three shrinking lines) | trailing paragraph-options group divider | visible |
| 14 | ▶≡ | Increase indent | visible |
| 15 | ↑ to bar | Move line/list-item up | visible |
| 16 | ↓ to bar | Move line/list-item down | visible |
| 17 | ▏■ | Block quote | visible |
| 18 | ≡ bullets | **List menu → popover: Bulleted / Dashed / Numbered** | **opened at t≈20.3s, Bulleted chosen** |

(Items 1–7 fit the visible width at rest; everything else is reached by swiping the strip
left. ~7 items visible at a time on a Pro Max width.)

### 3.2 Strip mechanics (the details worth copying)

- **It scrolls like content, not like tabs**: free momentum scrolling with no paging or
  snapping observed; position persists while you type (at t=42s the user swipes it back to the
  leading edge manually).
- **Buttons are stateful.** When the caret/selection carries a style, that button renders as a
  **yellow filled circle with a dark glyph** (measured ~37pt diameter). Observed on B: tap →
  the circle pops in slightly oversized (tap-down state) → settles; toggling off fades
  white → gray → plain glyph over ~200ms (measured at 10fps, t≈41.0–41.2s).
- **Popovers, not sheets, for option pickers**: the list button opens a dark rounded-rect menu
  (three rows, icon + label, no checkmarks) anchored directly **above the button**, over the
  strip. Choosing an option applies instantly and dismisses. Nothing covers the document.
- **Context awareness**: while the caret is inside a list, the strip's list/paragraph group is
  the relevant end (indent, move up/down are meaningful); when the list exits, the strip is
  back at its default leading position. (The video is ambiguous on whether the scroll-back at
  t≈31s and t≈42s is automatic or user-swiped — treat auto-return as optional, manual swipe as
  the baseline.)
- The strip is **the keyboard's accessory view**: it appears/disappears with the keyboard as
  one unit and sits flush above the QuickType/Writing-Tools row when that row is present.

### 3.3 The system Writing Tools row (not Notes UI)

From ~t=13s a second row appears between strip and keys: `🔍 Proofread | ✎ Rewrite | (AI)`.
This is the iOS 18+ **Writing Tools** surface owned by the system keyboard — it comes and goes
on its own (present ~13–36s, absent during selection callouts and near the end). Any
`UITextView`-based editor gets it for free on-device; the web twin should **not** replicate it.

## 4. Typing & formatting behaviors (as demonstrated)

1. **Title auto-style** — "Note" typed at 2.3–5.0s renders as Title live; return switches to
   Body for the next line. Undo appears in the nav on the first keystroke.
2. **Lists** — with the caret on an empty body line, list button → popover → **Bulleted**
   inserts a bullet on that line immediately (t≈21.7s). Return inside a list continues the
   list with a new bullet. **Return on an empty item exits the list** and drops the caret back
   to a flush-left Body line (t≈30.5–31.5s) — the classic notepad escape hatch, no toolbar
   round-trip needed.
3. **Inline styling via selection** — double-tap selects a word: translucent **amber selection
   wash + round yellow lollipop handles**, and the standard edit callout (`Cut | Copy | Paste |
   Delete | ▸`) appears above the selection. With the strip scrolled to the inline group,
   tapping **B** applies bold to the selection in place, dismisses the callout, keeps the
   selection's word bolded, and lights the B button (t≈40.0s).
4. **Style state follows the caret** — B stays lit while the caret/selection is in bold text
   and clears when it isn't (t≈41.0s). Typing after toggling a style off produces plain text
   (the "Just typing, watch the UI for styles" paragraph is entirely regular).
5. **No mode switches** — at no point does the document change appearance, position, or inset
   while formatting. Formatting is applied to the live text; there is no preview/commit split.

## 5. Timestamped outline

Source: `/Users/lukekeith/Makeready/Notes.MP4` — 55.92s, 60fps, 1320×2868 (3x). Sampled at
2fps (±0.5s) with 10–15fps windows over 20–22s and 36–42s (**bold** rows, ±0.1s).

| t (s) | What happens |
|---|---|
| 0.0–1.0 | Notes list ("All iCloud", 469 notes): grouped Today / Previous 7 Days / Previous 30 Days; bottom bar = search capsule + compose button |
| ~1.0–1.5 | Compose tapped → new note opens with keyboard + strip already presented, amber caret blinking top-left |
| 2.3–5.0 | Types "Note" — renders live in Title style; undo button appears in nav on first keystroke |
| ~5.5 | Return → Body style |
| 5.5–12.5 | Types "Here are my thoughts on the lesson" (17pt body) |
| ~13.0 | System Writing Tools row (Proofread / Rewrite / AI) appears above keyboard |
| 14–19.5 | User swipes the format strip left, revealing B I U S̶ · highlight · link · ¶-group (indent, move ↑/↓, block quote, list) |
| **20.3** | Taps list button → popover above it: Bulleted / Dashed / Numbered |
| **21.7** | Taps **Bulleted** → bullet inserted on current line, popover dismisses |
| 22–26 | Types "this is a bullet list"; Return continues list |
| 26–30 | Types "here is another" |
| 30.5–31.5 | Return on empty third bullet → **exits list**, caret flush-left Body; strip back at leading position |
| 33–36.5 | Types "This is bold" (plain) |
| **37.0** | Double-tap selects "bold": amber wash + yellow handles + callout (Cut/Copy/Paste/Delete/▸) |
| **40.0** | Taps **B** → oversized-yellow-circle pop → settles lit; word becomes bold; callout dismisses |
| **41.0–41.2** | B active state clears (white → gray → plain, ~200ms) — bold off / caret out of bold run |
| 42.0–42.5 | Strip swiped back to leading (Aa) position |
| 42.5–53 | Types "Just typing, watch the UI for styles" — plain body (123 layer for the comma) |
| 53–55.9 | Idle; final document: Title + body + 2-item bullet list + bolded word + closing paragraph |

## 6. Context from the current Notes app (knowledge, beyond the video)

- **Text styles** (under `Aa`): Title, Heading, Subheading, Body, Monostyled — paragraph-level,
  one per line/paragraph. Block quote adds a leading vertical rule; lists are Bulleted / Dashed
  / Numbered; checklists are a separate concept (tappable round checkboxes, completed items can
  auto-sort to the bottom).
- **Highlight** (item 11) applies one of five text-color/background treatments (purple, pink,
  orange, mint, blue in light variants) — Notes' only color affordance; there is no free-form
  text color picker.
- **Links** (item 12) can be URLs or note-to-note links (type a title, it autocompletes).
- Everything is stored as attributed rich text; **there is no markdown syntax surface** —
  though typing "- " or "1. " at line start auto-converts to the corresponding list, and
  Notes renders `#`-style shortcuts only via keyboard shortcuts on iPad/Mac, not iPhone.
- The strip layout above is the **iOS 26 (Liquid Glass)** generation; iOS 17 kept the same
  capabilities behind an `Aa` half-sheet panel. The strip is the pattern to copy — it keeps the
  document fully visible at all times.
- System caret/selection/handles come free with `UITextView`; the amber tint is the app's
  accent color (`tintColor`), not custom drawing.

## 7. Translation to the WRITE activity

What the write-activity input surface must copy to "feel like Notes"
(refines [06-activity-types.md](06-activity-types.md) §WRITE):

1. **Full-width page, no box.** The write page's input is the page below the prompt: no border,
   no background, no inner padding beyond the page's own text margins (~24–29pt). The
   placeholder is a ghost first line, not a boxed hint.
2. **Zero-tap start** on entering edit: caret placed, keyboard up, strip docked.
3. **Keyboard-accessory format strip**: one horizontally scrollable capsule; option pickers as
   popovers anchored above their button; stateful buttons using the accent-filled-circle
   active treatment. iPhone: `inputAccessoryView` on the text view. Web twin: a fixed-position
   strip above the visual viewport keyboard inset (`visualViewport` API), same geometry.
4. **Minimum viable format set** for member notes: Bold / Italic / Underline / Strikethrough,
   Bulleted + Numbered lists, and the return-on-empty-item list escape. Title auto-style,
   checklists, tables, attachments, highlight, and links are Notes features we explicitly
   **defer** — the strip pattern leaves room to add them without redesign.
5. **Selection styling** must work the Notes way: select → tap strip toggle → style applies in
   place, no mode change, no dialog; toggle state always reflects the caret's current run.
6. **Content shape**: rich text means the WRITE submission can no longer be a plain string —
   it needs the same block/markdown content format the TEXT activity uses (bold/italic/lists
   round-trip through markdown cleanly; underline needs an extension or is dropped). Logged as
   Q14 in [08-open-questions.md](08-open-questions.md).
7. **Do not build**: the system Writing Tools row (comes free natively, skipped on web),
   Monostyled/Heading tiers, table editing, note-linking.

The result: the WRITE page reads like a sheet of paper in the lesson's theme, and formatting
is a strip above the keyboard — exactly the mental model members already have from Notes.
