# 03 — Gaps

What has to change for the text activity to work in the viewer. Checked 2026-11-06 against the d2m
`activities-editor` spec and the built code. **Nothing here has been changed yet.** Under the repo's
rules, the d2m rows change through a d2m request, not by editing `iphone/MakeReadyUI/`.

## Must change before the editor is wired in

These change saved data, so doing them later means migrating real content.

| # | Gap | Today | Change | Where |
|---|---|---|---|---|
| D1 | **Coordinates are device points** | `transform.position` is a canvas `CGPoint`, `size` and `width` are points (`CanvasTextObject.swift:72-78`). A composition saved on one phone lands elsewhere on another | Store width units (`02` §4); the component converts at render | C-092 §4, C-091, screen §3 and §5 |
| D2 | **Canvas height is fixed** | Canvas is 709–775 pt and "nothing scrolls except the canvas content when a passage is taller" (screen §2). A long paste has nowhere to go | The canvas scrolls vertically and grows with content, up to any length (`01` §3) | Screen §2, C-091 |
| D3 | **The editor isn't what members see** | The canvas sits between a 56 pt header and a 76 pt bar, while the viewer is full-bleed 956 | Compose in the 440×956 space. Show the viewer's reserved zones as guides while manipulating: top chrome, rail, screen fold, pinned action | Screen §2–§3, C-091 new overlay |
| D4 | **Background has no color, focal point or motion** | C-091 is `plain` or `image + wash` (`ActivityCanvas.swift:25-28`), and §3's color tool writes to the text only. The owner's note on the highlights frame says background color is user-set. All the recording's text pages are solid color | `background` per `02` §5. Page color goes in the background tool's sheet, with `focal` set by dragging the image there. `motion` isn't exposed until parallax is designed | C-091 §4, screen tool 2, OQ-023 |
| D5 | **Every object is bold** | C-092 §2: Bold in every face, whole-object styling only. The recording's long pages are regular-weight body text with italics and links | Add `weight` and `marks` (`02` §3) | C-092 §2 and §4; font strip |
| D6 | **Fonts aren't portable** | `.custom("Georgia-Bold")`, `AmericanTypewriter-Bold`, SF Pro (`CanvasTextObject.swift:490-500`). Poppins isn't bundled: `Info.plist` has no `UIAppFonts` | Font keys and bundled open fonts (`02` §6) | C-092 §4, C-035 `type=Font`, app bundle, web |
| D7 | **Highlight offsets differ by platform** | Offsets are counted with `text.distance`, which counts graphemes (`CanvasTextObject.swift:468-469`). JavaScript counts UTF-16, so offsets disagree after any emoji | Store UTF-16 (`02` §3) | C-092 §4 |
| D8 | **No way to add an action** | No tool or slot for one; `activity-new` and the editor have nothing for it | Add an **Actions** entry and its sheet (kind, label, placement, prefill). Undrawn: needs a frame or an agreed default | Screen §2 tool row, new overlay |

## Must change before the viewer can render the components

| # | Gap | Today | Change | Where |
|---|---|---|---|---|
| D9 | **No read-only mode on C-092** | `.simultaneousGesture(manipulation)` is always attached with a `DragGesture` (`CanvasTextObject.swift:197`). In the viewer it would fight vertical drags | Add `mode: viewer`, with no gestures and no input field | C-092 §3 and §4 |
| D10 | **Animations loop forever and start at appear** | `repeatForever` begins in `.onAppear` (`CanvasTextObject.swift:364-377`), and the text activity's spec loops them while editing and after commit. Offscreen pages would burn CPU, and a member would never see the beginning | Add `trigger: onActive` and `loop`, with a controllable clock so the viewer can start, stop and reset it. Reduce Motion holds the rest pose | C-092 §2 and §4 |
| D11 | **Effects aren't defined portably** | Pixel's coarse raster "is not drawn" even on iOS (`CanvasTextObject.swift:747-749`). Sparkle, shimmer and neon are `TextRenderer` code with no CSS equivalent written | Specify each effect as a formula both platforms can follow, or drop the ones that can't be matched | C-092 §2; a web spike |
| D12 | **C-091 still contains the passage** | `passage`, `Verse`, the verse-row column and `PassageHitTester` remain (`ActivityCanvas.swift:43-61`, `155-213`, `376-399`), though the 2026-10-17 re-ruling superseded them. Possibly why d2m reads `updateNeeded` on this screen | Remove them; a passage is a C-092 | C-091 rebuild |

## New in d2m

| # | Row | Contents |
|---|---|---|
| N1 | `activities-player` screen | Currently queued, `web-member`, no spec, no Figma. Spec it from `01`. Platform becomes web (members, React) + iOS (leaders) |
| N2 | `activities-completion` screen | Queued, no spec. `01` §11 sets its place in the stack |
| N3 | Activity rail component | `01` §8. C-097 PageIndicator is a horizontal dot row and doesn't fit |
| N4 | Viewer chrome | Close + top action + scrim, `01` §9. C-021 GlyphButton may cover the circles; d2m decides |
| N5 | Video page and its controls | `01` §9. Scrubber with remaining time, presenter row, caption box |
| N6 | Action sheet + inline action + pinned action | `01` §10. C-105 Button may cover inline |

## Smaller editor items

| # | Item | Change |
|---|---|---|
| E1 | Lesson rail slides | The lesson rail's slide (C-079) shows only an image, so text activities are blank. Render the document at thumbnail scale; width units make that straightforward (program-lesson-add-activity D6 follow-on) |
| E2 | Previewing the stack | Add **Play from here** to the editor, opening the viewer on this activity. Leaders need to feel snaps and heights *(default)* |
| E3 | Stale status | The screen's status line still says the build waits on components, though all are built. `updateNeeded` is true with no stated reason. One unread comment. Clear these during the request |
| E4 | Width handles | OQ-C-091-005 is still open. `transform.width` depends on it, so resolve it with D1 (recommended: `widthHandles` and `onResizeWidth`) |
| E5 | Already-tracked undesigned parts | Tool 6's strip, highlight note editor, background picker (OQ-023), eyedropper (OQ-011). None block a first slice if their tools are hidden |

## Outside d2m

| # | App | Gap | Change |
|---|---|---|---|
| S1 | server | Nothing stores a document, and content lives in two parallel table sets | The new model and export (`05`) |
| S2 | iphone | Activity models and Actions are built for the old shape; `ActivityType` has no unknown case, so one new kind would fail a whole lesson (`StudyModels.swift:695`, `:344`) | New models on the new endpoints, decoding the envelope first and treating an unknown kind as a fallback page (`02` §9), so future kinds don't break installed builds |
| S3 | new web app | Members have nowhere to see the new content until the React viewer exists | Build it. There are no members to affect meanwhile |
| S4 | server + clients | Prayers have no list surface | `Prayer` table (`05`); member list screen later |
| S5 | iphone | `feature/program-lesson-add-activity` isn't on main | Merge first, so the editor's picker entry exists. The tiles are deliberately inert until wired |
| S6 | new web app | The member rebuild's home | React + MobX is ruled, and how it's hosted isn't: it needs a home, login handling and API access. Members' login and proxy live in the Laravel client today. Decide when the viewer's web build is planned |

## Order

```
d2m request: D1–D12, E3, E4 → S1 + S2 (new model, new endpoints)
  → editor wiring in the app (container, store, save)
  → N1–N6 → native viewer for leaders, and the React member viewer
  → one-time export and cutover (05 §7)
```
