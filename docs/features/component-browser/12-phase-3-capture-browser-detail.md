# Phase 3 — Browser detail: render, versions, comments, data editor  ·  app: capture

> Part of docs/features/component-browser/. Preconditions: Phase 2 VERIFIED.

## Goal

Columns 3 and 4 are fully functional: pan/zoom render with the version timeline (old versions
viewable and commentable), comment mode anchored to the viewed version, the wiring checklist
for unwired components, the recursive Data editor with Save / Save & Recapture, and live
capture streaming. This completes R1–R6 + R8's UI half.

## Companion skills

None apply.

## Tasks (in order)

- [x] 3.1 Column 3 render: `RenderPane` hosting viewer ZoomPane (img mode; host-owned view
      state + `c`/`0`/`Esc` keys per CR6), `VersionTimeline` (newest-first, current chip,
      old-version selection → `fetchComponentVersion`), `DevicePicker` (only when >1 viewport;
      refetches detail with viewport per CR9), never-captured + capturing states — files:
      `pages/components/{RenderPane,VersionTimeline,DevicePicker}.jsx`, `styles.css`
      (`cmp-timeline-*`) · spec: 07 §3.3, 01 D10, 03 §2.2/§2.3 · tests: walk
- [x] 3.2 Comment mode: pin layer on the render, drafts POSTed with the viewed version's
      `screenshotId` + `platform:"iphone"` (DB-2), threads/reply/resolve via existing routes —
      files: `RenderPane.jsx` (+ viewer CommentLayer reuse) · spec: 07 §3.3, 01 D5/D14 ·
      tests: walk (comment on old + current version; verify anchoring via §2.3 onThisVersion)
- [x] 3.3 Recapture: button → `POST /api/compare/capture {id, viewport, variant, platform:"iphone"}`
      (CR10), `CaptureLogDock` (new, per CR7), SSE + socket refresh (timeline head grows;
      auto-select only if current was selected) — files: `RenderPane.jsx`,
      `pages/components/CaptureLogDock.jsx` · spec: 07 §3.3/§5, 01 D15 · tests: walk (real capture)
- [x] 3.4 `WiringChecklist` (three checks + kebab `/capture-add` copy per D20) — files:
      `pages/components/WiringChecklist.jsx` · spec: 07 §3.4 · tests: walk (select a helper file)
- [x] 3.5 Column 4: `SidePanel` tabs; `CommentsTab` (this-version-first grouping with capture-date
      labels, resolved dimmed); `DataEditor` + `FieldRow` (D9 recursion: scalars typed, plain
      objects/arrays collapsible incl. arrays of objects like `metadata[]`, raw-JSON fallback
      per D9's rule), Save → `PUT /api/components/fixture`, Save & Recapture chaining 3.3 —
      files: `pages/components/{SidePanel,CommentsTab,DataEditor,FieldRow}.jsx`, `styles.css`
      (`cmp-fields-*`) · spec: 07 §3.5, 01 D8/D9, 03 §2.4 · tests: walk (edit `title`, both
      buttons; git diff shows the fixture edit)

## Phase gates (run fresh, record output)

- [x] `cd capture && npm test` — green
- [x] Full E2E walk 08 §3 steps 2–6 (tree → variants → render → recapture keeps history →
      comment old+current → data edit → recaptured render shows the edit)
- [x] `/compare` regression spot-walk (pins + capture on one comparison)

## Verification checklist

- [x] Contract parity: §2.3 consumption (screenshotId, onThisVersion, viewport-scoped comments)
      traced in code
- [x] A comment placed while viewing an OLD version lands with that version's versionId (DB
      check), and the CommentsTab groups it under "other versions" when viewing current
- [x] Data editor round-trips `CardEvent.json`'s real shape (incl. `metadata[]`,
      `imageStyle{}`) without key loss (git diff clean except the edited value)
- [x] Spec-parity spot-check: D9 fallback rule; D10 picker visibility; 07 §5 auto-select rule

## VERIFIED

✅ 2026-09-04 — gates run fresh in a live browser:
- `npm test` 30/30; `vite build` clean after every SPA change.
- E2E 08 §3 steps 2–6 walked live: ZoomPane render + device picker (pro-max/se per fixture,
  D10); version timeline with the retained 2026-06-28 version; selecting it shows "VIEWING OLD
  VERSION" + that render; comment placed on the OLD version anchored in the DB to
  cmqx21fwx004pslwihxj5sr05 and a second on current anchored to cmtmi90h90001v0dfbymocq64
  (psql-verified); CommentsTab groups "This version" / "Other versions (version of Jun 27,
  2026)"; badges propagate to timeline, variant list, tree. Data tab renders the real
  CardEvent shape per D9 (typed scalars, imageStyle object, metadata array[1] of objects);
  Save & Recapture wrote the fixture (git diff: `"Event title"` → `"Team Standup Ritual"`,
  key order preserved, whole-file 2-space normalize per CR16b) and the resulting THIRD version
  renders the edited title — all three versions retained with their comment badges; socket
  auto-refresh flipped the timeline + log dock without a reload.
- Two mid-walk fixes (dated): canvas pins are version-scoped (only the viewed version's pins
  render — 07 §3.3), and the draft target-chip hides when the host has no inspect concept
  (browser); `/compare` re-walked after both — new capture + both threads + pins render, live
  web pane fine.
- Unwired flow: WiringChecklist shipped (checks + kebab /capture-add copy per D20).
