---
phase: 02-component-system
plan: 05
subsystem: ui
tags: [php, blade, cva, scss, vite, bem, phpunit, laravel]

# Dependency graph
requires:
  - phase: 02-component-system
    provides: All 60 Vue SFC SCSS files with correct BEM classes and @use 'styles/colors' paths

provides:
  - PHP cva() helper globally autoloaded via Composer for variant-to-BEM-class mapping in Blade templates
  - 60 SCSS files duplicated at resources/css/components/ for Blade SCSS pipeline (flat naming convention)
  - resources/css/app.scss wired with 60 @use imports covering all primitive/domain/layout/panel components
  - CvaHelperTest.php with 9 unit tests covering all cva() edge cases
  - ComponentSmokeTest.php with 4 tests confirming cva() works in Blade rendering context

affects: [02-06, all subsequent Blade component plans, any plan using <x-*> components]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PHP cva() helper: takes (base, config, selected) and returns space-separated BEM string"
    - "Composer autoload.files for global PHP helper functions without package dependency"
    - "Flat SCSS layout: resources/css/components/{category}/{name}.scss (no subfolder per component)"
    - "Central SCSS entry: all component styles flow through app.scss @use imports (no per-template SCSS)"
    - "Test route gated by app()->environment('testing') for smoke test Blade views"

key-files:
  created:
    - app/View/helpers.php
    - resources/css/components/primitive/ (22 SCSS files)
    - resources/css/components/domain/ (30 SCSS files)
    - resources/css/components/layout/ (3 SCSS files)
    - resources/css/components/panel/ (5 SCSS files)
    - resources/views/test/cva-test.blade.php
    - tests/Feature/CvaHelperTest.php
    - tests/Feature/ComponentSmokeTest.php
  modified:
    - composer.json (added autoload.files entry)
    - resources/css/app.scss (added 60 @use component imports)
    - routes/web.php (added testing-env test route)

key-decisions:
  - "SCSS copied (not moved) from js/components/ — Vue components still import their own SCSS; Blade SCSS flows through app.scss only"
  - "Test route gated by app()->environment('testing') to prevent exposure in production"
  - "ComponentSmokeTest uses HTTP route rather than $this->blade() to test the full Blade rendering pipeline including cva() global availability"

patterns-established:
  - "Pattern: cva('Block', ['variants' => [...], 'defaultVariants' => [...]], compact('variant', 'size')) in @php blocks"
  - "Pattern: All component SCSS @use imports grouped by category with comment headers in app.scss"
  - "Pattern: app/View/helpers.php is the single location for global PHP view helpers"

requirements-completed: [CSYS-01, CSYS-02, CSYS-03]

# Metrics
duration: 2min
completed: 2026-03-17
---

# Phase 2 Plan 05: PHP cva() Helper + SCSS Pipeline Summary

**PHP cva() helper autoloaded globally via Composer, all 60 component SCSS files wired into Vite via app.scss @use imports, 13 PHPUnit tests confirming correct BEM class output and Blade rendering**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-17T07:08:07Z
- **Completed:** 2026-03-17T07:10:31Z
- **Tasks:** 2
- **Files modified:** 68

## Accomplishments

- Created `app/View/helpers.php` with PHP cva() function — exact port of TypeScript CVA, handles variants, defaultVariants, unknown keys, and empty string class values
- Copied all 60 SCSS files from `resources/js/components/` to flat `resources/css/components/` layout; updated `app.scss` with 60 `@use` imports organized by category
- Established test scaffold: 9-test `CvaHelperTest` covering all edge cases + 4-test `ComponentSmokeTest` confirming cva() callable from Blade rendering pipeline; `npm run build` produces 104 kB CSS with all styles

## Task Commits

Each task was committed atomically:

1. **Task 1: PHP cva() helper + Composer autoload + unit tests** - `af37041` (feat)
2. **Task 2: Relocate SCSS, wire app.scss, ComponentSmokeTest** - `7ad0a5f` (feat)

**Plan metadata:** (created next)

## Files Created/Modified

- `app/View/helpers.php` - PHP cva() helper, globally autoloaded
- `composer.json` - Added autoload.files entry for helpers.php
- `resources/css/app.scss` - Added 60 @use component imports (primitive/domain/layout/panel)
- `resources/css/components/primitive/*.scss` (22 files) - Button, Avatar, Badge, Card, Digit, Icon, Input, Label, Loading, Modal, Toggle, VerifyCode, BulletTextInput, DateInput, EmptyState, GenderSelect, MobileDate, MobileInput, MobileSelect, QrCode, SocialButton, StepIndicator
- `resources/css/components/domain/*.scss` (30 files) - All domain components including Navigation, GroupCard, StudyCard, VideoPlayer, PhoneEntry, etc.
- `resources/css/components/layout/*.scss` (3 files) - Auth, Home, ModalProvider
- `resources/css/components/panel/*.scss` (5 files) - Confirmation, GroupInfoCard, Keypad, PageTitle, StudyInfoCard
- `resources/views/test/cva-test.blade.php` - Minimal Blade view for smoke testing cva() in render context
- `routes/web.php` - Added test route gated by testing environment
- `tests/Feature/CvaHelperTest.php` - 9 unit tests for PHP cva() function
- `tests/Feature/ComponentSmokeTest.php` - 4 smoke tests verifying cva() in Blade context

## Decisions Made

- SCSS files are **copied** (not moved) from `js/components/` — Vue components still import their own SCSS directly via `import './foo.scss'`; the `css/components/` copies exist solely for Blade's `app.scss @use` pipeline. Both pipelines work independently.
- ComponentSmokeTest uses an HTTP route request rather than `$this->blade()` because the latter requires the component to exist at `resources/views/components/` (Plan 06 work). The HTTP approach tests the full rendering pipeline including global function availability.
- Test route is gated by `app()->environment('testing')` so it never appears in production routing.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — all SCSS files already used `@use 'styles/colors'` (not relative paths), so no path adjustments were needed after copying. The Vite `loadPaths: ['resources/css']` already resolves this correctly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PHP cva() is globally available; any Blade component can call `cva('Block', [...])` in an `@php` block immediately
- All SCSS is wired into Vite — styling will appear as soon as Blade components render with correct BEM class names
- `tests/Feature/ComponentSmokeTest.php` is the scaffold that Plan 06 Blade component tests should extend (add `assertSee` checks for actual `<x-primitive.button>` renders)
- No blockers for Plan 06 (Blade primitive components)

---
*Phase: 02-component-system*
*Completed: 2026-03-17*
