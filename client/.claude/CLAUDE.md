# Claude Code Instructions for MakeReady Client

## 🤖 Sub-Agent Strategy

This app uses specialized sub-agents to ensure architecture compliance. **Always use the appropriate sub-agent** rather than making changes directly.

### When to Use Sub-Agents

| Task | Use Sub-Agent | Why |
|------|---------------|-----|
| **Bootstrap new project** | `/boot` | **Creates complete project from scratch with all architecture** |
| Creating UI components | `/component` | Ensures proper CVA, SCSS, story creation |
| Creating pages | `/page` | Ensures proper imports, store usage, patterns |
| Creating stores | `/store` | Ensures Domain/Session/UI separation |
| **Creating/managing APIs** | `/api` | **Creates Express routes, updates Prisma schema, regenerates Postman** |
| Refactoring architecture | `/architect` | Reviews against spec, ensures compliance |
| Adding features | `/feature` | Coordinates multiple sub-agents |
| Phone verification (Twilio) | `/phone-verification` | Implements SMS verification with proper patterns |
| Generating Postman collection | `/postman` | Regenerates API collection with local & live environments |

---

## 📋 Sub-Agent Definitions

### 0. `/boot` - Project Bootstrap

**Purpose:** Bootstrap a complete web client project from scratch in an empty folder

**Responsibilities:**
- Initialize Git repository in project folder
- Create complete folder structure (ui/, util/, src/, .storybook/ - all inside client project)
- Generate all configuration files with **working Tailwind + shadcn setup**
- Create core utilities (CVA wrapper, classnames, when, useLifecycle) in util/
- Create MobX store structure (ApplicationStore, Domain/Session/UI stores) in src/store/
- Generate Hello World component with Storybook story in ui/
- Install all dependencies
- Start Storybook server
- Create initial Git commit

**See:** `.claude/commands/boot.md` for complete details

---

### 1. `/component` - UI Component Generator

**Purpose:** Create UI components in `ui/components/` following architecture patterns

**Responsibilities:**
- Create component in correct category (primitive/domain/layout)
- **IMPORTANT**: Component file must be in a folder: `ui/components/[category]/[component-name]/[component-name].tsx`
- Generate CVA variants with custom wrapper
- Create SCSS file with BEM naming in the same folder
- Generate Storybook story in `ui/stories/`
- Add export to `ui/index.ts`
- Ensure component is view-only (no app logic)

**Usage:**
```
/component button primitive
/component user-card domain
/component home-layout layout
```

**Required Checks:**
- ✅ Component in folder: `ui/components/[category]/[name]/[name].tsx` (NOT directly in category folder)
- ✅ Uses custom CVA wrapper from `../../../util/cva` (relative path)
- ✅ Imports only from `util/` (never from src)
- ✅ Observer + forwardRef pattern
- ✅ VariantProps extends ComponentCva.variants
- ✅ SCSS uses BEM naming (.ComponentName--variant)
- ✅ Story created in `ui/stories/components/[category]/`
- ✅ No application logic or store access
- ✅ Props interface with containerProps

**Template:**
```typescript
import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "../../../util/cva";
import { classnames } from "../../../util/classnames";
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
  containerProps?: React.HTMLAttributes<HTMLDivElement>;
}

export const ComponentName = observer(
  React.forwardRef<HTMLDivElement, IComponentName>((props, ref) => {
    const {
      children,
      className,
      mode = ComponentNameCva.defaults?.mode,
      containerProps,
    } = props;

    return (
      <div
        ref={ref}
        className={classnames(ComponentNameCva.variants({ mode }), className)}
        {...containerProps}
      >
        {children}
      </div>
    );
  })
);

ComponentName.displayName = "ComponentName";
```

---

### 2. `/page` - Page Component Generator

**Purpose:** Create page components in `src/pages/` that connect stores to UI

**Responsibilities:**
- Create page folder in `src/pages/[page-name]/`
- Generate page component following pattern
- Import UI components from `@/ui` (path alias)
- Import utilities from `@/util` (path alias)
- Connect to Application store properly
- Use observer pattern
- Implement useLifecycle if needed

**Usage:**
```
/page home
/page dashboard --with-store
/page profile --with-auth
```

**Required Checks:**
- ✅ Located in `src/pages/`
- ✅ Imports from `@/ui` barrel export (path alias)
- ✅ Imports from `@/util` barrel export (path alias)
- ✅ Uses `Application` store from `@/store/ApplicationStore`
- ✅ Observer wrapper on component
- ✅ Passes data to UI components via props (never direct store access in UI)
- ✅ Uses `when()` for conditional rendering
- ✅ Uses `useLifecycle()` if store has willMount/willUnmount

**Template:**
```typescript
import React from "react";
import { observer } from "mobx-react";
import { Application } from "@/store/ApplicationStore";
import { Button, Icon } from "@/ui";
import { when, useLifecycle } from "@/util";

export const HomePage = observer(() => {
  const { store, shouldMount } = useLifecycle(Application.ui.home);
  if (!shouldMount) return null;

  return (
    <div>
      {when(store.isLoading, <LoadingSpinner />)}
      <Button onClick={() => store.handleAction()}>
        Action
      </Button>
    </div>
  );
});
```

---

### 3. `/store` - MobX Store Generator

**Purpose:** Create MobX stores following Domain/Session/UI pattern in `src/store/`

**Responsibilities:**
- Create store in correct category (domain/session/ui)
- Extend Store base class
- Use proper MobX decorators
- Follow store responsibilities
- Create computed props for UI components
- No UI logic in domain stores
- No API calls in UI stores

**Usage:**
```
/store domain users
/store ui admin.user-management
/store session
```

**Required Checks:**
- ✅ Located in `src/store/domain/` or `src/store/ui/`
- ✅ Extends `Store` base class
- ✅ Constructor calls `super(application)`
- ✅ Uses `makeObservable(this)` in constructor
- ✅ Domain stores: API calls only, no UI transforms
- ✅ Session stores: Auth/session only, no domain data
- ✅ UI stores: Computed props matching component interfaces
- ✅ Actions for mutations
- ✅ Computed for derived state

---

### 4. `/api` - API & Database Manager

**Purpose:** Create and manage Express API routes with Prisma schema updates and automatic Postman regeneration

**Responsibilities:**
- Create new Express route files in `server/src/routes/`
- Generate full CRUD endpoints (GET, POST, PATCH, DELETE)
- Update Prisma schema for new database models
- Run database migrations
- Mount routes in `server/src/index.ts`
- Automatically regenerate Postman collection

**Usage:**
```
/api create tasks
/api update users
/api schema Task title:String completed:Boolean
```

**Workflow:**
1. Create route file with full CRUD operations in `server/src/routes/`
2. Update Prisma schema if database model needed
3. Run `cd server && npx prisma migrate dev`
4. Mount routes in server/src/index.ts
5. Run `/postman` to regenerate collection
6. Test endpoints

**See:** `.claude/commands/api.md` for complete implementation guide

---

### 5. `/architect` - Architecture Compliance Reviewer

**Purpose:** Review code changes against architecture spec, enforce compliance

**Checks:**
- ✅ Components in `ui/components/` not `src/components/`
- ✅ CVA uses custom wrapper from `util/cva`
- ✅ Components import only from `util/` (relative paths)
- ✅ Pages import from `@/ui` and `@/util` (path aliases)
- ✅ Stores in `src/store/` follow Domain/Session/UI pattern
- ✅ No application logic in UI components
- ✅ All components have Storybook stories in `ui/stories/`
- ✅ Proper barrel exports in `ui/index.ts`

---

### 6. `/feature` - Feature Implementation Coordinator

**Purpose:** Coordinate multiple sub-agents to implement complete features

**Process:**
1. Create UI components first (`/component`)
2. Create stores (`/store`)
3. Create pages (`/page`)
4. Integrate and test
5. Update Storybook

---

### 7. `/phone-verification` - Twilio SMS Verification Implementation

**Purpose:** Implement phone verification using Twilio's Verify API

**See:** `.claude/commands/phone-verification.md` for complete implementation guide

---

## 🚫 Critical Rules (NEVER VIOLATE)

### 0. **Component Creation - USE THE SUB-AGENT!**
- ❌ NEVER EVER create components manually - ALWAYS use `/component` slash command
- ❌ NEVER place component files directly in category folder (e.g., `ui/components/layout/auth.tsx`)
- ❌ NEVER write component code yourself - let the sub-agent do it
- ✅ **ALWAYS use `/component [name] [category]` command for ANY new component**
- ✅ Component file path must be: `ui/components/[category]/[name]/[name].tsx`

### 1. **Component Location**
- ❌ NEVER put components in `src/components/`
- ✅ ALWAYS put components in `ui/components/[category]/[name]/`

### 2. **Component Imports**
- ❌ NEVER import from `src/` in UI components
- ❌ NEVER import from `@/` in UI components (path aliases are for pages only)
- ✅ ONLY import from `../../../util/` (relative paths) in UI components

### 3. **Store Access**
- ❌ NEVER access Application store directly in UI components
- ✅ ONLY access stores in page components
- ✅ ALWAYS pass data via props

### 4. **CVA Pattern**
- ❌ NEVER use raw CVA from class-variance-authority
- ✅ ALWAYS use custom wrapper from `util/cva`
- ✅ ALWAYS provide enum access to variants

### 5. **Storybook**
- ❌ NEVER skip creating stories
- ✅ EVERY component needs a story
- ✅ Stories go in `ui/stories/components/[category]/`
- ✅ Storybook config is in `.storybook/`
- ✅ Run Storybook: `npm run storybook`

### 6. **Store Separation**
- ❌ NEVER put UI transforms in Domain stores
- ❌ NEVER put API calls in UI stores
- ❌ NEVER put domain data in Session stores
- ✅ Domain = API + raw data
- ✅ Session = Auth + session state
- ✅ UI = Component props + UI state

---

## 💡 Quick Reference

**Import Patterns:**

```typescript
// ✅ In UI components (ui/components/)
import { cva, classnames, when } from "../../../util";  // Relative path

// ✅ In pages (src/pages/)
import { Button, Icon } from "@/ui";                   // Path alias
import { when, useLifecycle } from "@/util";           // Path alias
import { Application } from "@/store/ApplicationStore";

// ✅ CVA enum usage
<Button variant={ButtonCva.variant.Default} />
```

**Component Checklist:**
- [ ] Located in `ui/components/[category]/[name]/`
- [ ] Uses custom CVA wrapper from `../../../util/cva`
- [ ] Has SCSS file with BEM naming
- [ ] Has Storybook story in `ui/stories/`
- [ ] Exported from `ui/index.ts`
- [ ] Observer + forwardRef
- [ ] No application logic
- [ ] Only imports from `util/` (relative paths)

**Page Checklist:**
- [ ] Located in `src/pages/`
- [ ] Imports from `@/ui` and `@/util` (path aliases)
- [ ] Accesses Application store
- [ ] Observer wrapper
- [ ] Passes data via props
- [ ] Uses `when()` for conditionals
- [ ] Uses `useLifecycle()` if needed
