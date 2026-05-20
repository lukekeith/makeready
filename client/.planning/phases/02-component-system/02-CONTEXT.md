# Phase 2: Component System - Context

**Gathered:** 2026-03-17
**Status:** Ready for replanning (architecture changed from Vue to Blade)

<domain>
## Phase Boundary

Migrate all ~60 React UI components to **Laravel Blade components** with identical SCSS/BEM styles and visual fidelity. Only components that genuinely require client-side JavaScript (video player, phone keypad, code entry, modal transitions) use Vue. Everything else is server-rendered Blade.

**Architecture change:** Originally planned as all-Vue SFCs. User decided Blade components are the correct approach for "all-in on Laravel" — client-side Vue is no different from the React SPA we're replacing.

</domain>

<decisions>
## Implementation Decisions

### Component Architecture (REVISED)
- **Default: Blade components** for all presentation-only components
- **Exception: Vue islands** only for components requiring client-side JS:
  - VideoPlayer (HLS.js requires JS)
  - PhoneEntry + KeyPad + Digit (real-time keypad input)
  - VerifyCode (code entry with auto-focus between digits)
  - Modal/ModalProvider (open/close transitions, Teleport)
  - BulletTextInput (contenteditable rich input)
- Blade components use `<x-component-name>` syntax with props and slots
- SCSS files copied as-is from archived React components — same BEM classes

### Blade Component Structure
- Components at `resources/views/components/` with same categories: `primitive/`, `domain/`, `layout/`, `panel/`
- Each component: `resources/views/components/primitive/button.blade.php` (flat, not in subfolders — Blade convention)
- SCSS co-located at `resources/css/components/` mirroring the structure
- Props via `@props` directive or component class

### CVA Equivalent for Blade
- PHP helper function or Blade component class that maps variant props to BEM CSS classes
- Same concept as React CVA: pass variant="primary" → outputs class "Button--primary"
- No need for the full CVA TypeScript library — simple PHP class mapping

### Vue Components (interactive only)
- Keep existing Vue infrastructure from Phase 2 Wave 1 (Pinia, Vite config, app.js)
- ~8 components remain as Vue SFCs at `resources/js/components/`
- Vue islands mount via data attributes in Blade templates
- Histoire stories only for Vue components

### Modal System
- Pinia modal store stays (already built) — modals need JS for open/close/transitions
- ModalProvider as Vue component with Teleport
- Modal content can be Blade-rendered HTML injected into Vue modal wrapper

### What to Keep from Phase 2 Vue Work
- Pinia modal store (`resources/js/stores/modal.store.ts`) ✓
- Vue app.js auto-mount script ✓
- Vite config for Vue + SCSS ✓
- Histoire config (for Vue-only components) ✓
- CVA TypeScript util (for Vue components only) ✓
- SCSS files (carry over to Blade components) ✓

### What to Remove/Replace
- ~50 Vue SFCs that are presentation-only → become Blade components
- ~50 Histoire stories for presentation components → removed (Blade doesn't need stories)
- Barrel export (index.ts) → not needed for Blade components

### Claude's Discretion
- PHP CVA helper implementation details
- Which Blade component pattern to use (anonymous vs class-based)
- How to handle Blade component slots vs React children
- SCSS import strategy for Blade components

</decisions>

<specifics>
## Specific Ideas

- "all-in on Laravel" — presentation components should be pure PHP/Blade, not JavaScript
- "Is vue the best way? ... components are typically done on the server-side" — user expects Laravel-native approach
- Visual fidelity paramount — every component must look identical, just rendered by PHP instead of JS
- SCSS files from the React app are the source of truth for styling
- The `archive/react-spa` branch has all original component code for reference
- The Phase 2 Vue components (on main branch) can also serve as reference for structure/props

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `archive/react-spa` branch: All ~60 React components with SCSS files
- Current main branch: Vue versions of all components (reference for prop interfaces)
- `resources/js/stores/modal.store.ts`: Pinia modal store (keep)
- `resources/js/util/cva.ts`: CVA wrapper (keep for Vue-only components)
- `resources/css/app.scss`: Global styles entry point

### Established Patterns (from Phase 1)
- Shared Blade layout at `resources/views/layouts/app.blade.php`
- Compliance pages prove the Blade + SCSS pattern works
- `@vite` directive loads compiled CSS

### Integration Points
- Blade components render inside Blade layouts via `<x-component-name>`
- Vue islands mount on specific elements for interactive features
- SCSS compiled by Vite, referenced via `@vite` in layout

### Components Needing Vue (interactive)
- VideoPlayer, PhoneEntry, KeyPad, Digit, VerifyCode, Modal, ModalProvider, BulletTextInput

### Components Becoming Blade (~50)
- All other primitives, domain, layout, and panel components

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-component-system*
*Context revised: 2026-03-17 — changed from all-Vue to Blade + Vue hybrid*
