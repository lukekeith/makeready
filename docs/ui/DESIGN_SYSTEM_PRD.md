# MakeReady Web Design System — PRD

**Status:** Draft for build
**Owner:** Luke
**Audience:** Claude CLI (build agent) + engineers
**Last updated:** 2026-06-24
**Companion docs:** [`COMPONENT_INVENTORY.md`](./COMPONENT_INVENTORY.md) · [`AUDIT_INTAKE.md`](./AUDIT_INTAKE.md)

---

## 1. Summary

Build a fully tokenized, component-complete design system for the **MakeReady web client** (`/client`, Laravel 11 + Vue 3) that makes the mobile web experience feel like a native app. The system must let us assemble **any new group-leader screen or workflow by composing existing components and layouts — with near-zero net-new component creation.**

The design system's north star: **give group leaders feature parity with the iPhone app inside the web client.** The web experience should look and behave like the iOS app, installable as a PWA, dark-themed, touch-first.

### Locked decisions (2026-06-24)

1. **Theme:** Dark mode only. The admin SPA's light theme is explicitly **out of scope** — do not tokenize or refactor admin. The system serves the member/group-leader mobile-web surface.
2. **Preview harness:** Extend the **existing Histoire** setup. No new framework.
3. **iOS parity:** **Strong parity.** Mirror the iPhone app's component set and interaction patterns (type-specific cards, swipeable rows, slide navigation, overlay-based modals, bottom tab bar) so web and app feel like one product.

---

## 2. Background & current state

This is a monorepo with two relevant UIs:

- **`/client`** — Laravel 11 + Vue 3 "islands" mounted into Blade pages (not a full SPA, except the admin area). This is the build target.
- **`/iphone`** — Swift/SwiftUI native app. This is the **design reference** for parity.

A meaningful foundation already exists in `/client` and must be **extended, not replaced**:

**Tokens** (`client/resources/css/styles/`)
- `_tokens.scss` — CSS custom properties for spacing (`--space-2xs`…`--space-3xl`, 4px base), typography (`--text-xs`…`--text-display` + matching `--leading-*`), control heights (`--control-h-sm/md/lg`), radius (`--radius-sm/md/lg/full`), white-alpha scale, frosted `--surface-overlay`. A single `@media (max-width: 360px)` block shrinks every token for small phones — the established responsive strategy.
- `_palette.scss` — primitive color ramps auto-generated from Figma (`resources/export.json`): `neutral-50…950`, `brand-50…950` (core `#6c47ff`), `indigo`, `error`, `warning`, `success`, `dark-neutral-50…950`, alpha utilities.
- `_colors.scss` — legacy SCSS color functions (`colors.primary(500)`) + semantic CSS vars (`--bg-*`, `--fg-*`, `--border-*`, `--badge-*`, `--data-*`).

**Components** (`client/resources/js/components/` + SCSS in `client/resources/css/components/{primitive,layout,panel,domain}/`)
- Primitives as Vue: `Digit`, `VerifyCode`, `BulletTextInput`, `Modal` (reka-ui), plus CSS-only primitives (`button`, `input`, `badge`, `card`, `avatar`, `icon`, `toggle`, `loading`).
- Variant system: custom **CVA** wrapper (`resources/js/util/cva.ts`) giving enum-like, type-safe variant access; `classnames()` helper.
- Domain islands: phone/verify auth, lesson player (6 step types), study home, navigation, group header, themed content.
- Admin island: separate Vue Router SPA using PrimeVue — **out of scope**.

**Modal management** (`resources/js/stores/modal.store.ts` + `modal-registry.ts` + `ModalProvider`)
- Pinia store with a modal **stack**: `openMenu`/`openFullscreen`/`close`/`closeTopmost`/`transitionContent`, priority (`low`/`high`, high closes low), z-index ladder (`BASE 1000 + depth*10`), content resolved from a registry, teleported to `<body>`, ESC closes topmost.

**Preview** (`histoire.config.ts`)
- Histoire 0.17.17 with `HstVue`; `storyGlob` covers `components/**/*.story.vue` and `pages/**/*.story.vue`. SCSS load paths wired. Plus a bespoke `ActivityPreviewPlayer` for lesson preview.

**Tech stack available:** Vue 3.5, Pinia, reka-ui (accessible primitives), CVA, Motion (`motion` 12.x), Vite 7, Histoire, Lucide icons, HLS.js. Use these; do not introduce parallel libraries.

### iOS reference (parity target)

The iPhone app's distinctive language the web must reproduce: dark canvas `#0d101a`, card surface `#252936`, brand `#6C47FF`, white-opacity layering, frosted `ultraThinMaterial` overlays, type-specific card system (**Study / Event / Group / Video**, each in **Row** + **Mini** sizes), swipeable action reveals, bottom tab bar (Home/Groups/Library/Calendar/Search + profile), hand-rolled slide navigation, overlay-based modals (not native sheets), named motion tokens, skeleton/shimmer loading. See `COMPONENT_INVENTORY.md` for the full mapped catalog.

---

## 3. Goals, non-goals, success criteria

### Goals
1. **Fully tokenized** — every color, spacing, gap, padding, radius, typography, shadow, blur, motion, z-index, and sizing value resolves to a token. No magic numbers in component CSS.
2. **Component-complete** — all standard component types (primitives, forms, layout/containers, panels/cards, navigation, overlays, feedback, data display) plus the domain components needed for group-leader parity.
3. **Composable layouts** — reusable page templates for every key screen type, so new screens are assembled, not designed from scratch.
4. **Robust modal/overlay management** — one system for menus, sheets, dialogs, fullscreen flows, toasts, and banners.
5. **App-like PWA** — installable, standalone, dark, safe-area-aware, with offline shell, per the [Web App Manifest spec](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest).
6. **Live preview harness** — Histoire-based, renders real components with full variant matrices, page layouts, and clickable prototypes for visual + interaction testing.
7. **Documented & gap-free intake** — a captured inventory of decisions/data (see §11 + `AUDIT_INTAKE.md`) ensuring the catalog is complete enough that any new group-leader feature ships with minimal new components.

### Non-goals
- Refactoring or theming the **admin SPA** (PrimeVue) — untouched.
- **Light mode** — not built.
- Changing the **server** API or the **iPhone** app.
- A full SPA rewrite of the client — keep the Blade + Vue islands architecture.

### Success criteria (measurable)
- **SC-1:** 100% of design-system component SCSS references tokens; a lint/grep pass finds zero raw hex, zero raw px for spacing/radius/type (allow-list documented).
- **SC-2:** Every component has a `.story.vue` with a variant matrix covering all variants × sizes × states (default/hover/active/focus/disabled/loading/error).
- **SC-3:** Each "key page" (§9) is reproducible in Histoire as a page story composed **only** from catalog components.
- **SC-4:** A new representative screen (chosen at review, e.g. "group announcements") is built end-to-end with **0 new primitives and ≤1 new domain component**.
- **SC-5:** The client passes a PWA install audit (installable, standalone display, themed, offline shell loads) in Chrome Lighthouse.
- **SC-6:** Visual parity sign-off: side-by-side of 5 shared screens (group home, member list, lesson player, calendar, library) web vs iOS approved by Luke.

---

## 4. Principles

1. **Tokens are the contract.** Components consume semantic tokens, never primitives or literals. Re-theming = swapping the semantic layer.
2. **Compose, don't create.** Favor variants/props/slots over new components. A new component is a last resort and must be justified against the catalog.
3. **Parity by default.** When a pattern exists on iOS, match its structure, sizing, and motion unless there's a web-specific reason not to.
4. **Touch-first, app-like.** 44px+ targets, safe-area insets, momentum scroll, no hover-only affordances, native-feeling transitions.
5. **SSR-friendly islands.** Primitives stay CSS-driven where possible (no hydration needed); interactivity is opt-in via islands.
6. **Accessible.** reka-ui for focus/aria; visible focus states; respects `prefers-reduced-motion`.
7. **One way to do a thing.** Single modal system, single icon set, single motion vocabulary.

---

## 5. Architecture & constraints

- **Render model:** Blade pages mount Vue islands via `data-vue` + `data-props` (see `resources/js/app.js`). Design-system components must work both inside islands and as CSS-only markup in Blade.
- **Styling:** SCSS compiled by Vite, consuming the token CSS vars. BEM-ish class naming already in use (`.Button--primary`, `.Button--mode-block`). Keep it.
- **Variants:** CVA wrapper for Vue components; mirror variant names in SCSS modifier classes so CSS-only usage matches.
- **State:** Pinia per island; modal store is shared.
- **Primitives lib:** reka-ui for dialog/menu/popover/toggle/etc. accessibility.
- **Motion:** `motion` package; durations/easings come from motion **tokens** (new — see §6).
- **Icons:** Lucide (web) mapped to the iOS icon names where parity matters (`IconHome`, `IconPeople`, `IconLibrary`, `IconCalendar`).
- **Constraint:** Do not add Tailwind, styled-components, or a second component library to the member surface.

---

## 6. Token system (requirement detail)

Adopt a **three-layer** token architecture. Layer 1 already largely exists; the work is completing Layers 2–3 and filling the missing categories.

**Layer 1 — Primitive tokens** (raw values; `_palette.scss`, `_tokens.scss`). Color ramps, the spacing/type/radius scales. Keep generated-from-Figma flow.

**Layer 2 — Semantic tokens** (intent; extend `_colors.scss`). `--bg-*`, `--fg-*`, `--border-*`, `--badge-*` exist — **re-point them to dark-mode values** (today several map to light neutrals). Add the missing semantic surfaces below.

**Layer 3 — Component tokens** (optional, per-component) e.g. `--button-bg`, `--card-pad`, resolving to Layer 2. Introduce only where a component needs local theming hooks.

### 6.1 Token categories — status & required work

| Category | Status | Required action |
|---|---|---|
| Spacing (`--space-*`) | ✅ Defined (4px base, 8 steps) | Audit for missing steps; ensure all gaps/padding use it. |
| Typography (`--text-*`, `--leading-*`) | ✅ Defined (8 sizes) | Add `--font-weight-*` (regular/medium/semibold/bold), `--tracking-*` (iOS uses 0.1px tracking on labels), and semantic text styles (see 6.2). |
| Radius (`--radius-*`) | ✅ Defined | Map all card/button/input radii to these (remove `var(--radius)` undefined refs). |
| Control heights (`--control-h-*`) | ✅ Defined | Apply to inputs (currently hardcoded `2.5rem`). |
| Color palette | ✅ Defined | No change to primitives. |
| Semantic color (`--bg/fg/border/badge`) | ⚠️ Light-biased | **Re-point to dark theme.** Define the canonical dark set (see 6.3). |
| **Shadows / elevation** | ❌ Inline only | Add `--shadow-sm/md/lg/xl` + frosted-overlay shadow. Derive from iOS card depth. |
| **Blur** | ⚠️ One value | Generalize `--surface-overlay-blur`; add `--blur-sm/md/lg` for frosted layers. |
| **Z-index ladder** | ⚠️ Modal store only | Define `--z-base/dropdown/sticky/overlay/modal/toast/banner`. Reconcile with modal store's `BASE_Z_INDEX 1000`. |
| **Motion** | ❌ Inline | Add duration + easing tokens mirroring iOS `Motion.swift` (see 6.4). |
| **Opacity scale** | ⚠️ White-alpha only | Add semantic disabled/pressed/hover opacity tokens. |
| **Icon sizes** | ❌ | `--icon-xs/sm/md/lg` (16/20/24/32). |
| **Avatar sizes** | ❌ | `--avatar-sm/md/lg/xl` (iOS uses 36/48/72). |
| **Layout** | ❌ | `--page-max-w`, `--page-pad-x`, `--gutter`, `--header-h`, `--tabbar-h`, `--touch-min: 44px`. |
| **Safe areas** | ❌ | Expose `--safe-top/right/bottom/left` from `env(safe-area-inset-*)`. |
| **Breakpoints** | ⚠️ One (360px) | Document the strategy; add tablet/large-phone if needed (decide in intake). |

### 6.2 Semantic text styles (new)
Define named, reusable text styles (font-size + line-height + weight + tracking) so screens never set type ad hoc. Map to iOS Typography.swift usage:
`text-display`, `text-title`, `text-heading`, `text-subheading`, `text-lead`, `text-body`, `text-body-strong`, `text-caption`, `text-overline/label` (uppercase + tracking). Provide both CSS utility classes and a `<Text variant>` component.

### 6.3 Dark semantic palette (extract exact values during build)
Seed from iOS `Colors.swift`: canvas `#0d101a`, surface/card `#252936`, elevated `#252936`, section/modal `#191C25`, brand `#6C47FF`, accent `#5680ff`, warning `#F4FF76`, error `#FF4759`, destructive `#df1439`, success `#57DB5D`, plus white-opacity layers (10/20/30/50/70). Reconcile against the web `brand`/`neutral` ramps and produce the canonical `--bg-*`/`--fg-*`/`--border-*` dark mapping. **Capture the final mapping in `AUDIT_INTAKE.md`.**

### 6.4 Motion tokens (mirror `Motion.swift`)
Durations: `--motion-micro 200ms`, `--motion-micro-fast 150ms`, `--motion-standard 300ms`, `--motion-brisk 250ms`, `--motion-settle 200ms`, `--motion-exit 200ms`. Easings: `--ease-standard` (easeInOut), `--ease-enter` (easeOut), `--ease-exit` (easeIn). Spring equivalents for modal present/dismiss (CSS or `motion` config). All gated by `prefers-reduced-motion`.

---

## 7. Component library (requirement detail)

The full catalog with variant matrices lives in **[`COMPONENT_INVENTORY.md`](./COMPONENT_INVENTORY.md)**. Summary of required coverage:

- **Primitives:** Button, IconButton, Text/Heading, Link, Icon, Avatar, Badge/Tag/Chip, Divider, Spinner/ProgressBar, Skeleton/Shimmer, Image (with fallback), Toggle/Switch, Checkbox, Radio, Card (base).
- **Forms:** TextInput, Textarea/MultilineInput, SearchField, Select/MenuInput, DatePickerField, ToggleControl, TagInput, AgeRangeInput, RichText/MarkdownEditor, FieldGroup, Label, HelpText/ErrorText, Form layout. Plus the existing `VerifyCode`, `Digit`/`Keypad`, `BulletTextInput`.
- **Layout & containers:** AppShell (header + content + tab bar + safe areas), Page/Screen, Section, Stack/VStack/HStack, Grid, FlowLayout (wrap), Scroll container, Spacer, Container/Panel, Sticky header, List + SectionedList, SearchableList.
- **Panels / cards (parity, type-specific):** CardStudy, CardEvent, CardGroup, CardVideo — each **Row** + **Mini**; plus CardMember, CardActivity, CardEnrollment, CardPost, CardSearchResult, KPI card. SwipeableCard wrapper + SlideButton actions. Skeleton variants for each.
- **Navigation:** TabBar (bottom), PageHeader (with tab switcher/TabSlider), PageTitle, NavBar items, Breadcrumb (if needed), back/slide navigation (SlideStack equivalent), FilterChipDropdown, menus (Add/User/Hamburger/ActionCard/contextual).
- **Overlays / feedback:** Modal/Dialog, BottomSheet/Menu sheet, Fullscreen flow, Popover, Tooltip, Toast, ErrorBanner (auto-dismiss + retry), ConfirmationOverlay, Alert, EmptyState, LoadingOverlay.
- **Data display:** DataComponent (icon+value / number+label), WeekdayIndicator, Calendar (split-month), Charts (Donut/Bar/Line/HeatMap — reuse ApexCharts or port iOS), QR code, StatusBadge.
- **Domain (group-leader parity):** group home/header, member list & profile drawer, enrollment flow steps, lesson player + step types, study/program home, media grid, video player, Bible reader bridge, post/announcement card.

**Variant requirements:** Every interactive component must define states: `default, hover, focus-visible, active/pressed, disabled, loading`, plus `error/success` where it accepts input. Sizes follow control-height tokens (`sm/md/lg`). Variant names align between CVA (Vue) and SCSS modifier classes.

---

## 8. Modal / overlay management (requirement detail)

**Extend the existing Pinia modal store** — do not rebuild. Required additions:

1. **Overlay taxonomy** unified under one manager: `menu` (bottom sheet), `sheet` (draggable bottom sheet), `dialog` (centered, scale+fade), `fullscreen` (flow), `popover`, `toast`, `banner`. Map each to a token-driven z-index lane.
2. **Z-index ladder tokens** reconciled with `BASE_Z_INDEX`: dropdown < sticky < overlay/sheet < modal < popover < toast < banner.
3. **Registry-driven content** — populate `modal-registry.ts`; every overlay content component registered by `contentId`. Document the registration pattern so new flows reuse it.
4. **Transitions** — present/dismiss using motion tokens; frosted backdrop (`--surface-overlay` + blur); spring for sheets; respect reduced-motion.
5. **Stacking & priority** — keep `priority` (high closes low), `closeTopmost`, ESC + backdrop-tap to dismiss, focus trap (reka-ui), body-scroll lock, restore focus on close.
6. **Toast/Banner service** — a non-stacking ephemeral channel (auto-dismiss 4s like iOS ErrorBanner, optional retry/action), separate from the modal stack.
7. **Multi-step flows** — formalize `transitionContent` for wizards (enrollment flow) so a single overlay swaps inner content with a loading bar.

Deliver a short **"how to add an overlay"** recipe in the inventory doc.

---

## 9. Layouts & key page templates

Provide composable templates (each a layout + slots, reproducible as a Histoire page story). Minimum set, drawn from both apps:

1. **App shell** — sticky `PageHeader`, scrollable content, bottom `TabBar`, safe-area padding, optional FAB/Add.
2. **Auth** — phone entry, code verify, join-by-code (exists; tokenize).
3. **Home / dashboard** — KPI row + activity chart + heatmap + activity feed (parity with iOS MainHome).
4. **List screen** — search + filter chips + sectioned/searchable list + swipeable rows + infinite scroll (Groups/Members/Library).
5. **Detail screen** — header + metadata + tabbed sections + action menu (Group home, Member profile, Lesson/Event/Post detail).
6. **Library / grid** — filter dropdowns + card grid (Study/Video minis) + sort.
7. **Calendar** — split-month + day event list.
8. **Lesson player** — step sequence (video/youtube/read/exegesis/input/complete) + themed content + progress.
9. **Wizard / flow** — multi-step overlay (enrollment: select group → program → schedule → date → confirm).
10. **Editor** — content/activity editors (read/exegesis/input/video) with toolbars.
11. **Empty / error / loading** states for each template.
12. **Invite / share** — code + QR + copy-link + share-sheet + scope/role selector + "invite contacts" list (new for web; ports iOS GroupInvitePage / StudyInvitePage / ShareInviteSheet / InviteMenu).
13. **Accept invite landing** — shows inviter, scope (program vs single lesson), role; accept / decline.
14. **Shared-with-me browser** — list of content shared with the current user (grouped by program / lesson), selectable to open. **New to both apps.**
15. **Scoped (contributor) shell** — a permission-aware AppShell variant whose navigation and content are limited to the invite's scope.

Each template documents: required slots, which catalog components fill them, and the responsive behavior.

---

## 9A. Priority feature coverage (validation)

Two near-term features set the build priority. This section confirms the design system covers them. Detailed component rows are in `COMPONENT_INVENTORY.md` §11.

### Feature 1 — Group-leader experience, 100% iOS parity
**Coverage: sufficient, with editors emphasized.** The catalog (§7, inventory §1–8) covers the group-leader surface: home/KPIs, groups, members + requests, enrollment wizard, library, calendar, search, notifications, lesson player. The **highest-effort parity surface is the content editors** (iOS `ProgramHomePage` 66KB, `EditDay` 56KB, `EditReadActivityPage` 61KB, `EditExegesisActivityPage` 54KB, `EditUserInput/EditYouTube`). These depend on form components already listed (RichText/MarkdownEditor, BlockStyleEditor, MediaPicker, MenuInput, DatePickerField, FieldGroup) plus the Editor template (§9.10). **Action:** treat editor screens as a first-class template; verify the form catalog fully covers them during intake (`AUDIT_INTAKE.md` §K).

### Feature 2 — Scoped contributor invites + shared-content browser
**Coverage: required additions made (see inventory §11).** Audit findings:
- The **web client has almost no invite/share/QR UI** — only `invite-modal.scss` and `join-code-island`. iOS has the full set (`GroupInvitePage`, `StudyInvitePage`, `InviteQRCodeView`, `ShareInviteSheet`, `InviteMenu`, `InviteContactsPage`). These must be **built for web** (port from iOS) and added to the catalog.
- **Neither app has a "shared with me" content browser** or an accept-invite landing scoped to a program/lesson. These are **net-new screens** for both platforms.
- **No app exposes a scope/role selector** when inviting (member vs contributor; whole program vs single lesson). New component.
- The **contributor's UI must be limited to the invite scope** — requires a permission-aware AppShell variant (§9.15) that conditionally renders nav/tabs/content from a scope descriptor.

**New components/templates this feature requires** (now in inventory §11): InviteSheet, QRCodeDisplay, CopyLinkField, ShareButton (Web Share API), InviteScopeSelector, RoleSelector, InviteContactsList, AcceptInviteCard, SharedContentList + SharedContentCard, ScopedAppShell, ScopeBadge.

> **Backend dependency (flag, not design-system work):** the server today supports invite/accept-by-token and QR generation, but **does not** model scoped access to a single program or lesson (no `LessonAccess`/`ProgramAccess`, the "Contributor" role is org-scoped). Delivering Feature 2 needs backend additions. The design system should be built **data-driven against a scope descriptor** (`{ type: 'program'|'lesson', id, role, expiresAt }`) so UI is ready when the API lands. Captured in `AUDIT_INTAKE.md` §K.

This confirms the docs are sufficient to generate the components and views both features need, provided the §11 additions and the §K intake are completed.

---

## 10. PWA — app-like delivery

Use the [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest). Requirements:

- **`manifest.webmanifest`** served by Laravel and linked in the Blade `<head>`, with: `name`, `short_name`, `description`, `start_url`, `scope`, `display: "standalone"` (consider `display_override: ["standalone","minimal-ui"]`), `orientation: "portrait"`, `background_color`/`theme_color` set to the dark canvas (`#0d101a`), `icons` (192, 512, maskable), `id`, `lang`, `categories`, and optional `shortcuts` (e.g. Groups, Calendar, Add) and `share_target` if relevant.
- **Theme meta:** `<meta name="theme-color" content="#0d101a">`, `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, apple touch icons, and iOS splash screens.
- **Viewport:** `viewport-fit=cover` to enable safe-area insets; expose `env(safe-area-inset-*)` as tokens (§6.1).
- **Service worker:** app-shell caching for offline launch + static asset caching; network-first for API. Keep minimal; document scope.
- **Install affordance:** capture `beforeinstallprompt`, offer an in-app "Add to Home Screen" hint for group leaders.
- **Standalone polish:** no browser chrome assumptions; custom pull-to-refresh if needed; disable text-size auto-adjust; momentum scrolling; prevent overscroll bounce where it breaks layout.
- **Icon/splash assets:** define required sizes; generate from a single source mark. List needed assets in `AUDIT_INTAKE.md`.

---

## 11. Information to collect (gap intake) — make the catalog complete

The system is only "build any screen without new components" complete once these gaps are closed. The detailed worksheet is **[`AUDIT_INTAKE.md`](./AUDIT_INTAKE.md)**; it must be filled in during build. Categories:

1. **Token reconciliation** — final dark semantic mapping (web ramps vs iOS hex); confirm shadow/blur/motion/z-index values; decide breakpoint strategy beyond 360px.
2. **Full component census** — enumerate every UI element across both apps; mark each as: covered / extend existing / net-new. Produce the canonical variant matrix per component. (Goal: catalog ⊇ union of both apps.)
3. **Interaction inventory** — every gesture/transition (swipe-to-reveal, slide nav, pull-to-refresh, long-press, drag-reorder) with its spec, so behaviors are reusable.
4. **Content & data shapes** — the props/data each card/list/detail needs (e.g. CardStudy fields, DataComponent variants, badge states) so components are data-driven and reused, not forked.
5. **State coverage** — for each component: empty/loading/error/disabled/selected/pending designs. Skeletons for each list/card.
6. **Iconography** — full icon list used by both apps, mapped Lucide ↔ iOS asset names; flag missing icons.
7. **Copy/format rules** — date/number/pluralization formats, truncation rules, empty-state copy, so screens render consistently.
8. **Accessibility specs** — focus order, aria roles, contrast checks for dark theme, reduced-motion behaviors, min target sizes.
9. **PWA assets & metadata** — final manifest values, icon/splash sizes, offline scope, shortcuts.
10. **Navigation map** — the full route/screen graph for the group-leader web experience, so layouts cover every destination.

Closing these = the deliverable that lets future features be assembled, not invented.

---

## 12. Preview harness (Histoire)

Extend the existing Histoire config. Requirements:

- **Story per component** under the existing `storyGlob`; one `<Variant>` per meaningful state, organized by catalog category (`Primitives/…`, `Forms/…`, `Cards/…`, `Layouts/…`, `Overlays/…`, `Pages/…`).
- **Variant matrices** — render variants × sizes × states in grids for visual diffing (use Histoire `:layout` grid). Include hover/active/focus/disabled/loading/error.
- **Dark backdrop** — global Histoire background = canvas `#0d101a`; provide a device-frame wrapper (mobile width + safe-area) so components are tested at real sizes.
- **Interactive controls** — use Histoire `controls` for key props where it aids testing (e.g. Button variant/size, Badge tone).
- **Page & prototype stories** — compose layouts (§9) as page stories; wire modal/overlay stories that actually open from the store; build 2–3 clickable prototype flows (auth, enrollment wizard, lesson player) to test navigation.
- **Token reference stories** — a "Foundations" section rendering color/spacing/type/radius/shadow/motion tokens as living swatches.
- **Tokenization guard** — a check (script/story) that surfaces components using raw values.

---

## 13. Deliverables

1. Completed token layers (SCSS/CSS vars) incl. all missing categories — dark theme canonical.
2. Component library (Vue + SCSS) covering the full catalog with CVA variants and stories.
3. Layout/page templates for all key screens.
4. Unified overlay/modal + toast/banner system with registry + recipe.
5. PWA: manifest, service worker, head meta, install affordance, icon/splash assets.
6. Histoire harness: foundations, component matrices, page + prototype stories, tokenization guard.
7. Filled-in `AUDIT_INTAKE.md` (the closed-gap census).
8. `DESIGN_SYSTEM.md` usage/contribution guide (how to add a component/variant/overlay/page).

---

## 14. Roadmap (suggested phases)

- **Phase 0 — Foundations:** finalize tokens (all categories, dark mapping), motion/z-index/shadow/blur, safe-area + layout tokens, Histoire foundations + dark backdrop + device frame.
- **Phase 1 — Primitives & forms:** Button, Text, Icon, Avatar, Badge, Card base, all inputs; stories + matrices; tokenize existing CSS-only primitives.
- **Phase 2 — Layout & navigation:** AppShell, TabBar, PageHeader, Stack/Grid/FlowLayout, lists, slide navigation; template stories.
- **Phase 3 — Overlays:** extend modal store, sheets/dialogs/menus, toast/banner, wizard transitions, registry + recipe.
- **Phase 4 — Cards & data display:** type-specific cards (Row/Mini), swipeable rows, KPI, DataComponent, calendar, charts, skeletons.
- **Phase 5 — Domain parity:** group/member/enrollment/lesson/library/media/bible screens as composed templates.
- **Phase 6 — PWA:** manifest, SW, install, assets, standalone polish, Lighthouse pass.
- **Phase 7 — Hardening:** tokenization guard, a11y pass, parity sign-off (SC-6), build the SC-4 test screen.

Each phase is shippable and ends with passing stories.

---

## 15. Definition of done

- All §3 success criteria met.
- `AUDIT_INTAKE.md` fully filled; component census shows catalog ⊇ both apps.
- No raw values in design-system component SCSS (guard passes).
- Histoire renders every component (matrices), every key page, and the prototype flows on a dark device frame.
- PWA installs and launches offline-shell in standalone, dark.
- Parity sign-off on the 5 shared screens.

---

## 16. Conventions

- **Files:** Vue components in `resources/js/components/{primitive|form|layout|panel|navigation|overlay|feedback|data|domain}/<name>/<name>.vue` (+ `.story.vue`); SCSS in `resources/css/components/<category>/<name>.scss`.
- **Classes:** BEM-ish, block = PascalCase (`.CardStudy`), modifiers `--variant` / `--size-md` / `--is-loading`.
- **Variants:** CVA names match SCSS modifiers exactly.
- **Tokens:** `--<category>-<scale>`; semantic before primitive in component code.
- **Stories:** `Category/ComponentName`; one Variant per state; matrices via grid layout.
- **No** new CSS frameworks, no light-mode forks, no admin/PrimeVue coupling.
