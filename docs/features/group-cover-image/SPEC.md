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
| client | ⬜ | no 2.0 web leader screens; the web's own cover upload (`leader-group-home.store.ts:462-473`, legacy body, reads the flat `coverImageUrl`) keeps working because the response stays flat (D10) and clears the stored original (D9); web stores map group fields explicitly, so the additive fields are ignored | — |
| iphone | ✅ | cover tap + menu on the group page, PhotosPicker, Edit cover (d2m-built screen) wired, full-screen viewer, upload Action | §iphone |
| capture | ⬜ | Edit cover's capture case is d2m's (built with the screen); no change here | — |

**Sequencing:** contract settled → server verifies → contract FREEZES → iphone, once the owner has
specced and built Edit cover in d2m (D4) → the walk.

**Backward compatibility:** D21 (2026-10-27) is additive — the two new framing keys are optional and defaulted, Swift `Codable` ignores unknown keys, and neither released 1.0 nor the web reads `coverFraming`; D20's 16:9 covers are aspect-filled by every existing reader. The upload's existing body (`imageData`, `contentType`) works unchanged
for released 1.0 builds and the web, and its response keeps `coverImageUrl` at the top level — released
1.0 (`GroupActions.swift:339-349`) and the web (`leader-group-home.store.ts:471`) both decode it there,
so the new response fields are added beside it, never under a `data` wrapper (D10). The new fields are
optional and additive on every payload. A released 1.0 or web cover upload wipes the 2.0 original and
framing by design (D9).

**Blast radius:** the four inline group mappers in `groups.ts` — POST (172-194), GET list (278-300),
GET `/:id` (609-630), PATCH (1118-1140); the cover upload route (1241-1414) and its `@openapi` block; the
OpenAPI Group schema (`openapi-definition.ts:253,289`); R2 keys under `groups/`. Deliberately NOT
extended: `GET /api/groups/code/:code` (416), the public group endpoint (~880-910), `members.ts:1066`,
`public.ts:176` — none of them feeds an editor.

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
| D2 | Tap with a cover | Presents C-066 `ActionMenuOverlay` through the shell overlay host with three rows, in order: "Change image" (glyph `upload`) → D1's picker; "Edit image" (glyph `edit`) → Edit cover on the stored original (D7); "View image" (glyph `eye`) → D8; Done cancels. Glyph names are existing `GlyphName` cases (`Glyph.swift:86,88,207`) — the set has no `image`/`view`, and an unknown name renders the red stub (`ActionMenuRow.swift:80-116`). "Has a cover" is read from `AppState.shared.groups[groupId]?.coverImageUrl`, never from the screen state (whose `coverURL` is `""` until the image is cached, `GroupDetailContainer.swift:137-140`); while the group is not in `AppState` the tap does nothing (the `editDestination` guard, :125-128). Rejected: separate buttons on the page (the frame has none) | Luke 2026-10-27 · glyphs + has-cover source auto (recommended) 2026-10-27 |
| D3 | Image source | iOS system `PhotosPicker` only, presented with the `.photosPicker(isPresented:selection:matching: .images)` modifier (not `.sheet`/`.fullScreenCover`) and loaded with `loadTransferable(type: Data.self)` — no photo-library permission prompt. The pick is downsampled to ≤ 2400px longest side, upright, before Edit cover is pushed (memory, and D16). Rejected: the MakeReady media library (no 2.0 picker design); both (costs both) | Luke 2026-10-27 |
| D4 | Edit cover page design | Figma 4724:53609 "Edit image" (title "Edit cover") is specced and built in d2m by the owner before this feature's iPhone phase; the build wires the d2m-built screen and does not write it. The cover-tap hook on `GroupsDetailScreen` (`onCoverTap`) and the full-screen viewer are mechanical edits the build makes and routes to `/ui2-resolve` (ui2-groups-browse D2 precedent). Rejected: building Edit cover directly (the first whole 2.0 page outside the design system) | Luke 2026-10-27 |
| D5 | Gestures and limits | On Edit cover: pinch zooms, two-finger rotate rotates, one-finger drag pans, simultaneously. Zoom floor = the smallest scale at which the rotated image still covers the whole frame (no empty corners at any rotation); pan is clamped by the same coverage test; zoom ceiling = 8× the floor; rotation is free and snaps to 0° when released within ±3°. ~~The frame is the cover's aspect, 408:180 (2.267:1).~~ The frame is 16:9 — superseded 2026-10-27 by D20. Rejected: free zoom with black corners (broken in lists) | Luke 2026-10-27 |
| D6 | After a new pick | Edit cover opens with the picked photo centred at the zoom floor, rotation 0; Save uploads (D10); Cancel or back discards the pick and leaves the cover as it was. Rejected: saving a centre crop at once (photos rarely match 2.27:1) | Luke 2026-10-27 |
| D7 | Re-editing | Edit image opens `coverOriginalUrl` at `coverFraming`; a group with a cover but no original (every group today, and any set by D9) opens `coverImageUrl` as the original at identity framing (scale 1 = floor, rotation 0, centred). Rejected: editing the rendered cover (each edit confined to the last crop) | Luke 2026-10-27 (keep original) · (assumed at brainstorm) (no-original fallback) |
| D8 | View image | Full-screen viewer through the overlay host: the original (`coverOriginalUrl ?? coverImageUrl`) aspect-fit over `color-layout-background` at 0.95 opacity; tap anywhere or swipe down closes it; no zoom in v1. Presented only after the C-066 menu's dismissal completes (`onDismiss`), because the overlay host keeps only the first presented overlay (`FilterMenuOverlay.swift:384-389`). Rejected: showing the cropped cover (the page already shows it) | Luke 2026-10-27 (original) · (assumed at spec) 2026-10-27 (chrome) |
| D9 | Covers set elsewhere | Any cover upload without `framing` (released 1.0, web, the legacy body) sets `coverOriginalUrl` and `coverFraming` to null. PATCH with the `coverImageUrl` key present (a URL or null) does the same. The complete list of `Group.coverImageUrl` writers (audit 2026-10-27): POST create (`groups.ts:110,151` — new columns start null), PATCH (1055), the upload route (1363), fixtures (`fixtures/images.ts:262` — leaves both null, i.e. D7's fallback); no DELETE-cover or clone route exists. Rejected: keeping the stored original (Edit image would reopen a photo that is no longer the cover) | (assumed at brainstorm) |
| D10 | Upload contract | `POST /api/groups/:id/cover-image` body: `imageData` (required, the rendered cover, JPEG base64), `contentType?`, `framing?` `{scale, rotation, offsetX, offsetY}`, `originalData?` (JPEG base64). With `framing`: stores it; with `originalData` too: uploads the original (longest side capped at 2400px, quality 0.9) to R2 under `groups/{id}/cover-original-{timestamp}.jpeg` and sets `coverOriginalUrl`; `framing` without `originalData` keeps the current original (a re-edit); `originalData` without `framing` → 400. Rendered cover handling is today's (1200/400/150, history). Response, flat: `{success, coverImageUrl, coverOriginalUrl, coverFraming}` — `coverImageUrl` stays top-level for released 1.0 and the web. The original is always re-encoded server-side: `sharp(buf).rotate().resize(2400, 2400, {fit:'inside', withoutEnlargement:true}).jpeg({quality:90})` (applies EXIF orientation, strips metadata incl. GPS); key `groups/group-{id}-{ts}-original.jpeg` (the flat layout of `storage.ts:220-260`) via `uploadToR2`, no WebP ladder; `contentType` is ignored for it. Either image failing `sharp().metadata()` → 400 (today a malformed image is a 500). Both R2 uploads complete before ONE `prisma.group.update` writes `coverImageUrl`, `coverOriginalUrl`, `coverFraming` together; any R2 failure → 500 and no DB change (orphan objects accepted, as today). Rejected: a separate original-upload endpoint (two requests that can half-succeed); a `data` wrapper (breaks 1.0 and the web) | (assumed at spec) 2026-10-27 · response, re-encode, key, atomic write auto (recommended) 2026-10-27 |
| D11 | Framing shape | ~~superseded 2026-10-27 by D21 (adds `flipped`, `quarterTurns`)~~ `coverFraming` JSON `{scale, rotation, offsetX, offsetY}`, all finite numbers: `scale` 1…8 (relative to the zoom floor, D5's ceiling, so it survives a different render size), `rotation` degrees −180…180, `offsetX`/`offsetY` −1…1 (fractions of the frame's width/height from centred). zod `.strict()` on upload — an unknown key, a missing key or an out-of-range value → 400. The phone decodes it with `try?` so a bad stored value never fails a group list decode | (assumed at spec) 2026-10-27 · bounds + `.strict()` auto (recommended) 2026-10-27 |
| D12 | Render size (A1) | ~~1200×529 (408:180)~~ superseded 2026-10-27 by D20: 1200×675 (16:9). The phone renders the framed image, JPEG quality 0.9, exactly what the Edit cover frame shows. Rejected: server-side render (see §Idea) | (assumed at brainstorm) |
| D13 | Save states | (Save is the header's Done since D22, 2026-10-27.) Saving = Save disabled + spinner, gestures off; a second Save while saving is ignored (`isSaving` guard; the POST is not coalesced); success → pop to the group page, patch the three returned fields into the group in `AppState.groups` and persist (Groups list updates), and seed `Ui2ImageCache` with the rendered image under the new URL so the cover does not flash the placeholder; failure → `AppState.shared.recordError(…, surface: true, friendlyMessage: "Couldn't save the cover", retry:)` (the `GroupDetailContainer.swift:101` pattern) with the page kept as-is (C-048 has no error slot); 401 → sign-out (`AuthStatusPolicy`); 404 → pop to Groups. The status is only visible through `requestWithStatus` (`APIClient.swift:209-231`), so the new Action calls it, with a timeout parameter added (120s for this call), not `uploadImage` (which folds a 404 into `serverError`). Rejected: an inline error (none designed) | (assumed at spec) 2026-10-27 · guard, cache seed, status path auto (recommended) 2026-10-27 |
| D14 | Permissions | Same as today's cover upload and PATCH: `groupManageFilter`; the cover tap exists only on groups-detail, which only managers reach | (assumed at brainstorm) |
| D16 | Body size | The route keeps the global 10mb JSON limit (`index.ts:220`). The phone downscales the original to ≤ 2400px and encodes JPEG 0.9 (measured with sharp: 1.0–2.5MB → 1.4–3.4MB base64) plus the 1200×675 render (0.4–0.6MB base64): ≤ ~4.5MB per request. The server re-enforces the cap (D10). Rejected: raising the limit on this route (a route-level `express.json` cannot — the global parser runs first and 413s; it would mean excluding the path from it) | auto (recommended) 2026-10-27 |
| D17 | Server layering | A new `server/src/services/group-cover.ts` owns decode, validation of the images, the R2 uploads, the old-original delete and the single DB write; the route keeps zod, `groupManageFilter`, history and the HTTP mapping. The four inline group mappers become one `toGroupPayload` in the same task that adds the two fields. Rejected: growing the inline route (house rule: thin routes) | auto (recommended) 2026-10-27 |
| D18 | Media library capture | The rendered cover is captured to the media library on an upload that carries `originalData` or no `framing` (a new image); a re-edit (`framing` without `originalData`) captures nothing; the original is never captured. Rejected: capturing every save (re-edits pile up near-duplicate rows) | auto (recommended) 2026-10-27 |
| D19 | Old originals | After the DB write commits, an upload that replaced or cleared `coverOriginalUrl` deletes the previous original from R2, best-effort (`extractKeyFromUrl` + `deleteFromR2`, `storage.ts:93,107`; a failure is logged, never returned). Rendered covers are not deleted (the media library still references them). Group soft-delete keeps today's no-cleanup behaviour. Rejected: leaving originals orphaned (nothing references them) | auto (recommended) 2026-10-27 |
| D20 | Output aspect (owner, supersedes D5's frame + D12's size) | The cover is 16:9 everywhere: Edit cover's frame is 16:9, the phone renders 1200×675, and C-087 CoverImage becomes 16:9 on every screen that draws it — a design change routed to `/ui2-component-update C-087` (never edited here); covers saved before keep their 2.27:1 pixels and are aspect-filled into the 16:9 slot. Rejected: keeping the 2.27:1 slot and showing a band of the 16:9 image (silently re-crops what the leader framed); framing at 2.27:1 (owner asked for 16:9) | Luke 2026-10-27 |
| D21 | Framing shape (supersedes D11) | `coverFraming` = D11's four keys + `flipped: boolean` (horizontal mirror, applied before rotation) + `quarterTurns: 0…3` (counter-clockwise 90° steps, applied before the fine `rotation`); zod keeps `.strict()` with both new keys optional, defaulting to `false` / `0`, so a stored D11 value and a D11-shaped body stay valid. `rotation` stays the fine angle −45…45 after quarter turns are separated. Rejected: folding flips/turns into `rotation` (a mirror is not a rotation; 90° steps must survive the ±3° snap) | Luke 2026-10-27 (flip, rotate 90°) · (assumed at spec) 2026-10-27 (shape) |
| D22 | Edit cover chrome (owner, Figma 4729:53712) | ~~superseded 2026-10-27 by D28~~ C-040 header: leading "Cancel", title "Edit cover", trailing "Done"; Done saves (D13), disabled while saving or when nothing changed on a re-edit (a new pick is always savable). No bottom buttons, no bottom tool bar. Under the header: top-left Flip horizontal + Rotate 90° (counter-clockwise) icon buttons, top-right "Auto". Rejected: Figma 4724:53609's bottom Save/Cancel (superseded by the owner) | Luke 2026-10-27 |
| D28 | Edit cover chrome (supersedes D22; owner ruling OQ-schat-edit-cover-1 in the d2m edit-cover spec) | C-040 `textButtons` header: leading "Cancel", title "Edit cover", trailing "Done"; Done saves (D13) and shows the C-040 saving spinner (D66) while saving; Done is disabled on a re-edit with no change (a new pick is always savable). Under the header: top-left Flip horizontal + Rotate 90° (counter-clockwise) icon buttons; **no Auto**. Pinned at the bottom: the d2m straighten dial (drag ±45°, the degree readout inside it). No bottom Save/Cancel. Rejected: Auto (removed by the owner in the d2m spec) | Luke 2026-10-27 |
| D23 | Auto | ~~superseded 2026-10-27 by D29~~ Runs `VNDetectHorizonRequest` on the original; when a horizon is found, sets `rotation` to level it (clamped to ±45°) and re-applies the zoom floor; when none is found the button is disabled (checked once on open). Rejected: auto-frame by saliency; Reset (Cancel already discards) | Luke 2026-10-27 |
| D29 | Auto dropped (supersedes D23) | There is no Auto: no button, no `VNDetectHorizonRequest`, no horizon state in the model; Task 15 removes what Task 14 built for it. Rejected: keeping the detection unused (dead code and a Vision pass on every open) | Luke 2026-10-27 (OQ-schat-edit-cover-1) |
| D24 | Fine rotation + feedback | ~~superseded 2026-10-27 by D30~~ Two-finger twist only (no straighten dial); a degree readout (integer, e.g. "-12°") shows centred just above the frame while twisting and fades 0.6s after release; the ±3° snap (D5) stays. A rule-of-thirds grid shows inside the frame while any gesture is active; the image outside the frame is drawn dimmed (`color-layout-background` at 0.6) | Luke 2026-10-27 (twist only) · (assumed at spec) 2026-10-27 (readout, grid, dim from the recording) |
| D30 | Fine rotation + feedback (supersedes D24) | Two inputs drive ONE fine `rotation` (−45…45): the canvas two-finger twist and the d2m dial (`onStraighten(degrees)` sets it absolutely on every change, `onStraightenEnd()` on release); the dial is centred on `rotation` (`rotationDegrees`), so a twist moves it too. While either is active the screen shows the thirds grid (`showsGrid`) and the integer readout inside the dial (`readoutDegrees`, nil otherwise; the screen fades it 0.6s). The ±3° snap (D5) and the settle to coverage (D25) run on release of either. Flip negates the rotation (`CoverFramingMath.flippedHorizontally`), so the dial and readout change sign. The dim and grid are drawn by the d2m screen around the canvas slot; the canvas draws only the image and owns the gestures. Rejected: twist only (owner added the dial) | Luke 2026-10-27 (OQ-schat-edit-cover-1) · (assumed at revise) 2026-10-27 (one shared value, snap on dial release) |
| D25 | Zero black edges (owner, recording 30–42 s) | During a pan or pinch the image may go past the coverage limit with rubber-band resistance (displacement × 0.3 beyond the limit); on release it springs back (`spring(response: 0.35, dampingFraction: 0.85)`) to the nearest framing that covers the frame. Flip and Rotate 90° re-apply the zoom floor immediately. After any gesture ends, no frame pixel is uncovered | Luke 2026-10-27 (goal) · (assumed at spec) 2026-10-27 (constants) |
| D26 | Cancel with changes | Cancel (or edge-swipe back) with any framing change, or on a new pick, presents C-066 with one destructive row "Discard changes" + Done; Discard pops, Done stays. With no change it pops at once. Rejected: discarding silently (framing is effort to redo) | Luke 2026-10-27 |
| D27 | Design inputs for the d2m Edit cover spec | The owner's d2m screen spec of Edit cover uses Figma 4729:53712 (chrome), `editor-reference.md` (the recording outline) and D20–D26; F1 stays the iPhone gate. Rejected: building from 4724:53609 (superseded) | Luke 2026-10-27 |
| D15 | Scope | Group covers on iPhone only. Rejected: program covers (another entity, another screen) and the web (no 2.0 web leader screens) | (assumed at brainstorm) |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/groups/:id/cover-image` (extended) | server | iphone | `requireAuth` + `groupManageFilter` | D10, framing per D21 (reopened 2026-10-27) | `{success, coverImageUrl, coverOriginalUrl, coverFraming}` — flat, `coverImageUrl` where 1.0 and the web read it (D10) | 400 (D10/D11, undecodable image) · 401 · 404 (not a manager, or inactive) · 413 over 10mb (D16) · 500 R2 failure |
| group payloads — `GET /api/groups`, `GET /api/groups/:id`, PATCH, POST (extended; one `toGroupPayload`, D17) | server | iphone | as today | — | + `coverOriginalUrl` (string\|null), `coverFraming` (D21 \| null) | as today |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `Group.coverOriginalUrl` (text, null) | `coverOriginalUrl` | Edit image reopens the full photo; D7 | landed 20261027164451_group_cover_image (22b8c4e) |
| SC2 | ADD | `Group.coverFraming` (jsonb, null) | `coverFraming` | Edit image restores zoom/rotate/position; D11 | landed 20261027164451_group_cover_image (22b8c4e) |
| SC3 | EDIT | cover upload body + response | D10 | new pick + re-edit in one request; D10 | landed 28b0382 (no migration) |
| SC4 | EDIT | `coverFraming` JSON shape (no column change) | + `flipped`, `quarterTurns` (optional, defaulted) | Edit cover flip + rotate 90°; D21 | landed 37d1438 (no migration) |

**Data plan:** SC1–SC2 are nullable adds through `server/schema/*.yaml` → `schema:diff` → one Atlas
migration; no backfill — existing groups read null and use D7's fallback. Undo = drop both columns.

## server

- Schema SC1–SC2 in `server/schema/schema.yaml` (Group at :269): `coverOriginalUrl` string null,
  `coverFraming` json null → `schema:diff` → one Atlas migration (+ `atlas.sum`).
- Group payloads: one `toGroupPayload` replacing the four inline mappers, with both fields (D17); the
  OpenAPI Group schema and the route's `@openapi` block gain them.
- Cover upload: `services/group-cover.ts` (D17) — D10 body + flat response, D11 strict zod, original
  re-encode + upload, one atomic write, D9 clearing on a framing-less upload, D18 library rule, D19
  old-original delete. PATCH with the `coverImageUrl` key also clears (D9). No body-limit change (D16).

## iphone

- **Group page:** `GroupsDetailScreen` gains `onCoverTap: () -> Void = {}` (build edit, D4) — a default
  so `ViewRegistry.swift:3631`, `GroupsScreensEditTests.swift:25-26` keep compiling; the tappable cover
  carries its own accessibility label + button trait (`CoverImage` is `accessibilityHidden`).
  `GroupDetailContainer` routes it per D1/D2, reading `AppState`, not the screen state.
- **Picker:** the `.photosPicker(isPresented:selection:matching: .images)` modifier on the group page
  container (D3) — a system picker, neither `.sheet` nor `.fullScreenCover`.
- **Edit cover:** route `UI2Destination.editGroupCover(groupId:, source: .newPick(UIImage) | .stored)`
  (`UI2ShellModel.swift:18-34` needs a UIKit import; the pick is already ≤ 2400px, D3; the switch at
  `UI2Shell.swift:150-161`)
  → `EditGroupCoverContainer` wiring the d2m-built screen: gesture state per D5, D12 render, D13 save.
- **Viewer:** a full-screen overlay view per D8 (build-made, routed to `/ui2-resolve`).
- **State:** `UserGroup` + `coverOriginalUrl?`, `coverFraming?` — added to the custom `init(from:)` with
  `decodeIfPresent` (`coverFraming` via `try?`, D11) and to the memberwise init
  (`GroupModels.swift:43-95`), so old disk caches (schemaVersion 1, no migration) still decode. A new
  `GroupActions.saveCover(groupId:, rendered:, framing:, original:)` on `requestWithStatus` (D13),
  patching the three returned fields into `AppState.groups`; `APIClientProtocol` + `StubAPIClient`
  gain the timeout parameter. The legacy `uploadCoverImage` stays for the legacy pages.
- **Render:** a new helper draws the framed image with `UIGraphicsImageRenderer` (applies orientation —
  `APIClient.resizeImageIfNeeded` does not) at 1200×675, JPEG 0.9 (D12, D20).

## Testing

- **server:** `server/src/routes/__tests__/groups-cover-image.request.test.ts` on the
  `groups-edit-fields.request.test.ts` pattern (its sharp mock gains `rotate`/`metadata`, storage gains
  `uploadToR2`/`deleteFromR2`; its harness `express.json()` is 100kb — tiny bodies) + a
  `group-cover.ts` service unit test: upload with framing + original (both stored, original under its key, ≤ 2400px); framing
  only keeps the original; legacy body clears both (D9); PATCH `coverImageUrl` clears; `originalData`
  without framing 400; bad framing 400; non-manager 404; response is flat with `coverImageUrl` top-level; unknown framing key 400; undecodable image 400; R2 failure leaves the row unchanged; D18 capture rule; D19 deletes the old original; payloads carry both fields.
- **iphone:** framing math — the zoom floor at 0°, 45° and 90° for wide and tall images, pan clamp,
  ±3° snap, `scale` relative to the floor round-trips; render produces 1200×675; D7 fallback; menu
  rows per cover state (glyphs `upload`/`edit`/`eye`); has-cover read from AppState; decode of the new
  fields, a bad `coverFraming`, and an old cache without them; Save re-entry ignored; 404 → pop; `ios:build-check --test`; swiftlint baseline.
- **Cross-app E2E (Fixtures):** D1 on Empty Group with a photo put in the simulator's Photos library
  (`xcrun simctl addmedia <udid> server/fixtures/images/<file>` — not a server fixture); save; re-edit zooms out past
  the old crop; View shows the full photo; a legacy-body upload then makes Edit open the cover itself.
- **Human walk (on device):** gesture feel (pinch + rotate + pan together), the snap, the menu.

## Out of scope

- Picking from the MakeReady media library (no 2.0 picker design) — owner 2026-10-27.
- Program covers; cover editing on the web — owner 2026-10-27.
- Filters, brightness, any adjustment beyond zoom/rotate/position; zoom inside the viewer.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | ~~Edit cover is not in d2m yet~~ — cleared 2026-10-27: built by d2m and committed on main (`8b83f38`, `iphone/MakeReadyUI/Screens/Groups/EditCoverScreen.swift`, with C-087 at 16:9 and C-040 `leadingEnabled`/`trailingLoading`); its interface is `EditCoverScreen(state:canvas:onFrameLayout:onCancel:onDone:onFlip:onRotate90:onStraighten:onStraightenEnd:)` — no `onAuto` (D29) | build-time risk — cleared |
| F2 | Two base64 images may exceed the route's JSON body limit | settled by D16 — measured ≤ ~4.5MB against the global 10mb limit; no change |
| F3 | The cover-tap hook and the viewer are MakeReadyUI / app edits outside d2m | route both to `/ui2-resolve` after the build (D4) |
| F4 | contract: the spec's response `{success, data:{…}}` would break released 1.0 (`GroupActions.swift:339-349`) and the web (`leader-group-home.store.ts:471`), both reading a flat `coverImageUrl` (`groups.ts:1404-1407`) | corrected in place: flat response (D10, §Contract, §Apps); client ⬜ holds on that condition |
| F5 | Glyphs `image` and `view` do not exist in `GlyphName` | D2 uses `upload` / `edit` / `eye`. build-time risk — if the Figma menu frame draws other glyphs, the iPhone phase routes the glyph add to `/ui2-component-update` (C-066) rather than drawing one |
| F6 | `uploadImage` folds a 404 into `APIError.serverError`, so D13's pop-on-404 was unreachable | D13: the new Action uses `requestWithStatus` with a timeout parameter |
| F7 | A cover still loading reads as "no cover" in the screen state; a group outside `AppState` would offer the picker and 404 | D2: has-cover from `AppState`, tap inert until the group is loaded |
| F8 | Released 1.0 and the web upload with the legacy body, which wipes the 2.0 original and framing (D9); the 1.0 pages are not in the current app target (no Sources phase), so only App Store 1.0 builds and the web can do it | accepted by design (D9) |
| F9 | The original would land on a public URL with EXIF (GPS) and an unspecified orientation | D10: server re-encodes with `.rotate()`, metadata stripped; phone sends upright pixels (D3) |
| F10 | The agent walk env (`agent_walk.env`) carries no R2 settings; `getR2Client` throws without them (`storage.ts:13-21`), so every cover save on the walk is a 500 and fixture images are skipped | build-time risk — settled at the agent walk: R2 settings in `agent_walk.env` are a config change, the owner's (a `human-step` park naming `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_URL`), unless the walk env has them by then. **Settled 2026-10-27 by 97acb50 on main:** the walk env stores images in a local s3mock (`R2_ENDPOINT` + dummy keys in `agent_walk.env`); walk readiness smoked a framed upload, original + framing read back, both objects served 200 |
| F11 | The legacy admin SPA posts multipart `image` and reads `res.data.group` (`admin-island/stores/domain/groups.domain.ts:112-121`); the zod body requires `imageData`, so it already 400s | pre-existing, out of scope; not touched |
| F11 | D20 makes C-087 16:9 on every consumer (groups-detail, study-program-home, others in the registry) — a d2m component change | done 2026-10-27 — d2m made C-087 16:9 (`8b83f38`) |

## Plan

The plan, with its code: `docs/features/group-cover-image/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · Group cover columns — schema YAML, Atlas migration, Prisma client
- Phase 1 · Task 2 · One `toGroupPayload` carrying the two new fields
- Phase 2 · Task 3 · `saveGroupCover` service — re-encode, upload, one atomic write, old-original delete
- Phase 2 · Task 4 · Cover upload route on the service, PATCH clearing, OpenAPI — and the contract freeze
- Phase 3 · Task 5 · `UserGroup.coverOriginalUrl` + `coverFraming`, decoding old caches and bad values
- Phase 3 · Task 6 · `GroupActions.saveCover` on `requestWithStatus` with a timeout
- Phase 4 · Task 7 · Cover framing math — zoom floor, pan clamp, ±3° snap, relative scale
- Phase 4 · Task 8 · The 1200×529 render and the ≤ 2400px upright pick
- Phase 4 · Task 9 · `EditGroupCoverModel` — gesture state, D6/D7 opening, D13 save outcomes
- Phase 5 · Task 10 · The full-screen cover viewer (D8)
- Phase 7 · Task 11 · Edit cover page — wire the d2m-built screen to `EditGroupCoverModel`, route `.editGroupCover`
- Phase 7 · Task 12 · The cover tap on the group page — picker, C-066 menu, viewer (D1/D2/D3/D8)
- Phase 6 · Task 13 · Cover framing gains flipped + quarterTurns
- Phase 7 · Task 14 · Framing math, render and model for D20–D26
- Phase 7 · Task 15 · Drop Auto, add the dial's straighten API to the model (D29, D30)
