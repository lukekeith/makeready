---
description: Make the Vue (web) version of a component match its iPhone version for ONE variant — capture both in the /compare tool, diff them with iPhone as the reference, then fix the web component/SCSS and recapture until they match (or a real parity gap is surfaced).
argument-hint: <component> <variant>   (a comparison + variant name, e.g. CardStudy Pending)
---

# Capture: parity check — $ARGUMENTS

Parse `$ARGUMENTS` as two tokens: the **first** is the component, the **second** is the variant.
(e.g. `CardStudy Pending` → component `CardStudy`, variant `Pending`.) If a token is missing,
ask which component/variant. Below, `<component>` and `<variant>` mean those two tokens, `<id>`
means the resolved comparison id (from the fixture — often a kebab-case slug, e.g.
`CardStudy` → `card-study`), and `<viewport>` defaults to `pro-max`.

Goal: get the **web** render of `<component>` (variant `<variant>`) to match the **iPhone**
render. The iPhone build is the design reference; the **web** Vue component + SCSS is what you
edit. Never edit the iPhone app or change shared design tokens to force a match — if the gap is
structural, surface it (see step 6).

This assumes the comparison already exists in `/compare`. If `<component>` or the variant
`<variant>` doesn't exist yet, stop and tell the user to run `/capture-add <component>` first.

## 1. Resolve the comparison + variant

- Find the spec: `capture/fixtures/compare/**/*.json` whose `id` or title matches `<component>`.
  Read its `id` (→ `<id>`), `adapter`, and `variants[]`. Confirm `<variant>` is one of the
  `variants[].name` (case-insensitive match is fine — use the spec's exact casing for capture
  commands). If not, list the available variant names and stop.
- Note the variant's `shared` data — both platforms render this same data, so any visible
  difference is an implementation gap, not a data difference.
- Default viewport: **pro-max** (use `se` too only if the user asks or the gap looks layout-width
  dependent).
- Identify the web source from the adapter's `toClient` (`component` + the island registry in
  `client/resources/js/components/domain/component-capture/component-capture.vue`) →
  `client/resources/js/components/.../<name>/<name>.vue` + its `.scss`. Identify the iPhone source
  from `toIphone` (`view: "component.<X>"`) → the `component.<X>` case in
  `iphone/MakeReadyCaptureTests/ViewRegistry.swift` and the SwiftUI component it builds.

## 2. Get the iPhone reference shot (needs an Xcode build — ASK FIRST)

The iPhone shot is the source of truth. You need a current one **for this exact variant** — a
shot of a different variant is NOT a valid reference (different data → different render).

- Check what already exists: the versioned shots live at
  `capture/fixtures/compare/_shots/<id>/<viewport>/iphone/<versionId>.png`, but the variant is
  recorded in the DB (the `version` row's `variantName`), not the path. Query it to find the
  latest iPhone version for `<variant>`:
  ```
  cd capture && node -e "import('./db/index.mjs').then(async({prisma})=>{const vs=await prisma.version.findMany({where:{comparisonId:'<id>'},orderBy:{capturedAt:'desc'},include:{screenshots:{select:{platform:true,path:true}}}});for(const v of vs)console.log(v.id,v.variantName,v.viewport,v.screenshots.map(s=>s.platform).join('+'));await prisma.\$disconnect()})"
  ```
- If a recent iPhone shot of `<variant>` exists and the user says it's current, **Read** it and use it.
- Otherwise the iPhone side must be captured, which runs `xcodebuild`. **Per the iPhone rules,
  never build without explicit permission.** Ask the user:
  > "Capturing the iPhone reference for `<component>`/`<variant>` runs an Xcode build (a few
  > min). Run it?"
  On yes:
  ```
  cd capture && node runners/compare/capture.mjs <id> <viewport> "<variant>" iphone
  ```
  It prints `✓ iphone: _shots/<id>/<viewport>/iphone/<versionId>.png`. **Read** that path.
- A blank/placeholder cover or photo on the iPhone shot is a remote-image snapshot limitation —
  don't chase it, and never alter the web to match a missing image.

## 3. Capture the web shot (rebuild the client bundle FIRST)

The client at :8001 serves the **built** Vue bundle from `client/public/build/` — there is no
client HMR dev server. Source edits are invisible to captures until you rebuild. A stale bundle
renders the island empty (the shot is only ~32 CSS px tall; the page console warns
`No component registered for "ComponentCapture"`). So **always build before capturing web**:

```
cd client && npm run build          # vite build, ~5s
cd ../capture && node runners/compare/capture.mjs <id> <viewport> "<variant>" client
```

(Needs Laravel on :8001 + the capture services — i.e. `/capture-start` already run. If it can't
connect, tell the user to start them and stop.) It prints
`✓ client: _shots/<id>/<viewport>/client/<versionId>.png`. **Read** that path.

## 4. Diff — iPhone (reference) vs web

Read both shots together and compare, treating iPhone as correct. Walk the obvious axes:

- **Layout & size:** dimensions, padding/margins, gaps, alignment, corner radius, overall shape.
- **Image/avatar:** shape (circle vs rounded-rect), size, crop, fallback treatment.
- **Typography:** which lines exist, size/weight/color hierarchy, truncation/line-clamp, tracking.
- **Metadata / chips:** icon glyph + label, count formatting, ordering, spacing.
- **State:** selected/pending/etc. — border, tint, badges, checkmarks.
- **Color:** backgrounds, borders, foregrounds vs the design tokens.

List each concrete difference. Separate **fixable web drift** from **structural parity gaps**
(step 6).

## 5. Fix the web component → rebuild → recapture → verify (loop)

For each fixable difference, make the **smallest token-faithful** change to the Vue/SCSS
(`client/resources/css/components/.../<name>.scss` + the `.vue`). Use existing design-system
tokens/variables — don't hardcode values that have a token. Then **rebuild + recapture web**
(step 3 commands) and **Read** the new shot to confirm the change landed and didn't regress
anything. Repeat until the web render matches the iPhone reference for this variant.

History is preserved — each capture writes a new version; old screenshots are kept.

## 6. Surface real parity gaps (don't fake them)

Some differences are intrinsic to the two implementations and must NOT be papered over by
distorting the web component:

- A field one side renders and the other doesn't, or renders in a different place (e.g. a
  secondary line under the title vs inline in a meta row).
- A fallback that differs by design (initials vs a generic glyph).
- A platform-only affordance (a badge/control that exists on only one side).
- Anything that would require changing the iPhone app or a shared design token to reconcile.

For these, **stop and tell the user** what the gap is and the options (change web, change iPhone,
change the token, or accept the difference) — let them decide.

## 7. Report

Summarize: what you changed on the web side (with the recapture confirming it), what now matches,
any structural parity gaps awaiting the user's decision, and whether the iPhone reference was
freshly captured or reused. Tell the user to review at `http://localhost:5950/compare/<id>`
(the variant menu jumps to the latest capture of each variant).
