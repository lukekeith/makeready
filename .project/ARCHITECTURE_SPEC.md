# Full-Stack Application Architecture Specification

**Version:** 2.0
**Last Updated:** 2025-10-25
**Based On:** Tax Guardian Client Architecture

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Multi-App Monorepo Structure](#multi-app-monorepo-structure)
3. [Frontend Architecture](#frontend-architecture)
4. [Component Architecture](#component-architecture)
5. [State Management with MobX](#state-management-with-mobx)
6. [Storybook Integration](#storybook-integration)
7. [DevOps & Build Pipeline](#devops--build-pipeline)
8. [Component Generation Workflow](#component-generation-workflow)
9. [TypeScript Configuration](#typescript-configuration)
10. [Dependencies & Tooling](#dependencies--tooling)
11. [File Naming Conventions](#file-naming-conventions)
12. [Implementation Checklist](#implementation-checklist)

---

## Executive Summary

This specification defines a scalable, maintainable **full-stack monorepo architecture** that supports multiple applications (frontend, backend, mobile, services) in a single repository, with a focus on React frontend development.

### Architecture Highlights

- **Multi-App Monorepo** - Multiple applications coexist with shared code
- **Component-Driven Development** via Storybook
- **Type-Safe Variants** using Class Variance Authority (CVA)
- **Observable State Management** with MobX
- **Strict Separation of Concerns** between UI and data layers
- **Automated DevOps** with custom build tooling
- **Shared Utilities** - Common code reused across applications

### Core Principles

1. **Monorepo structure** - All applications in one repository
2. **Components are view-only** - Never directly access data stores
3. **Everything in Storybook** - Every component and variant must be testable in isolation
4. **MobX for state** - Observable pattern for all reactive data
5. **Clear app boundaries** - Each app has its own folder with clear responsibilities
6. **Shared code** - `ui/` and `util/` shared across all apps
7. **CVA for variants** - Type-safe styling variants for all components

---

## Multi-App Monorepo Structure

### Philosophy

A **monorepo** (monolithic repository) contains multiple applications that:
- Share common code (`ui/`, `util/`)
- Have independent deployment pipelines
- Can be developed and tested independently
- Maintain clear boundaries and responsibilities

### Root Structure

```
project-root/
├── .storybook/              # Storybook configuration (shared across apps)
│   ├── main.js             # Stories config, addons, framework
│   ├── preview.js          # Global decorators and parameters
│   └── preview-head.html   # CSS variables, fonts, global styles
│
├── ui/                      # Shared component library (ALL APPS)
│   ├── components/
│   │   ├── primitive/      # Base components (Button, Input, Icon, etc.)
│   │   ├── domain/         # Business-specific components
│   │   ├── domain-form/    # Form components for workflows
│   │   ├── layout/         # Page layout templates
│   │   ├── table/          # Data table variants
│   │   ├── container/      # Container components
│   │   ├── domain-modal/   # Modal variants
│   │   └── domain-panel/   # Panel components
│   ├── stories/
│   │   ├── components/     # Story files (mirrors component structure)
│   │   ├── data/           # Props stores for Storybook (MobX)
│   │   └── assets/         # Story-specific assets
│   ├── assets/             # SVG icons, fonts, images
│   ├── animations.scss     # Global animation definitions
│   ├── index.ts            # Main export file
│   └── no-op.ts            # No-op utilities
│
├── util/                    # Shared utilities (ALL APPS)
│   ├── hooks/              # Custom React hooks
│   ├── joi/                # Validation utilities
│   ├── storybook-containers/ # Story layout helpers
│   ├── classnames.ts       # Class composition utility
│   ├── cva.ts              # CVA wrapper
│   ├── when.ts             # Conditional rendering
│   └── ...                 # 60+ shared utilities
│
├── client/                  # 🌐 WEB CLIENT (React + MobX)
│   ├── pages/              # Page components
│   ├── store/              # MobX stores
│   │   ├── application.store.tsx  # Root singleton store
│   │   ├── domain.store.tsx       # Domain data stores
│   │   ├── session.store.tsx      # User session/auth
│   │   └── ui.store.tsx           # UI state stores
│   ├── api/                # API client & validation
│   ├── app.tsx             # Root app component
│   ├── page-manager.tsx    # Routing logic
│   ├── route-config.tsx    # Route definitions
│   ├── index.html          # HTML entry point
│   ├── styles/             # Global stylesheets
│   ├── assets/             # Client-specific assets
│   ├── vite.config.ts      # Vite config for client
│   ├── tsconfig.json       # TypeScript config
│   └── package.json        # Client dependencies
│
├── server/                  # 🖥️  BACKEND API (Node.js/Express)
│   ├── src/
│   │   ├── routes/         # API routes
│   │   ├── controllers/    # Request handlers
│   │   ├── models/         # Data models
│   │   ├── middleware/     # Express middleware
│   │   ├── services/       # Business logic
│   │   └── index.ts        # Server entry point
│   ├── tests/              # Backend tests
│   ├── package.json        # Server dependencies
│   ├── tsconfig.json       # TypeScript config
│   └── .env.example        # Environment variables template
│
├── iphone/                  # 📱 iOS APP (React Native)
│   ├── src/
│   │   ├── screens/        # App screens
│   │   ├── components/     # Mobile-specific components
│   │   ├── navigation/     # Navigation setup
│   │   ├── store/          # MobX stores (mobile)
│   │   └── App.tsx         # Root component
│   ├── ios/                # iOS native code
│   ├── android/            # Android native code (if supporting both)
│   ├── package.json        # React Native dependencies
│   └── tsconfig.json       # TypeScript config
│
├── android/                 # 🤖 ANDROID APP (React Native or Kotlin)
│   ├── app/                # Android app code
│   ├── build.gradle        # Build configuration
│   └── ...                 # Android-specific files
│
├── models/                  # 🧠 ML/AI MODELS (Python)
│   ├── src/
│   │   ├── training/       # Model training scripts
│   │   ├── inference/      # Prediction/inference code
│   │   ├── preprocessing/  # Data preprocessing
│   │   └── api.py          # Model API (Flask/FastAPI)
│   ├── notebooks/          # Jupyter notebooks
│   ├── requirements.txt    # Python dependencies
│   ├── Dockerfile          # Container for model service
│   └── README.md           # Model documentation
│
├── desktop/                 # 💻 DESKTOP APP (Electron)
│   ├── src/
│   │   ├── main/           # Electron main process
│   │   ├── renderer/       # Renderer process (React)
│   │   └── preload/        # Preload scripts
│   ├── package.json        # Electron dependencies
│   └── electron-builder.yml # Build configuration
│
├── shared/                  # 🔗 SHARED CODE (All Apps)
│   ├── types/              # Shared TypeScript types
│   ├── constants/          # Shared constants
│   ├── config/             # Shared configuration
│   └── utils/              # Cross-platform utilities
│
├── scripts/                 # 🛠️  BUILD & DEPLOYMENT
│   ├── build.sh            # Build all apps
│   ├── deploy.sh           # Deploy script
│   ├── setup-dev.sh        # Development setup
│   └── ...                 # Additional scripts
│
├── docs/                    # 📚 DOCUMENTATION
│   ├── api/                # API documentation
│   ├── architecture/       # Architecture docs
│   └── guides/             # Developer guides
│
├── .github/                 # GitHub workflows
│   └── workflows/
│       ├── client-ci.yml   # Client CI/CD
│       ├── server-ci.yml   # Server CI/CD
│       └── ...             # Additional workflows
│
├── package.json             # Root package.json (workspace config)
├── tsconfig.json            # Root TypeScript config
├── .gitignore               # Global gitignore
├── README.md                # Project overview
└── ARCHITECTURE_SPEC.md     # This document
```

### Application Naming Conventions

| Folder | Application | Technology Stack | Purpose |
|--------|-------------|------------------|---------|
| `/client` | Web Client | React + Vite + MobX | Customer-facing web application |
| `/admin` | Admin Portal | React + Vite + MobX | Internal admin interface |
| `/server` | Backend API | Node.js + Express | RESTful API server |
| `/iphone` | iOS App | React Native | Native iOS application |
| `/android` | Android App | React Native or Kotlin | Native Android application |
| `/models` | ML Service | Python + Flask/FastAPI | Machine learning models |
| `/desktop` | Desktop App | Electron + React | Cross-platform desktop app |
| `/chrome-ext` | Browser Extension | React + Chrome APIs | Chrome extension |
| `/cli` | CLI Tool | Node.js | Command-line interface |

### Shared Code Strategy

#### `ui/` - Shared UI Components
- **Used by:** `client/`, `admin/`, `desktop/`, `chrome-ext/`
- **Contains:** All React components, Storybook stories
- **Import pattern:** `import { Button } from "ui"`

#### `util/` - Shared Utilities
- **Used by:** All applications
- **Contains:** Helper functions, hooks, validators
- **Import pattern:** `import { classnames } from "util"`

#### `shared/` - Cross-Platform Code
- **Used by:** All applications
- **Contains:** Types, constants, configurations
- **Import pattern:** `import { API_URL } from "shared/constants"`

### Folder Responsibilities

| Folder | Owns | Shared With | Notes |
|--------|------|-------------|-------|
| `ui/` | UI components | All frontend apps | Storybook lives here |
| `util/` | Utilities | All apps | Pure functions, no app-specific code |
| `shared/` | Types, constants | All apps | Cross-platform compatibility |
| `client/` | Web app pages/stores | None | Self-contained application |
| `server/` | API routes/models | None | Backend business logic |
| `iphone/` | iOS screens | None | Mobile-specific code |
| `models/` | ML models | None | Python-specific code |

---

## Frontend Architecture

### Single Frontend App Structure

For projects with **only a web client**, use this simplified structure:

```
project-root/
├── .storybook/
├── ui/                      # Shared components
├── util/                    # Shared utilities
├── client/                  # Web client app
│   ├── pages/
│   ├── store/
│   └── ...
└── package.json             # Single package.json
```

### Multi-Frontend App Structure

For projects with **multiple frontend apps** (web + admin + mobile):

```
project-root/
├── .storybook/
├── ui/                      # Shared components (ALL frontends)
├── util/                    # Shared utilities (ALL apps)
├── client/                  # Customer web app
├── admin/                   # Admin web app
├── iphone/                  # iOS mobile app
└── package.json             # Workspace root
```

### Client Application Structure

Detailed structure for a frontend app (e.g., `/client`):

```
client/
├── pages/                   # Page components
│   ├── home/
│   │   ├── home.page.tsx
│   │   ├── home.scss
│   │   └── index.ts
│   ├── dashboard/
│   └── ...
├── store/                   # MobX stores
│   ├── application.store.tsx
│   ├── domain.store.tsx
│   ├── session.store.tsx
│   ├── ui.store.tsx
│   └── domain/
│       ├── users.domain.tsx
│       └── ...
├── api/                     # API clients
│   ├── when.ts             # Conditional rendering
│   └── ...                 # 60+ utilities
│
├── dts/                     # Custom TypeScript definitions
├── script/                  # Build and utility scripts
├── unit-test/              # Unit tests
│
├── vite.config.ts          # Vite build configuration
├── tsconfig.json           # TypeScript configuration
├── build.conf.ts           # Build target configuration
├── staticwebapp.config.json # Deployment config (Azure)
├── package.json            # Dependencies & scripts
└── .eslintrc               # Linting rules
```

### Folder Responsibilities

| Folder | Purpose | Imports From | Exports To |
|--------|---------|--------------|------------|
| `ui/components/` | Pure UI components | `util/`, other `ui/components/` | `app/`, Storybook |
| `ui/stories/` | Storybook stories & data | `ui/components/`, `util/` | Storybook only |
| `app/client/pages/` | Page compositions | `ui/`, `app/client/store/`, `util/` | `app/client/page-manager.tsx` |
| `app/client/store/` | MobX state stores | `app/client/api/`, `util/` | `app/client/pages/` |
| `util/` | Shared utilities | None (pure functions) | Everywhere |

---

## Component Architecture

### Component Hierarchy

```
Primitive Components (25+)
    ↓ used by
Domain Components (8+)
    ↓ used by
Domain Forms (26+)
    ↓ used by
Layout Components (12+)
    ↓ used by
Page Components (14+)
```

### Component Structure Template

Every component follows this pattern:

```typescript
// ui/components/[category]/[component-name]/[component-name].tsx

import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import classnames from "util/classnames";

// 1. Define CVA with variants
export const ComponentNameCva = cva("ComponentName", {
  variants: {
    mode: {
      Primary: "ComponentName--primary",
      Secondary: "ComponentName--secondary",
      Disabled: "ComponentName--disabled",
    },
    size: {
      Large: "ComponentName--large",
      Medium: "ComponentName--medium",
      Small: "ComponentName--small",
    },
  },
  compoundVariants: [],
  defaultVariants: {
    mode: "Primary",
    size: "Medium",
  },
});

// 2. Define props interface extending VariantProps
export interface IComponentName extends VariantProps<typeof ComponentNameCva.variants> {
  children?: React.ReactNode;
  className?: string;
  containerProps?: React.HTMLAttributes<HTMLDivElement>;
  // Component-specific props
  onAction?: () => void;
}

// 3. Implement component with observer + forwardRef
export const ComponentName = observer(
  React.forwardRef<HTMLDivElement, IComponentName>((props, ref) => {
    const {
      children,
      className,
      mode = ComponentNameCva.defaults?.mode,
      size = ComponentNameCva.defaults?.size,
      containerProps,
      onAction,
    } = props;

    return (
      <div
        ref={ref}
        className={classnames(
          ComponentNameCva.variants({ mode, size }),
          className
        )}
        {...containerProps}
      >
        {children}
      </div>
    );
  })
);

ComponentName.displayName = "ComponentName";
```

### CVA Pattern

#### Custom CVA Wrapper

The architecture uses a **custom CVA wrapper** that provides type-safe enum-like access to variants:

```typescript
// util/cva.ts

import { cva as cvaPackage } from "class-variance-authority";

export const cva = <T>(...args: Parameters<typeof cvaPackage<T>>) => {
  const result = cvaPackage(...args);
  const variantOptions = args[1]?.variants;
  const defaults = args[1]?.defaultVariants;
  const enums = getEnums(variantOptions);

  return {
    variants: result,           // Original CVA function
    defaults,                   // Default variant values
    ...enums                    // Enum objects for type safety
  };
};

function getEnums(variantOptions: any) {
  const enums: any = {};
  if (!variantOptions) return enums;

  for (const key in variantOptions) {
    enums[key] = Object.keys(variantOptions[key]).reduce((acc, variant) => {
      acc[variant] = variant;
      return acc;
    }, {} as any);
  }

  return enums;
}

export { VariantProps } from "class-variance-authority";
```

#### Usage Benefits

```typescript
// Instead of string literals:
<Button mode="Primary" size="Large" />

// Use type-safe enums:
<Button mode={ButtonCva.mode.Primary} size={ButtonCva.size.Large} />

// Access defaults:
const mode = props.mode ?? ButtonCva.defaults?.mode;

// Call CVA function:
const classes = ButtonCva.variants({ mode, size });
```

### Component Categories

#### 1. Primitive Components

**Purpose:** Basic UI building blocks with no business logic

**Examples:**
- `button/` - Clickable buttons with modes (primary, secondary, destructive, link)
- `form-input/` - Text inputs with validation states
- `form-selection/` - Dropdowns, checkboxes, radio buttons
- `icon/` - SVG icon wrapper
- `text-style/` - Typography components
- `modal/` - Base modal container
- `tabs/` - Tab navigation
- `tooltip/` - Tooltips and popovers
- `badge/` - Status badges
- `loading-animation/` - Spinners and loaders

**Requirements:**
- No API calls or data fetching
- No direct store access
- All state passed via props
- All variants documented in Storybook

#### 2. Domain Components

**Purpose:** Business-specific components that compose primitives

**Examples:**
- `kpi/` - Key performance indicator cards
- `panel/` - Data display panels
- `sidebar/` - Navigation sidebars
- `header/` - Page headers

**Requirements:**
- Compose primitive components
- Accept domain data via props (never fetch directly)
- Business logic only for display transformation
- All variants documented in Storybook

#### 3. Domain Form Components

**Purpose:** Complex form workflows with validation

**Examples:**
- `login-form/` - Multi-step login (ID → MFA → Complete)
- `create-account-form/` - Account creation workflow
- `payment-form/` - Payment processing forms

**Pattern:**
```typescript
export interface IFormComponent {
  // Data
  initialData?: FormData;

  // State
  page?: number;
  isLoading?: boolean;

  // Callbacks (return validation errors or boolean)
  onSubmit(data: FormData): Promise<FormSubmissionResult<FormData>>;
  onChangePage?(page: number): void;

  // Optional
  text?: Partial<AllText>; // i18n support
}

export type FormSubmissionResult<T> =
  | boolean                    // Success
  | FieldErrors<T>            // Validation errors
  | void;                     // No-op
```

**Requirements:**
- Use `react-hook-form` for validation
- Use custom `usePagedForm` hook for multi-step forms
- Return validation errors in standard format
- Never directly call APIs (use callbacks)
- Loading states managed internally or via props

#### 4. Layout Components

**Purpose:** Page-level templates that compose domain components

**Examples:**
- `login-layout/` - Login page structure
- `customer-dashboard-layout/` - Customer dashboard template
- `user-management-layout/` - Admin user management template

**Pattern:**
```typescript
export const LayoutComponent = observer(
  React.forwardRef<HTMLDivElement, ILayoutComponent>((props, ref) => {
    // Extract specific children types using groupReactChildren
    const groups = groupReactChildren(props.children);
    const sidebar = groups.get(SideBar);
    const header = groups.get(Header);

    return (
      <div className="Layout">
        {sidebar}
        <div className="Layout__content">
          {header}
          <div className="Layout__body">
            {props.children}
          </div>
        </div>
      </div>
    );
  })
);
```

**Requirements:**
- Accept children for flexible composition
- Provide consistent structure across pages
- Use `groupReactChildren()` for flexible child ordering
- All layouts documented in Storybook

---

## State Management with MobX

### Store Architecture

```
ApplicationStore (singleton)
├── DomainStore       # API data and business logic
├── SessionStore      # User session, auth, URL params
└── UIStore           # UI state transformations
```

### Root Store Pattern

```typescript
// app/client/store/application.store.tsx

import { observable, makeObservable } from "mobx";
import { DomainStore } from "./domain.store";
import { SessionStore } from "./session.store";
import { UIStore } from "./ui.store";

export class ApplicationStore {
  @observable domain = new DomainStore(this);
  @observable session = new SessionStore(this);
  @observable ui = new UIStore(this);

  constructor() {
    makeObservable(this);
  }

  @action
  clear() {
    this.domain = new DomainStore(this);
  }
}

// Singleton instance
export const Application = new ApplicationStore();
```

### Base Store Class

```typescript
// app/client/store/store.tsx

export interface IApplicationStore {
  domain: IDomainStore;
  session: ISessionStore;
  ui: IUIStore;
}

export class Store {
  application: IApplicationStore;

  constructor(app: IApplicationStore) {
    this.application = app;
  }
}
```

All stores extend `Store` to access the root `ApplicationStore`.

### Domain Store Pattern

**Purpose:** Raw API data and business logic

```typescript
// app/client/store/domain/customers.domain.tsx

import { observable, makeObservable } from "mobx";
import { Store } from "../store";
import { ApplicationStore } from "../application.store";
import { createDomainFromAPI } from "util/api";
import { API } from "app/client/api";

export class CustomersDomain extends Store {
  @observable api = createDomainFromAPI(
    this.application,
    API.Customers,
    MOCK.domain?.Customers
  );

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }
}
```

**Requirements:**
- One domain store per API resource
- Use `createDomainFromAPI()` for API integration
- Observable API response state (loading, error, data)
- No UI-specific transformations

### Session Store Pattern

**Purpose:** User authentication, session state, URL parameters

```typescript
// app/client/store/session.store.tsx

export class SessionStore extends Store {
  @observable user?: User;
  @observable token?: string;
  @observable queryParams: string = "";

  @computed
  get queryParamsObject() {
    return parseQueryParams(this.queryParams);
  }

  @computed
  get isAuthenticated() {
    return !!this.token && !!this.user;
  }

  @action
  login(user: User, token: string) {
    this.user = user;
    this.token = token;
  }

  @action
  logout() {
    this.user = undefined;
    this.token = undefined;
  }
}
```

### UI Store Pattern

**Purpose:** Transform domain/session data into component-ready props

```typescript
// app/client/store/ui/admin/user-management.ui.tsx

export class UserManagementUI extends Store {
  // Observable UI state
  @observable selectedUserId?: string;
  @observable searchQuery: string = "";

  // Computed props for components
  @computed
  get userTable(): IUserTable {
    const api = this.application.domain.users.api.listUsers;
    const users = api.data?.payload || [];

    return {
      mode: api.isLoading ? UserTableCva.mode.loading : void 0,
      error: gatherFieldErrors(getFieldErrors(api.error))?.__system__?.message,
      data: users.filter(u =>
        u.name.toLowerCase().includes(this.searchQuery.toLowerCase())
      ),
      selectedId: this.selectedUserId,
      onSelect: this.selectUser,
      onSearch: this.setSearchQuery,
    };
  }

  @computed
  get userForm(): IUserForm {
    const user = this.application.domain.users.api.getUser.data?.payload;

    return {
      initialData: user,
      isLoading: this.application.domain.users.api.updateUser.isLoading,
      onSubmit: this.handleUserUpdate,
    };
  }

  // Actions for UI mutations
  @action
  selectUser = (id: string) => {
    this.selectedUserId = id;
  };

  @action
  setSearchQuery = (query: string) => {
    this.searchQuery = query;
  };

  @action
  handleUserUpdate = async (data: UserFormData) => {
    const result = await this.application.domain.users.api.updateUser(data);
    if (result.success) {
      this.selectedUserId = undefined;
      return true;
    }
    return result.errors; // Return validation errors
  };
}
```

### MobX Decorators Reference

| Decorator | Use Case | Example |
|-----------|----------|---------|
| `@observable` | Mutable state | `@observable count = 0;` |
| `@computed` | Derived state (memoized) | `@computed get double() { return this.count * 2; }` |
| `@action` | State mutations | `@action increment() { this.count++; }` |

### Store Responsibilities

| Store Type | Responsibilities | Does NOT |
|------------|------------------|----------|
| **Domain** | API calls, raw data, business logic | Transform for UI, hold UI state |
| **Session** | Auth, user session, URL params | Store domain data, UI state |
| **UI** | Component props, UI state, transformations | API calls, business logic |

### Page Integration Pattern

```typescript
// app/client/pages/user-management/user-management.page.tsx

import { observer } from "mobx-react";
import { Application } from "store/application.store";
import { UserTable, UserForm, UserManagementLayout } from "ui";
import { useLifecycle } from "util/hooks/use-life-cycle";

export const UserManagementPage = observer(() => {
  const store = Application.ui.admin.userManagement;

  useLifecycle({
    willMount: () => {
      store.refresh(); // Load data on mount
      return true;
    },
  });

  return (
    <UserManagementLayout>
      <UserTable {...store.userTable} />
      {store.selectedUserId && (
        <UserForm {...store.userForm} />
      )}
    </UserManagementLayout>
  );
});
```

**Key Pattern:**
1. Import singleton `Application` store
2. Access UI store for page: `Application.ui.admin.userManagement`
3. Use `useLifecycle` hook for mount/update logic
4. Spread computed props to components: `{...store.userTable}`
5. Pass action methods as event handlers: `onSelect={store.selectUser}`

---

## Storybook Integration

### Configuration

#### Main Configuration

```javascript
// .storybook/main.js

const path = require("path");

module.exports = {
  stories: [
    {
      directory: path.resolve(process.env.PROJECT_ROOT || "", "./ui"),
      files: "**/*.mdx",
    },
    {
      directory: path.resolve(process.env.PROJECT_ROOT || "", "./ui"),
      files: "**/*.stories.@(js|jsx|ts|tsx)",
    },
    {
      directory: path.resolve(process.env.PROJECT_ROOT || "", "./ui"),
      files: "**/*.bugs.@(js|jsx|ts|tsx)",
    },
  ],

  addons: [
    "@storybook/preset-scss",      // SCSS support
    "@storybook/addon-links",       // Story linking
    "@storybook/addon-essentials",  // Core features
    "@storybook/addon-interactions", // Interaction testing
    "@storybook/addon-a11y",        // Accessibility testing
  ],

  framework: {
    name: "@storybook/react-vite",
    options: {},
  },

  staticDirs: [
    path.resolve(process.env.PROJECT_ROOT || "", "./ui/assets"),
    path.resolve(process.env.PROJECT_ROOT || "", "./ui/stories/assets"),
  ],

  typescript: {
    reactDocgen: "react-docgen-typescript",
    reactDocgenTypescriptOptions: {
      include: [
        path.resolve(process.env.PROJECT_ROOT || "", "ui/components/**/**.tsx"),
      ],
    },
  },

  docs: {
    autodocs: false,
    docsMode: false,
  },
};
```

#### Preview Configuration

```javascript
// .storybook/preview.js

export const parameters = {
  actions: { argTypesRegex: "^on[A-Z].*" },
  controls: {
    matchers: {
      color: /(background|color)$/i,
      date: /Date$/,
    },
  },
};
```

#### Global Styles

```html
<!-- .storybook/preview-head.html -->

<style>
  :root {
    /* Color System - Neutral */
    --color-neutral-50: #F9FAFB;
    --color-neutral-100: #F3F4F6;
    --color-neutral-200: #E5E7EB;
    --color-neutral-300: #D1D5DB;
    --color-neutral-400: #9CA3AF;
    --color-neutral-500: #6B7280;
    --color-neutral-600: #4B5563;
    --color-neutral-700: #374151;
    --color-neutral-800: #1F2937;
    --color-neutral-900: #111827;

    /* Color System - Primary */
    --color-primary-50: #FFF1F2;
    --color-primary-100: #FFE4E6;
    /* ... additional color scales */

    /* Color System - Success, Warning, Error, etc. */
    /* ... */
  }

  /* Tailwind-inspired reset */
  *, ::before, ::after {
    box-sizing: border-box;
    border-width: 0;
    border-style: solid;
  }

  body {
    margin: 0;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    line-height: 1.5;
  }

  /* Storybook-specific */
  #storybook-root {
    width: 100vw;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>

<!-- Fonts -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@100..900&display=swap" rel="stylesheet">
```

### Story File Pattern

```typescript
// ui/stories/components/primitive/button.stories.tsx

import type { StoryFn } from "@storybook/react";
import { Button, ButtonCva } from "ui/components/primitive/button/button";
import { cvaOptionsToStorybook } from "util/cva";
import { Center } from "util/storybook-containers/center";

// 1. Export default with component metadata
export default {
  title: "ApplicationUi/primitive/Button",
  component: Button,

  // 2. Auto-generate controls from CVA
  argTypes: {
    ...cvaOptionsToStorybook(ButtonCva),
    children: { table: { disable: true } },
  },
};

// 3. Template pattern
const Template = (children?: any) => (args: any) => (
  <Center>
    <Button {...args}>{children}</Button>
  </Center>
);

// 4. "All" story showing all variants
const AllTemplate = () => (args: any) => (
  <Center column gap={20}>
    <h2>Modes</h2>
    {Object.values(ButtonCva.mode).map(mode => (
      <div key={mode}>
        <h3>{mode}</h3>
        {Object.values(ButtonCva.size).map(size => (
          <Button key={size} mode={mode} size={size} {...args}>
            {mode} - {size}
          </Button>
        ))}
      </div>
    ))}
  </Center>
);

// 5. Export stories
export const All: StoryFn = AllTemplate().bind({});
export const Primary: StoryFn = Template("Primary Button").bind({});
Primary.args = {
  mode: ButtonCva.mode.Primary,
  size: ButtonCva.size.Large,
};

export const Secondary: StoryFn = Template("Secondary Button").bind({});
Secondary.args = {
  mode: ButtonCva.mode.Secondary,
  size: ButtonCva.size.Medium,
};
```

### Props Store Pattern for Stories

For complex components with many props, use MobX stores in Storybook:

```typescript
// ui/stories/data/primitive/form-input-props.tsx

import { observable, action, makeObservable } from "mobx";
import { ReactNode } from "react";
import { IFormInput, FormInputCva } from "ui/components/primitive/form-input/form-input";

class FormInputPropsStore implements IFormInput {
  @observable id = "test";
  @observable mode = FormInputCva.mode.normal;
  @observable label?: ReactNode;
  @observable help?: ReactNode;
  @observable placeholder = "Enter text...";

  constructor() {
    makeObservable(this);
  }

  @action
  withHelp() {
    this.help = "This is some helper text";
    return this;
  }

  @action
  withError() {
    this.help = "Something went wrong";
    this.mode = FormInputCva.mode.error;
    return this;
  }

  @action
  asDisabled() {
    this.mode = FormInputCva.mode.disabled;
    return this;
  }

  @action
  withIcon() {
    // Set icon prop
    return this;
  }
}

export const FormInputProps = () => new FormInputPropsStore();
```

**Usage in Story:**

```typescript
// ui/stories/components/primitive/form-input.stories.tsx

import { FormInputProps } from "ui/stories/data/primitive/form-input-props";

export const WithHelp: StoryFn = () => {
  const props = FormInputProps().withHelp();
  return <FormInput {...props} />;
};

export const WithError: StoryFn = () => {
  const props = FormInputProps().withError();
  return <FormInput {...props} />;
};
```

### CVA to Storybook Controls Utility

```typescript
// util/cva.ts (extended)

export function cvaOptionsToStorybook(cvaResult: any) {
  const argTypes: any = {};

  for (const variantKey in cvaResult) {
    if (variantKey === 'variants' || variantKey === 'defaults') continue;

    const options = Object.keys(cvaResult[variantKey]);
    argTypes[variantKey] = {
      control: { type: 'select' },
      options,
      defaultValue: cvaResult.defaults?.[variantKey],
    };
  }

  return argTypes;
}
```

### Storybook Container Utilities

```typescript
// util/storybook-containers/center.tsx

import React from "react";

export interface ICenter {
  children?: React.ReactNode;
  column?: boolean;
  gap?: number;
}

export const Center: React.FC<ICenter> = ({ children, column, gap }) => (
  <div style={{
    display: 'flex',
    flexDirection: column ? 'column' : 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: gap ? `${gap}px` : '16px',
    padding: '20px',
  }}>
    {children}
  </div>
);
```

### Story Organization Rules

1. **Mirror component structure:** `ui/stories/components/` should mirror `ui/components/`
2. **One story file per component:** `button.stories.tsx` for `button.tsx`
3. **Always include "All" story:** Show all variant combinations
4. **Use descriptive story names:** `export const PrimaryLarge`, not `export const Story1`
5. **Group related stories:** Use Storybook folders matching component categories

---

## DevOps & Build Pipeline

### Package.json Scripts

```json
{
  "scripts": {
    "dev": "devops dev",
    "test": "devops test",
    "storybook": "devops storybook",
    "component": "devops component",
    "page": "devops page",
    "clean": "devops clean",
    "release": "devops release",
    "package": "devops package",
    "ts": "devops ts",
    "pr": "devops pr --repoUrl <REPO_URL> --masterBranch main"
  }
}
```

### DevOps CLI Commands

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run storybook` | Launch Storybook on port 6006 |
| `npm run component` | Generate new component with story boilerplate |
| `npm run page` | Generate new page component |
| `npm test` | Run unit tests |
| `npm run ts` | TypeScript type checking |
| `npm run release` | Build production bundle |
| `npm run pr` | Create pull request with automated checks |

### Vite Configuration

```typescript
// vite.config.ts

import * as Vite from "vite";
import { useDevopsPlugins } from "./node_modules/devops/shim/index.js";

function environmentBuildIncrement(): Vite.Plugin {
  return {
    name: "vite-plugin-build-increment",
    config() {
      // Read/increment build number from cache
      const incrementCachedFile = path.join(
        "node_modules",
        ".cache",
        "devops",
        "persist.local.json"
      );

      let buildIncrement = 0;
      if (fs.existsSync(incrementCachedFile)) {
        const cachedFile = fs.readJSONSync(incrementCachedFile);
        cachedFile.run += 1;
        buildIncrement = cachedFile.run;
      } else {
        buildIncrement = Number(process.env.VITE_BUILD_INCREMENT || "0") + 1;
      }

      fs.ensureDirSync(path.dirname(incrementCachedFile));
      fs.writeJSONSync(incrementCachedFile, { run: buildIncrement });

      process.env.VITE_BUILD_INCREMENT = `${buildIncrement}`;

      return {
        define: {
          "process.env.VITE_BUILD_INCREMENT": JSON.stringify(buildIncrement),
        },
      };
    },
  };
}

export default async (): Promise<Vite.UserConfig> => {
  return {
    plugins: [
      environmentBuildIncrement(),
      ...(await useDevopsPlugins())
    ],
    build: {
      rollupOptions: {
        output: {
          manualChunks: {},
        },
      },
    },
    resolve: {
      alias: {
        config: path.resolve(process.env.PROJECT_ROOT || ".", "./app/config"),
      },
    },
  };
};
```

### Build Targets

```typescript
// build.conf.ts

export const BUILD_TARGETS = [
  "prod",      // Production build
  "dev",       // Development build
  "devhost",   // Development with local host
  "prodhost",  // Production with local host
];
```

Each target has a corresponding environment file:
- `app/config/env.prod.ts`
- `app/config/env.dev.ts`
- `app/config/env.devhost.ts`
- `app/config/env.prodhost.ts`

### Environment Configuration Pattern

```typescript
// app/config/env.base.ts

export interface IEnvironment {
  apiUrl: string;
  apiKey?: string;
  environment: "development" | "production" | "staging";
  version: string;
  buildIncrement: number;
}

export const BaseEnvironment: IEnvironment = {
  apiUrl: "",
  environment: "development",
  version: "1.0.0",
  buildIncrement: Number(process.env.VITE_BUILD_INCREMENT || 0),
};
```

```typescript
// app/config/env.prod.ts

import { IEnvironment, BaseEnvironment } from "./env.base";

export const Environment: IEnvironment = {
  ...BaseEnvironment,
  apiUrl: "https://api.production.com",
  environment: "production",
};
```

### Deployment Configuration

#### Azure Static Web Apps

```json
// staticwebapp.config.json

{
  "navigationFallback": {
    "rewrite": "index.html",
    "exclude": ["/images/*.{png,jpg,gif,ico}", "/*.{css,scss,js}"]
  },
  "routes": [],
  "responseOverrides": {
    "404": {
      "rewrite": "/index.html",
      "statusCode": 200
    }
  }
}
```

---

## Component Generation Workflow

### Overview

The devops package includes a powerful `component` command that scaffolds new components with all necessary files, following the architecture patterns automatically.

### Command Usage

```bash
# Interactive mode (recommended for manual use)
npm run component

# Alternative: Direct devops command
devops component
```

### Interactive Prompts

The component generator will prompt you for:

#### 1. Component Name
```
Message: "Type a name for the component:"
Input: avatar
Result: Component named "Avatar" (auto-converted to PascalCase)
```

**Validation:**
- Name must be unique (not already exist in project)
- Automatically converted to PascalCase for component names
- Files/folders use kebab-case conversion

#### 2. Category Selection
```
Message: "Start typing to select the directory to add your new component:"
Options:
  - container
  - domain
  - domain-form
  - domain-modal
  - domain-panel
  - layout
  - primitive
  - table
  - New... (create new category)
```

**If "New..." selected:**
```
Message: "Type a name for the new directory:"
Input: your-category
Result: New category folder created in kebab-case
```

### Generated Files

For a component named "Avatar" in category "primitive", the generator creates:

#### File Structure
```
ui/
├── components/
│   └── primitive/
│       └── avatar/
│           ├── avatar.tsx       # Component implementation
│           └── avatar.scss      # Component styles
└── stories/
    ├── components/
    │   └── primitive/
    │       └── avatar.stories.tsx   # Storybook story
    └── data/
        └── primitive/
            └── avatar-props.tsx     # Props store for Storybook
```

#### 1. Component File (avatar.tsx)

```typescript
import React from "react";
import { classnames } from "../../../../util/classnames.js";
import { cva, VariantProps } from "../../../../util/cva.js";
import { observer } from "mobx-react";
import "./avatar.scss";

// CVA (Class Variance Authority) variant definitions
export const AvatarCva = cva("Avatar", {
  variants: {
    mode: {},
  },
  defaultVariants: { mode: undefined },
});

// Props interface
export interface IAvatar extends VariantProps<typeof AvatarCva.variants> {
  className?: string;
  containerProps?: React.HTMLProps<HTMLDivElement>;
}

// Main component with React.forwardRef and mobx observer
export const Avatar = observer(
  React.forwardRef<HTMLDivElement, IAvatar>((props: IAvatar, _ref) => {
    const { className, containerProps, mode } = props;

    return (
      <div
        className={classnames(AvatarCva.variants({ mode }), className)}
        {...containerProps}
      ></div>
    );
  })
);
```

**Features:**
- CVA variant system pre-configured
- MobX observer for reactivity
- ForwardRef support
- Type-safe props interface
- Ready for customization

#### 2. Styles File (avatar.scss)

```scss
.Avatar {
  // Add your styles here
}
```

#### 3. Storybook Story (avatar.stories.tsx)

```typescript
import React from "react";
import { StoryFn } from "@storybook/react";
import { cvaOptionsToStorybook } from "../../../../util/cva.js";
import { Avatar, AvatarCva } from "../../../components/index.js";
import { AvatarProps } from "../../data/primitive/avatar-props.js";

export default {
  title: "ApplicationUi/Primitive/Avatar",
  component: Avatar,
  args: {},
  argTypes: {
    ...cvaOptionsToStorybook(AvatarCva),
    children: { table: { disable: true } },
    className: { table: { disable: true } },
    containerProps: { table: { disable: true } },
  },
};

const Template = (children?: any) => (args: any) => (
  <Avatar {...args}>{children}</Avatar>
);

export const Basic: StoryFn = Template().bind({});
Basic.args = AvatarProps();
```

**Features:**
- Hierarchical story organization
- Auto-generated Storybook controls from CVA
- Props factory integration
- Ready to add more story variants

#### 4. Props Store (avatar-props.tsx)

```typescript
import { IAvatar } from "../../../components/index.js";
import { makeObservable, observable } from "mobx";

class Store implements IAvatar {
  @observable className?: string = void 0;

  constructor() {
    makeObservable(this);
  }
}

export const AvatarProps = () => new Store();
```

**Features:**
- MobX observable store
- Type-safe implementation of component interface
- Factory pattern for creating prop instances
- Ready to add builder methods

### Automatic Barrel File Updates

After generation, the command automatically updates barrel exports:

#### Updated File: ui/components/primitive/index.ts
```typescript
// ... existing exports ...
export * from "./avatar/avatar.js";
```

This allows clean imports:
```typescript
import { Avatar } from "ui/components/primitive";
// instead of
import { Avatar } from "ui/components/primitive/avatar/avatar";
```

### Token-Based Template System

The generator uses a token replacement system with case transformations:

#### Available Tokens

| Token | Description | Example Input | Example Output |
|-------|-------------|---------------|----------------|
| `${{component: pascal}}` | Component name (PascalCase) | "user avatar" | `UserAvatar` |
| `${{component: kebab}}` | Component name (kebab-case) | "user avatar" | `user-avatar` |
| `${{component: camel}}` | Component name (camelCase) | "user avatar" | `userAvatar` |
| `${{category: pascal}}` | Category name (PascalCase) | "primitive" | `Primitive` |
| `${{category: kebab}}` | Category name (kebab-case) | "Primitive" | `primitive` |
| `${{project: pascal}}` | Project name | "application-ui" | `ApplicationUi` |

#### Supported Case Transformations

- `pascal` - PascalCase (UpperCamelCase)
- `camel` - camelCase
- `kebab` - kebab-case
- `snake` - snake_case
- `constant` - CONSTANT_CASE
- `upper` - UPPERCASE
- `lower` - lowercase
- `sentence` - Sentence case
- `header` - Header-Case

### Manual Component Generation (Claude-Compatible)

Since the `devops component` command is interactive, here's how to generate components manually (which Claude can help with):

#### Step 1: Create Component Directory
```bash
mkdir -p ui/components/primitive/avatar
```

#### Step 2: Create Component Files

Use the templates above, replacing tokens manually:
- Component name: `Avatar`
- Category: `primitive`
- File names: `avatar.tsx`, `avatar.scss`

#### Step 3: Create Story Files
```bash
mkdir -p ui/stories/components/primitive
mkdir -p ui/stories/data/primitive
```

Create `avatar.stories.tsx` and `avatar-props.tsx` using templates above.

#### Step 4: Update Barrel Exports

Add to `ui/components/primitive/index.ts`:
```typescript
export * from "./avatar/avatar.js";
```

### Claude Workflow for Component Generation

When working with Claude to create components:

**Option A: Use the interactive command yourself**
```bash
# Run this in your terminal
npm run component
# Then ask Claude to help customize the generated files
```

**Option B: Ask Claude to generate files directly**
```
"Create a new Avatar component in the primitive category following the devops template pattern"
```

Claude will:
1. Create all 4 files with proper structure
2. Use the correct naming conventions
3. Follow CVA patterns
4. Set up Storybook integration
5. Update barrel exports

**Option C: Hybrid approach**
```bash
# You: Run the interactive command
npm run component
# Type: avatar
# Select: primitive

# Then ask Claude:
"Review the generated Avatar component and add these variants:
- size: Small, Medium, Large
- status: Online, Offline, Away"
```

### Post-Generation Customization

After generating a component, customize it by:

#### 1. Add CVA Variants
```typescript
export const AvatarCva = cva("Avatar", {
  variants: {
    size: {
      Small: "Avatar--small",
      Medium: "Avatar--medium",
      Large: "Avatar--large",
    },
    status: {
      Online: "Avatar--online",
      Offline: "Avatar--offline",
      Away: "Avatar--away",
    },
  },
  defaultVariants: {
    size: "Medium",
    status: "Offline",
  },
});
```

#### 2. Add Props
```typescript
export interface IAvatar extends VariantProps<typeof AvatarCva.variants> {
  src?: string;
  alt?: string;
  initials?: string;
  className?: string;
  containerProps?: React.HTMLProps<HTMLDivElement>;
  onClick?: () => void;
}
```

#### 3. Implement Component Logic
```typescript
export const Avatar = observer(
  React.forwardRef<HTMLDivElement, IAvatar>((props, ref) => {
    const {
      src,
      alt,
      initials,
      size = AvatarCva.defaults?.size,
      status = AvatarCva.defaults?.status,
      className,
      containerProps,
      onClick,
    } = props;

    return (
      <div
        ref={ref}
        className={classnames(AvatarCva.variants({ size, status }), className)}
        onClick={onClick}
        {...containerProps}
      >
        {src ? (
          <img src={src} alt={alt} />
        ) : (
          <span className="Avatar__initials">{initials}</span>
        )}
        <span className="Avatar__status" />
      </div>
    );
  })
);
```

#### 4. Add Styles
```scss
.Avatar {
  position: relative;
  border-radius: 50%;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;

  &--small { width: 32px; height: 32px; }
  &--medium { width: 48px; height: 48px; }
  &--large { width: 64px; height: 64px; }

  &__status {
    position: absolute;
    bottom: 0;
    right: 0;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 2px solid white;
  }

  &--online &__status { background-color: var(--color-success-500); }
  &--offline &__status { background-color: var(--color-neutral-400); }
  &--away &__status { background-color: var(--color-warning-500); }
}
```

#### 5. Enhance Story
```typescript
export const All: StoryFn = () => (
  <Center column gap={20}>
    <h2>Sizes</h2>
    <Center row gap={10}>
      {Object.values(AvatarCva.size).map(size => (
        <Avatar key={size} size={size} initials="JD" />
      ))}
    </Center>

    <h2>Status</h2>
    <Center row gap={10}>
      {Object.values(AvatarCva.status).map(status => (
        <Avatar key={status} status={status} initials="JD" />
      ))}
    </Center>
  </Center>
);

export const WithImage: StoryFn = Template().bind({});
WithImage.args = {
  src: "https://i.pravatar.cc/150?img=1",
  alt: "User avatar",
  size: AvatarCva.size.Large,
  status: AvatarCva.status.Online,
};

export const WithInitials: StoryFn = Template().bind({});
WithInitials.args = {
  initials: "JD",
  size: AvatarCva.size.Medium,
  status: AvatarCva.status.Away,
};
```

#### 6. Enhance Props Store
```typescript
class Store implements IAvatar {
  @observable src?: string = "https://i.pravatar.cc/150?img=1";
  @observable alt?: string = "User avatar";
  @observable initials?: string = "JD";
  @observable size = AvatarCva.size.Medium;
  @observable status = AvatarCva.status.Offline;
  @observable className?: string;

  constructor() {
    makeObservable(this);
  }

  @action
  withInitials(initials: string) {
    this.initials = initials;
    this.src = undefined;
    return this;
  }

  @action
  withImage(src: string) {
    this.src = src;
    this.initials = undefined;
    return this;
  }

  @action
  asOnline() {
    this.status = AvatarCva.status.Online;
    return this;
  }

  @action
  asLarge() {
    this.size = AvatarCva.size.Large;
    return this;
  }
}

export const AvatarProps = () => new Store();
```

### Component Generation Best Practices

1. **Use descriptive names** - "UserAvatar" not "Avatar1"
2. **Choose the right category** - Primitive for base, Domain for business-specific
3. **Start with minimal variants** - Add more as needed
4. **Write stories first** - Document expected behavior before implementation
5. **Test in Storybook** - Verify all variants render correctly
6. **Update props store** - Add builder methods for common scenarios
7. **Follow naming conventions** - PascalCase components, kebab-case files
8. **Export from barrel** - Keep imports clean

### Related Commands

```bash
# Create new component (interactive)
npm run component

# Edit existing component scaffolding
npm run component edit

# Create new page component
npm run page

# View components in Storybook
npm run storybook

# Type-check after generation
npm run ts
```

---

## TypeScript Configuration

```json
// tsconfig.json

{
  "compilerOptions": {
    "emitDecoratorMetadata": true,
    "esModuleInterop": true,
    "allowUnreachableCode": false,
    "declaration": true,
    "experimentalDecorators": true,
    "jsx": "react",
    "lib": ["es2017", "esnext", "dom"],
    "module": "ESNext",
    "moduleResolution": "node",
    "noImplicitAny": true,
    "noImplicitReturns": false,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "removeComments": false,
    "strict": true,
    "strictNullChecks": true,
    "target": "ES2017",
    "typeRoots": ["./node_modules/@types", "./dts"],
    "skipLibCheck": true,

    "paths": {
      "ui/*": ["./ui/*"],
      "app": ["./app"],
      "util": ["./util"],
      "config/*": ["./app/config/*"]
    },

    "sourceMap": true
  },

  "include": [
    "./app",
    "./ui",
    "./test",
    "./unit-test",
    "./dts",
    "./util"
  ],

  "exclude": ["./node_modules"]
}
```

### Key Configuration Points

| Option | Value | Reason |
|--------|-------|--------|
| `experimentalDecorators` | `true` | Required for MobX decorators |
| `emitDecoratorMetadata` | `true` | Required for MobX decorators |
| `strict` | `true` | Enforce strict type checking |
| `noImplicitAny` | `true` | All variables must have explicit types |
| `strictNullChecks` | `true` | Prevent null/undefined errors |
| `paths` | Custom aliases | Enable `import from "ui/..."` |

---

## Dependencies & Tooling

### Core Dependencies

```json
{
  "devDependencies": {
    "devops": "git+ssh://github.com/vega-studio/node-devops.git#5.2.26",
    "mobx": "6.13.2",
    "mobx-react": "9.1.1",
    "react-hook-form": "7.53.0",
    "react-transition-group": "4.4.5",
    "typescript": "5.6.3",
    "vite": "5.4.10"
  },
  "dependencies": {
    "@types/react": "18.3.16"
  }
}
```

### Required Packages

#### State Management
- `mobx` - Observable state management
- `mobx-react` - React bindings for MobX

#### Forms
- `react-hook-form` - Form validation and state
- `@hookform/resolvers` - Validation resolvers (Joi, Zod)
- `joi` - Schema validation
- `zod` - Alternative schema validation

#### UI & Animation
- `react-transition-group` - Animation transitions
- `class-variance-authority` - CVA for variant styling

#### Build Tools
- `vite` - Build tool and dev server
- `typescript` - Type checking
- `devops` - Custom DevOps CLI (from vega-studio)

#### Storybook
- `@storybook/react-vite` - Storybook with Vite
- `@storybook/addon-essentials` - Core Storybook features
- `@storybook/addon-a11y` - Accessibility testing
- `@storybook/addon-interactions` - Interaction testing
- `@storybook/preset-scss` - SCSS support

#### API Integration
- `swagger-typescript-api` - Generate TypeScript API clients

### Utilities

#### Custom Hooks
- `use-life-cycle` - Component lifecycle management
- `use-paged-form` - Multi-step form validation

#### Utilities
- `classnames` - Class composition
- `when` - Conditional rendering
- `deep-clone` - Object cloning
- `fuzzy` - Fuzzy search

---

## File Naming Conventions

### Components

```
component-name/
├── component-name.tsx        # Component implementation
├── component-name.scss       # Component styles
└── index.ts                  # Re-export
```

**Example:**
```
button/
├── button.tsx
├── button.scss
└── index.ts
```

### Stories

```
component-name.stories.tsx    # Story file
```

**Example:**
```
button.stories.tsx
```

### Stores

```
[domain-name].domain.tsx      # Domain store
[feature-name].ui.tsx         # UI store
session.store.tsx             # Session store
application.store.tsx         # Root store
```

**Examples:**
```
customers.domain.tsx
user-management.ui.tsx
```

### Pages

```
page-name/
├── page-name.page.tsx        # Page component
├── page-name.scss            # Page styles
└── index.ts                  # Re-export
```

**Example:**
```
user-management/
├── user-management.page.tsx
├── user-management.scss
└── index.ts
```

### Utilities

```
utility-name.ts               # Single utility file
```

**Examples:**
```
classnames.ts
when.ts
deep-clone.ts
```

### Case Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `kebab-case` | `user-management.page.tsx` |
| Components | `PascalCase` | `UserManagement` |
| Stores | `PascalCase` | `UserManagementUI` |
| Functions | `camelCase` | `getUserById` |
| Constants | `SCREAMING_SNAKE_CASE` | `BUILD_TARGETS` |
| CSS Classes | `BEM` | `Button--primary` |

---

## Implementation Checklist

### Project Initialization

- [ ] Install dependencies (see Dependencies section)
- [ ] Set up `devops` package from vega-studio/node-devops
- [ ] Configure `tsconfig.json` with paths and strict mode
- [ ] Set up `vite.config.ts` with build increment plugin
- [ ] Create folder structure (`ui/`, `app/`, `util/`, `.storybook/`)

### Storybook Setup

- [ ] Configure `.storybook/main.js` with React Vite framework
- [ ] Add Storybook addons (essentials, a11y, interactions, scss)
- [ ] Create `.storybook/preview-head.html` with CSS variables
- [ ] Set up static directories for assets
- [ ] Configure TypeScript docgen for auto-generated prop docs

### Component System

- [ ] Create `util/cva.ts` wrapper with enum generation
- [ ] Create `util/classnames.ts` for class composition
- [ ] Create `util/when.ts` for conditional rendering
- [ ] Set up `ui/components/primitive/` folder
- [ ] Create base primitive components (Button, FormInput, TextStyle, Icon)
- [ ] Add CVA variants to all primitives
- [ ] Write stories for all primitives with "All" variant showcase

### State Management

- [ ] Set up MobX with decorators enabled in `tsconfig.json`
- [ ] Create `app/client/store/store.tsx` base class
- [ ] Create `app/client/store/application.store.tsx` singleton
- [ ] Create `app/client/store/domain.store.tsx` with API domains
- [ ] Create `app/client/store/session.store.tsx` for auth/session
- [ ] Create `app/client/store/ui.store.tsx` for UI state
- [ ] Implement computed props pattern in UI stores

### Forms

- [ ] Install `react-hook-form` and `@hookform/resolvers`
- [ ] Create `util/hooks/use-paged-form.ts` for multi-step forms
- [ ] Create form validation utilities with Joi/Zod
- [ ] Implement form submission result pattern
- [ ] Create domain form components with validation

### Utilities

- [ ] Create lifecycle hook: `util/hooks/use-life-cycle.ts`
- [ ] Create Storybook containers: `util/storybook-containers/center.tsx`
- [ ] Create CVA to Storybook utility: `cvaOptionsToStorybook()`
- [ ] Add React children utilities: `groupReactChildren()`
- [ ] Add form utilities: validation, error handling

### DevOps

- [ ] Configure build targets in `build.conf.ts`
- [ ] Create environment configs (`env.dev.ts`, `env.prod.ts`)
- [ ] Set up deployment config (`staticwebapp.config.json`)
- [ ] Add npm scripts for dev, storybook, build, release
- [ ] Configure Vite build increment plugin

### Testing & Quality

- [ ] Set up ESLint configuration
- [ ] Configure unit test framework
- [ ] Add accessibility testing in Storybook
- [ ] Implement TypeScript strict mode across project
- [ ] Document all component props with JSDoc

### Documentation

- [ ] Document CVA pattern usage
- [ ] Create component development guidelines
- [ ] Document MobX store patterns
- [ ] Create Storybook writing guide
- [ ] Add README with setup instructions

---

## Summary

This architecture provides:

1. **Component-Driven Development** - Every component testable in Storybook
2. **Type-Safe Variants** - CVA with enum-like access for IntelliSense
3. **Observable State** - MobX with clear separation (Domain/Session/UI)
4. **View-Only Components** - Never directly access stores or APIs
5. **Automated DevOps** - Custom CLI for component generation, builds, releases
6. **Scalable Structure** - Clear hierarchy from primitives to pages

### Key Benefits

- **Developer Experience**: IntelliSense for variants, auto-generated Storybook controls
- **Type Safety**: Strict TypeScript with full typing across components and stores
- **Maintainability**: Clear separation of concerns, predictable patterns
- **Testability**: Every component in Storybook, isolated from business logic
- **Scalability**: Easy to add new components, pages, and features

### Next Steps

1. Use this spec to initialize new projects
2. Run `devops component` to generate new components with boilerplate
3. Run `devops page` to generate new pages
4. Refer to this document for patterns and conventions
5. Update this spec as patterns evolve

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Maintained By:** Development Team
