# MakeReady Web Design System — Usage & Contribution Guide

The dark, iOS-parity component system for the MakeReady web client (`/client`,
Laravel 11 + Vue 3). This is the **how-to** companion to the
[PRD](./DESIGN_SYSTEM_PRD.md), [inventory](./COMPONENT_INVENTORY.md), and
[intake](./AUDIT_INTAKE.md).

> **Scope:** dark theme, member/group-leader surface only. Never touch the admin
> SPA (light, PrimeVue) or build a light-mode fork.

---

## 1. Architecture in one minute

- **Tokens are the contract.** Components consume **semantic** tokens
  (`--bg-*`, `--fg-*`, `--border-*`) and **structural** tokens (`--space-*`,
  `--radius-*`, `--text-*`, `--motion-*`, `--icon-*`, …) — never raw hex/px.
- **Three token layers** (`resources/css/styles/`):
  1. `_palette.scss` — primitive ramps (generated from Figma). Don't hand-edit.
  2. `_tokens.scss` — structural scales (spacing, type, radius, shadow, blur,
     z-index, motion, opacity, icon/avatar/layout/safe-area).
  3. `_semantic.scss` — the dark mapping (`--bg/--fg/--border/--badge`). `@use`'d
     **after** `_palette.scss` in `app.scss` so it wins the cascade. **Re-theming
     = editing this one file.**
- **Components emit BEM classes; SCSS lives in `resources/css/components/`** and
  is `@use`'d by `app.scss`. The Vue `.vue` does **not** import its `.scss`
  (styles are global). Histoire loads `app.scss` via `histoire.setup.ts`, so
  every story renders with real tokens on the `#0d101a` canvas.
- **CVA wrapper** (`resources/js/util/cva.ts`) gives enum-like variants. **CVA
  variant keys must match the SCSS modifier class names exactly.**
- **One overlay manager**: the Pinia `modal.store.ts` + `ModalProvider` +
  `modal-registry.ts`, plus the ephemeral `toast.store.ts` (toasts + banner).

---

## 2. File layout & conventions

```
resources/js/components/<category>/<name>/<name>.vue        # component
resources/js/components/<category>/<name>/<name>.story.vue  # Histoire story
resources/css/components/<category>/<name>.scss             # styles → @use in app.scss
```

Categories: `primitive`, `form`, `layout`, `navigation`, `overlay`, `card`,
`data`, `invite`. Stories live next to the component; page templates live in
`resources/js/pages/*.story.vue`.

- **Block** = PascalCase (`.CardStudy`); modifiers `--variant` / `--size-md` /
  `--is-loading`.
- **Story title** = `Category/ComponentName` (e.g. `Primitives/Button`,
  `Cards/CardStudy`, `Pages/Home Dashboard`).
- Util imports from a component are always `../../../util/cva` and
  `../../../util/classnames` (3 levels up).

---

## 3. Add a component

1. **Check the catalog first.** Favor a new *variant/prop/slot* on an existing
   component over a new component (PRD principle 2). A new component is a last
   resort.
2. Create the three files above. Copy `primitive/button/button.vue` as the
   canonical exemplar (dual `<script>`: a plain `<script lang="ts">` exporting
   `<Name>Cva`, then `<script setup>`).
3. **SCSS:** tokens only. Run `npm run guard` — it fails on raw hex/rgba and raw
   px in `padding`/`margin`/`gap`/`border-radius`. (Intrinsic structural
   dimensions like a 72×108 cover or an icon size are fine.)
4. **CVA keys == SCSS modifiers.** `Lead: 'Text--lead'` ⇒ `.Text--lead {}`.
5. Add `@use 'components/<category>/<name>';` to `app.scss` (keep the section
   lists alphabetical).
6. **Story:** one `<Variant>` per meaningful state — cover
   `default · hover · focus-visible · active · disabled · loading` and
   `error/success` for inputs. Use `:layout="{ type: 'grid', width: N }"` for
   matrices, `type: 'single'` for page-like stories.
7. Interactive components: `:focus-visible` ring (`--border-brand`), 44px min
   target (`--touch-min`), proper role/aria, and a `prefers-reduced-motion`
   path for any animation (the motion tokens already collapse under it).

## 4. Add a variant

Add the key to the component's CVA block **and** the matching `--modifier` rule
in its SCSS, then add a `<Variant>` to the story. Done — no new file.

## 5. Add an overlay

See the full recipe in [`COMPONENT_INVENTORY.md` §6](./COMPONENT_INVENTORY.md).
Short version:
- **Controlled** (local, self-contained): build it like `overlay/dialog` — reka-ui
  `DialogRoot` for focus-trap/scroll-lock/ESC, `v-model:open`, own frosted
  backdrop, `.mp-*` motion-token transitions.
- **Store-driven** (stacking/priority/wizards): make a content component that
  dismisses via `useModalStore().closeTopmost()`, register it in
  `modal-registry.ts`, open with `openMenu/openSheet/openDialog/openFullscreen/openPopover`.
- **Ephemeral**: `useToastStore().showToast(...)` / `.error(msg, retry)`.
- Mount **one** `<ModalProvider>` at the app root.

## 6. Add a page template

Compose **only** catalog components into a `resources/js/pages/<name>.story.vue`,
wrapped in `<DeviceFrame size="Md">` + (usually) `<AppShell>`. Title it
`Pages/<Name>`. If you find yourself writing real component markup instead of
composing, that's a signal a catalog component is missing — add it first. See
`pages/group-announcements.story.vue` (the SC-4 proof: a full screen with **0**
new components) for the pattern.

---

## 7. Checks before you ship

- `npm run guard` — tokenization guard passes (no raw values).
- `npm run story:dev` — your story renders on the dark device frame; variants
  cover all states.
- No `.scss` import inside the `.vue`; no edits to the admin layout or light mode.
- CVA keys match SCSS modifiers; `@use` line added to `app.scss`.

## 8. Gotchas

- **Charts** (`data/*-chart`) hardcode the palette hexes inside the `.vue` —
  ApexCharts paints SVG and can't read CSS custom properties. If a brand token
  changes, update those constants too.
- **`withDefaults` factory defaults** can't reference a `<script setup>` const
  (the SFC compiler hoists them) — inline the literal.
- **Badge/Icon** kept legacy modifier names for back-compat with existing Blade;
  see AUDIT_INTAKE §B.
- The legacy primitives (`digit`, `verify-code`, `mobile-*`, etc.) and `domain/*`
  cards predate this system and are allow-listed in the guard — migrate
  opportunistically.
