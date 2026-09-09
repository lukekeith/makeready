# 02 — How Notes Actually Works

Platform knowledge behind the behaviors in [01-video-analysis.md](01-video-analysis.md). This is
what to replicate at the *mechanism* level, not just the pixel level. Where something is
inference rather than documented API, it is marked **[inferred]**.

---

## 1. The editor is a `UITextView`, not a custom canvas

Every text behavior in the recording is standard TextKit 2:

| Observed | Provided by |
|---|---|
| Amber caret, amber selection wash, round lollipop handles | `UITextView.tintColor` — the accent color, not custom drawing |
| `Cut │ Copy │ Paste │ Delete │ ›` callout | `UIMenuController` / `UIEditMenuInteraction`, system-supplied |
| Double-tap word selection, drag-to-extend, magnifier | `UITextInteraction` |
| Keyboard-follows-caret scrolling | `UITextView` + `keyboardLayoutGuide` content insets |
| Proofread / Rewrite row | `UIWritingToolsCoordinator` (iOS 18+), owned by the system keyboard |
| Undo / redo | `UIUndoManager` on the text view's `undoManager` |

**The lesson:** on iOS, the correct build of this is a `UITextView` wrapped for SwiftUI, *not* a
SwiftUI `TextEditor` (which cannot host an `inputAccessoryView`, cannot expose the undo manager,
and cannot apply attributed runs cleanly). See
[03-makeready-translation.md](03-makeready-translation.md) §2.

## 2. The document is an attributed string, not markdown

Notes stores rich text as an attributed string with two layers of attribute:

- **Character attributes** (bold, italic, underline, strikethrough, highlight, link) — applied to
  arbitrary ranges, freely overlapping.
- **Paragraph attributes** (Title / Heading / Subheading / Body / Monostyled, block quote,
  bulleted / dashed / numbered list, checklist, indent level) — exactly one style per paragraph,
  plus an integer indent depth.

Consequences that show up in the video:

- **Toolbar state is a query against the caret's attribute run**, not app-held state. `B` lights
  because `attributedText.attribute(.font, at: caretLocation)` reports a bold trait; it clears
  the instant the caret moves out. This is why toggling is instantaneous and never desyncs.
- **The style menus are paragraph-scoped and mutually exclusive** (a paragraph is Title *or*
  Body, bulleted *or* numbered), while `B/I/U/S` are character-scoped and freely combinable. The
  strip's `≡` divider at position 13 is exactly this boundary: everything to its right is
  paragraph-scoped.
- **Return-on-empty-list-item** is a text-storage rule, not a button: on `\n` insertion, if the
  current paragraph is a list item with zero content characters, remove the list attribute from
  that paragraph instead of inserting a new item.
- **"New Notes Start With: Title"** (Settings → Notes) is a paragraph-style default applied to
  paragraph 0 of an empty document, live as you type — hence the first line renders large
  immediately rather than on commit.

On disk Notes uses a private serialization (a protobuf-backed archive in a Core Data store),
which is why there is no markdown syntax surface anywhere in the UI — you cannot type `**bold**`
and get bold. The only typed shortcuts that convert are `- ` and `1. ` at the start of a line
(auto-list). **[inferred from behavior, not from the video]**

## 3. There is no save

- Edits mutate the live text storage; a **coalescing autosave** commits to the store on a short
  idle timer and on resign-first-responder / backgrounding.
- Consequently the back chevron is safe, `Done` is *dismiss editing*, not *commit*, and the note
  is already in the list with its new title before you navigate back.
- Undo is per-editing-session and keystroke-coalesced (typing a word is one undo step, not one
  per character), which is why the undo button appears on the *first* keystroke and stays.

## 4. The list is derived, not authored

- **Title** = the first non-empty line of the document. There is no title field.
- **Preview** = the next non-empty line, single-line truncated. (Settings can hide it.)
- **Date column** = `modifiedAt`, formatted relative: time for today, weekday inside a week, short
  date beyond.
- **Sections** = buckets over `modifiedAt` (Today / Yesterday / Previous 7 Days / Previous 30
  Days / month / year), computed at render time, not stored.
- **Sort** is by `modifiedAt` descending within a section — so typing in a note moves it to the
  top of Today. Pinned notes get their own leading section.
- The folder line (`🗀 Notes`) appears **only in aggregate views** like `All iCloud`, where notes
  come from more than one folder.

## 5. Sync and identity

- Notes syncs over **CloudKit**, per-record, with field-level merge; the "All iCloud" title is
  literally the aggregate of the iCloud account's folders. Local-only notes live in a separate
  "On My iPhone" account.
- Because sync is record-level and autosave is idle-coalesced, two devices editing the same note
  produce a conflict Notes resolves by keeping both versions as separate notes rather than
  merging text. **[inferred]**
- Shared notes add a per-participant permission and an attribution layer; not exercised here.

## 6. The chrome is the iOS 26 "Liquid Glass" system

Not custom art:

- Floating circular / capsule bar-button items over content are the standard
  `UIBarButtonItem` rendering in iOS 26; the grouping (bare circle vs. two-glyph capsule vs.
  filled accent circle) is `UIBarButtonItemGroup` semantics — *navigation*, *actions cluster*,
  *primary action*.
- The large title (`All iCloud` + `469 Notes`) is a `UINavigationItem` large-title with a
  subtitle, scrolling as content.
- The bottom search capsule + compose circle is the iOS 26 bottom-bar search placement
  (`UISearchController` with `searchBarPlacement = .inline` in a floating bottom bar).
- Popovers over the accessory strip are `UIMenu` presented as a popover from a bar/accessory
  button — not sheets, so they never resize the keyboard or dim the document.

**Practical implication for a non-Apple app:** all of this is *reproducible* — floating buttons
over content, an accessory strip, popovers anchored to strip buttons — but none of it comes free
outside UIKit's own bar system. Budget it as custom chrome.

## 7. The format strip is an `inputAccessoryView`

- It is attached to the text view, so it appears/disappears with the keyboard **as one unit**,
  automatically, with the keyboard's own timing curve. It is not a view the app animates.
- It sits above the QuickType / Writing Tools row because the system stacks accessory views on
  top of the keyboard's own accessory stack.
- Horizontal scrolling is a plain `UIScrollView` with no paging — so scroll position is state the
  view owns and nothing resets it on typing.
- The active-state treatment (filled accent circle, ~37 pt, ~200 ms fade out) is a button
  configuration change, not a separate view.

## 8. What this buys, feature by feature

| Notes feature | Mechanism | Cost to reproduce elsewhere |
|---|---|---|
| Zero-tap start | `becomeFirstResponder()` in `viewDidAppear` | trivial |
| Title auto-style | paragraph-style default on paragraph 0 | low |
| Live style toggles | attribute query at caret + `typingAttributes` | low |
| List continue / escape | text-storage rules on `\n` | low |
| Selection callout | system `UIEditMenuInteraction` | free on iOS, **must be built on web** |
| Writing Tools | system keyboard | free on iOS, **not available on web** |
| Markup / drawing | `PencilKit` | medium on iOS, high on web |
| Tables | custom TextKit attachment | high everywhere |
| Attachments / scan | `VisionKit` + `PHPicker` | medium |
| Undo | `UIUndoManager` | free on iOS; on web, a custom command stack |
| Autosave | idle timer + resign-responder | low, but needs a server contract (see 03) |
