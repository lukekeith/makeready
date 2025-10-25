# Claude Code Instructions for MakeReady

## 🏗️ Architecture Overview

This is a **multi-app monorepo** following strict architectural patterns. Before making ANY changes, you MUST:

1. **Read the architecture spec**: `.project/ARCHITECTURE_SPEC.md`
2. **Use the appropriate sub-agent** for the task
3. **Follow the component patterns** exactly as specified
4. **Never violate separation of concerns**

## 🤖 Sub-Agent Strategy

This project uses specialized sub-agents to ensure architecture compliance. **Always use the appropriate sub-agent** rather than making changes directly.

### When to Use Sub-Agents

| Task | Use Sub-Agent | Why |
|------|---------------|-----|
| Creating UI components | `/component` | Ensures proper CVA, SCSS, story creation |
| Creating pages | `/page` | Ensures proper imports, store usage, patterns |
| Creating stores | `/store` | Ensures Domain/Session/UI separation |
| Refactoring architecture | `/architect` | Reviews against spec, ensures compliance |
| Adding features | `/feature` | Coordinates multiple sub-agents |
| Phone verification (Twilio) | `/phone-verification` | Implements SMS verification with proper patterns |

---

## 📋 Sub-Agent Definitions

### 1. `/component` - UI Component Generator

**Purpose:** Create UI components in `ui/components/` following architecture patterns

**Responsibilities:**
- Create component in correct category (primitive/domain/layout)
- Generate CVA variants with custom wrapper
- Create SCSS file with BEM naming
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
- ✅ Uses custom CVA wrapper from `util/cva`
- ✅ Imports only from `util/` (never from client)
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
- Import UI components from `ui`
- Import utilities from `util`
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
- ✅ Located in `client/src/pages/`
- ✅ Imports from `ui` barrel export
- ✅ Imports from `util` barrel export
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
import { Button, Icon } from "ui";
import { when, useLifecycle } from "util";

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

**Purpose:** Create MobX stores following Domain/Session/UI pattern

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
- ✅ Extends `Store` base class
- ✅ Constructor calls `super(application)`
- ✅ Uses `makeObservable(this)` in constructor
- ✅ Domain stores: API calls only, no UI transforms
- ✅ Session stores: Auth/session only, no domain data
- ✅ UI stores: Computed props matching component interfaces
- ✅ Actions for mutations
- ✅ Computed for derived state

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

### 4. `/architect` - Architecture Compliance Reviewer

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
- ✅ Components in `ui/` not `client/src/components/`
- ✅ CVA uses custom wrapper
- ✅ Components import only from `util/`
- ✅ Pages import from `ui` and `util`
- ✅ Stores follow Domain/Session/UI pattern
- ✅ No application logic in UI components
- ✅ All components have Storybook stories
- ✅ Proper barrel exports

---

### 5. `/feature` - Feature Implementation Coordinator

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

### 6. `/phone-verification` - Twilio SMS Verification Implementation

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
- Server endpoints: `/api/verification/send` and `/api/verification/verify`
- UI Components: PhoneInput, VerificationInput, PhoneVerification (use `/component`)
- Stores: VerificationDomain (domain), PhoneVerificationUI (ui) (use `/store`)
- Page: PhoneVerificationPage (use `/page`)

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

### 1. **Component Location**
- ❌ NEVER put components in `client/src/components/`
- ✅ ALWAYS put components in `ui/components/[category]/`

### 2. **Component Imports**
- ❌ NEVER import from `client/` in UI components
- ❌ NEVER import from `@/` in UI components
- ✅ ONLY import from `util/` in UI components

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
makeready/
├── .storybook/              # Storybook config (root level)
├── ui/                      # Shared UI components (ALL APPS)
│   ├── components/
│   │   ├── primitive/       # Base components
│   │   ├── domain/          # Business components
│   │   ├── layout/          # Page layouts
│   │   └── index.ts         # Barrel export
│   └── stories/
│       └── components/      # Storybook stories
├── util/                    # Shared utilities (ALL APPS)
│   ├── cva.ts              # Custom CVA wrapper
│   ├── classnames.ts       # Classnames utility
│   ├── when.ts             # Conditional rendering
│   ├── hooks/              # Custom hooks
│   └── index.ts            # Barrel export
├── client/                  # Web app
│   └── src/
│       ├── pages/          # Page components ONLY
│       ├── store/          # MobX stores
│       │   ├── ApplicationStore.ts
│       │   ├── Store.ts
│       │   ├── DomainStore.ts
│       │   ├── SessionStore.ts
│       │   ├── UIStore.ts
│       │   ├── domain/     # Domain stores
│       │   └── ui/         # UI stores
│       └── api/            # API client
└── server/                  # Backend API
```

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

4. Is it a complete feature?
   → Use `/feature`

5. Need to review/refactor?
   → Use `/architect`

6. Multiple types?
   → Use `/feature` to coordinate
```

---

## 💡 Quick Reference

**Import Patterns:**

```typescript
// ✅ In UI components
import { cva, classnames, when } from "util";

// ✅ In pages
import { Button, Icon } from "ui";
import { when, useLifecycle } from "util";
import { Application } from "@/store/ApplicationStore";

// ✅ CVA enum usage
<Button variant={ButtonCva.variant.Default} />
```

**Component Checklist:**
- [ ] Located in `ui/components/[category]/`
- [ ] Uses custom CVA wrapper
- [ ] Has SCSS file with BEM naming
- [ ] Has Storybook story
- [ ] Exported from `ui/index.ts`
- [ ] Observer + forwardRef
- [ ] No application logic
- [ ] Only imports from `util/`

**Page Checklist:**
- [ ] Located in `client/src/pages/`
- [ ] Imports from `ui` and `util`
- [ ] Accesses Application store
- [ ] Observer wrapper
- [ ] Passes data via props
- [ ] Uses `when()` for conditionals
- [ ] Uses `useLifecycle()` if needed

---

## 📖 Documentation Files

- `.project/ARCHITECTURE_SPEC.md` - Complete architecture specification
- `.project/MONOREPO_GUIDE.md` - Monorepo patterns and setup
- `ARCHITECTURE_COMPLIANCE.md` - Current compliance status
- `client/DESIGN_SYSTEM.md` - Design system guidelines
- `client/ICONS.md` - Icon usage guide

---

## 🚀 Getting Started

1. **Read the spec**: `.project/ARCHITECTURE_SPEC.md`
2. **Review examples**: Check existing components in `ui/components/primitive/`
3. **Use sub-agents**: Don't create components manually
4. **Follow patterns**: The architecture is strict by design
5. **Test in Storybook**: `npm run storybook`

---

**Remember:** The architecture exists to ensure:
- ✅ Components are reusable across apps
- ✅ Clear separation of concerns
- ✅ Type safety with CVA
- ✅ Testability in Storybook
- ✅ Scalability as the project grows

**Always use the appropriate sub-agent!**
