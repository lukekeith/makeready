---
phase: 02-component-system
plan: 01
subsystem: component-infrastructure
tags: [vue, cva, histoire, pinia, modal, scss, typescript]
dependency_graph:
  requires: [01-foundation-compliance]
  provides: [CVA wrapper, classnames util, Pinia modal store, ModalProvider, AuthLayout, HomeLayout, Button primitive, Histoire pipeline]
  affects: [all subsequent component plans, all page plans]
tech_stack:
  added:
    - class-variance-authority@0.7.1
    - reka-ui@2.9.2
    - pinia@3.0.4
    - lucide-vue-next@0.577.0
    - histoire@0.17.17
    - "@histoire/plugin-vue@0.17.17"
  patterns:
    - Vue SFC with dual <script> + <script setup> for named CVA exports
    - Pinia setup store (composition API style)
    - Vue Teleport for portal rendering (replaces createPortal)
    - BEM SCSS co-located with components (global, not scoped)
    - Sass loadPaths for cross-directory @use resolution
    - Histoire stories co-located alongside components
key_files:
  created:
    - resources/js/util/cva.ts
    - resources/js/util/classnames.ts
    - resources/js/util/index.ts
    - resources/js/stores/modal.store.ts
    - resources/js/modal-registry.ts
    - resources/js/components/layout/modal-provider/modal-provider.vue
    - resources/js/components/layout/modal-provider/modal-provider.scss
    - resources/js/components/layout/modal-provider/modal-provider.story.vue
    - resources/js/components/layout/auth/auth.vue
    - resources/js/components/layout/auth/auth.scss
    - resources/js/components/layout/auth/auth.story.vue
    - resources/js/components/layout/home/home.vue
    - resources/js/components/layout/home/home.scss
    - resources/js/components/layout/home/home.story.vue
    - resources/js/components/primitive/button/button.vue
    - resources/js/components/primitive/button/button.scss
    - resources/js/components/primitive/button/button.story.vue
    - histoire.config.ts
    - tsconfig.json
    - resources/css/styles/_colors.scss
    - resources/css/card-depth.scss
  modified:
    - package.json
    - vite.config.js
    - resources/js/app.js
    - resources/css/app.scss
decisions:
  - "histoire@0.17.17 pinned (not 1.0.0-beta.1) — beta requires Node 20.19+, environment has 20.18.1"
  - "histoire.config.ts uses includePaths + loadPaths for SCSS resolution (legacy + modern Sass APIs)"
  - "Button SCSS @use path changed from '@/styles/colors' to 'styles/colors' (loadPaths resolves from resources/css)"
  - "tsconfig.json added (Histoire 0.17 requires it for story collection)"
  - "ModalProvider uses custom SVG X icon instead of lucide-vue-next X (avoids import in layout component)"
  - "app.js uses data-vue attribute (not data-vue-component) per CONTEXT.md decision"
metrics:
  duration: "~45 min"
  completed: "2026-03-17"
  tasks_completed: 2
  files_created: 21
  files_modified: 4
---

# Phase 02 Plan 01: Component Infrastructure Summary

**One-liner:** CVA wrapper + Pinia modal store + Histoire pipeline with Button/AuthLayout/HomeLayout/ModalProvider ported from React archive to Vue 3 SFCs.

## What Was Built

Complete component system foundation enabling all subsequent migration plans:

1. **CVA wrapper** (`resources/js/util/cva.ts`) — Direct port of `archive/react-spa:util/cva.ts`. Identical API: `ButtonCva.variant.Primary` enum access, `ButtonCva.defaults?.variant`, `ButtonCva.variants({ ... })`. Pure TypeScript, no framework dependency.

2. **classnames utility** (`resources/js/util/classnames.ts`) — Direct port, filters falsy values and joins.

3. **Pinia modal store** (`resources/js/stores/modal.store.ts`) — Port of MobX ModalService. Full API preserved: `openMenu`, `openFullscreen`, `close`, `closeTopmost`, `transitionContent`, `closeAllByPriority`. Priority system (fullscreen auto-closes menus). Content transition with setTimeout.

4. **ModalProvider** (`modal-provider/modal-provider.vue`) — Renders modal stack via `<Teleport to="body">`. Escape key handler, body scroll lock, close buttons, loading bar for transitions. Content resolved from `modalRegistry`.

5. **Auth layout** (`layout/auth/auth.vue`) — Centered/Split/Minimal variants with BEM SCSS. Slots: default, emailForm, socialButtons.

6. **Home layout** (`layout/home/home.vue`) — Comfortable/Compact variants with BEM SCSS. Header with logo/title, user name, avatar slot, header-actions slot.

7. **Button primitive** (`primitive/button/button.vue`) — All 10 variants from archive (Primary, Secondary, Ghost, Outline, Destructive, Link, LinkMuted, White, Jump, JumpPrimary). Named export `ButtonCva` in `<script>` block for Histoire importability. Jump variants with label+description layout.

8. **Histoire pipeline** — `histoire.config.ts` + `histoire@0.17.17` + SCSS `includePaths`/`loadPaths` config. `npm run story:build` builds 4 stories, 20 variants successfully.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] histoire@1.0.0-beta.1 incompatible with Node 20.18.1**
- **Found during:** Task 1 — npm install pulled beta.1 which requires jsdom@27 → html-encoding-sniffer@6 → Node 20.19+
- **Issue:** `npm run story:build` failed with `ERR_REQUIRE_ESM` on html-encoding-sniffer
- **Fix:** Pinned `histoire@0.17.17` and `@histoire/plugin-vue@0.17.17` (stable release series). Had to edit root workspace package-lock.json to remove cached beta entries before npm would resolve correctly.
- **Commit:** b70d2cc (modified package.json)

**2. [Rule 3 - Blocking] tsconfig.json missing — Histoire requires it**
- **Found during:** Task 2 — `npm run story:build` errored with `TSConfckParseError: tsconfig.json not found`
- **Issue:** Laravel project had no tsconfig.json (not needed by Vite alone)
- **Fix:** Created `tsconfig.json` with `moduleResolution: bundler`, `jsx: preserve`, Vue-compatible settings
- **Commit:** b70d2cc

**3. [Rule 3 - Blocking] SCSS @use '@/styles/colors' alias not resolvable in Histoire workers**
- **Found during:** Task 2 — button.scss `@use '@/styles/colors'` failed in Histoire's separate Vite process
- **Issue:** Vite's `@` alias resolution doesn't apply to Sass `@use`. Histoire workers have their own Sass context.
- **Fix:** Changed `@use '@/styles/colors'` to `@use 'styles/colors'` in button.scss. Added `loadPaths` and `includePaths` to both `vite.config.js` and `histoire.config.ts` pointing to `resources/css`. Both legacy and modern Sass APIs require this.
- **Files modified:** button.scss, histoire.config.ts, vite.config.js

## Verification

- `npm run build`: PASS (67 modules, no TypeScript or SCSS errors)
- `npm run story:build`: PASS (4 stories, 20 variants built successfully)
- `ButtonCva.variant.Primary` returns `"Primary"` (enum access confirmed by TypeScript)
- `useModalStore()` exports `openMenu/openFullscreen/close/closeTopmost/transitionContent`
- ModalProvider uses `<Teleport to="body">` for portal rendering
- Histoire stories: Button (16 variants), AuthLayout (3), HomeLayout (3), ModalProvider (1)

## Self-Check: PASSED

All 11 key files verified present. Both task commits (b70d2cc, 0d862ef) confirmed in git log.
