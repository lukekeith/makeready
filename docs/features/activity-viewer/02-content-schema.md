# 02 — The activity document

One JSON document describes every activity on every platform. The viewer never branches on the
device, and adding a platform means writing a renderer, not changing content.

## 1. The rules that shape it

1. **Layers are separate.** A background layer, a content layer and an actions list, with nothing
   shared between them. Background changes never touch text.
2. **Positions and sizes scale with the screen's width.** The same composition wraps the same way
   on every phone.
3. **Height is never a limit.** Content that doesn't fit makes the page taller, and the viewer
   scrolls it (`01` §3).
4. **The document holds what the author chose, not what a device computed.** Page height, scroll
   ranges and crop rectangles are computed at render time.
5. **An unknown kind degrades, it never fails.** The new app's installed iPhone builds always lag the
   server, so a kind added next year must not break this year's build (§9).

## 2. The envelope

Every activity, of every kind:

```jsonc
{
  "schemaVersion": 1,
  "kind": "text",                      // text | bible | video | youtube | write | poll | future kinds
  "background": { /* §5 */ },
  "content":    { /* §3 for canvas kinds, §8 for the rest */ },
  "actions":    [ /* §7 */ ],
  "chrome":     { "topAction": "share" },   // share | menu | none
  "fallback":   { "title": "A new activity", "body": "Update the app to see this." }
}
```

## 3. Canvas content: `text` and `bible`

Per ruling D55, a Bible passage is text objects like any other. Both kinds use this content type.

```jsonc
"content": {
  "type": "canvas",
  "verticalAnchor": "center",          // center | top
  "objects": [ /* drawn in array order, last on top */
    {
      "id": "o1",
      "role": "body",                  // eyebrow | heading | body | scripture | citation | prayer
      "text": "Finally, brothers and sisters…",
      "font": "serif",                 // §6 key, never a platform font name
      "weight": 700,                   // 400 | 500 | 700
      "size": 26,                      // width units (§4)
      "lineHeight": 1.25,              // ratio of size
      "tracking": 0,                   // ratio of size
      "color": "#FFFFFF",
      "alignment": "left",             // left | center | right
      "label": "none",                 // none | solidDark | solidLight
      "listStyle": "none",             // none | bullet | numbered | bibleVerse
      "startNumber": 1,
      "reference": null,               // structured Bible reference, as C-092 §4
      "animation": { "kind": "none", "trigger": "onActive", "loop": false },
      "effect": "none",                // none | sparkle | neon | shimmer | pixel
      "transform": {
        "x": 220, "y": 478,            // object center, width units
        "width": 392,                  // layout width, width units
        "scale": 1,
        "rotation": 0                  // degrees
      },
      "marks": [                       // inline styling, optional
        { "start": 0, "end": 12, "kind": "bold" },
        { "start": 40, "end": 58, "kind": "italic" },
        { "start": 90, "end": 112, "kind": "link", "href": "https://…" }
      ],
      "highlights": [
        { "id": "h1", "start": 12, "end": 30, "noteMarkdown": null }
      ]
    }
  ]
}
```

**Character offsets** in `marks` and `highlights` are **UTF-16 code units**, in all clients.
JavaScript strings and `NSString` use this natively. Swift `String` distances count grapheme
clusters and would disagree after any emoji, so Swift converts at the boundary.

**Roles** carry meaning for screen readers and search. They don't change appearance. Reading order
is top to bottom by `y`, then array order.

**Long text** is one object whose text runs past the screen. There's no size limit other than the
document's (§10).

## 4. The coordinate space: why it works on every phone

The author composes on a reference canvas **440 units wide and 956 tall**. One unit at render time:

```
u = viewportWidth / 440
```

Every horizontal and vertical position, every width and every font size is multiplied by `u`. Text
wraps at the same words on a 375 pt phone and a 440 pt phone, because width and font size scale
together. Rotation and `scale` are unitless.

**Vertical placement** is the only part that depends on the phone's shape, and it's computed like
this. Let `T = 107u` (clear of the top chrome) and `B = 85u` (the end space from `01` §3, plus the
pinned action's height if the page has one).

```
1. contentTop, contentBottom = bounding box of all objects, rotated and scaled, × u
2. offset = (viewportHeight − 956u) / 2     when verticalAnchor is center
   offset = 0                               when verticalAnchor is top
3. fits = contentBottom − contentTop ≤ viewportHeight − T − B
4. if fits:     nudge offset by the smallest amount that puts the box inside [T, viewportHeight − B]
                pageHeight = viewportHeight
   if not fits: offset = T − contentTop
                pageHeight = contentBottom + offset + B
```

| Phone | Short composition | Long composition |
|---|---|---|
| Taller than the reference | Extra space is shared above and below | Starts at `T`, scrolls |
| Same as the reference | Exactly as authored | Starts at `T`, scrolls |
| Shorter than the reference | Still fits, nudged into the safe band, no scrolling | Starts at `T`, scrolls |

The nudge moves all objects together, so a composition keeps its internal spacing.

**Cross-platform tolerance.** CoreText and browsers can wrap one word differently even with the same
font file. Page height is measured from the laid-out text on each client, so this can't clip
content. Authors separate stacked objects with at least one line of space, and the editor warns when
two objects overlap *(default)*.

**Accessibility text size** doesn't reflow canvas objects, since that would break compositions. It's
served by a reader view reachable from the top-right menu, later *(default)*.

## 5. The background layer

```jsonc
"background": {
  "color": "#0E4A4D",                  // always present; also the placeholder while an image loads
  "image": {                           // optional
    "mediaId": "…",
    "focal": { "x": 0.5, "y": 0.4 }    // the point kept visible when cropped, 0–1
  },
  "wash": { "color": "#3B1E8F", "opacity": 0.6 },   // optional; drawn over the image
  "motion": { "mode": "scroll", "rate": 1 }
}
```

Draw order, bottom to top: `color`, `image` (cover, around `focal`), `wash`, then the content layer.

**Motion** says how the background moves as the page's **content** scrolls (`inner`):

| Mode | Background | Image height needed |
|---|---|---|
| `scroll` | Moves with the content | `pageHeight` |
| `fixed` | Stays still behind the content | `viewportHeight` |
| `parallax` | Moves at `rate` × the content's speed, 0 < rate < 1 | `viewportHeight + (pageHeight − viewportHeight) × rate` |

```
backgroundOffset = −inner × rate      // scroll: rate = 1. fixed: rate = 0.
```

Rendering only needs one extra transform on the background layer, which is why this has to stay a
separate layer. On a page that doesn't scroll, the three modes look the same.

**Between pages**, in every mode, the background travels rigidly with its page and keeps the hard
edge recorded in `01` §2. Reduce Motion treats `parallax` as `scroll`.

A background shared across a whole lesson (seen in the earlier recordings) would be a lesson-level
field. It isn't part of this document *(default: later)*.

## 6. Fonts

The document stores a key. Each client ships the same font file for it, so text looks and wraps the
same everywhere.

| Key | Face | Replaces in today's editor | Why |
|---|---|---|---|
| `display` | Poppins | Poppins | Open licence; already in `client/public/fonts/poppins`, not yet in the iPhone bundle |
| `sans` | Inter | SF Pro | SF Pro's licence limits it to Apple platforms |
| `serif` | Source Serif 4 | Georgia | Georgia isn't on Android, and web would need a commercial licence |
| `mono` | Courier Prime | American Typewriter | American Typewriter is Apple-only |

All four are open-licensed. The owner has said the exact faces don't matter (OQ-activities-editor-016),
so the swap keeps the same four roles. *(default)*

An unknown key falls back to `sans`. A file is only added here if it's licensed for every platform.

## 7. Actions

```jsonc
"actions": [
  {
    "id": "a1",
    "kind": "addToPrayerList",         // closed list below; unknown kinds aren't drawn
    "label": "Add to Prayer List",
    "placement": "inline",             // inline | pinned
    "payload": { "title": "A Prayer to Focus My Mind on God", "body": "God, sometimes…" }
  }
]
```

| Kind | What the tap does | Stores to |
|---|---|---|
| `addToPrayerList` | Opens the action sheet, prefilled from `payload` | `Prayer` (`05` §2) |
| `write` | Opens the action sheet with an empty body and the `payload.prompt` as placeholder ("Write your thoughts") | `ActivityResponse` with `actionId` (`05` §2) |
| `openUrl` | Opens `payload.url` | Nothing |
| `nextLesson` | Starts `payload.lessonId`, or the next scheduled one | Nothing |

Actions are authored and rendered by every kind, so a video can carry "Write your thoughts". Inline
actions draw after the last object, centered, 24u below it *(default)*. At most one pinned action
per page *(default)*. Member data is keyed by `activityKey` and the action's `id`, so a new version of
the document doesn't lose it.

## 8. The other kinds

These fix only the shape the viewer needs. Each kind's editor is specced later on the same surface.

| Kind | `content` | Page height | Notes |
|---|---|---|---|
| `text` | `canvas` (§3) | Per §4 | |
| `bible` | `canvas` (§3), plus `passages` (`05` §4) | Per §4 | Text objects carry verse numbers via `listStyle: bibleVerse` |
| `video` | `{ type: "video", videoId, posterMediaId, captionsTrack, presenter: { name, avatarMediaId, subtitle } }` | Viewport | Playback per `01` §9 |
| `youtube` | `{ type: "youtube", youtubeVideoId, startSeconds, endSeconds }` | Viewport | Same page layout as `video`, in YouTube's required player. Its controls and caption styling are YouTube's, so it can't fully match §9 |
| `poll` | `{ type: "poll", prompt: TextObject, options: [{ id, label }], multiple: false }` | Per §4 | Results go through a dedicated endpoint, later |
| `write` | `{ type: "write", prompt: TextObject, placeholder }` | Per §4 | Inline field; the keyboard pauses the pager |

## 9. Forward compatibility

| Case | Behavior |
|---|---|
| Unknown `kind` | Takes a rail slot and a page. Shows `fallback` centered over `background.color`. The stack keeps working |
| Unknown field | Ignored and preserved on save |
| Higher `schemaVersion` than the client knows | Same as an unknown kind |
| Malformed document | Same as an unknown kind, plus an error logged. Never fails the lesson |
| Unknown `effect`, `animation` or action `kind` | Renders without it |

Clients decode the envelope first and the content second, so one bad activity can't fail its lesson.
Server writes validate strictly; client reads are lenient.

## 10. Storage

A document is one `Activity.document` value, saved whole on Done, validated by the server against this
schema, with a 256 KB limit *(default)*. Everything about versions, groups and progress is in `05`.

Text objects aren't normalized into tables, since nothing queries inside them. Full-text search, if
wanted, reads `role` and `text` from the document.

## 11. A complete example

The recording's prayer page as a document:

```json
{
  "schemaVersion": 1,
  "kind": "text",
  "background": { "color": "#0E4A4D", "motion": { "mode": "scroll", "rate": 1 } },
  "content": {
    "type": "canvas",
    "verticalAnchor": "center",
    "objects": [
      { "id": "o1", "role": "eyebrow", "text": "PRAYER", "font": "sans", "weight": 700, "size": 11,
        "lineHeight": 1.2, "tracking": 0.12, "color": "#FFFFFF", "alignment": "left",
        "transform": { "x": 220, "y": 182, "width": 392, "scale": 1, "rotation": 0 } },
      { "id": "o2", "role": "prayer", "text": "God, sometimes it's hard to focus my mind on good things…",
        "font": "sans", "weight": 700, "size": 28, "lineHeight": 1.3, "color": "#FFFFFF", "alignment": "left",
        "transform": { "x": 220, "y": 470, "width": 392, "scale": 1, "rotation": 0 } }
    ]
  },
  "actions": [
    { "id": "a1", "kind": "addToPrayerList", "label": "Add to Prayer List", "placement": "inline",
      "payload": { "title": "A Prayer to Focus My Mind on God", "body": "God, sometimes it's hard…" } }
  ],
  "chrome": { "topAction": "share" },
  "fallback": { "title": "A prayer", "body": "Update the app to see this." }
}
```
