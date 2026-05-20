---
phase: "02-component-system"
plan: "02-03"
subsystem: "domain-components"
tags: ["vue", "components", "domain", "migration", "scss", "histoire"]
dependency_graph:
  requires: ["02-01", "02-02"]
  provides: ["all-domain-components"]
  affects: ["page-layer"]
tech_stack:
  added: ["hls.js"]
  patterns:
    - "Vue 3 SFC with dual-script block for CVA type exports"
    - "Inline SVG icons replacing lucide-react and react-icons"
    - "Digit primitive keypad replacing Keypad panel"
    - "Modal primitive replacing Radix Dialog"
    - "v-if isMounted client-only guard for VideoPlayer"
    - "defineExpose for imperative VideoPlayer API"
    - "Dynamic import for hls.js to avoid SSR resolution issues"
    - "backdrop-filter blur preserved in Navigation (no z-index)"
key_files:
  created:
    - resources/js/components/domain/navigation/navigation.vue
    - resources/js/components/domain/navigation/navigation.scss
    - resources/js/components/domain/navigation-menu-content/navigation-menu-content.vue
    - resources/js/components/domain/navigation-menu-content/navigation-menu-content.scss
    - resources/js/components/domain/phone-entry/phone-entry.vue
    - resources/js/components/domain/phone-entry/phone-entry.scss
    - resources/js/components/domain/profile-form/profile-form.vue
    - resources/js/components/domain/profile-form/profile-form.scss
    - resources/js/components/domain/account-modal-content/account-modal-content.vue
    - resources/js/components/domain/account-modal-content/account-modal-content.scss
    - resources/js/components/domain/edit-profile-modal-content/edit-profile-modal-content.vue
    - resources/js/components/domain/edit-profile-modal-content/edit-profile-modal-content.scss
    - resources/js/components/domain/group-home/group-home.vue
    - resources/js/components/domain/group-home/group-home.scss
    - resources/js/components/domain/invite-modal/invite-modal.vue
    - resources/js/components/domain/invite-modal/invite-modal.scss
    - resources/js/components/domain/join-code-page/join-code-page.vue
    - resources/js/components/domain/join-code-page/join-code-page.scss
    - resources/js/components/domain/question-modal/question-modal.vue
    - resources/js/components/domain/question-modal/question-modal.scss
    - resources/js/components/domain/read-verse-modal/read-verse-modal.vue
    - resources/js/components/domain/read-verse-modal/read-verse-modal.scss
    - resources/js/components/domain/scripture-display/scripture-display.vue
    - resources/js/components/domain/scripture-display/scripture-display.scss
    - resources/js/components/domain/study-launcher/study-launcher.vue
    - resources/js/components/domain/study-launcher/study-launcher.scss
    - resources/js/components/domain/video-player/video-player.vue
    - resources/js/components/domain/video-player/video-player.scss
  modified:
    - package.json
decisions:
  - "Used inline Digit keypad grid in PhoneEntry instead of porting Keypad panel"
  - "VideoPlayer uses dynamic import('hls.js') wrapped in isMounted guard to prevent SSR resolution failure"
  - "Navigation backdrop-filter:blur(40px) preserved — no z-index on any child elements"
  - "GroupHome and StudyLauncher created from SCSS-only archive — no TSX source existed"
  - "InviteModal rewritten using Modal primitive (replaces Radix Dialog)"
  - "AccountModalContent inlines PageTitleIconTitle header pattern (panel not yet ported)"
  - "Story inline arrays moved to script setup refs to avoid Vue template single-quote parsing errors"
metrics:
  duration: "~4 hours (two-session continuation)"
  completed_date: "2026-03-17"
  tasks_completed: 2
  files_created: 87
---

# Phase 02 Plan 03: Domain Component Migration Summary

All 29 domain components from the React SPA successfully migrated to Vue 3 SFCs with SCSS and Histoire stories.

## Objective

Migrate all 29 domain components from `archive/react-spa` git branch to Vue SFCs. Each component required three files: `[name].vue`, `[name].scss`, and `[name].story.vue`.

## What Was Built

### Task 1: 16 Simpler/Medium Components (commit bd572bf)

- `account-link` — State-based (LinkGoogle/LinkedMember/LinkedGoogle/LinkMember), inline Google SVG and grid SVG replacing react-icons
- `event-card` — Date formatting helpers, CardDepth type, cover image
- `group-card` — Cover + gradient overlay, back button in Header mode, lock/unlock inline SVGs
- `group-home-header` — Group header with member count, gradient
- `group-leader-info` — Leader avatar and info display
- `group-leader-note` — Invite/Member mode, Avatar primitive
- `group-list-card` — Circular image, Users SVG, selected overlay with checkmark
- `group-post-card` — 5 PostType variants (WELCOME/POLL/VIDEO/EVENT/ANNOUNCEMENT), relative time, poll bars
- `invite-header` — Join invitation header
- `lesson-page-header` — Study lesson navigation header
- `member-card` — Member profile card
- `organization-card` — Organization display card
- `question-button` — Button to open question explanation
- `read-passage-button` — Button to open scripture passage
- `study-card` — 5 modes (Default/Lesson/Header/Progress/LessonList), section progress with checkmarks
- `study-schedule-card` — Day-of-week indicators, first/last date with month abbreviations

### Task 2: 14 Complex Components (commit baf2f8d)

- `navigation` — 5-button nav bar, Avatar for profile, backdrop-filter:blur(40px), NO z-index anywhere
- `navigation-menu-content` — Profile/Account/Terms/Privacy/Logout buttons with inline SVGs
- `phone-entry` — Inline 4x3 Digit keypad grid (1-9, *, 0, backspace), Button White submit
- `profile-form` — MobileInput/MobileSelect/MobileDate with v-model (`update:modelValue`) pattern
- `account-modal-content` — Multi-view (main/phone-entry/phone-verify/success), nested Modal confirmations for unlink/conflict
- `edit-profile-modal-content` — Avatar file upload, Google photo sync, sticky header with Cancel/Save
- `group-home` — Slot-based page layout (groupCard/studies/posts/leaderButtons/navigation), loading skeleton
- `invite-modal` — Reka UI via Modal primitive, QrCode display, copy link with check/copy SVG
- `join-code-page` — VerifyCode Alphanumeric (Light theme), Button White, Enter keydown handler
- `question-modal` — Modal Fullscreen wrapper, title + description
- `read-verse-modal` — Blocks and legacy verses support, v-html for text content blocks
- `scripture-display` — Inline verse layout with absolute-positioned verse numbers, size variants
- `study-launcher` — Slot-based (buttons/default), cover image hero header, back button
- `video-player` — HLS.js dynamic import, client-only guard (isMounted), defineExpose imperative API, volume slider, scrubber

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Functionality] Install hls.js dependency**
- **Found during:** Task 2, VideoPlayer
- **Issue:** `video-player.vue` uses dynamic `import('hls.js')` but the package was not installed, causing build failure
- **Fix:** Installed `hls.js` via npm
- **Files modified:** `package.json`, `package-lock.json`
- **Commit:** baf2f8d (included in task commit)

**2. [Rule 1 - Bug] Fix story inline array single-quote parsing**
- **Found during:** Task 2, `story:build`
- **Issue:** Vue template compiler cannot parse single-quoted strings inside multi-line `:verses="[...]"` double-quoted bindings
- **Fix:** Moved verse array data into `<script setup>` refs in `scripture-display.story.vue` and `read-verse-modal.story.vue`
- **Files modified:** Two story files
- **Commit:** baf2f8d (included in task commit)

**3. [Rule 3 - Blocking] Keypad panel not available**
- **Found during:** Task 2, PhoneEntry
- **Issue:** React PhoneEntry imported `Keypad` panel component which has not been ported to Vue
- **Fix:** Inlined a 4x3 Digit keypad grid directly in PhoneEntry using the existing `Digit` primitive
- **Commit:** baf2f8d

**4. [Rule 3 - Blocking] PageTitleIconTitle panel not available**
- **Found during:** Task 2, AccountModalContent and EditProfileModalContent
- **Issue:** React versions imported `PageTitleIconTitle` / `PageTitleIconTitleLink` panel components (not yet ported)
- **Fix:** Inlined equivalent header markup directly in each component
- **Commit:** baf2f8d

**5. [Rule 3 - Blocking] GroupHome and StudyLauncher have no TSX source**
- **Found during:** Task 2
- **Issue:** Both components exist only as `.scss` in `archive/react-spa` (no `.tsx`)
- **Fix:** Created Vue components from scratch using the SCSS structure as the design specification
- **Commit:** baf2f8d

**6. [Rule 3 - Blocking] InviteModal used Radix Dialog directly**
- **Found during:** Task 2
- **Issue:** React version used `@radix-ui/react-dialog` directly, not ported to Vue
- **Fix:** Rewrote using the `Modal` primitive (Reka UI based) already available in Vue component library
- **Commit:** baf2f8d

## Build Verification

- `npm run build`: PASSED (Vite production build, 210.71 kB JS, 565ms)
- `npm run story:build`: PASSED (54 stories, 213 variants, 2.69s)

## Self-Check: PASSED

All 29 domain components created with three files each (`.vue`, `.scss`, `.story.vue`).
Both `npm run build` and `npm run story:build` pass with zero errors.
