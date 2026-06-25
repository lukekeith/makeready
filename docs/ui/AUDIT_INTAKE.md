# Audit & Intake Worksheet

Companion to [`DESIGN_SYSTEM_PRD.md`](./DESIGN_SYSTEM_PRD.md) §11. Filling this in is the deliverable that makes the catalog "build any screen without new components" complete. Work top-to-bottom; check boxes and record decisions inline. Sources to mine: `client/resources/css/styles/*`, `client/resources/js/components/*`, `iphone/MakeReady/{Colors,Typography,Utilities/Motion}.swift`, `iphone/MakeReady/{Components,Pages}/*`.

---

## A. Token reconciliation

> **Phase 0 status (2026-06-24):** complete. Structural categories live in
> `client/resources/css/styles/_tokens.scss`; the dark semantic mapping lives in
> the new `client/resources/css/styles/_semantic.scss`, `@use`'d after
> `_palette.scss` in `app.scss` so its `:root` block overrides palette's
> light-biased defaults (verified by Sass compile — the dark `--bg-canvas`
> definition wins the cascade). Re-pointing was zero-risk: these semantic tokens
> had **0 consumers** in the repo and the admin SPA does not reference them.

- [x] **Dark semantic mapping.** Final values + source resolved below. Conflict rule: **where iOS hue ≠ web ramp, the iOS hue wins** (parity is the north star); the iOS hex is aliased as a new `--color-ios-*` / `--color-*` primitive so the web ramps stay untouched.

| Semantic token | Proposed (dark) | iOS source | Web ramp | Final (in `_semantic.scss`) |
|---|---|---|---|---|
| `--bg-canvas` | `#0d101a` | appBackground | — | **`#0d101a`** → `--color-canvas` |
| `--bg-surface` / card | `#252936` | cardBackground | — | **`#252936`** → `--color-surface` |
| `--bg-elevated` | `#252936` | surfaceElevated | — | **`#252936`** → `--color-elevated` |
| `--bg-section` / modal | `#191C25` | sectionBackground | — | **`#191c25`** → `--color-section` (new) |
| `--bg-pending` | `#201B48` | backgroundPurple | — | **`#201b48`** → `--color-pending` (new) |
| `--bg-overlay` | black @ 50% + blur | DialogOverlay | alpha-black-50 | **`rgba(0,0,0,.5)`** → `--color-alpha-black-50` (+ `--blur-lg` on the scrim) |
| `--fg-primary` | white | — | — | **`#fff`** → `--color-white-100` |
| `--fg-secondary` | white-70 | — | — | **white-70** → `--color-white-70` |
| `--fg-tertiary` | white-50 | — | — | **white-50** → `--color-white-50` |
| `--fg-disabled` | white-30 | `.white30` | — | **white-30** → `--color-white-30` (added to `_tokens.scss`) |
| `--brand` / `--bg-brand-primary` | `#6C47FF` | brandPrimary | brand-500 | **`#6c47ff`** → `--color-brand-500` (web ramp == iOS, no conflict). Text `--fg-brand` uses **brand-400** for legibility on dark |
| `--accent` / `--fg-accent` | `#5680ff` | accentBlue | — | **`#5680ff`** → `--color-accent` (new) |
| `--fg-error` / `--bg-error-subtle` | `#FF4759` / @20% | error | error-500 `#fb2c36` | **`#ff4759`** → `--color-ios-error` / `--color-error-tint` (**iOS hue wins**) |
| `--fg-warning` / `--bg-warning-subtle` | `#F4FF76` / @20% | warning | warning ramp (ambers) | **`#f4ff76`** → `--color-ios-warning` / `--color-warning-tint` (**iOS hue wins** — web ramp is amber, iOS is chartreuse) |
| `--fg-success` | `#57DB5D` | success | success-500 `#00c950` | **`#57db5d`** → `--color-ios-success` (**iOS hue wins**) |
| `--fg-destructive` | `#df1439` | destructive | — | **`#df1439`** → `--color-destructive` (new) |
| `--border-default` / `--border-primary` | white-10 | — | — | **white-10**; `--border-strong` = white-20 |

> **Badges** re-pointed to dark (tinted bg + bright fg): neutral = white-10 / white-70; brand/error/warning/success/indigo = hue@20% tint + bright hue. **`--data-categorical-*`** (charts) left as palette placeholders — out of Phase 0 scope, addressed in Phase 4.

- [x] **Shadows / elevation** — dark = deepening black, not a grey lift. `--shadow-sm` `0 1px 2px rgba(0,0,0,.30)`, `--shadow-md` `0 2px 8px /.35`, `--shadow-lg` `0 8px 24px /.45`, `--shadow-xl` `0 16px 48px /.55`, `--shadow-overlay` `0 12px 40px /.55` (frosted floating panels).
- [x] **Blur** — `--blur-sm 8px`, `--blur-md 16px`, `--blur-lg 20px`. `--surface-overlay-blur` now resolves to `var(--blur-lg)` (was inline `20px`) — single source.
- [x] **Z-index ladder** — `--z-base 0`, `--z-dropdown 100`, `--z-sticky 200`, `--z-overlay 900` (scrim/sheets), `--z-modal 1000` (**pinned to `BASE_Z_INDEX` in `modal.store.ts`**), `--z-popover 1100`, `--z-toast 1200`, `--z-banner 1300`. Note: the store stacks modals at `1000 + depth*10`, so popover/toast/banner sit deliberately above a shallow modal stack.
- [x] **Motion** — durations value-identical to `Motion.swift`: `--motion-micro-fast 150ms`, `--motion-micro 200ms`, `--motion-settle 200ms`, `--motion-exit 200ms`, `--motion-brisk 250ms`, `--motion-standard 300ms`. Easings: `--ease-standard` (easeInOut), `--ease-enter` (easeOut), `--ease-exit` (easeIn), `--ease-spring` (overshoot ≈ modal-present spring response 0.4). **Reduced-motion:** `@media (prefers-reduced-motion: reduce)` collapses all durations to `0.01ms` and easings to `linear`. Spring *dismiss* + draggable-sheet springs are component-level (Phase 3).
- [x] **Font weights & tracking** — `--font-weight-regular/medium/semibold/bold` = 400/500/600/700. Tracking: `--tracking-label 0.1px` (iOS label), plus `--tracking-tight -0.2px`, `--tracking-normal 0`, `--tracking-wide 0.6px` (uppercase overline / month abbr).
- [x] **Icon sizes** — `--icon-xs/sm/md/lg` = 16/20/24/32. ✅ confirmed.
- [x] **Avatar sizes** — DS scale chosen: `--avatar-sm/md/lg/xl` = **36/48/72/96** (PRD §6.1). ⚠️ **Divergence to resolve at component time:** iOS `Avatar` uses a finer 6-step ramp (24/32/40/48/64/96). Decision: keep the 4-step DS scale for web; map iOS `.xs/.sm` → nearest web step when porting. Noted in `_tokens.scss`.
- [x] **Layout tokens** — `--page-max-w 480px`, `--page-pad-x 16px` (→12 ≤360), `--gutter 12px` (→8), `--header-h 56px` (→50), `--tabbar-h 64px` (→58), `--touch-min 44px`.
- [x] **Safe-area** — `--safe-top/right/bottom/left` = `env(safe-area-inset-*, 0px)` (0 fallback keeps non-notch browsers correct). ✅ `viewport-fit=cover` now set on the app/home/auth layouts (Phase 6), so the insets resolve in standalone.
- [x] **Breakpoint strategy** — **Decision: keep the single `@media (max-width: 360px)` shrink** as the only breakpoint; extended it to also tighten the new layout tokens (page-pad-x/gutter/header-h/tabbar-h). The member surface is phone-first with a `--page-max-w` cap on larger viewports, so no tablet/large-phone breakpoint is added now; revisit only if a tablet-specific layout is requested.

---

## B. Component census (catalog ⊇ both apps)

> **Phase 1 status (2026-06-24):** Primitives + forms layer built as Vue 3 + CVA
> components with stories. Each Vue component emits BEM classes matching its
> SCSS modifiers (PRD §16); SCSS lives in `resources/css/components/{primitive,form}/`
> and is `@use`'d by `app.scss` (loaded globally in Histoire via `histoire.setup.ts`).
> Existing CSS-only primitives were tokenized in place (dark tokens; the undefined
> `var(--radius)` bug fixed across button/badge/card/input + domain cards).
>
> **Built — Primitives:** Button (exemplar), Text/Heading, Link, Icon, IconButton,
> Avatar, Badge, Card (base), Divider, Spinner (wraps `.Loading`), Skeleton,
> ProgressBar, Image, Switch (wraps `.Toggle`), Checkbox, Radio.
> **Built — Forms:** TextInput (wraps `.Input`), Textarea, SearchField,
> Select/MenuInput, DatePickerField, ToggleControl, TagInput, AgeRangeInput,
> FieldGroup, Label, HelpText (ErrorText = `tone="Error"`). Existing kept:
> VerifyCode, Digit/Keypad, BulletTextInput.
> Reka-ui deferred: Checkbox/Radio/Switch/Select were hand-rolled framework-light
> for SSR-friendliness; reka-ui reserved for overlays (Phase 3).
> **Deferred to later phases:** RichText/MarkdownEditor + BlockStyleEditor +
> MediaPicker/CameraCapture + KeyboardToolbar (editor phase / Feature 1).
>
> **Naming reconciliation (to record in matrices):** Badge tone modifiers keep the
> legacy names (`default/primary/secondary/destructive/success/warning/outline`,
> + new `indigo`) rather than the inventory's `neutral/brand/error/…` — preserved
> to avoid breaking `badge.blade.php`; CVA keys match the SCSS modifiers. Icon's
> legacy numeric scale (12/16/20/24/32/48) is retained for live Blade; new Icon
> component uses the catalog `--icon-*` tokens (16/20/24/32) via inline sizing.

- [ ] Walk `iphone/MakeReady/Components/` (all ~100 files) and `client/resources/js/components/` + `css/components/`. For each UI element, record one row:

| Element | In web? | In iOS? | Catalog entry | Action (covered / extend / net-new) | Variant matrix done? |
|---|---|---|---|---|---|
| _(example)_ Button | yes | yes (ActionButton) | Primitives/Button | extend | ☐ |
| | | | | | |

- [~] **Confirmed gaps vs iPhone (Phase 7 coverage audit, 2026-06-24).** Catalog
  coverage is **~85%** — primitives, forms, type-specific cards, charts, calendar,
  nav, overlays, and the full invite/scope set are built. The unbuilt surface,
  in priority order:
  1. **Content editors (highest effort — PRD §9A Feature 1).** Not buildable from
     the current form catalog. Missing sub-controls: `BlockStyleEditor`
     (bg-image source + color overlay + opacity + font-size picker + theme select),
     `RichTextInput`/`MarkdownEditor` (formatting toolbar, markdown round-trip —
     only `bullet-text-input` exists), `MediaLibraryPicker`/`CoverImagePicker`,
     and the exegesis verse-highlighter. → add `form/rich-text-editor`,
     `form/block-style-editor`, `form/media-picker`, `domain/verse-highlighter`,
     then the day/activity editor page templates.
  2. **Bible reader** (reader overlay, version menu, verse highlighting) — absent.
  3. **Notifications feed** — absent (+ a `card-notification`).
  4. **Video recorder + teleprompter** — absent (inventory scopes a web subset).
  5. **Interaction patterns** still unbuilt (intake §C): drag-to-reorder,
     pull-to-refresh, and the AlphabetScrubber option on `searchable-list`.
  6. **Media library grid + media-detail overlay**, full-screen image viewer.
  These are tracked as the Phase 5 "editor/Feature-1" follow-up, not regressions.
- [ ] For each component, finalize the **variant × size × state** matrix. Attach to its story.

---

## C. Interaction inventory

- [ ] For each pattern, record trigger, motion token, thresholds, reduced-motion behavior:
  - [ ] Swipe-to-reveal (row actions) — reveal width, snap threshold, action set: ____
  - [ ] Slide navigation (push/pop, leading/trailing) — duration, gesture: ____
  - [ ] Pull-to-refresh — threshold, indicator: ____
  - [ ] Long-press / press-and-hold — delay, use sites: ____
  - [ ] Drag-to-reorder — handle, haptic/none: ____
  - [ ] Bottom-sheet drag-to-dismiss — velocity threshold: ____
  - [ ] Peek-scroll / rubber-band — resistance: ____
  - [ ] Tab switch transition: ____

---

## D. Content & data shapes

> **Phase 4 status (2026-06-24):** type-specific cards + data display built,
> data-driven (props documented in each `.vue` header). Each card ships **Row +
> Mini** (`size` prop) + a **Skeleton** component; charts wrap `vue3-apexcharts`.
> Chart color palettes are hardcoded design hexes inside each chart `.vue`
> (ApexCharts paints SVG and cannot read CSS custom properties) — flagged so a
> future token change must update those constants too.

- [x] Record the props/data each reusable element consumes (so they stay data-driven, not forked):
  - [x] **CardStudy** `{ title, description, coverUrl, dataItems: {icon?,value}[], unconfirmed?, pending? }`; states default / pending (`--bg-pending` + animated brand border) / unconfirmed badge. **CardEvent** `{ title, day, month, coverUrl?, dataItems? }`. **CardGroup** `{ name, imageUrl?, initials?, memberCount, meta?, selected? }`; selected = brand border + check. **CardVideo** `{ title, category?, thumbUrl, duration? }`.
  - [x] **DataComponent** — `icon-value` (`#icon` slot + `value`) and `number-label` (`number` + `label`); 16px (`--space-lg`) row gaps.
  - [x] **StatusBadge** enum → tone map: pending/unconfirmed → Warning, confirmed/active/completed → Success, expired → Default(neutral), revoked → Destructive. Wraps `.Badge`.
  - [x] **List cards** — CardMember `{ name, role?, meta?, avatarUrl?, initials?, pending? }`; CardActivity `{ text, timestamp, icon? }`; CardEnrollment `{ programTitle, status, schedule?, progress? }`; CardPost `{ author, authorAvatarUrl?, timestamp, body, mediaUrl? }`; CardSearchResult `{ title, subtitle?, type, thumbUrl? }`.
  - [x] **KPI** `{ value, label, trend?: {dir,value}, icon? }`, tappable (role=button, emits click).
  - [ ] (Pending) map each shape to its server API response — do during domain parity (Phase 5).
- [ ] Map each shape to the server API response that feeds it (so components match real data). Reference: server routes.

---

## E. State coverage

- [ ] For every list/card/detail: design + story for `empty / loading (skeleton) / error / disabled / selected / pending`.
- [ ] Skeleton variant exists for each card and list type.
- [ ] Empty-state copy + illustration/icon defined per screen.

---

## F. Iconography

- [ ] Full icon list used across both apps.
- [ ] Mapping table Lucide ↔ iOS asset names (`IconHome`, `IconPeople`, `IconLibrary`, `IconCalendar`, search, profile, +).
- [ ] Flag icons with no Lucide equivalent → custom SVG list: ____

---

## G. Copy & formatting rules

- [ ] Date formats (short/long, relative "sent recently").
- [ ] Number/count formatting + pluralization ("28 Members").
- [ ] Truncation rules (title 1-line, desc 2-line).
- [ ] Uppercase/tracking rules (overline/labels, month abbreviations).

---

## H. Accessibility

> **Phase 7 pass (2026-06-24).** Audited; results below.

- [x] **Dark-theme contrast — all key pairs meet WCAG AA (≥4.5:1):** fg-primary
  (white) on canvas **18.98:1** (AAA); fg-secondary (white-70) **9.47:1** (AAA);
  fg-tertiary (white-50) **5.35:1** (AA); fg-white on the brand button **5.27:1**
  (AA); fg-error (#ff4759) on canvas **5.69:1** (AA). No failures. (Computed in
  `scripts` math; re-run if the palette changes.)
- [x] **Focus-visible** styles present across 25 design-system SCSS files (brand
  ring `--border-brand`); reka-ui supplies focus order/trap for dialog/menu/popover.
- [x] **aria roles**: 90 component `.vue` files set `role`/`aria-*`; overlays use
  reka-ui (`role=dialog`, `aria-modal`, listbox/option, switch, etc.).
- [x] **`prefers-reduced-motion`**: 11 component SCSS files gate animations, plus
  the global collapse in `_tokens.scss` (all `--motion-*` → ~0, easings → linear)
  — so every token-driven transition is covered.
- [~] **Min target 44px** (`--touch-min`): enforced on the key interactive
  surfaces (ListItem, TabBar, close buttons, back/nav). Follow-up: audit smaller
  icon-only controls (Sm sizes) to confirm ≥44px hit area where they're primary.

---

## I. PWA assets & metadata

> **Phase 6 status (2026-06-24):** PWA shipped for the member surface (admin
> untouched). `public/manifest.webmanifest`, `public/sw.js`, `public/offline.html`,
> icon set under `public/icons/pwa/`, and `resources/views/partials/pwa.blade.php`
> (head meta + SW registration + install hint) `@include`d in the app/home/auth
> layouts. `viewport-fit=cover` added to all three.

- [x] **`manifest.webmanifest`** — name "MakeReady", short_name "MakeReady", description, `start_url:/home?source=pwa`, `scope:/`, `id:/?source=pwa`, theme_color/background_color `#0d101a`, `display:standalone` (+ `display_override:[standalone,minimal-ui]`), `orientation:portrait`, categories `[education, productivity, lifestyle]`, lang en.
- [x] **`shortcuts`** — Home (`/home`), Groups (`/groups`) — the routes that exist today. (Calendar/Add deferred until those routes land.)
- [~] **`share_target`** — omitted: no receiving route/handler exists yet. Add when an in-app "share to MakeReady" target is built (needs a server endpoint).
- [x] **Icon set** — `icon-192/512.png` (any) + `icon-maskable-192/512.png` (safe-zone) + `apple-touch-icon.png` (180) + `logo-mark.svg`. **Source mark:** `public/logo-mark.svg` (purple `#6C47FF` mark), rendered on the `#0d101a` canvas via ImageMagick.
- [~] **Apple touch icon** set (180). **iOS splash screens** (`apple-touch-startup-image` per device size) **not yet generated** — listed as a follow-up (needs the ~15 device-specific PNGs; generate from the same mark on canvas).
- [x] **Service worker** scope `/`; strategy: navigations network-first → cache → `offline.html`; static assets (`/build`, `/icons`, `/images`, `/themes`, asset extensions) stale-while-revalidate; `/api/*`, `/admin/*`, `/auth/*`, `/login`, `/logout` network-only (never cached). `CACHE_VERSION='mr-v1'` (bump to invalidate).
- [x] **Offline shell** — `public/offline.html` (dark, branded, "You're offline" + retry), precached at SW install.

---

## J. Navigation map

- [ ] Produce the full route/screen graph for the group-leader web experience (mirror iOS `Pages/`), including overlays/wizards.
- [ ] Confirm every destination maps to a layout template (PRD §9). Gaps: ____
- [ ] Deep-link / URL scheme parity needs (`makeready://group/{id}` → web route): ____

---

## K. Priority feature coverage (invites, scope, shared content)

Validates the two near-term features (PRD §9A). Server today supports invite/accept-by-token + QR generation, but **not** scoped program/lesson access — flag backend work, design UI data-driven.

### Feature 1 — group-leader parity
- [ ] Confirm the **content editors** (program / day / read / exegesis / user-input / youtube) are fully buildable from the form catalog (RichText/MarkdownEditor, BlockStyleEditor, MediaPicker, MenuInput, DatePicker, FieldGroup, KeyboardToolbar). List any editor sub-control with no catalog component: ____
- [ ] Confirm every iOS `Pages/Manage/*` screen maps to a layout template + components (no gaps). Gaps: ____

### Feature 2 — scoped contributor invites + shared content

> **Phase 5 status (2026-06-24):** the UI catalog for Feature 2 is **built and
> data-driven against the scope descriptor**, ready for the API. Components:
> ScopeBadge, RoleSelector, InviteScopeSelector, QRCodeDisplay, CopyLinkField,
> ShareButton, InviteSheet, AcceptInviteCard, SharedContentCard, SharedContentList,
> ScopedAppShell. Page templates: `Pages/Invite Flow`, `Pages/Accept Invite`,
> `Pages/Shared With Me`. **Backend still owes** scoped `ProgramAccess`/`LessonAccess`
> (flagged in PRD §9A) — the UI is built so it drops in when the API lands.

- [x] **Scope descriptor** finalized: `{ type: 'program' | 'lesson', id, role: 'member' | 'contributor', expiresAt? }` (+ optional `label` for display). All Feature-2 components consume this shape.
- [ ] **Invite data shape** → server: still needs `ProgramAccess`/`LessonAccess` model + `Invite` scope/role fields. **Backend owner/ticket: TBD** (flagged, not design-system work).
- [x] **Role/permission states**: `ScopedAppShell` exposes a `readonly` computed (true when `role==='member'`) via `#default="{ readonly }"` so scoped editors/detail screens disable in-scope; contributor vs leader differ by tab `visibleFor` filtering.
- [x] **ScopedAppShell nav map**: tabs carry `visibleFor?: ('member'|'contributor')[]` — only matching tabs render; a persistent ScopeBadge shows the active scope. (Concrete per-destination table still to confirm with product.)
- [x] **Shared-with-me** data: `SharedContentList` takes `groups: { key, title, items: SharedItem[] }[]` grouped by program/lesson; each item `{ title, coverUrl?, inviterName, role, scopeType, scopeLabel? }`. **API source: TBD** (new "shared with me" endpoint needed).
- [x] **AcceptInvite landing**: `AcceptInviteCard` shows inviter (+avatar), ScopeBadge (role·scope), prominent scopeLabel ("Day 4 of Romans"), expiry note; emits `accept`/`decline`.
- [x] **QR/share for web**: QRCodeDisplay renders the data-URL from `/api/qrcode/generate` (brand `#6C47FF`); ShareButton uses `navigator.share` with copy-link fallback; CopyLinkField copies + success toast.
- [~] **Invite lifecycle states**: StatusBadge covers pending/accepted/expired/revoked tones; a leader "sent invites" list view is **not yet built** (add in a follow-up).
- [x] **Empty/error states**: SharedContentList has an `#empty` slot/state; AcceptInvite expiry shown; invalid-code/out-of-scope handled by the existing join + error-banner channel. (Full per-screen error copy → §G.)

---

## Sign-off

- [ ] All sections complete → catalog is feature-complete for group-leader parity.
- [ ] Reviewed with Luke.
- [ ] SC-4 test screen built with 0 new primitives / ≤1 new domain component.
