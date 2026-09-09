# 01 — Video Analysis (frame-by-frame)

Both recordings are YouVersion (Bible App) lesson surfaces on iPhone (1320×2868 @ 60/240fps).
Video 1 = **Guided Prayer** (27.2s). Video 2 = **Guided Scripture** ("Refreshment for Your Soul",
22.1s). Analysis method: 4fps contact sheets end-to-end, 15fps re-extraction of the four motion
windows (first transition, content entrance, checkmark draw, dismissal), full-res crops of the
indicator rail.

## 1. Surface anatomy (shared by both lessons)

- **Presentation:** full-screen sheet over the app home. Entry from a tappable card on home
  (video 2 shows a black loading interstitial with a spinner before the first page).
- **Persistent chrome**, fixed while pages scroll beneath:
  - Top-left: X (close) in a ~36pt translucent circle.
  - Top-right: one contextual action, also circled — Guided Prayer shows a **mute/audio toggle**
    (lesson has narration), Guided Scripture shows a **share** icon. → chrome actions are
    per-lesson configurable.
  - A subtle top scrim keeps status bar + chrome legible as content scrolls under.
- **Indicator rail**, right edge ~78% down the viewport (see §4).
- **No visible page header, no progress bar, no button navigation.** All progression is gesture.

## 2. Page inventory

### Video 1 — Guided Prayer (6 pages, one shared backdrop)

Backdrop: a single photographic image (misty forest, warm amber) with a dark gradient scrim,
**fixed for the entire lesson** — pages scroll over it; it never moves (no parallax detected).

| # | Eyebrow | Content | Notes |
|---|---|---|---|
| 1 | WELCOME | "You matter to God. / And He wants to hear from you." | App-voice sans, large, white; top-aligned |
| 2 | HONOR GOD | Psalm 148:1-5 as a serif blockquote with a white left rule, citation "PSALMS 148:1-5 NIV", then sans instruction "Meditate on this verse…" | Scripture = serif + left rule + small-caps citation |
| 3 | (none at first) | Phil 4:7 blockquote, centered vertically | Text appears alone first; page later becomes… |
| 4 | MY CONCERNS | …same verse + citation + "Whatever is on your mind matters to God." + "Spend the next few moments…" + literal placeholder text "[Add to Prayer List]" + **"Add Prayer" outline button** | Secondary content fades in as a later group; pages 3/4 are actually one page with staged reveal |
| 5 | THANK GOD | Long prayer in large sans ("God, Thank You for proving…Amen.") | Personal/app voice = sans |
| 6 | CLOSING | ✓-in-circle badge + Eph 3:20-21 paraphrase + "Sit with your conversation with God… Give yourself permission to reflect…" | Text reveals word-by-word, narration-paced (§5.4) |

### Video 2 — Guided Scripture (7 pages, per-page backgrounds)

Backgrounds change per page and **slide with their page** (a stepped background edge is visible
mid-transition — each page owns an opaque background panel).

| # | Eyebrow | Background | Content |
|---|---|---|---|
| 1 | — | black | **Video activity**: full-bleed vertical video, autoplays after buffer spinner; baked-in captions; bottom bar = channel avatar + "LCBC Church" + Follow pill, subtitle "Proverbs 11:25", elapsed time, scrubber, play/pause. Swiping up mid-playback is allowed (video still playing as it slides off) |
| 2 | white + gray decorative wave header graphic | light | **Article**: serif H1 "A Mindset of Abundance", long sans body (multi-viewport scroll), inline verse quote + citation, list lines ("The last will be first.…"), ends "…Our God has unlimited strength, power, and resources." |
| 3 | BE ENCOURAGED | dark gray (#26262a-ish) | Centered serif: "You don't have to be rich to be generous; you just need a heart that is willing to serve." |
| 4 | SCRIPTURE | dark gray | Large serif verse "A generous person will prosper; whoever refreshes others will be refreshed." + sans citation "Proverbs 11:25 NIV" |
| 5 | SHARE YOUR FAITH | dark gray | Centered serif: "Today, choose to be generous!…" |
| 6 | PRAYER | dark gray | Larger serif prayer ("Father, You have been so generous to me.…Amen.") + **"⊕ Add to Prayer List"** text-button row |
| 7 | — | dark | **Completion**: "Guided Scripture Streak" title + teal pill badge (droplet icon + "1"), "UP NEXT" label + card (next lesson "Guided Prayer", description, thumbnail), "^ Swipe Up" hint at bottom |

**Add to Prayer List flow (video 2, ~17-19s):** tapping the row slides a standard bottom sheet
("Add Prayer" title, X left, white **Save** pill right; "PRAYER" section label + char-count "64";
prayer text prefilled from the activity; footer "🔒 Your prayer is private, until you choose to
share it."). The lesson dims behind it. Save dismisses the sheet back to the page. In video 1 the
same concept appears as a small outlined "Add Prayer" button instead — same action, two button
presentations.

## 3. Typography system observed

Two voices, consistently applied in both lessons:

- **Scripture voice:** serif (Charter/Georgia-class), used for every Bible quotation and the
  prayer/encouragement pages of video 2. Often paired with a left rule (blockquote) + small-caps
  citation line ("PSALMS 148:1-5 NIV") in muted weight.
- **App voice:** geometric sans (SF-adjacent), used for welcome text, instructions, personal
  prayer text (video 1 page 5), completion UI, buttons.
- **Eyebrow labels:** ~11pt small caps, wide letterspacing, ~60% opacity, always above content.
- Body scale is large (comfortably 22-28pt equivalent); the prayer page of video 2 is a step
  larger than its quote pages. White or near-white ink on dark; dark ink on the white article.

## 4. Indicator rail (the scrollbar replacement)

Vertical rail fixed near the right edge (~x 92%, y ~72-80%):

- **One element per activity**: small ~4px dots for non-current activities.
- The **current activity's element stretches into a capsule** (~28-40px tall).
- Inside the capsule, a **contrasting thumb travels top→bottom** tracking scroll position *within*
  the current activity (clearly visible during the long article: dark dot inside the white capsule
  descends as the user scrolls). For short pages the capsule reads as simply filled.
- Passed activities' dots sit above the capsule, upcoming below (order = lesson order).
- The rail is visible during interaction and dims (but does not fully disappear) at rest.
- On the completion page the capsule is the last element with all dots above it.

## 5. Motion findings (timings from 15fps windows; ±35ms)

### 5.1 Page-to-page transition
Finger-tracked vertical scroll: the outgoing page's content translates up and off-screen with the
gesture (interruptible, rubber-bands on over-scroll), the incoming page arrives from below and
snaps to fill the viewport. Deceleration matches native iOS scroll physics (no custom spring
overshoot on the page itself). In video 1 only the *content* moves (backdrop fixed); in video 2
each page's opaque background panel moves with it.

### 5.2 Content entrance (the signature move)
The incoming page settles **empty**, then content choreographs in (measured on the Phil 4:7 page,
total ≈ 750ms):

1. t=0: page settled; background bare.
2. t≈0-120ms: blockquote left-rule appears as a short stub.
3. t≈120-500ms: primary text fades 0→100% opacity while rising ~12px and scaling ≈0.97→1.0
   (single ease-out group); the rule grows to full height alongside.
4. t≈400-750ms: secondary group (eyebrow, citation, instruction lines) fades in, staggered.
5. Action buttons (Add Prayer) arrive last, ≈200ms after the secondary group.

The MY CONCERNS page demonstrates that reveal groups can also be triggered **later within the same
page** (narration-timed): the verse existed alone for seconds before the eyebrow + guidance +
button group faded in around it.

### 5.3 Completion checkmark (video 1 CLOSING, ≈700ms total)
1. Tick stroke draws left-to-right, ≈300ms, slight bounce at the end (the tick briefly tilts).
2. ≈80ms hold.
3. Circle strokes clockwise around it, ≈320ms, with a small springy rotation settle.
4. Badge is part of the page content (it scrolls with the page; it re-plays only on page entry).

### 5.4 Word-by-word reveal (video 1 CLOSING)
Text reveals one word at a time, paced by narration (cadence observed 130-260ms/word, not
uniform). Each word fades from ~35% ghost opacity to 100% — the un-revealed remainder is not
rendered at all (layout grows as words arrive, left-aligned reflow). Runs for the whole closing
passage (~17s of the recording).

### 5.5 Dismissal (video 1, ≈25.5-27s)
On the last page, an upward over-scroll (content lifts ~10%, checkmark fades near the top scrim)
crosses a threshold → the **entire lesson sheet slides down** (standard iOS sheet dismissal,
≈400ms ease-in) revealing the app home. Gesture direction is *up*; exit motion is *down*. Video 2
never dismisses on-camera but shows the explicit "^ Swipe Up" affordance on its completion page.

### 5.6 Video activity specifics (video 2)
- Autoplays once buffered; a centered system spinner overlays the paused/buffering video.
- Standard scrubber + play/pause; captions baked into the media.
- Swipe-up to leave mid-playback is permitted (this lesson's video is skippable — the ask
  specifies this must be configurable per activity).

## 6. Timestamped outlines (for future re-analysis)

Source files (as analyzed): `~/Makeready/ScreenRecording_08-09-2026 16-42-49_1.mov` (240fps
recording, 27.16s) and `…17-29-32_1.MP4` (60fps, 22.10s); originals in iCloud
`…/MakeReady/Recordings/`. Timestamps ±0.3s (4fps overview; motion windows re-measured at 15fps).

### Video 1 — Guided Prayer (27.16s)

| t (s) | What's demonstrated |
|---|---|
| 0.0–1.8 | WELCOME page settled: eyebrow style, app-voice sans, fixed forest backdrop, X + mute chrome |
| 1.8–2.5 | **First page transition** (finger-tracked scroll; backdrop stays fixed) → HONOR GOD |
| 2.5–4.0 | HONOR GOD settled: serif blockquote + left rule + citation; indicator rail visible |
| 4.0–5.0 | **Content-entrance choreography** (the measured window): empty page → rule stub → text fade/rise/scale |
| 5.0–6.3 | MY CONCERNS **staged reveal**: verse alone → eyebrow + guidance + "Add Prayer" button group fades in later |
| 6.3–7.0 | Transition to THANK GOD; prayer text fade-in |
| 7.0–8.8 | THANK GOD settled (large sans prayer) |
| 8.8–10.0 | Swipe to CLOSING; **checkmark draw** (tick ~9.3–9.6, circle ~9.6–10.0 + spring settle) |
| 9.5–24.5 | **Word-by-word narration-paced reveal** of the closing passage; intra-page scroll (badge scrolls off; rail thumb travels) |
| 25.5–27.2 | **Over-scroll swipe-up dismissal**: content lifts, then whole sheet slides down revealing app home |

### Video 2 — Guided Scripture (22.10s)

| t (s) | What's demonstrated |
|---|---|
| 0.0–1.0 | Home card tap → black loading interstitial with spinner |
| 1.0–5.5 | **VIDEO activity**: autoplay after buffer, baked captions, bottom bar (channel + Follow, "Proverbs 11:25" subtitle, elapsed/scrubber/play-pause) |
| 5.5–6.5 | **Swipe past playing video** → white article page slides in (**per-page background panels**, stepped edge visible) |
| 6.5–10.5 | Long article scroll-through ("A Mindset of Abundance"); **rail thumb tracks intra-activity position** |
| 10.5–12.0 | BE ENCOURAGED centered serif quote page (dark panel) |
| 12.0–13.5 | SCRIPTURE page: large serif verse + citation |
| 13.5–15.0 | SHARE YOUR FAITH page |
| 15.0–17.0 | PRAYER page (larger serif) + "⊕ Add to Prayer List" row |
| 17.0–19.0 | **Add Prayer bottom sheet**: X/Save, PRAYER label + char count, prefilled text, privacy footer; Save dismisses |
| 19.5–22.1 | **Completion page**: "Guided Scripture Streak" + teal badge "1", UP NEXT card, "^ Swipe Up" hint (recording ends here) |

## 7. Design takeaways the architecture must honor

1. **A lesson is a vertical stack of full-viewport pages inside one scroller** with snap points at
   page boundaries; long pages scroll freely between snaps.
2. **Backgrounds are a first-class layer** with two modes: lesson-shared fixed backdrop
   (video 1) or per-page panels (video 2).
3. **Entrance choreography is decoupled from scrolling** — it triggers on page-settle, in ordered
   reveal groups (primary → secondary → actions), optionally narration/timer-scheduled.
4. The indicator needs **two levels of position**: activity index + intra-activity scroll.
5. Completion is just a **special final page** (badge + streak + up-next) with an over-scroll
   dismissal gesture.
6. Buttons inside pages (Add Prayer) open **standard bottom sheets** above the lesson; the pager
   doesn't navigate away.
