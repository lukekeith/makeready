# Claude Code Instructions for MakeReady Client

## 🎯 Overview

This is the **MakeReady Web Client** - a React application built with Vite, MobX, Tailwind CSS, and shadcn/ui components.

**Technology Stack:**
- **Framework**: React 18 + TypeScript
- **Build Tool**: Vite
- **State Management**: MobX with Domain/Session/UI pattern
- **Styling**: Tailwind CSS + SCSS for components
- **Component Library**: shadcn/ui + custom components
- **UI Testing**: Storybook
- **Routing**: React Router
- **Forms**: React Hook Form + Zod validation

## 🏗️ Architecture

This application follows a strict **component-based architecture** with clear separation of concerns:

```
client/
├── .storybook/         # Storybook configuration
├── ui/                 # Reusable UI components
│   ├── components/
│   │   ├── primitive/  # Base UI components (Button, Input, etc.)
│   │   ├── domain/     # Business-specific components
│   │   └── layout/     # Layout components
│   └── stories/        # Storybook stories
├── util/               # Shared utilities
│   ├── cva.ts         # Custom CVA wrapper
│   ├── classnames.ts  # Classname utilities
│   ├── when.ts        # Conditional rendering helper
│   └── hooks/         # Custom React hooks
├── shared/             # Shared types and constants
├── src/
│   ├── pages/         # Page components (connect stores to UI)
│   ├── store/         # MobX stores (Domain/Session/UI pattern)
│   └── lib/           # App-specific utilities
```

## 🤖 Sub-Agent Commands

Use these slash commands to ensure architecture compliance:

### `/component` - Create UI Components

Creates components in `ui/components/` following strict patterns.

**Usage:**
```
/component button primitive
/component user-card domain
/component page-layout layout
```

**What it creates:**
- Component file: `ui/components/[category]/[name]/[name].tsx`
- Styles: `ui/components/[category]/[name]/[name].scss`
- Story: `ui/stories/components/[category]/[name].stories.tsx`
- Export in `ui/index.ts`

**Component Rules:**
- ✅ MUST use custom CVA wrapper from `util/cva`
- ✅ MUST import ONLY from `util/` (never from `@/` or stores)
- ✅ MUST use Observer + forwardRef pattern
- ✅ MUST have SCSS file with BEM naming
- ✅ MUST have Storybook story
- ❌ NEVER access Application store directly
- ❌ NEVER put components in `src/components/`

### `/page` - Create Page Components

Creates page components in `src/pages/` that connect stores to UI.

**Usage:**
```
/page home
/page dashboard --with-store
```

**What it creates:**
- Page file: `src/pages/[name]/[name].page.tsx`
- Connects to Application store
- Uses UI components from `ui`
- Uses utilities from `util`

**Page Rules:**
- ✅ MUST import UI components from `ui` barrel export
- ✅ MUST access Application store from `@/store/ApplicationStore`
- ✅ MUST use Observer wrapper
- ✅ MUST pass data to UI via props (not direct store access)
- ✅ MUST use `when()` for conditional rendering
- ✅ MUST use `useLifecycle()` if store has lifecycle methods

### `/store` - Create MobX Stores

Creates MobX stores following Domain/Session/UI pattern.

**Usage:**
```
/store domain users
/store ui admin.user-management
/store session
```

**Store Separation:**
- **Domain Stores** (`store/domain/`): API calls + raw data (NO UI logic)
- **Session Stores** (`store/session/`): Auth + session state (NO domain data)
- **UI Stores** (`store/ui/`): Computed props for components + UI state (NO API calls)

**Store Rules:**
- ✅ MUST extend `Store` base class
- ✅ MUST call `super(application)` in constructor
- ✅ MUST use `makeObservable(this)` in constructor
- ✅ Domain stores: API calls only, no UI transforms
- ✅ UI stores: Computed props matching component interfaces, no API calls

### `/feature` - Implement Complete Features

Coordinates multiple sub-agents to implement complete features.

**Usage:**
```
/feature user-profile
/feature data-dashboard
```

**Process:**
1. Creates UI components (`/component`)
2. Creates stores (`/store`)
3. Creates pages (`/page`)
4. Integrates everything
5. Updates Storybook

### `/architect` - Review Architecture Compliance

Reviews code against architecture patterns and enforces compliance.

**Usage:**
```
/architect review
/architect refactor src/components
```

## 🚫 Critical Rules

### Component Creation
- ❌ **NEVER create components manually** - always use `/component` command
- ❌ **NEVER place components in `src/components/`**
- ✅ **ALWAYS use `/component [name] [category]` command**
- ✅ Component files MUST be in folder: `ui/components/[category]/[name]/[name].tsx`

### Imports
- ❌ **NEVER import from `@/` in UI components**
- ✅ UI components ONLY import from `util/`
- ✅ Pages import from `ui` and `util` and `@/store`

### State Management
- ❌ **NEVER access stores directly in UI components**
- ✅ Access stores ONLY in page components
- ✅ Pass data via props from pages to UI components

### Styling
- ❌ **NEVER use raw CVA from class-variance-authority**
- ✅ Use custom wrapper from `util/cva`
- ✅ Every component needs SCSS file with BEM naming

### Testing
- ❌ **NEVER skip creating Storybook stories**
- ✅ Every UI component needs a story

## 💡 Quick Reference

### Import Patterns

```typescript
// ✅ In UI components (ui/components/)
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import { when } from "util";

// ✅ In pages (src/pages/)
import { Button, Icon } from "ui";
import { when, useLifecycle } from "util";
import { Application } from "@/store/ApplicationStore";

// ✅ CVA enum usage
<Button variant={ButtonCva.variant.Primary} />
```

### Component Template

```typescript
import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./component-name.scss";

export const ComponentNameCva = cva("ComponentName", {
  variants: {
    mode: { Primary: "ComponentName--primary" }
  },
  defaultVariants: { mode: "Primary" }
});

export interface IComponentName extends VariantProps<typeof ComponentNameCva.variants> {
  children?: React.ReactNode;
  className?: string;
}

export const ComponentName = observer(
  React.forwardRef<HTMLDivElement, IComponentName>((props, ref) => {
    const { children, className, mode } = props;

    return (
      <div
        ref={ref}
        className={classnames(ComponentNameCva.variants({ mode }), className)}
      >
        {children}
      </div>
    );
  })
);
```

### Page Template

```typescript
import React from "react";
import { observer } from "mobx-react";
import { Application } from "@/store/ApplicationStore";
import { Button } from "ui";
import { when, useLifecycle } from "util";

export const HomePage = observer(() => {
  const { store, shouldMount } = useLifecycle(Application.ui.home);
  if (!shouldMount) return null;

  return (
    <div>
      {when(store.isLoading, <LoadingSpinner />)}
      <Button onClick={() => store.handleAction()}>
        Click Me
      </Button>
    </div>
  );
});
```

## 🚀 Development Commands

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Run Storybook
npm run storybook

# Build Storybook
npm run build-storybook

# Lint code
npm run lint
```

## 📖 Additional Documentation

- `DESIGN_SYSTEM.md` - Design system guidelines
- `ICONS.md` - Icon usage guide
- `components.json` - shadcn/ui configuration

## 🎯 Best Practices

1. **Always use sub-agents** - Don't create components/pages/stores manually
2. **Follow the architecture** - Component location and import rules are strict
3. **Test in Storybook** - Every UI component should have a story
4. **Separation of concerns** - UI components are pure, pages connect to stores
5. **Type safety** - Use TypeScript and CVA for type-safe variants
