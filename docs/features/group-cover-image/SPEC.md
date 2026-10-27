# group-cover-image — spec
> lg · follows program `ui2-groups` (docs/features/ui2-groups/PROGRAM.md — its §Out of scope "cover upload")

## Idea

**Why.** On the iPhone 2.0 group page the cover (C-087) is display-only (ui2-groups P13): a leader
cannot add a cover to a new group, replace one, or reframe one that crops badly. The server already
takes a cover upload; nothing in 2.0 lets a leader use it, and nothing keeps the original photo, so a
crop can never be undone.

**What success looks like.** On the walk env: tapping the cover of "Empty Group" opens the iOS photo
picker; picking a wide photo opens Edit cover with it centred; zooming, rotating and dragging then Save
shows the new cover on the group page and in the Groups list; tapping the cover again offers Change
image · Edit image · View image; Edit image reopens the full photo exactly where it was left, and
zooming out reveals what the last crop cut off; View image shows the whole photo.

**In your words.** "if there is no cover image, then tapping it will open the image picker/selection"
→ D1 · "if there is a coverage image, then open an action menu with "Change image", "Edit image", or
"View image" as the options" → D2 · "a UI that lets me zoom and rotate within the visible frame aspect
ratio of the cover" → D5, D6.

**The concept.** The cover becomes non-destructive: the group keeps the original photo and the
framing (zoom, rotation, position) next to the rendered cover. The phone renders exactly what the
Edit cover frame shows and uploads it with the framing; Edit always reopens the original.

```mermaid
flowchart LR
  T[cover tap] -->|no cover| P[PhotosPicker] --> E[Edit cover]
  T -->|has cover| M[C-066 menu]
  M -->|Change image| P
  M -->|Edit image| E
  M -->|View image| V[full-screen original]
  E -->|Save: render 2.27:1 + framing (+ original on a new pick)| S[(POST cover-image)]
```

**How it fits today.** `POST /api/groups/:id/cover-image` (`groups.ts` ~1300) takes one base64
image, writes 1200/400/150px JPEGs to R2, sets `coverImageUrl`, records history (browse) and
fire-and-forgets a media-library capture. `GroupActions.uploadCoverImage` calls it. The UI2 shell
has C-066 + `.ui2OverlayHost()`; no picker, no viewer, no Edit cover page exist.

**Approaches considered.** Chosen: the phone renders the crop (what you see is what saves) and the
server stores it with the framing and the original. Rejected: the server renders from original +
framing (two renderers — Core Graphics and sharp — must agree to the pixel on rotation and
resampling).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | `Group.coverOriginalUrl` + `Group.coverFraming`; cover upload accepts the original and the framing; group payloads return them; other cover writes clear them | §server |
| client | ⬜ | no 2.0 web leader screens; the web's own cover upload keeps working and clears the stored original (D9) | — |
| iphone | ✅ | cover tap + menu on the group page, PhotosPicker, Edit cover (d2m-built screen) wired, full-screen viewer, upload Action | §iphone |
| capture | ⬜ | Edit cover's capture case is d2m's (built with the screen); no change here | — |

**Sequencing:** contract settled → server verifies → contract FREEZES → iphone, once the owner has
specced and built Edit cover in d2m (D4) → the walk.

**Backward compatibility:** the upload's existing body (`imageData`, `contentType`) works unchanged
for released 1.0 builds and the web; the new fields are optional and additive on every payload.

**Blast radius:** group payloads (list, detail, PATCH, create); the cover upload route; R2 keys under
the group cover prefix.

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Tap with no cover | On groups-detail, tapping C-087 when `coverImageUrl` is null presents the iOS `PhotosPicker` (images only, single selection); a pick opens Edit cover (D6); dismissing the picker changes nothing. Rejected: a placeholder "Add cover" button (the design taps the cover itself) | Luke 2026-10-27 |
| D2 | Tap with a cover | Presents C-066 `ActionMenuOverlay` through the shell overlay host with three rows, in order: "Change image" (glyph `image`) → D1's picker; "Edit image" (glyph `edit`) → Edit cover on the stored original (D7); "View image" (glyph `view`) → D8; Done cancels. Rejected: separate buttons on the page (the frame has none) | Luke 2026-10-27 |
| D3 | Image source | iOS system `PhotosPicker` only — no photo-library permission prompt. Rejected: the MakeReady media library (no 2.0 picker design); both (costs both) | Luke 2026-10-27 |
| D4 | Edit cover page design | Figma 4724:53609 "Edit image" (title "Edit cover") is specced and built in d2m by the owner before this feature's iPhone phase; the build wires the d2m-built screen and does not write it. The cover-tap hook on `GroupsDetailScreen` (`onCoverTap`) and the full-screen viewer are mechanical edits the build makes and routes to `/ui2-resolve` (ui2-groups-browse D2 precedent). Rejected: building Edit cover directly (the first whole 2.0 page outside the design system) | Luke 2026-10-27 |
| D5 | Gestures and limits | On Edit cover: pinch zooms, two-finger rotate rotates, one-finger drag pans, simultaneously. Zoom floor = the smallest scale at which the rotated image still covers the whole frame (no empty corners at any rotation); pan is clamped by the same coverage test; zoom ceiling = 8× the floor; rotation is free and snaps to 0° when released within ±3°. The frame is the cover's aspect, 408:180 (2.267:1). Rejected: free zoom with black corners (broken in lists) | Luke 2026-10-27 |
| D6 | After a new pick | Edit cover opens with the picked photo centred at the zoom floor, rotation 0; Save uploads (D10); Cancel or back discards the pick and leaves the cover as it was. Rejected: saving a centre crop at once (photos rarely match 2.27:1) | Luke 2026-10-27 |
| D7 | Re-editing | Edit image opens `coverOriginalUrl` at `coverFraming`; a group with a cover but no original (every group today, and any set by D9) opens `coverImageUrl` as the original at identity framing (scale 1 = floor, rotation 0, centred). Rejected: editing the rendered cover (each edit confined to the last crop) | Luke 2026-10-27 (keep original) · (assumed at brainstorm) (no-original fallback) |
| D8 | View image | Full-screen viewer through the overlay host: the original (`coverOriginalUrl ?? coverImageUrl`) aspect-fit over `color-layout-background` at 0.95 opacity; tap anywhere or swipe down closes it; no zoom in v1. Rejected: showing the cropped cover (the page already shows it) | Luke 2026-10-27 (original) · (assumed at spec) 2026-10-27 (chrome) |
| D9 | Covers set elsewhere | Any cover upload without `framing` (released 1.0, web, the legacy body) sets `coverOriginalUrl` and `coverFraming` to null. PATCH with `coverImageUrl` does the same. Rejected: keeping the stored original (Edit image would reopen a photo that is no longer the cover) | (assumed at brainstorm) |
| D10 | Upload contract | `POST /api/groups/:id/cover-image` body: `imageData` (required, the rendered cover, JPEG base64), `contentType?`, `framing?` `{scale, rotation, offsetX, offsetY}`, `originalData?` (JPEG base64). With `framing`: stores it; with `originalData` too: uploads the original (longest side capped at 2400px, quality 0.9) to R2 under `groups/{id}/cover-original-{timestamp}.jpeg` and sets `coverOriginalUrl`; `framing` without `originalData` keeps the current original (a re-edit); `originalData` without `framing` → 400. Rendered cover handling is today's (1200/400/150, history, library capture). Rejected: a separate original-upload endpoint (two requests that can half-succeed) | (assumed at spec) 2026-10-27 |
| D11 | Framing shape | `coverFraming` JSON `{scale: number ≥ 1, rotation: degrees −180…180, offsetX, offsetY: fractions of the frame's width/height from centred}` — `scale` relative to the zoom floor so it survives a different render size. Validated by zod on upload; any other shape → 400 | (assumed at spec) 2026-10-27 |
| D12 | Render size (A1) | The phone renders the framed image at 1200×529 (408:180), JPEG quality 0.9, exactly what the Edit cover frame shows. Rejected: server-side render (see §Idea) | (assumed at brainstorm) |
| D13 | Save states | Saving = Save disabled + spinner, gestures off; success → pop to the group page, merge the returned group into `AppState.groups` (Groups list updates); failure → the shell banner "Couldn't save the cover" with the page kept as-is (C-048 has no error slot); 401 → sign-out; 404 → pop to Groups. Rejected: an inline error (none designed) | (assumed at spec) 2026-10-27 |
| D14 | Permissions | Same as today's cover upload and PATCH: `groupManageFilter`; the cover tap exists only on groups-detail, which only managers reach | (assumed at brainstorm) |
| D15 | Scope | Group covers on iPhone only. Rejected: program covers (another entity, another screen) and the web (no 2.0 web leader screens) | (assumed at brainstorm) |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/groups/:id/cover-image` (extended) | server | iphone | `requireAuth` + `groupManageFilter` | D10 | `{success, data:{coverImageUrl, coverOriginalUrl, coverFraming}}` | 400 (D10/D11) · 401 · 404 · 413 over the body limit |
| group payloads — `GET /api/groups`, `GET /api/groups/:id`, PATCH, POST (extended) | server | iphone | as today | — | + `coverOriginalUrl` (string\|null), `coverFraming` (D11 \| null) | as today |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `Group.coverOriginalUrl` (text, null) | `coverOriginalUrl` | Edit image reopens the full photo; D7 | planned |
| SC2 | ADD | `Group.coverFraming` (jsonb, null) | `coverFraming` | Edit image restores zoom/rotate/position; D11 | planned |
| SC3 | EDIT | cover upload body + response | D10 | new pick + re-edit in one request; D10 | planned |

**Data plan:** SC1–SC2 are nullable adds through `server/schema/*.yaml` → `schema:diff` → one Atlas
migration; no backfill — existing groups read null and use D7's fallback. Undo = drop both columns.

## server

- Schema SC1–SC2; group payloads add both fields (list, detail, PATCH, create).
- Cover upload: D10 body, D11 zod, original upload to R2, D9 clearing on a framing-less upload;
  PATCH `coverImageUrl` also clears (D9). Raise the route's JSON limit to fit two images (F2).

## iphone

- **Group page:** `GroupsDetailScreen` gains `onCoverTap` (build edit, D4); `GroupDetailContainer` routes
  it per D1/D2.
- **Picker:** `PhotosPicker` presented from the group page container (system sheet — a hardware/system
  picker, the sanctioned exception to the overlay rule).
- **Edit cover:** route `UI2Destination.editGroupCover(groupId:, source: .newPick(UIImage) | .stored)`
  → `EditGroupCoverContainer` wiring the d2m-built screen: gesture state per D5, D12 render, D13 save.
- **Viewer:** a full-screen overlay view per D8 (build-made, routed to `/ui2-resolve`).
- **State:** `UserGroup` + `coverOriginalUrl?`, `coverFraming?`; `GroupActions.uploadCoverImage(id:,
  rendered:, framing:, original:)` returning nothing and merging the group into `AppState.groups`.

## Testing

- **server:** upload with framing + original (both stored, original under its key, ≤ 2400px); framing
  only keeps the original; legacy body clears both (D9); PATCH `coverImageUrl` clears; `originalData`
  without framing 400; bad framing 400; non-manager 404; payloads carry both fields.
- **iphone:** framing math — the zoom floor at 0°, 45° and 90° for wide and tall images, pan clamp,
  ±3° snap, `scale` relative to the floor round-trips; render produces 1200×529; D7 fallback; menu
  rows per cover state; decode of the new fields; `ios:build-check --test`; swiftlint baseline.
- **Cross-app E2E (Fixtures):** D1 on Empty Group with a fixture photo; save; re-edit zooms out past
  the old crop; View shows the full photo; a legacy-body upload then makes Edit open the cover itself.
- **Human walk (on device):** gesture feel (pinch + rotate + pan together), the snap, the menu.

## Out of scope

- Picking from the MakeReady media library (no 2.0 picker design) — owner 2026-10-27.
- Program covers; cover editing on the web — owner 2026-10-27.
- Filters, brightness, any adjustment beyond zoom/rotate/position; zoom inside the viewer.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | Edit cover is not in d2m yet (Figma 4724:53609); the iPhone phase needs the d2m-built screen | build-time risk — the owner runs the d2m screen spec + build before the iPhone phase; an agent run reaching it first parks as a human step |
| F2 | Two base64 images (up to ~2400px original + 1200px render) may exceed the route's JSON body limit | audit measures the limit; raise it on this route only |
| F3 | The cover-tap hook and the viewer are MakeReadyUI / app edits outside d2m | route both to `/ui2-resolve` after the build (D4) |
