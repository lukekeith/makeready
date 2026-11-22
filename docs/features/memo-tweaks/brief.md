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
