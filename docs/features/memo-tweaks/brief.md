# memo tweaks — owner feedback from the first device run (2026-11-21)

The owner ran the voice-memo build (main `f951be0f`) on an iPhone 17 Pro Max and asked for these
changes. Each one brings a memo surface into line with the rest of the UI 2.0 app.

## 1. library-home: a list page like the others

> "the library page needs to look and feel like all the other list pages with search at the top, a
> list item style that matches the other list item styles, pull to refresh, filters with search, etc."
> (owner 2026-11-21)

Match `members-home` and `study-programs` (the house list pages):

- **Search at the top:** C-131 SearchFilterHeader (C-034 search field + C-035 filter chips), pinned
  under the TopNav as on members-home. Placeholder: `Search library`. It replaces C-008
  NotesBottomBar on this screen: no bottom search capsule, and no compose button there either
  (new notes come from the TabBar + menu's "Write a note", notes D17).
- **Filters:** one C-035 chip, **Type**, which opens C-036 FilterMenuOverlay with the options
  `Notes` and `Voice memos`. The label shows the current selection, defaulting to `All types`, as
  the members-home chips do. The filter combines with search.
- **Rows:** notes (C-005) and memos (C-006) take the house list-row look: the same type scale,
  insets, row height rhythm and C-088 hairline rule as C-037 / C-059 rows on members-home and
  study-programs. They no longer use the Apple-Notes styling. A memo row keeps its mic glyph,
  duration and preview states (ready / Transcribing… / Audio only / Waiting to upload); a note
  keeps its title, date and preview.
- **Sections:** keep the newest-first date grouping (Today, Previous 7 Days, …) only if the house
  list pages have a section-header pattern for it (C-020 SectionHeader). Otherwise pick the closest
  house pattern and say which.
- **Pull to refresh:** the shared `PullToRefresh` (as `media-home` uses it), with an `onRefresh`
  callback.
- **States:** `populated-mixed`, `search-mixed`, `filter-memos`, `empty`, `loading`.

## 2. memo-detail: a detail page with the house PageHeader

> "the memo detail view needs to be like all the other detail/home page views with a PageHeader at
> the top. The icons in circles that it's currently using for the back chevron and three dot menu
> looks too much like the default iOS styles and needs to match our detail page pageheader style."
> (owner 2026-11-21)

> "there needs to be a 16px gap between the pageheader and the page content, right now it looks like
> the title of the memo is right under the top" (owner 2026-11-21)

- Replace C-009 EditorNavChrome on memo-detail with **C-040 PageHeader**, as group-detail and
  enrollment-home use it: `style: .twoIcons`, `leadingGlyph: .back`, `rightButtons: [.threeDots]`,
  with no title in the bar. The ⋯ opens the same C-066 menu (Rename · Delete).
- **16 pt between the PageHeader and the content:** the memo title starts 16 pt below the header's
  bottom edge.
- No other change to the page.
- **The same chrome change on note-editor:** if note-editor still uses C-009's circled glyphs, the
  owner's rule applies to it too ("like all the other detail/home page views"). Raise it as a
  question; don't change it in this request.

## 3. C-011 LiveWaveformView and C-012 PlayheadWaveformView: smooth while recording

> "the animation for the voice memo while recording seemed really choppy, it should be smooth while
> recording a memo." (owner 2026-11-21)

Today both views redraw only when a new `samples` array arrives, with animation off (§2 Motion). The
engine delivers levels in bursts (now ~47 Hz, before ~12 Hz), so the bars jump.

- **Continuous scroll:** while recording, the bars move left continuously at the sample rate's
  pitch (C-011: 4 pt per sample; C-012: its 4 pt pitch at 80 pt/s), driven by a display-rate
  clock (`TimelineView(.animation)` or equivalent). Between two `samples` updates the view advances
  by elapsed time instead of waiting for the next array. A new sample slides in from the right edge
  (C-011) or from under the playhead (C-012); it doesn't pop in.
- **Paused:** the scroll stops dead.
- **Prop:** if the view needs the time of the latest sample to stay in step, add a `sampleTime`
  prop (seconds); the container feeds it the engine's `elapsed`.
- Reduce Motion: fall back to the current step-per-update drawing.

## 4. note-editor: the same PageHeader

> Asked whether note-editor should move to the PageHeader too: "yes" (owner 2026-11-21)

- Replace C-009 EditorNavChrome on note-editor with **C-040 PageHeader**, the same detail-page
  style as memo-detail (§2): back on the leading side, no circles.
- **Trailing buttons, reading:** ⋯ (`rightButtons: [.threeDots]`), opening the same menu as today.
- **Trailing buttons, editing:** C-009 shows Undo and Done while editing. Keep both actions, in
  the PageHeader's own vocabulary: Done as its trailing text label (`trailingLabel: "Done"`, the
  `.cancelDone`-style trailing label), and Undo as a glyph button beside it, if PageHeader can hold
  both. If it can't, raise it as a question with a recommendation instead of inventing chrome.
- **16 pt between the PageHeader and the content**, as on memo-detail.

## 5. C-016 RecorderSheet: present and dismiss like the + menu

> "the red dot and contents of the voice memo modal don't animate up with the modal, I thought we
> fixed this and documented how to prevent it from happening again" (owner 2026-11-21)

> "the voice memo modal should work just like the plus button's, dim the background and make it
> tappable to dismiss, also swipe down to dismiss, I don't see why it's different" (owner 2026-11-21)

The model is C-066's presentation, `ActionMenuLayer` in `MakeReadyUI/ActionMenuPresentation.swift`
(the + menu's sheet).

1. **It owns its motion.** The recorder is presented through the shell's `.hostedOverlay`, which
   arrives without the presenting transaction, so its `.move(edge: .bottom)` insertion transition
   never carries the contents (see ActionMenuLayer's doc comment, and animation-debug Class 8). Do
   what ActionMenuLayer does:
   - keep a `shown` @State that is false on insert;
   - in `.onAppear`, `withAnimation(motion-sheet-present) { shown = true }`;
   - slide the whole sheet with `.visualEffect { offset(y: shown ? 0 : proxy.size.height) }`, so it
     moves as one laid-out piece;
   - add `visible: Bool` (default true) and `onHidden: () -> Void`. When `visible` turns false, run
     `withAnimation { shown = false } completion: { onHidden() }`.
2. **Dim.** A full-screen `Token.black80` behind the sheet, faded by `shown` exactly like
   ActionMenuLayer's dim, ignoring safe areas. Tapping it calls `onDismiss`. This replaces
   OQ-C-016-5's "undimmed, touches pass through".
3. **Swipe down to dismiss.** At the compact detent, a downward drag past
   `ActionMenuMotion.shouldDismiss` calls `onDismiss` in every phase. The drag up to expanded and the
   expanded↔compact snap don't change; from expanded, a drag down snaps to compact first.
4. **Props**, all defaulted: `visible`, `onHidden`, `onDismiss`. The ready-state swipe that called
   `onClose` now calls `onDismiss`. `onClose` stays for the mic-denied Close button.
5. **What dismissing means** is decided by the caller: while ready it closes and keeps nothing; while
   recording it saves, exactly like Done.
6. **Captures:** `compact` with the dim, `ready`, `expanded`.

## 6. C-040 PageHeader: a Done check and larger icon buttons

> "there is no way to dismiss the keyboard on the memo page like we did on the notes page. I think we
> should standardize it and add support to the pageHeader that does this … a purple circle with a
> checkmark animates into the right position of the pageheader, pushing any other button or icon to
> the left … the three dot action menu in pageHeader is hard to see because it's so small … the back
> chevron [too]. We need to take it another step larger (a step is 8px). Maybe they should be 24x24 or
> 32x32, whichever is a step larger than the current size." (owner 2026-11-21; the reference is Apple
> Notes, `/Users/lukekeith/MakeReady/Notes/notes dismiss.MP4`)

1. **Larger icon buttons.** Every C-021 glyph PageHeader draws (back, three-dots, the rest) goes one
   8 pt step up from today's 24 pt to **32 pt**. Hit targets stay at least 44 pt. The glyph's stroke
   weight scales with it, and the 56 pt bar height doesn't change. This covers every screen that
   uses PageHeader.
2. **Done check.** Add `showsDone: Bool = false` and `onDone: () -> Void = {}`. When true, a 32 pt
   `color-accent` filled circle with a white checkmark sits at the trailing edge.
   - **Showing it:** it animates in, scaling from 0.5 and fading in on the house spring. Any trailing
     glyph buttons slide left to make room.
   - **Hiding it:** the same in reverse.
   - Spacing between it and the other trailing buttons uses PageHeader's existing gap.
   - Its accessibility label is "Done".
3. **memo-detail:** while the title is being renamed (keyboard up), pass `showsDone: true`. Tapping it
   commits the rename and dismisses the keyboard, exactly as Return does.
4. **note-editor:** while editing, swap `backAndLink` (back · "Done" text) for `twoIcons` (back, no
   right buttons) with `showsDone: true`. The check calls the old Done action: stop editing and
   dismiss the keyboard. The reading state doesn't change. Undo stays beside the format strip.
5. **Captures:** PageHeader `done` (with ⋯ pushed left) and `done-only`; memo-detail `renaming` with
   the check; note-editor `typing` with the check.

## 7. library-home rows: a leading icon avatar

> "the list items on the library page for memos and notes need an icon in a circle on the left of the
> list item, just like we do on the members page, same relative size as the avatars on the member
> page too... except it will be styled like the fallback with initials, but have an icon instead."
> (owner 2026-11-21)

1. **C-038 Avatar:** add two `FallbackGlyph` cases, `microphone` (library `microphone`) and `note`
   (library `notebook-pen`). Draw them on the same ground, glyph tone and glyph-to-diameter ratio as
   the **Initials** state, not the Unknown-user ground. Existing consumers don't change.
2. **C-005 NoteListRow / C-006 MemoListRow:** lead with C-038 at **32 pt, round**, exactly like the
   member rows (C-037 `subject=member`) on members-home, with the same gap to the text column and the
   same vertical alignment. Notes use `note` and memos use `microphone`, with no photo or initials.
   Memo rows drop their inline mic glyph before the title, since the avatar now says it's a memo.
   Duration, preview states and the hairline rules don't change; the rule starts where the text
   column starts, as it does on members-home.
3. **Captures:** every C-005 and C-006 state, library-home `populated-mixed` and `search-mixed`, and
   C-038 with the new glyphs.

## 8. library-home rows: the time moves up, in purple

> "the timestamp on the voice memo's list item on the library page, it should be purple" — asked whether
> that means the duration or the time: "Both, and move the time to the same position as the duration,
> the second line of the note's list item should be the first line of the note truncated" (owner
> 2026-11-21)

1. **Line 1:** the title on the left (one line, truncating). On the right, the date label (the notes
   rule: the time today, the weekday within 7 days, a short date otherwise).
   - Memos add their duration after it: `9:38 PM · 0:05`.
   - The whole right-hand label is **`color-accent`** in both row types, so a note and a memo look
     alike. A note's label is just its date label.
2. **Line 2:** one line, truncating, with no date in front.
   - A note shows the first line of its body text after the title.
   - A memo shows the transcript preview, or its state text: Transcribing… / Audio only / Waiting to
     upload, with today's styles.
   - A note with no body text has no line 2, and its row is shorter, as today.
3. The context line on notes stays as it is.
4. This goes together with §7's leading avatar.

## 9. library-home Type filter: the house multi-select

> "you also made a mistake on the filters for the library page, when I click the type, it is a single
> select to select and dismiss, but it should be the same multi-select style we use on all the other
> filters." (owner 2026-11-21)

The Type chip works exactly like members-home's Groups and Leaders chips (filter-multiselect D1/D4/D15):
- C-036 opens in its multi-select form, with `Notes` and `Voice memos` as checkable rows and **Save**.
  The menu has no "All types" row (D3).
- The chip is active while anything is checked, and its label follows members-home's rule: `All types`
  with nothing checked, otherwise the house wording for the checked set.
- The screen takes `selectedTypes: Set<…>` as C-036's seed and reports `onSaveTypes(Set<…>)`. It
  replaces the single-select `typeFilter` / `onTypeFilterChange`.
- Nothing checked, or both checked, shows every row. The container filters by the set.
- Captures: `filter-memos` (Voice memos checked) and the open menu.
