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

- [ ] 3.1 Column 3 render: `RenderPane` hosting viewer ZoomPane (img mode; host-owned view
      state + `c`/`0`/`Esc` keys per CR6), `VersionTimeline` (newest-first, current chip,
      old-version selection → `fetchComponentVersion`), `DevicePicker` (only when >1 viewport;
      refetches detail with viewport per CR9), never-captured + capturing states — files:
      `pages/components/{RenderPane,VersionTimeline,DevicePicker}.jsx`, `styles.css`
      (`cmp-timeline-*`) · spec: 07 §3.3, 01 D10, 03 §2.2/§2.3 · tests: walk
- [ ] 3.2 Comment mode: pin layer on the render, drafts POSTed with the viewed version's
      `screenshotId` + `platform:"iphone"` (DB-2), threads/reply/resolve via existing routes —
      files: `RenderPane.jsx` (+ viewer CommentLayer reuse) · spec: 07 §3.3, 01 D5/D14 ·
      tests: walk (comment on old + current version; verify anchoring via §2.3 onThisVersion)
- [ ] 3.3 Recapture: button → `POST /api/compare/capture {id, viewport, variant, platform:"iphone"}`
      (CR10), `CaptureLogDock` (new, per CR7), SSE + socket refresh (timeline head grows;
      auto-select only if current was selected) — files: `RenderPane.jsx`,
      `pages/components/CaptureLogDock.jsx` · spec: 07 §3.3/§5, 01 D15 · tests: walk (real capture)
- [ ] 3.4 `WiringChecklist` (three checks + kebab `/capture-add` copy per D20) — files:
      `pages/components/WiringChecklist.jsx` · spec: 07 §3.4 · tests: walk (select a helper file)
- [ ] 3.5 Column 4: `SidePanel` tabs; `CommentsTab` (this-version-first grouping with capture-date
      labels, resolved dimmed); `DataEditor` + `FieldRow` (D9 recursion: scalars typed, plain
      objects/arrays collapsible incl. arrays of objects like `metadata[]`, raw-JSON fallback
      per D9's rule), Save → `PUT /api/components/fixture`, Save & Recapture chaining 3.3 —
      files: `pages/components/{SidePanel,CommentsTab,DataEditor,FieldRow}.jsx`, `styles.css`
      (`cmp-fields-*`) · spec: 07 §3.5, 01 D8/D9, 03 §2.4 · tests: walk (edit `title`, both
      buttons; git diff shows the fixture edit)

## Phase gates (run fresh, record output)

- [ ] `cd capture && npm test` — green
- [ ] Full E2E walk 08 §3 steps 2–6 (tree → variants → render → recapture keeps history →
      comment old+current → data edit → recaptured render shows the edit)
- [ ] `/compare` regression spot-walk (pins + capture on one comparison)

## Verification checklist

- [ ] Contract parity: §2.3 consumption (screenshotId, onThisVersion, viewport-scoped comments)
      traced in code
- [ ] A comment placed while viewing an OLD version lands with that version's versionId (DB
      check), and the CommentsTab groups it under "other versions" when viewing current
- [ ] Data editor round-trips `CardEvent.json`'s real shape (incl. `metadata[]`,
      `imageStyle{}`) without key loss (git diff clean except the edited value)
- [ ] Spec-parity spot-check: D9 fallback rule; D10 picker visibility; 07 §5 auto-select rule

## VERIFIED

⬜ Not yet — do not open the next phase doc.
