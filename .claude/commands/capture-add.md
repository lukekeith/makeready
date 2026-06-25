---
description: Add a component/page from docs/capture/manifest.md to the /compare tool — analyze the iPhone + Web versions, extract all variants & props, build the variant-aware fixture + adapter + harness, register it in the DB, and capture the first variant's first version.
argument-hint: <component>   (an id/name from docs/capture/manifest.md, e.g. card-group)
---

# Capture: add a comparison — $ARGUMENTS

Goal: stand up an apples-to-apples comparison for **$ARGUMENTS** in the `/compare` tool, with
**variants** (each variant has its own data, named to match the iPhone component's variant).

Reference implementation to copy: `card-study` —
`capture/runners/compare/adapters/card-study.mjs`, `capture/fixtures/compare/cards/card-study.json`
(note its `variants: [{ name, shared }]` shape), the `ComponentCapture` island, and the
`component.card-study` case in `iphone/MakeReadyCaptureTests/ViewRegistry.swift`.

## 1. Analyze the iPhone component (source of truth for variants)

- Find it under `iphone/MakeReady/Components/**` (e.g. `CardStudy.swift`, `GroupCard.swift`).
- Extract **every variant** — from its variant `enum`/`CardStatus`/size params and especially its
  `#Preview` cases — and the **props** each needs. Record the exact variant **names** as the iPhone
  code spells them (e.g. `.lesson`, `Row`, `Mini`, `pending`). These become the fixture variant names.
- Note the data model (the `…Data` struct / init params) so the adapter can build it.

## 2. Analyze the Web component & confirm data parity

- Find the matching Vue component under `client/resources/js/components/**` (+ its `*.story.vue`).
- Confirm it can render the **same data** for each variant (same fields). If a field is missing on
  one side, flag it to the user (a real parity gap) rather than papering over it.

## 3. Build the harness + fixture

- **Adapter** `capture/runners/compare/adapters/$ARGUMENTS.mjs` exporting `{ toClient(shared), toIphone(shared) }`
  (map semantic icons → inline SVG for web / SF Symbols for iPhone, like card-study). Register it in
  `capture/runners/compare/adapters/index.mjs`.
- **Web island**: add the component to the registry in
  `client/resources/js/components/domain/component-capture/component-capture.vue`.
- **iPhone**: add a `component.$ARGUMENTS` case to `iphone/MakeReadyCaptureTests/ViewRegistry.swift`
  (build the SwiftUI component from props; extend `CaptureComponent` in `CaptureFixture.swift` only if new fields are needed).
- **Fixture** `capture/fixtures/compare/<group>/$ARGUMENTS.json` with the right `type`
  (`component`|`page`), `group` (category — Cards/Forms/etc.), `adapter`, `viewports`, and a
  `variants: [{ name, shared }]` array — **one entry per iPhone variant**, each with its own data.

## 4. Register in the DB + capture the first variant/version

- The comparison is upserted into Postgres automatically on first capture. Capture the **first
  variant's** web screenshot (instant):
  ```
  cd capture && node runners/compare/capture.mjs $ARGUMENTS pro-max "<FirstVariantName>" client
  ```
  (Needs Laravel :8001 + client Vite — i.e. `/capture-start` already run.) Read the new web
  screenshot to sanity-check it rendered.
- The **iPhone** side needs an `xcodebuild` — ask the user before running:
  ```
  cd capture && node runners/compare/capture.mjs $ARGUMENTS pro-max "<FirstVariantName>" iphone
  ```

## 5. Hand off

- Tick `$ARGUMENTS` in `docs/capture/manifest.md`.
- Tell the user to open `http://localhost:5950/compare/$ARGUMENTS`, list the variants you created,
  and note which still need an iPhone capture. Mention any data-parity gaps you found.
