# 06 — Activity Type Catalog

Seven authorable types. Table shows the enum value (existing → kept, **new**), then each type's
content shape, player behavior, and edit-in-place behavior (details in 07).

| Type | Enum | Status |
|---|---|---|
| Video | `VIDEO` | existing |
| YouTube | `YOUTUBE` | existing |
| Write | `USER_INPUT` | existing |
| Exegesis | `EXEGESIS` | existing, new member UI |
| Text | **`TEXT`** | new |
| Bible verse | **`BIBLE`** | new |
| Image | **`IMAGE`** | new |
| (legacy) | `READ` | kept read-only; renders as derived TEXT/BIBLE pages (one per `ActivityReadBlock`); new authoring always creates TEXT/BIBLE |

All types share the presentation fields from 03 §4.2 (`eyebrow`, `layout`, `background`,
`textRole`, `scale`, `advanceRule`, `revealMode`, `actions`).

## VIDEO — leader-recorded/uploaded video (Cloudflare Stream)

- **Content:** `videoId`/`videoUrl` (existing), captions track (existing Stream captions),
  `posterTime`.
- **Player:** full-bleed page; autoplay muted-then-unmute-on-gesture per platform rules (WKWebView
  host grants `mediaTypesRequiringUserActionForPlayback = []`, browsers may need a tap-to-unmute
  chip); buffering spinner; bottom bar = title/subtitle + elapsed + scrubber + play/pause (the
  reference's channel/Follow row is out of scope). Heartbeat → `POST …/video-progress` (≥90%
  completion rule unchanged).
- **`advanceRule`:** `FREE` (swipe past any time, keeps playing until `passed`, then pauses) or
  `AFTER_MEDIA` (scroll clamp until `watchPercentage ≥ 90`).
- **Edit:** page shows the video with a replace/record affordance; tapping bottom bar fields
  edits title/subtitle inline.

## YOUTUBE — pasted URL

- **Content:** existing `youtubeUrl/VideoId/Start/EndSeconds/ThumbnailUrl`.
- **Player:** same page chrome as VIDEO with the IFrame API supplying progress; identical
  advance rules. Thumbnail poster until `settled` (avoids eager iframe cost).
- **Edit:** URL field in an inspector sheet; start/end trimmed via inline chips.

## WRITE — question / prayer / note input

- **Content:** `placeholder`, `helpTitle/Description/Icon` (existing), `prompt` (the question,
  rendered as page text), SOAP note-type mapping unchanged (`activity-progress.ts` submit).
- **Player:** prompt rendered like a TEXT page (primary group); input affordance is a
  ghost-input row that opens the keyboard in place (page pins input above keyboard;
  `--lesson-vh` handles the resize). Save → `POST …/submit { note }`.
  `advanceRule: AFTER_INPUT` clamps until a non-empty save.
- **Input UX reference:** the iPhone Notes app — full-width no-box notepad canvas with a
  scrollable format strip above the keyboard; full behavioral spec + translation contract in
  [11-notes-editor-analysis.md](11-notes-editor-analysis.md).
- **Edit:** tap prompt to edit text; tap input row to edit placeholder; help fields in inspector.

## TEXT — authored/pasted display text

- **Content:** `content` (markdown, existing block format), everything else is presentation
  fields. The "prayer page" of the reference = TEXT with `textRole: SCRIPTURE`, `scale: L`,
  `actions: [ADD_TO_PRAYER_LIST]`.
- **Player:** the workhorse page. Reveal groups: primary = body; secondary = eyebrow +
  any citation; actions last. Long content scrolls (article pattern) — `layout: TOP` for
  articles, `CENTER` for statements.
- **Actions:** `ADD_TO_PRAYER_LIST` opens the save sheet (prefilled with page text, 64-char
  title derived, privacy footer). Server: prayers land in the existing notes pipeline as a new
  note type `PRAYER` (08 §5).
- **Edit:** tap text → inline contenteditable; toolbar for scale/role; background & eyebrow per 07.

## BIBLE — verse/passage display

- **Content:** `ActivitySourceReference` (existing model) + resolved locked text (existing
  API.Bible pipeline + `isLocked` block semantics); `citation` auto-formatted
  ("PROVERBS 11:25 NIV").
- **Player:** SCRIPTURE role enforced: serif, left rule, small-caps citation (palette `quote`
  tokens). Short verse = centered statement page; long passage = scrolling page.
- **Edit:** tap passage → the existing Bible passage picker (parity twin already built);
  tap citation style → inspector. Text itself is locked (never editable), same rule as today.

## IMAGE — image page with overlays (new capability)

- **Content:** `imageUrl` (media library / upload → R2, existing infra), `alt` (Claude alt-text
  pipeline exists), `overlays: [{ type: 'text', content, role, scale, position: {x,y,anchor},
  maxWidth }]` — positioned text over the image; future overlay types (sticker/gradient) fit the
  same array.
- **Player:** full-bleed image (its own background, `cover`); overlays render in the reveal
  groups (image = backdrop at t0, overlays = primary group). Scrim slider value stored in
  `background.overlayOpacity`.
- **Edit:** tap image → media picker; drag overlays to reposition (edit mode only); tap overlay
  text to edit inline. Contrast guard warns (04 §4).

## EXEGESIS — annotated passage with floating note card (redesigned member UI)

- **Content:** unchanged — locked scripture block + `ContentHighlight` rows (`start/end`,
  `noteMarkdown`, `style`, `orderNumber`). The just-shipped highlighting service stays the
  single writer.
- **Player (new):** one scrolling SCRIPTURE page; highlights rendered via the existing selection
  spans. Tap a highlight →
  - **Floating note card** (~85% width, max 40% viewport height, internally scrollable)
    appears near the tap, above the text, with the note markdown + highlight-order chip.
  - Card is **draggable anywhere** (direct manipulation, stays where dropped,
    viewport-anchored — it does not scroll with the text).
  - Passage scrolling stays fully live behind/around the card — a dozen-highlight passage is
    browsed by scrolling + tapping; the card re-targets (250ms ease) on each tap.
  - Active highlight gets an emphasis state; visited highlights dim slightly (visited state
    already tracked). Card close = X or tap-through on empty text.
  - Each open → `POST …/exegesis-visit` (unchanged); `advanceRule: AFTER_HIGHLIGHTS` clamps
    until all visited (today's rule), `FREE` allows casual reading.
- **Kills:** the bottom-sheet overlay (`exegesis-step.vue` `.ExegesisStep__overlay`) and the
  iPhone editor's split-screen *member preview* pathway. (The leader's highlight editor itself is
  07/phase-later.)
- **Edit:** tap highlight → same floating card in edit mode (edit note, change style); select
  text → create highlight (existing `HighlightableTextView` web equivalent / selection API from
  the highlighting feature).

## Completion page (not authorable)

Synthetic, appended by the pager: checkmark badge (05 §5), "«Program» Streak" + count badge
(server `streak`), UP NEXT card (server `upNext`, taps into the next lesson), "^ Swipe Up" hint.
No entry in the enum; leaders see it in edit mode but only its theme follows the lesson palette.
