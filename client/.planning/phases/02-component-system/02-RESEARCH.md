# Phase 2: Component System (REVISED — Blade + Vue Hybrid) - Research

**Researched:** 2026-03-17
**Domain:** Laravel Blade components, PHP CVA variant system, Blade+Vue coexistence
**Confidence:** HIGH — verified against Laravel 12.x official docs + live codebase inspection

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Default: Blade components** for all presentation-only components
- **Exception: Vue islands** only for components requiring client-side JS:
  - VideoPlayer (HLS.js requires JS)
  - PhoneEntry + KeyPad + Digit (real-time keypad input)
  - VerifyCode (code entry with auto-focus between digits)
  - Modal/ModalProvider (open/close transitions, Teleport)
  - BulletTextInput (contenteditable rich input)
- Blade components use `<x-component-name>` syntax with props and slots
- SCSS files copied as-is from archived React components — same BEM classes
- Components at `resources/views/components/` with same categories: `primitive/`, `domain/`, `layout/`, `panel/`
- Each component: `resources/views/components/primitive/button.blade.php` (flat, not in subfolders — Blade convention)
- SCSS co-located at `resources/css/components/` mirroring the structure
- Props via `@props` directive or component class
- PHP helper function or Blade component class that maps variant props to BEM CSS classes
- Same concept as React CVA: pass variant="primary" outputs class "Button--primary"
- Keep existing Vue infrastructure: Pinia, Vite config, app.js
- ~8 components remain as Vue SFCs at `resources/js/components/`
- Vue islands mount via data attributes in Blade templates
- Histoire stories only for Vue components
- Pinia modal store stays
- ModalProvider as Vue component with Teleport
- Remove ~50 Vue SFCs that are presentation-only
- Remove ~50 Histoire stories for presentation components
- Barrel export (index.ts) not needed for Blade components

### Claude's Discretion

- PHP CVA helper implementation details
- Which Blade component pattern to use (anonymous vs class-based)
- How to handle Blade component slots vs React children
- SCSS import strategy for Blade components

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CSYS-01 | Vue CVA wrapper ported from React custom wrapper with type-safe variant enums | Already complete on main — keep `resources/js/util/cva.ts`; this phase adds PHP equivalent |
| CSYS-02 | All existing SCSS/BEM component styles migrated to Laravel Vite pipeline | Already complete for Vue phase; this phase restructures SCSS imports for Blade (via `@use` in app.scss) |
| CSYS-03 | Histoire configured for Vue component development and preview | Already complete — keep as-is, only Vue components get stories |
| CSYS-04 | Modal service ported to Pinia store + Vue Teleport | Already complete on main — keep entirely, ModalProvider stays Vue |
| CSYS-05 | All primitive components migrated | 22 Vue primitives → ~14 become Blade, ~8 stay Vue (Digit, Modal, VerifyCode, BulletTextInput, and interactive ones) |
| CSYS-06 | All layout components migrated | 3 Vue layouts → Auth and Home become Blade, ModalProvider stays Vue |
| CSYS-07 | All domain components migrated | 29 Vue domain components → ~28 become Blade, PhoneEntry stays Vue |
| CSYS-08 | All panel components migrated | 5 Vue panel components → ~4 become Blade, Keypad stays Vue |
</phase_requirements>

---

## Summary

Phase 2 was originally executed as all-Vue SFCs. All 60 components exist on `main` as Vue files. The revised architecture converts ~52 of those to anonymous Blade components, retaining only ~8 as Vue islands for genuine client-side interactivity. The SCSS files are already in the Vite pipeline with correct `@use 'styles/colors'` paths — they can be imported into `app.scss` rather than being co-located with Blade templates.

The core technical pattern is: anonymous Blade components at `resources/views/components/{category}/{name}.blade.php` with `@props` for prop declaration, a PHP `cva()` helper function for variant-to-BEM-class mapping, and `$slot` / `$namedSlot` for content injection. The existing Vue components serve as the definitive spec for props, slots, and HTML structure — the Blade conversion is a mechanical translation of `<script setup>` + `<template>` into PHP/Blade.

**Primary recommendation:** Use anonymous Blade components (single `.blade.php` file, no PHP class) for all presentation components. Build a simple PHP `cva()` helper in `app/View/helpers.php` or as a Blade directive. Import all component SCSS centrally in `app.scss` via `@use` — do not attempt per-component SCSS loading from Blade templates.

---

## Standard Stack

### Core

| Library/Feature | Version | Purpose | Why Standard |
|-----------------|---------|---------|--------------|
| Laravel Blade anonymous components | 12.x | Server-rendered UI components | Official Laravel primitive, zero dependencies, full `@props` + slots system |
| `@props` directive | 12.x | Declare component props with defaults | Anonymous component data API; anything not in `@props` goes to `$attributes` bag |
| `$attributes->merge()` | 12.x | Pass-through HTML attributes + class merging | Allows callers to add classes without overriding BEM base classes |
| `$slot` / `$namedSlot` | 12.x | Content injection (replaces React `children` and named slots) | Direct equivalent of Vue `<slot name="x">` |
| PHP helper `cva()` | custom | Variant → BEM class mapping | ~30-line pure PHP function; no Composer package needed |
| Existing Vite SCSS pipeline | already configured | Compile component SCSS | `loadPaths: [resources/css]` already set; `@use 'styles/colors'` resolves |

### Supporting (Vue Islands — keep as-is)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Vue 3 | ^3.5.30 | Interactive components | Only for the ~8 components requiring JS |
| Pinia | ^3.0.4 | Modal store + join-flow state | Already complete; keep modal.store.ts |
| reka-ui | ^2.9.2 | Dialog primitives for Modal/ModalProvider | Already used in Modal.vue — keep |
| hls.js | ^1.6.15 | HLS video in VideoPlayer | Client-only; VideoPlayer stays Vue |
| Histoire | 0.17.17 | Component preview for Vue components only | Already configured; no change needed |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Anonymous Blade components | Class-based Blade components | Class-based adds a PHP file per component — overkill for purely presentational rendering with no computed logic |
| Custom PHP `cva()` helper | `feature-ninja/cva` Composer package | The Composer package has the right API but adds a dependency; a ~30-line custom function is sufficient for BEM string mapping |
| `@use` in app.scss | Per-component `@vite()` calls | Blade cannot auto-import per-component SCSS the way Vue SFCs do; all SCSS must flow through the single Vite entry point |
| Blast (Storybook for Blade) | No Blade previewing at all | Blast integrates Storybook Server with Blade but is a heavy addition; given that all complex interactive components remain in Histoire (Vue), skipping Blast is justified |

---

## Architecture Patterns

### Recommended Project Structure

```
resources/
├── views/
│   └── components/          # Blade components (NEW — flat per-category)
│       ├── primitive/
│       │   ├── button.blade.php
│       │   ├── avatar.blade.php
│       │   ├── icon.blade.php
│       │   └── ...
│       ├── domain/
│       │   ├── group-card.blade.php
│       │   ├── navigation.blade.php
│       │   └── ...
│       ├── layout/
│       │   ├── auth.blade.php
│       │   └── home.blade.php
│       └── panel/
│           ├── page-title.blade.php
│           ├── confirmation.blade.php
│           └── ...
├── css/
│   ├── app.scss             # Entry point — @use all component SCSS here
│   ├── styles/
│   │   └── _colors.scss     # Shared tokens (already exists)
│   └── components/          # Component SCSS files (NEW directory structure)
│       ├── primitive/
│       │   ├── button.scss
│       │   ├── avatar.scss
│       │   └── ...
│       ├── domain/
│       │   └── ...
│       ├── layout/
│       │   └── ...
│       └── panel/
│           └── ...
├── js/
│   ├── components/          # Vue components ONLY (~8 interactive)
│   │   ├── primitive/
│   │   │   ├── digit/       # KEEP as Vue
│   │   │   ├── modal/       # KEEP as Vue
│   │   │   ├── verify-code/ # KEEP as Vue
│   │   │   └── bullet-text-input/ # KEEP as Vue
│   │   ├── domain/
│   │   │   ├── phone-entry/ # KEEP as Vue
│   │   │   └── video-player/ # KEEP as Vue
│   │   ├── panel/
│   │   │   └── keypad/      # KEEP as Vue
│   │   └── layout/
│   │       └── modal-provider/ # KEEP as Vue
│   ├── stores/
│   │   └── modal.store.ts   # KEEP as-is
│   ├── util/
│   │   ├── cva.ts           # KEEP for Vue components
│   │   └── classnames.ts    # KEEP for Vue components
│   └── app.js               # KEEP — register only the ~8 Vue components
└── app/
    └── View/
        └── helpers.php      # NEW — PHP cva() helper function
```

### Pattern 1: Anonymous Blade Component with CVA-equivalent

**What:** Pure Blade `.blade.php` file with `@props`, a PHP `cva()` helper call, and BEM class output
**When to use:** Any component that has no event handlers, reactive state, or DOM APIs

```php
{{-- resources/views/components/primitive/button.blade.php --}}
@props([
    'variant' => 'Primary',
    'size'    => 'Default',
    'mode'    => 'Action',
    'label'   => null,
    'loading' => false,
    'disabled' => false,
    'type'    => 'button',
])

@php
    $classes = cva('Button', [
        'variants' => [
            'variant' => [
                'Primary'     => 'Button--primary',
                'Secondary'   => 'Button--secondary',
                'Destructive' => 'Button--destructive',
                'Outline'     => 'Button--outline',
                'Ghost'       => 'Button--ghost',
                'Link'        => 'Button--link',
                'White'       => 'Button--white',
            ],
            'size' => [
                'Default' => 'Button--size-default',
                'Sm'      => 'Button--size-sm',
                'Lg'      => 'Button--size-lg',
                'Icon'    => 'Button--size-icon',
            ],
            'mode' => [
                'Action' => 'Button--mode-action',
                'Block'  => 'Button--mode-block',
            ],
        ],
    ], ['variant' => $variant, 'size' => $size, 'mode' => $mode]);

    $classes .= $loading ? ' Button--loading' : '';
@endphp

<button
    type="{{ $type }}"
    {{ $attributes->merge(['class' => $classes]) }}
    @if($disabled || $loading) disabled @endif
>
    <span class="Button__content">
        {{ $slot }}
        @if($label) {{ $label }} @endif
    </span>
    @if($loading)
        <span class="Button__spinner" aria-hidden="true">
            {{-- spinner SVG --}}
        </span>
    @endif
</button>
```

**Usage in Blade pages/layouts:**
```blade
<x-primitive.button variant="Primary" size="Default">Join Group</x-primitive.button>
<x-primitive.button variant="Secondary" :loading="true">Saving...</x-primitive.button>
```

### Pattern 2: PHP `cva()` Helper Function

**What:** Pure PHP function mirroring the TypeScript CVA API — takes base class, variant map, and selected variants; returns BEM class string
**When to use:** Called inside `@php` blocks in every Blade component that has variants

```php
<?php
// app/View/helpers.php
// Autoloaded via composer.json "autoload" > "files"

if (!function_exists('cva')) {
    /**
     * Class Variance Authority — PHP port
     * Maps variant key/value pairs to BEM CSS class strings.
     *
     * @param string $base       Base BEM block class (e.g. 'Button')
     * @param array  $config     ['variants' => ['variant' => ['Primary' => 'Button--primary']]]
     * @param array  $selected   ['variant' => 'Primary', 'size' => 'Default']
     * @return string            Space-separated class string
     */
    function cva(string $base, array $config, array $selected = []): string
    {
        $classes = [$base];
        $variants = $config['variants'] ?? [];

        foreach ($variants as $key => $map) {
            $value = $selected[$key] ?? ($config['defaultVariants'][$key] ?? null);
            if ($value !== null && isset($map[$value]) && $map[$value] !== '') {
                $classes[] = $map[$value];
            }
        }

        return implode(' ', array_filter($classes));
    }
}
```

**Register in composer.json:**
```json
"autoload": {
    "files": ["app/View/helpers.php"],
    "psr-4": { "App\\": "app/" }
}
```
Run `composer dump-autoload` after adding.

### Pattern 3: Named Slots (React children → Blade slots)

**What:** Blade `$slot` is the default slot (maps to `children` in React/Vue `<slot />`). Named slots map to Vue's `<slot name="x">`.

**Component definition:**
```php
{{-- resources/views/components/panel/page-title.blade.php --}}
@props([
    'title'    => null,
    'leftLink' => null,
    'rightLink' => null,
    ...
])

<div {{ $attributes->merge(['class' => 'PageTitle']) }}>
    <div class="PageTitle__container">
        <div class="PageTitle__left">
            @if(isset($leftIcon))
                <button class="PageTitle__icon-button" type="button">
                    {{ $leftIcon }}
                </button>
            @elseif($leftLink)
                <button class="PageTitle__link-button" type="button">{{ $leftLink }}</button>
            @endif
        </div>
        @if($title)
            <div class="PageTitle__center">
                <span class="PageTitle__title">{{ $title }}</span>
            </div>
        @endif
        <div class="PageTitle__right">
            @if(!$slot->isEmpty())
                {{ $slot }}
            @elseif($rightLink)
                <button class="PageTitle__link-button" type="button">{{ $rightLink }}</button>
            @endif
        </div>
    </div>
</div>
```

**Usage with named slots:**
```blade
<x-panel.page-title title="Group Details" left-link="Cancel">
    <x-slot:left-icon>
        <svg>...</svg>
    </x-slot>
</x-panel.page-title>
```

### Pattern 4: Vue Island Coexistence

**What:** The ~8 Vue components remain at `resources/js/components/` and are registered in `app.js`. Blade pages embed them via `data-vue` attributes.

**app.js (update — register only interactive components):**
```javascript
import PhoneEntry from './components/domain/phone-entry/phone-entry.vue'
import KeyPad from './components/panel/keypad/keypad.vue'
import Digit from './components/primitive/digit/digit.vue'
import VerifyCode from './components/primitive/verify-code/verify-code.vue'
import Modal from './components/primitive/modal/modal.vue'
import ModalProvider from './components/layout/modal-provider/modal-provider.vue'
import BulletTextInput from './components/primitive/bullet-text-input/bullet-text-input.vue'
import VideoPlayer from './components/domain/video-player/video-player.vue'

const componentRegistry = {
  'PhoneEntry': PhoneEntry,
  'KeyPad': KeyPad,
  // ... etc
}
```

**Blade page embedding a Vue island:**
```blade
{{-- Phone entry island in a join-flow Blade page --}}
<div
    data-vue="PhoneEntry"
    data-props='{"title":"Enter your phone number","buttonLabel":"Continue"}'
></div>
```

**Important:** Props passed via `data-props` must be JSON-serializable. No callbacks/functions — Vue components must handle their own events internally or via Pinia store.

### Anti-Patterns to Avoid

- **Importing SCSS inside Blade files:** Blade has no `import './button.scss'` equivalent. All SCSS must flow through the Vite entry point (`resources/css/app.scss`). Use `@use 'components/primitive/button'` in app.scss.
- **Using class-based Blade components for pure presentation:** Adding a PHP class for every component doubles file count with no benefit. Reserve class-based components for cases requiring PHP logic (date formatting, collection filtering).
- **Passing PHP closures/functions as Blade component props:** Blade props are strings, booleans, and arrays. Callbacks are not possible — any "onClick" behavior must become a form action, link href, or be handled by a Vue island.
- **Trying to animate Blade components with CSS transitions on mount:** Server-rendered HTML has no JS lifecycle. CSS-only entry animations are fine; anything requiring JavaScript state should stay Vue.
- **Nested `<x-` calls inside Vue template strings:** Don't compose Blade components from within Vue component templates. Vue islands should be self-contained.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Variant-to-class mapping | Custom array_map loops inline | PHP `cva()` helper | Centralizes variant logic; matches the mental model already established in Vue/TypeScript CVA |
| BEM class string building | String concatenation | `cva()` + `$attributes->merge(['class' => ...])` | `$attributes->merge` handles both default and caller-passed classes correctly without overwriting |
| Slot content checking | `isset($mySlot)` everywhere | `$slot->isEmpty()` and `isset($namedSlot)` | Laravel provides slot object with isEmpty() — more idiomatic |
| Dialog/overlay for Vue modals | Custom Blade overlay | Existing Pinia modal store + ModalProvider Vue component | Already fully built on main; zero work needed |
| SVG icon management | Separate icon component | Inline SVG in components or a `<x-icon name="..." />` Blade component | SVGs are already inlined in Vue components; copy them inline to Blade or create a single lookup Blade component |

**Key insight:** The primary complexity in this phase is volume (52 conversions), not difficulty. Each conversion is mechanical: copy the Vue `<template>`, translate `v-if` to `@if`, `v-for` to `@foreach`, `:class="..."` to inline PHP, and `{{ var }}` to `{{ $var }}`.

---

## Common Pitfalls

### Pitfall 1: SCSS Not Loading for Blade Components

**What goes wrong:** Blade components render correctly but have no styles because their SCSS was never imported.
**Why it happens:** Vue SFCs imported SCSS inline with `import './button.scss'`. Blade has no such mechanism — if SCSS isn't in the Vite entry graph, it doesn't compile.
**How to avoid:** Maintain a `resources/css/components/` directory mirroring the component structure. Add `@use 'components/primitive/button'` etc. to `app.scss`. All SCSS flows through the single Vite entry.
**Warning signs:** Components render as plain HTML with correct classes but missing visual styling; opening DevTools shows no CSS rules for the BEM class.

### Pitfall 2: `@props` Doesn't Recognize kebab-case Prop Names

**What goes wrong:** `@props(['leftLink' => null])` but caller passes `left-link="..."` — prop is not received.
**Why it happens:** Laravel auto-converts kebab-case HTML attributes to camelCase PHP variables in `@props`. `left-link` → `$leftLink`. This works correctly, but must be accounted for consistently.
**How to avoid:** Always declare props in camelCase inside `@props`. Always pass them as kebab-case in HTML. Test both directions.
**Warning signs:** Prop appears `null` even when passed; check the attribute name casing.

### Pitfall 3: `$attributes` Bag Includes Unexpected Attributes

**What goes wrong:** Caller passes `class="extra-class"` and it appears as a standalone attribute rather than merged with BEM classes.
**Why it happens:** `$attributes->merge(['class' => 'Button Button--primary'])` correctly appends caller classes, but if you echo `{{ $attributes }}` without merge, it replaces instead.
**How to avoid:** Always use `$attributes->merge(['class' => $computedClasses])` on the root element. Never do `class="{{ $computedClasses }}"` because it drops any caller-passed class.
**Warning signs:** Caller-applied utility classes or modifier overrides don't appear in the rendered HTML.

### Pitfall 4: Vue Island Props Must Be JSON-serializable

**What goes wrong:** Passing a PHP `Carbon` date object, Eloquent model, or closure as `data-props` causes a JSON encode error or passes `null`.
**Why it happens:** `data-props` is a JSON string in the HTML attribute. PHP objects are not JSON-serializable by default.
**How to avoid:** In Blade pages, serialize data before passing to Vue: `data-props='{{ json_encode(["memberSince" => $member["memberSince"]]) }}'`. Format dates as ISO strings. Pass only primitives and arrays.
**Warning signs:** Vue component logs "undefined" for props in the console; PHP throws `JsonException`.

### Pitfall 5: Removing Vue Files That Are Still Needed

**What goes wrong:** Deleting all Vue SFCs when converting to Blade accidentally removes one of the ~8 interactive components.
**Why it happens:** The list of components to keep is easy to misread; file deletion is irreversible (without git).
**How to avoid:** Delete Vue files only after confirming the Blade replacement is in place AND the component is not in the interactive keep-list. Use git to stage deletions separately from additions.
**Warning signs:** App.js throws import errors; `data-vue="PhoneEntry"` mounts with a console warning "No component registered".

### Pitfall 6: Composer Autoload Not Updated After Adding helpers.php

**What goes wrong:** `Call to undefined function cva()` in Blade templates.
**Why it happens:** PHP doesn't automatically discover new files in `autoload.files`. The autoloader cache must be regenerated.
**How to avoid:** Run `composer dump-autoload` after adding `helpers.php` to `composer.json` autoload files array.
**Warning signs:** `cva()` undefined error on first page load after adding the helper.

---

## Code Examples

### Blade Button Component (full example)

```php
{{-- Source: Laravel 12.x Blade docs + Vue Button.vue on main branch --}}
{{-- resources/views/components/primitive/button.blade.php --}}

@props([
    'variant'  => 'Primary',
    'size'     => 'Default',
    'mode'     => 'Action',
    'loading'  => false,
    'disabled' => false,
    'type'     => 'button',
])

@php
    $baseClasses = cva('Button', [
        'variants' => [
            'variant' => [
                'Primary'     => 'Button--primary',
                'Secondary'   => 'Button--secondary',
                'Destructive' => 'Button--destructive',
                'Outline'     => 'Button--outline',
                'Ghost'       => 'Button--ghost',
                'Link'        => 'Button--link',
                'LinkMuted'   => 'Button--link-muted',
                'White'       => 'Button--white',
                'Jump'        => 'Button--jump',
                'JumpPrimary' => 'Button--jump-primary',
            ],
            'size' => [
                'Default' => 'Button--size-default',
                'Sm'      => 'Button--size-sm',
                'Lg'      => 'Button--size-lg',
                'Icon'    => 'Button--size-icon',
            ],
            'mode' => [
                'Action' => 'Button--mode-action',
                'Block'  => 'Button--mode-block',
            ],
        ],
    ], compact('variant', 'size', 'mode'));

    if ($loading) $baseClasses .= ' Button--loading';
@endphp

<button
    type="{{ $type }}"
    {{ $attributes->merge(['class' => $baseClasses]) }}
    @disabled($disabled || $loading)
>
    <span class="Button__content">{{ $slot }}</span>
    @if($loading)
        <span class="Button__spinner" aria-hidden="true">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
            </svg>
        </span>
    @endif
</button>
```

### Blade Avatar Component (reka-ui → native HTML)

```php
{{-- Source: Avatar.vue on main branch + MDN img fallback pattern --}}
{{-- resources/views/components/primitive/avatar.blade.php --}}

@props([
    'src'      => null,
    'alt'      => 'Avatar',
    'fallback' => '?',
])

<span {{ $attributes->merge(['class' => 'Avatar']) }}>
    @if($src)
        <img class="Avatar__image" src="{{ $src }}" alt="{{ $alt }}"
             onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'">
        <span class="Avatar__fallback" style="display:none">{{ $fallback }}</span>
    @else
        <span class="Avatar__fallback">{{ $fallback }}</span>
    @endif
</span>
```

Note: reka-ui's `AvatarRoot/AvatarImage/AvatarFallback` logic is replaced by a simple `onerror` fallback. Same visual result, zero JS dependency.

### SCSS Import Strategy (app.scss additions)

```scss
// resources/css/app.scss
// @use rules must come first
@use 'compliance';
@use 'card-depth';

// Primitive components
@use 'components/primitive/button';
@use 'components/primitive/avatar';
@use 'components/primitive/badge';
@use 'components/primitive/card';
@use 'components/primitive/icon';
@use 'components/primitive/input';
@use 'components/primitive/label';
@use 'components/primitive/loading';
@use 'components/primitive/step-indicator';
@use 'components/primitive/toggle';
// ... (interactive Vue components: digit, modal, verify-code, bullet-text-input — still @used here)
@use 'components/primitive/digit';
@use 'components/primitive/modal';
@use 'components/primitive/verify-code';

// Domain components
@use 'components/domain/group-card';
@use 'components/domain/navigation';
// ... all ~28 domain Blade components

// Layout components
@use 'components/layout/auth';
@use 'components/layout/home';
@use 'components/layout/modal-provider';

// Panel components
@use 'components/panel/page-title';
// ...

// Global styles below @use blocks
* { box-sizing: border-box; ... }
```

**Note:** SCSS files move from `resources/js/components/**/*.scss` to `resources/css/components/**/*.scss`. The `loadPaths` in `vite.config.js` already includes `resources/css`, so `@use 'styles/colors'` inside component SCSS continues to resolve correctly.

### PHP cva() Helper (complete implementation)

```php
<?php
// app/View/helpers.php

if (!function_exists('cva')) {
    /**
     * Class Variance Authority — PHP port for Blade components
     *
     * @param string $base      Base BEM block class (e.g. 'Button')
     * @param array  $config    {
     *     variants: array<string, array<string, string>>,
     *     defaultVariants?: array<string, string>
     * }
     * @param array  $selected  Variant key => value pairs from @props
     * @return string           Space-separated CSS class string
     */
    function cva(string $base, array $config, array $selected = []): string
    {
        $classes = [$base];
        $variants = $config['variants'] ?? [];
        $defaults = $config['defaultVariants'] ?? [];

        foreach ($variants as $key => $map) {
            $value = $selected[$key] ?? ($defaults[$key] ?? null);
            if ($value !== null && isset($map[$value]) && $map[$value] !== '') {
                $classes[] = $map[$value];
            }
        }

        return implode(' ', array_filter($classes));
    }
}
```

**composer.json addition:**
```json
"autoload": {
    "files": [
        "app/View/helpers.php"
    ],
    "psr-4": {
        "App\\": "app/"
    }
}
```

---

## Component Conversion Map

The following table maps each existing Vue SFC to its Phase 2 REVISED disposition:

### Primitives (22 Vue → ~14 Blade + ~8 Vue kept)

| Component | Vue File | Disposition | Notes |
|-----------|----------|-------------|-------|
| Avatar | `primitive/avatar/avatar.vue` | **→ Blade** | reka-ui AvatarRoot → img with onerror fallback |
| Badge | `primitive/badge/badge.vue` | **→ Blade** | Simple span with variant class |
| BulletTextInput | `primitive/bullet-text-input/bullet-text-input.vue` | **KEEP Vue** | contenteditable — requires JS |
| Button | `primitive/button/button.vue` | **→ Blade** | Full CVA variant mapping |
| Card | `primitive/card/card.vue` | **→ Blade** | Presentational wrapper |
| DateInput | `primitive/date-input/date-input.vue` | **→ Blade** | Native date input; form submit handles value |
| Digit | `primitive/digit/digit.vue` | **KEEP Vue** | Part of PhoneEntry interactive island |
| EmptyState | `primitive/empty-state/empty-state.vue` | **→ Blade** | Static presentational |
| GenderSelect | `primitive/gender-select/gender-select.vue` | **→ Blade** | Native select element |
| Icon | `primitive/icon/icon.vue` | **→ Blade** | span wrapper with size variant |
| Input | `primitive/input/input.vue` | **→ Blade** | Native input; label prop |
| Label | `primitive/label/label.vue` | **→ Blade** | HTML label element |
| Loading | `primitive/loading/loading.vue` | **→ Blade** | CSS spinner (no JS state) |
| MobileDate | `primitive/mobile-date/mobile-date.vue` | **→ Blade** | Native date input variant |
| MobileInput | `primitive/mobile-input/mobile-input.vue` | **→ Blade** | Native input variant |
| MobileSelect | `primitive/mobile-select/mobile-select.vue` | **→ Blade** | Native select variant |
| Modal | `primitive/modal/modal.vue` | **KEEP Vue** | DialogRoot (reka-ui) + JS open/close |
| QrCode | `primitive/qr-code/qr-code.vue` | **→ Blade** | Static img display |
| SocialButton | `primitive/social-button/social-button.vue` | **→ Blade** | Button with inline SVG logo |
| StepIndicator | `primitive/step-indicator/step-indicator.vue` | **→ Blade** | Server provides currentStep as prop |
| Toggle | `primitive/toggle/toggle.vue` | **→ Blade** | Checkbox input styled as toggle |
| VerifyCode | `primitive/verify-code/verify-code.vue` | **KEEP Vue** | Auto-focus between digits — requires JS |

### Domain Components (29 Vue → ~28 Blade + PhoneEntry Vue)

| Component | Disposition | Notes |
|-----------|-------------|-------|
| AccountLink | **→ Blade** | Anchor with avatar |
| AccountModalContent | **→ Blade** | Modal content panel (rendered by Vue ModalProvider) |
| EditProfileModalContent | **→ Blade** | Modal content panel |
| EventCard | **→ Blade** | Card with date/title props |
| GroupCard | **→ Blade** | Cover image, member count — all presentational |
| GroupHome | **→ Blade** | Layout component for groups page |
| GroupHomeHeader | **→ Blade** | Header section |
| GroupLeaderInfo | **→ Blade** | Leader name/avatar |
| GroupLeaderNote | **→ Blade** | Text block |
| GroupListCard | **→ Blade** | List variant of GroupCard |
| GroupPostCard | **→ Blade** | Post/announcement card |
| InviteHeader | **→ Blade** | Invitation header |
| InviteModal | **→ Blade** | Modal content panel |
| JoinCodePage | **→ Blade** | Layout for join flow step |
| LessonPageHeader | **→ Blade** | Lesson header |
| MemberCard | **→ Blade** | Member avatar + name |
| Navigation | **→ Blade** | Server renders selected state; no JS nav needed for SSR |
| NavigationMenuContent | **→ Blade** | Menu content panel |
| OrganizationCard | **→ Blade** | Organization details card |
| PhoneEntry | **KEEP Vue** | Keypad with digit input + real-time formatting |
| ProfileForm | **→ Blade** | Form fields; submit via POST or Vue island |
| QuestionButton | **→ Blade** | Button with question styling |
| QuestionModal | **→ Blade** | Modal content panel |
| ReadPassageButton | **→ Blade** | Bible passage link button |
| ReadVerseModal | **→ Blade** | Modal content panel |
| ScriptureDisplay | **→ Blade** | Scripture text block |
| StudyCard | **→ Blade** | Study title/cover card |
| StudyLauncher | **→ Blade** | CTA panel for starting study |
| StudyScheduleCard | **→ Blade** | Schedule entry card |
| VideoPlayer | **KEEP Vue** | HLS.js dynamic import — requires JS |

### Layout Components (3 Vue → 2 Blade + ModalProvider Vue)

| Component | Disposition | Notes |
|-----------|-------------|-------|
| Auth | **→ Blade** | AuthLayout wrapper — no JS needed |
| Home | **→ Blade** | HomeLayout wrapper — no JS needed |
| ModalProvider | **KEEP Vue** | Teleport + Pinia store — requires JS |

### Panel Components (5 Vue → 4 Blade + Keypad Vue)

| Component | Disposition | Notes |
|-----------|-------------|-------|
| Confirmation | **→ Blade** | Join flow confirmation panel |
| GroupInfoCard | **→ Blade** | Info display card |
| Keypad | **KEEP Vue** | Embedded in PhoneEntry as Vue |
| PageTitle | **→ Blade** | Named slots for left/right icons |
| StudyInfoCard | **→ Blade** | Study details card |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All-Vue SFCs (Phase 2 Wave 1) | Blade for presentation, Vue for interactivity | 2026-03-17 (architecture revision) | ~52 Vue files become Blade; SCSS moves from js/ to css/ |
| reka-ui `AvatarRoot` in Avatar | Native HTML `<img>` with onerror fallback | This phase | No JS dependency; simpler markup |
| `import './button.scss'` in Vue SFCs | `@use 'components/primitive/button'` in app.scss | This phase | All SCSS flows through single Vite entry |
| Histoire stories for all ~60 components | Histoire stories only for ~8 Vue interactive components | This phase | ~52 story files removed; Blade components have no story tooling (acceptable) |

**Deprecated/outdated:**
- `resources/js/components/primitive/button/button.vue` and all other ~52 Vue SFCs slated for Blade conversion: removed in this phase
- `resources/js/components/index.ts` barrel export: removed (no equivalent needed for Blade)
- `resources/js/components/**/*.story.vue` for presentation components: removed

---

## Open Questions

1. **Navigation component — active state without JavaScript**
   - What we know: The Vue Navigation.vue receives a `selected: NavItem` prop and highlights the active tab. In Blade, the controller can pass the current route segment as a variable.
   - What's unclear: Does the Navigation Blade component need a `selected` prop passed from each controller, or can it use Laravel's `Request::routeIs()` / `Route::currentRouteName()` directly inside the Blade file?
   - Recommendation: Use `Request::routeIs('home.*')` etc. directly in the Blade component via `@php`. No prop needed. Verify the route naming convention in `routes/web.php`.

2. **Modal content components (AccountModalContent, InviteModal, etc.) as Blade**
   - What we know: ModalProvider is Vue and uses `modalRegistry` which maps `contentId` strings to Vue components. If modal content becomes Blade, it can't be referenced in the Vue registry.
   - What's unclear: How modal content components work when the container is Vue but the content is Blade HTML.
   - Recommendation: Modal content components that become Blade should be fetched via an AJAX route or embedded as hidden Blade partials that Vue's ModalProvider reveals. Alternatively, keep modal content components as Vue (they are thin wrappers). Investigate in Wave 1 — the planner should flag these as "needs spike."

3. **StepIndicator animation state**
   - What we know: The Vue StepIndicator has a `watch` on `completedSteps` that triggers a 600ms animation class. This reactive behavior is not possible in Blade.
   - What's unclear: Whether the animation is critical to the UX or just a nice-to-have.
   - Recommendation: Blade version renders static step state (active/complete classes based on server props). CSS transition remains on `.StepIndicator__step--complete` entry — no animation on change. Accept this as a minor UX delta from the "no new features" constraint.

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from `.planning/config.json` — treating as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (via Laravel's test suite) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test --filter ComponentTest` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CSYS-01 | CVA TypeScript wrapper preserved for Vue | unit | N/A — TypeScript; validated by Histoire story render | ✅ (kept) |
| CSYS-02 | All SCSS loads; no missing styles | smoke | `php artisan test --filter ComponentSmokeTest` | ❌ Wave 0 |
| CSYS-03 | Histoire runs for Vue components | manual | `npm run story:dev` — visual check | ✅ (kept) |
| CSYS-04 | Modal service opens/closes via Pinia | manual | Histoire story for ModalProvider | ✅ (kept) |
| CSYS-05 | All primitive Blade components render | smoke | `php artisan test --filter PrimitiveComponentTest` | ❌ Wave 0 |
| CSYS-06 | All layout Blade components render | smoke | `php artisan test --filter LayoutComponentTest` | ❌ Wave 0 |
| CSYS-07 | All domain Blade components render | smoke | `php artisan test --filter DomainComponentTest` | ❌ Wave 0 |
| CSYS-08 | All panel Blade components render | smoke | `php artisan test --filter PanelComponentTest` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `php artisan test --filter ComponentSmokeTest`
- **Per wave merge:** `php artisan test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/Feature/ComponentSmokeTest.php` — renders each Blade component in a test view; asserts HTTP 200 and key BEM classes present in output
- [ ] `tests/Feature/CvaHelperTest.php` — unit tests for `cva()` PHP helper function
- [ ] PHP helper file: `app/View/helpers.php` — registered in composer.json autoload.files

*(Pattern for ComponentSmokeTest: use `$this->blade('<x-primitive.button>Test</x-primitive.button>')->assertSee('Button--primary')`)*

---

## Sources

### Primary (HIGH confidence)

- Laravel 12.x Blade docs (https://laravel.com/docs/12.x/blade) — anonymous components, @props, named slots, $attributes->merge()
- Live codebase inspection — all 60 Vue SFCs read directly; prop interfaces, CVA configs, and SCSS paths verified

### Secondary (MEDIUM confidence)

- `feature-ninja/cva` PHP library (https://github.com/feature-ninja/cva) — confirmed a PHP CVA equivalent exists; custom implementation chosen instead
- area17/blast (https://github.com/area17/blast) — Storybook for Blade exists; decided against adding it given Vue/Histoire already covers interactive components

### Tertiary (LOW confidence)

- Modal content in Blade + Vue ModalProvider coexistence pattern — no single authoritative source; marked as Open Question requiring spike

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — Blade anonymous components and @props are stable Laravel 12.x APIs verified against official docs
- Architecture: HIGH — codebase fully inspected; all 60 Vue files read; conversion table is accurate
- PHP cva() helper: HIGH — simple pure-PHP implementation with no edge cases; verified against variant maps in Vue files
- SCSS import strategy: HIGH — vite.config.js loadPaths confirmed; @use 'styles/colors' already working in existing component SCSS
- Modal content in Blade: LOW — no authoritative pattern; flagged as Open Question

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable Laravel APIs; no fast-moving dependencies)
