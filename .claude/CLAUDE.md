# Claude Code Instructions for MakeReady

## 🏗️ Architecture Overview

This is a **multi-repo project** with three separate applications, each with its own git repository. Before making ANY changes, you MUST:

1. **Understand the multi-repo structure**: Three separate git repos (client, server, iphone)
2. **Read the architecture spec**: `.project/ARCHITECTURE_SPEC.md`
3. **Use the appropriate sub-agent** for the task
4. **Follow the component patterns** exactly as specified
5. **Run git operations in the correct repository directory**
6. **Never violate separation of concerns**

## 🗂️ Multi-Repo Structure

This project contains **three separate applications with independent git repositories**:

- **`/client`** - Web client (React + MobX + Vite) - Has own `.git` repo
- **`/server`** - Backend API (Express + Prisma) - Has own `.git` repo
- **`/iphone`** - iOS app (Swift/SwiftUI) - Has own `.git` repo
- **Root folder** - Has NO git repo (workspace coordination only)

Each app also has its own `.claude/` folder for app-specific configurations.

### ⚠️ Git Operations - CRITICAL

**ALWAYS change to the app directory before running git commands:**

```bash
# For client changes
cd client && git status && git add . && git commit -m "..."

# For server changes
cd server && git status && git add . && git commit -m "..."

# For iPhone changes
cd iphone && git status && git add . && git commit -m "..."
```

**NEVER run git commands from the root folder** - it has no `.git` repository.

For cross-app changes (e.g., API update + client update), commit to each affected repository separately.

## 🤖 Sub-Agent Strategy

This project uses specialized sub-agents to ensure architecture compliance. **Always use the appropriate sub-agent** rather than making changes directly.

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

**⚠️ Note:** This creates a **single client app**, not the full multi-repo structure. For multi-repo setup, create client/server/iphone folders separately.

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

**Usage:**
```
# 1. Create empty folder and copy .claude into it
mkdir my-app && cd my-app
cp -r /path/to/makeready/.claude ./

# 2. Run boot command
/boot
```

**What You Get:**
- ✅ Complete architecture following MakeReady patterns
- ✅ Tailwind + shadcn configured correctly (HSL format, inlined config)
- ✅ Storybook running at http://localhost:6006
- ✅ Hello World component visible in Storybook
- ✅ MobX stores ready to use
- ✅ All dependencies installed
- ✅ Git initialized with first commit

**Time:** 2-3 minutes (including dependency install)

**See:** `.claude/commands/boot.md` for complete details

---

### 1. `/component` - UI Component Generator

**Purpose:** Create UI components in `client/ui/components/` following architecture patterns

**Responsibilities:**
- Create component in correct category (primitive/domain/layout)
- **IMPORTANT**: Component file must be in a folder: `client/ui/components/[category]/[component-name]/[component-name].tsx`
- Generate CVA variants with custom wrapper
- Create SCSS file with BEM naming in the same folder
- Generate Storybook story in `client/ui/stories/`
- Add export to `client/ui/index.ts`
- Ensure component is view-only (no app logic)
- **After creating component**, commit to client repo: `cd client && git add . && git commit -m "Add [component] component"`

**Usage:**
```
/component button primitive
/component user-card domain
/component home-layout layout
```

**File Structure:**
```
client/ui/components/
├── primitive/
│   └── button/
│       ├── button.tsx      ← Component file
│       ├── button.scss     ← Styles
│       └── button.test.tsx ← Optional tests
├── layout/
│   └── auth/
│       └── auth.tsx        ← Component file (layout components may not need SCSS)
```

**Required Checks:**
- ✅ Component in folder: `client/ui/components/[category]/[name]/[name].tsx` (NOT directly in category folder)
- ✅ Uses custom CVA wrapper from `../../../util/cva` (relative path within client)
- ✅ Imports only from `client/util/` (never from client/src)
- ✅ Observer + forwardRef pattern
- ✅ VariantProps extends ComponentCva.variants
- ✅ SCSS uses BEM naming (.ComponentName--variant)
- ✅ Story created in `client/ui/stories/components/[category]/`
- ✅ No application logic or store access
- ✅ Props interface with containerProps
- ✅ Git commit to `/client` repo

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

**Purpose:** Create page components in `client/src/pages/` that connect stores to UI

**Responsibilities:**
- Create page folder in `client/src/pages/[page-name]/`
- Generate page component following pattern
- Import UI components from `@/ui` (client path alias)
- Import utilities from `@/util` (client path alias)
- Connect to Application store properly
- Use observer pattern
- Implement useLifecycle if needed
- **After creating page**, commit to client repo: `cd client && git add . && git commit -m "Add [page] page"`

**Usage:**
```
/page home
/page dashboard --with-store
/page profile --with-auth
```

**Required Checks:**
- ✅ Located in `client/src/pages/`
- ✅ Imports from `@/ui` barrel export (client path alias)
- ✅ Imports from `@/util` barrel export (client path alias)
- ✅ Uses `Application` store from `@/store/ApplicationStore`
- ✅ Observer wrapper on component
- ✅ Passes data to UI components via props (never direct store access in UI)
- ✅ Uses `when()` for conditional rendering
- ✅ Uses `useLifecycle()` if store has willMount/willUnmount
- ✅ Git commit to `/client` repo

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

**Purpose:** Create MobX stores following Domain/Session/UI pattern in `client/src/store/`

**Responsibilities:**
- Create store in correct category (domain/session/ui)
- Extend Store base class
- Use proper MobX decorators
- Follow store responsibilities
- Create computed props for UI components
- No UI logic in domain stores
- No API calls in UI stores
- **After creating store**, commit to client repo: `cd client && git add . && git commit -m "Add [store] store"`

**Usage:**
```
/store domain users
/store ui admin.user-management
/store session
```

**Required Checks:**
- ✅ Located in `client/src/store/domain/` or `client/src/store/ui/`
- ✅ Extends `Store` base class
- ✅ Constructor calls `super(application)`
- ✅ Uses `makeObservable(this)` in constructor
- ✅ Domain stores: API calls only, no UI transforms
- ✅ Session stores: Auth/session only, no domain data
- ✅ UI stores: Computed props matching component interfaces
- ✅ Actions for mutations
- ✅ Computed for derived state
- ✅ Git commit to `/client` repo

**Domain Store Template:**
```typescript
import { observable, makeObservable } from "mobx";
import { Store } from "../store";
import { ApplicationStore } from "../application.store";

export class UsersDomain extends Store {
  @observable users: User[] = [];

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  @action
  async fetchUsers() {
    // API call
  }
}
```

**UI Store Template:**
```typescript
import { observable, computed, action, makeObservable } from "mobx";
import { Store } from "../../store";

export class UserManagementUI extends Store {
  @observable selectedUserId?: string;

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  @computed
  get userTableProps(): IUserTable {
    const users = this.application.domain.users.users;
    return {
      data: users,
      selectedId: this.selectedUserId,
      onSelect: this.selectUser,
    };
  }

  @action
  selectUser = (id: string) => {
    this.selectedUserId = id;
  };
}
```

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
- **After creating API**, commit to server repo: `cd server && git add . && git commit -m "Add [resource] API endpoints"`

**Usage:**
```
/api create tasks
/api update users
/api schema Task title:String completed:Boolean
```

**Required Checks:**
- ✅ Route file created in `server/src/routes/`
- ✅ Routes mounted in `server/src/index.ts`
- ✅ Prisma schema updated (if needed)
- ✅ Database migration run successfully (from server directory)
- ✅ All CRUD endpoints functional
- ✅ Error handling with try/catch
- ✅ TypeScript types correct
- ✅ Postman collection regenerated
- ✅ Git commit to `/server` repo

**Workflow:**
1. Create route file with full CRUD operations in `server/src/routes/`
2. Update Prisma schema if database model needed
3. Run `cd server && npx prisma migrate dev`
4. Mount routes in server/src/index.ts
5. Run `/postman` to regenerate collection (generates both local and live environments)
6. Test endpoints
7. Commit to server repo: `cd server && git add . && git commit -m "Add [resource] API"`

**See:** `.claude/commands/api.md` for complete implementation guide

---

### 5. `/architect` - Architecture Compliance Reviewer

**Purpose:** Review code changes against architecture spec, enforce compliance

**Responsibilities:**
- Read `.project/ARCHITECTURE_SPEC.md`
- Review proposed changes for violations
- Suggest correct patterns
- Refactor non-compliant code
- Update documentation

**Usage:**
```
/architect review
/architect refactor client/src/components
/architect validate
```

**Checks:**
- ✅ Components in `client/ui/components/` not `client/src/components/`
- ✅ CVA uses custom wrapper from `client/util/cva`
- ✅ Components import only from `client/util/` (relative paths)
- ✅ Pages import from `@/ui` and `@/util` (path aliases)
- ✅ Stores in `client/src/store/` follow Domain/Session/UI pattern
- ✅ No application logic in UI components
- ✅ All components have Storybook stories in `client/ui/stories/`
- ✅ Proper barrel exports in `client/ui/index.ts`

---

### 6. `/feature` - Feature Implementation Coordinator

**Purpose:** Coordinate multiple sub-agents to implement complete features

**Responsibilities:**
- Break down feature into tasks
- Call `/component` for UI components
- Call `/store` for state management
- Call `/page` for page components
- Ensure proper integration
- Follow feature → component → page flow

**Usage:**
```
/feature user-authentication
/feature dashboard-with-charts
/feature social-login
```

**Process:**
1. Create UI components first (`/component`)
2. Create stores (`/store`)
3. Create pages (`/page`)
4. Integrate and test
5. Update Storybook

---

### 7. `/phone-verification` - Twilio SMS Verification Implementation

**Purpose:** Implement phone verification using Twilio's Verify API for authentication flows

**Responsibilities:**
- Create server-side API endpoints for SMS verification
- Create client-side UI components (PhoneInput, VerificationInput, PhoneVerification)
- Create MobX stores (VerificationDomain, PhoneVerificationUI)
- Configure Twilio credentials securely
- Implement proper phone number formatting (E.164)
- Handle verification flow with resend timer
- Follow security best practices

**Usage:**
```
/phone-verification
```

**Required Components:**
- Server endpoints: `/api/verification/send` and `/api/verification/verify` (in `server/`)
- UI Components: PhoneInput, VerificationInput, PhoneVerification (use `/component` - creates in `client/ui/`)
- Stores: VerificationDomain (domain), PhoneVerificationUI (ui) (use `/store` - creates in `client/src/store/`)
- Page: PhoneVerificationPage (use `/page` - creates in `client/src/pages/`)
- Commits to **both** `server` and `client` repos

**Twilio Configuration:**
```env
# server/.env
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_VERIFY_SERVICE_ID=your_service_id_here
```

**Required Checks:**
- ✅ Credentials stored in `server/.env` (never in client)
- ✅ Phone numbers formatted as E.164 (+1XXXXXXXXXX)
- ✅ Server-side validation of phone format
- ✅ Rate limiting implemented
- ✅ Resend timer (60 seconds) in UI store
- ✅ Error handling with user-friendly messages
- ✅ Domain store handles API calls only
- ✅ UI store provides computed props for components
- ✅ Components in `ui/components/primitive/` and `ui/components/domain/`

**Integration Patterns:**
- Sign-up with phone verification
- Add phone to existing account
- Two-factor authentication (2FA)

**See:** `.claude/commands/phone-verification.md` for complete implementation guide

---

## 🚫 Critical Rules (NEVER VIOLATE)

### 0. **Component Creation - USE THE SUB-AGENT!**
- ❌ NEVER EVER create components manually - ALWAYS use `/component` slash command
- ❌ NEVER place component files directly in category folder (e.g., `client/ui/components/layout/auth.tsx`)
- ❌ NEVER write component code yourself - let the sub-agent do it
- ✅ **ALWAYS use `/component [name] [category]` command for ANY new component**
- ✅ The sub-agent will create: component file, SCSS, story, and barrel export
- ✅ Component file path must be: `client/ui/components/[category]/[name]/[name].tsx`
- ✅ Examples: `/component button primitive`, `/component auth-layout layout`

**IMPORTANT**: If the user asks to create a component, your FIRST action must be to use the `/component` slash command. Do not write any component code manually.

### 1. **Component Location**
- ❌ NEVER put components in `client/src/components/`
- ✅ ALWAYS put components in `client/ui/components/[category]/[name]/`

### 2. **Component Imports**
- ❌ NEVER import from `client/src/` in UI components
- ❌ NEVER import from `@/` in UI components (path aliases are for pages, not UI components)
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
- ✅ Stories go in `client/ui/stories/components/[category]/`
- ✅ Storybook config is in `client/.storybook/`
- ✅ Run Storybook from client directory: `cd client && npm run storybook`

### 6. **Store Separation**
- ❌ NEVER put UI transforms in Domain stores
- ❌ NEVER put API calls in UI stores
- ❌ NEVER put domain data in Session stores
- ✅ Domain = API + raw data
- ✅ Session = Auth + session state
- ✅ UI = Component props + UI state

---

## 📁 Folder Structure Reference

```
makeready/                   # Root folder (NO .git repo)
├── .claude/                # Root-level Claude configuration
├── .project/               # Architecture documentation
├── client/                 # Web app (has own .git repo)
│   ├── .git/              # Client git repository
│   ├── .claude/           # Client-specific Claude config
│   ├── .storybook/        # Storybook config (in client!)
│   ├── ui/                # UI components (client-specific)
│   │   ├── components/
│   │   │   ├── primitive/  # Base components
│   │   │   │   └── button/
│   │   │   │       ├── button.tsx
│   │   │   │       └── button.scss
│   │   │   ├── domain/     # Business components
│   │   │   └── layout/     # Page layouts
│   │   ├── stories/       # Storybook stories
│   │   └── index.ts       # Barrel export
│   ├── util/              # Utilities (client-specific)
│   │   ├── cva.ts         # Custom CVA wrapper
│   │   ├── classnames.ts  # Classnames utility
│   │   ├── when.ts        # Conditional rendering
│   │   ├── hooks/         # Custom hooks
│   │   └── index.ts       # Barrel export
│   └── src/
│       ├── pages/         # Page components
│       ├── store/         # MobX stores
│       │   ├── ApplicationStore.ts
│       │   ├── Store.ts
│       │   ├── DomainStore.ts
│       │   ├── SessionStore.ts
│       │   ├── UIStore.ts
│       │   ├── domain/    # Domain stores
│       │   └── ui/        # UI stores
│       ├── api/           # API client
│       └── main.tsx
├── server/                # Backend API (has own .git repo)
│   ├── .git/             # Server git repository
│   ├── .claude/          # Server-specific Claude config
│   ├── src/
│   │   ├── routes/       # Express routes
│   │   └── index.ts      # Server entry
│   ├── prisma/           # Database schema
│   └── .env              # Server environment variables
└── iphone/               # iOS app (has own .git repo)
    ├── .git/            # iPhone git repository
    ├── .claude/         # iPhone-specific Claude config
    └── MakeReady/       # Swift project
```

**Key Points:**
- ❌ NO shared `/ui` or `/util` at root level
- ✅ `/client/ui` and `/client/util` are client-specific
- ✅ Three separate git repositories (client, server, iphone)
- ✅ Each app has its own `.claude/` configuration
- ✅ Root folder coordinates workspaces but has NO git repo

---

## 🎯 Decision Flow

```
Task: Create something

1. Is it a UI component?
   → Use `/component`

2. Is it a page?
   → Use `/page`

3. Is it a store?
   → Use `/store`

4. Is it an API endpoint or database model?
   → Use `/api`

5. Is it a complete feature?
   → Use `/feature`

6. Need to review/refactor?
   → Use `/architect`

7. Multiple types?
   → Use `/feature` to coordinate

8. Need to update Postman collection?
   → Use `/postman`
```

---

## 💡 Quick Reference

**Import Patterns:**

```typescript
// ✅ In UI components (client/ui/components/)
import { cva, classnames, when } from "../../../util";  // Relative path

// ✅ In pages (client/src/pages/)
import { Button, Icon } from "@/ui";                   // Path alias
import { when, useLifecycle } from "@/util";           // Path alias
import { Application } from "@/store/ApplicationStore";

// ✅ CVA enum usage
<Button variant={ButtonCva.variant.Default} />
```

**Component Checklist:**
- [ ] Located in `client/ui/components/[category]/[name]/`
- [ ] Uses custom CVA wrapper from `../../../util/cva`
- [ ] Has SCSS file with BEM naming
- [ ] Has Storybook story in `client/ui/stories/`
- [ ] Exported from `client/ui/index.ts`
- [ ] Observer + forwardRef
- [ ] No application logic
- [ ] Only imports from `client/util/` (relative paths)
- [ ] Git committed to `/client` repo

**Page Checklist:**
- [ ] Located in `client/src/pages/`
- [ ] Imports from `@/ui` and `@/util` (path aliases)
- [ ] Accesses Application store
- [ ] Observer wrapper
- [ ] Passes data via props
- [ ] Uses `when()` for conditionals
- [ ] Uses `useLifecycle()` if needed
- [ ] Git committed to `/client` repo

---

## 📖 Documentation Files

- `.project/ARCHITECTURE_SPEC.md` - Complete architecture specification
- `.project/MONOREPO_GUIDE.md` - Monorepo patterns and setup
- `ARCHITECTURE_COMPLIANCE.md` - Current compliance status
- `client/DESIGN_SYSTEM.md` - Design system guidelines
- `client/ICONS.md` - Icon usage guide

---

## 🚀 Getting Started

1. **Understand multi-repo structure**: Three separate git repos (client, server, iphone)
2. **Read the spec**: `.project/ARCHITECTURE_SPEC.md`
3. **Review examples**: Check existing components in `client/ui/components/primitive/`
4. **Use sub-agents**: Don't create components manually
5. **Follow patterns**: The architecture is strict by design
6. **Test in Storybook**: `cd client && npm run storybook`
7. **Git operations**: Always `cd` into the app directory before committing

---

**Remember:** The architecture exists to ensure:
- ✅ Components are reusable within the client app
- ✅ Clear separation of concerns (UI vs pages vs stores)
- ✅ Type safety with CVA
- ✅ Testability in Storybook
- ✅ Scalability as the project grows
- ✅ Independent git history per app

**Always use the appropriate sub-agent AND commit to the correct git repository!**
