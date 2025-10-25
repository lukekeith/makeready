# Monorepo Architecture Guide

## Overview

This architecture supports **multiple applications in a single repository** (monorepo), allowing you to build full-stack applications with shared code.

## When to Use Monorepo Structure

### ✅ Use Monorepo When:
- Building full-stack applications (frontend + backend)
- Multiple related applications (web + mobile + admin)
- Sharing code between applications (components, utilities, types)
- Want unified versioning and deployment
- Need atomic cross-app changes

### ❌ Use Separate Repos When:
- Completely independent applications
- Different teams with no overlap
- Different release cycles
- Different technology stacks with no sharing

## Monorepo Patterns

### Pattern 1: Single Frontend App (Simplified)

**Use case:** Just a web client, no other apps yet.

```
project-root/
├── .storybook/
├── ui/                      # Components
├── util/                    # Utilities
├── client/                  # Web app
└── package.json
```

**Setup:**
```bash
bash .project/setup-architecture.sh
# Select: "Single web client only"
```

### Pattern 2: Frontend + Backend

**Use case:** Web client with Node.js API.

```
project-root/
├── .storybook/
├── ui/                      # Shared components
├── util/                    # Shared utilities
├── client/                  # Web client (React)
├── server/                  # Backend API (Node.js)
└── package.json             # Workspace root
```

**Setup:**
```bash
bash .project/setup-architecture.sh
# Select: "Frontend + Backend"
```

**Commands:**
```bash
# Start both
npm run dev

# Start individually
npm run dev:client
npm run dev:server

# Build both
npm run build

# Deploy
npm run deploy
```

### Pattern 3: Multi-Platform (Web + Mobile)

**Use case:** Web app + iOS/Android apps sharing components.

```
project-root/
├── .storybook/
├── ui/                      # Shared components (web + mobile)
├── util/                    # Shared utilities
├── client/                  # Web client
├── iphone/                  # iOS app (React Native)
├── android/                 # Android app (React Native)
└── package.json
```

**Shared Code:**
- `ui/` components work in both web and React Native
- `util/` utilities are platform-agnostic
- Business logic in `shared/` folder

### Pattern 4: Full Stack (Everything)

**Use case:** Complete product with web, mobile, backend, ML models.

```
project-root/
├── ui/                      # Shared UI
├── util/                    # Shared utilities
├── shared/                  # Shared types/constants
├── client/                  # Web client
├── admin/                   # Admin portal
├── server/                  # Backend API
├── iphone/                  # iOS app
├── models/                  # ML models (Python)
├── desktop/                 # Desktop app (Electron)
└── scripts/                 # Build/deploy scripts
```

## Application Folder Naming

### Recommended Names

| App Type | Folder Name | Alt Names | Technology |
|----------|-------------|-----------|------------|
| **Frontend** | `/client` | `/web`, `/frontend`, `/app` | React + Vite |
| **Admin Portal** | `/admin` | `/admin-portal`, `/backoffice` | React + Vite |
| **Backend API** | `/server` | `/api`, `/backend` | Node.js + Express |
| **iOS** | `/iphone` | `/ios`, `/mobile-ios` | React Native |
| **Android** | `/android` | `/mobile-android` | React Native/Kotlin |
| **ML Models** | `/models` | `/ml`, `/ai`, `/ml-service` | Python + Flask |
| **Desktop** | `/desktop` | `/electron` | Electron + React |
| **Browser Extension** | `/chrome-ext` | `/extension` | React + Chrome APIs |
| **CLI Tool** | `/cli` | `/command-line` | Node.js |
| **Worker Service** | `/worker` | `/jobs`, `/queue` | Node.js |

### Naming Rules

1. **Use singular or descriptive names**: `/client` not `/clients`
2. **Be specific for platform**: `/iphone` and `/android`, not `/mobile`
3. **Use common conventions**: `/server` not `/backend-api-service`
4. **Keep it short**: `/admin` not `/admin-portal-application`
5. **Avoid generic names**: `/app` is ambiguous (which app?)

## Shared Code Organization

### `/ui` - Shared UI Components

**Used by:** All React-based apps (web, mobile with React Native Web, Electron)

**Contains:**
- Components (Button, Input, etc.)
- Storybook stories
- Assets (icons, fonts)
- Animations

**Import:**
```typescript
import { Button, FormInput } from "ui";
import { ButtonCva } from "ui";
```

### `/util` - Shared Utilities

**Used by:** All applications

**Contains:**
- Pure functions
- Custom hooks
- Validators
- Helpers

**Import:**
```typescript
import { classnames, when } from "util";
import { useLifecycle } from "util/hooks";
```

### `/shared` - Cross-Platform Code

**Used by:** All applications

**Contains:**
- TypeScript types/interfaces
- Constants
- Configuration
- API type definitions

**Import:**
```typescript
import { User, API_URL } from "shared/types";
import { MAX_UPLOAD_SIZE } from "shared/constants";
```

## Package Management

### Workspace Configuration

**Root `package.json`:**
```json
{
  "name": "my-app-monorepo",
  "private": true,
  "workspaces": [
    "client",
    "server",
    "iphone",
    "models"
  ],
  "scripts": {
    "dev": "concurrently \"npm run dev:client\" \"npm run dev:server\"",
    "dev:client": "npm run dev --workspace=client",
    "dev:server": "npm run dev --workspace=server",
    "build": "npm run build --workspaces",
    "test": "npm run test --workspaces",
    "storybook": "npm run storybook --workspace=client"
  },
  "devDependencies": {
    "concurrently": "^8.0.0"
  }
}
```

### Installing Dependencies

```bash
# Install for all workspaces
npm install

# Install for specific workspace
npm install axios --workspace=client
npm install express --workspace=server

# Install at root (shared)
npm install typescript -D
```

## Development Workflow

### Starting Development

```bash
# Start everything
npm run dev

# Start specific apps
npm run dev:client      # Web client
npm run dev:server      # Backend API
npm run dev:iphone      # iOS (simulator)
```

### Building

```bash
# Build all apps
npm run build

# Build specific app
npm run build:client
npm run build:server
```

### Testing

```bash
# Test all apps
npm test

# Test specific app
npm test --workspace=client
npm test --workspace=server
```

## Deployment Strategies

### Strategy 1: Monolithic Deployment

Deploy all apps together from single repo.

**Pros:**
- Atomic deployments
- Single CI/CD pipeline
- Coordinated releases

**Cons:**
- All apps deploy together
- Slower deployments

### Strategy 2: Independent Deployment

Deploy each app independently.

**Pros:**
- Fast deployments
- Independent scaling
- Deploy only what changed

**Cons:**
- More complex CI/CD
- Version management

### Strategy 3: Hybrid

Deploy frontend and backend separately, but coordinate releases.

## CI/CD Configuration

### GitHub Actions Example

```yaml
# .github/workflows/ci.yml

name: CI

on: [push, pull_request]

jobs:
  test-client:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm install
      - run: npm test --workspace=client

  test-server:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm install
      - run: npm test --workspace=server

  deploy-client:
    needs: test-client
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm install
      - run: npm run build --workspace=client
      - run: npm run deploy --workspace=client

  deploy-server:
    needs: test-server
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm install
      - run: npm run build --workspace=server
      - run: npm run deploy --workspace=server
```

## Common Patterns

### Pattern: Shared Types

**Problem:** Frontend and backend need same type definitions.

**Solution:** Define types in `/shared/types/`

```typescript
// shared/types/user.ts
export interface User {
  id: string;
  name: string;
  email: string;
}

// client/pages/profile.tsx
import { User } from "shared/types";

// server/routes/users.ts
import { User } from "shared/types";
```

### Pattern: Shared Constants

**Problem:** API URLs, config values needed everywhere.

**Solution:** Define in `/shared/constants/`

```typescript
// shared/constants/api.ts
export const API_URL = process.env.API_URL || "http://localhost:3000";
export const API_TIMEOUT = 30000;

// client/api/client.ts
import { API_URL } from "shared/constants";

// iphone/src/api/client.ts
import { API_URL } from "shared/constants";
```

### Pattern: Shared Utilities

**Problem:** Same helper functions needed in multiple apps.

**Solution:** Put in `/util/`

```typescript
// util/format-date.ts
export function formatDate(date: Date): string {
  return date.toISOString();
}

// Used everywhere
import { formatDate } from "util";
```

### Pattern: Component Reuse

**Problem:** Want same components in web and mobile.

**Solution:** Use React Native Web or platform-specific components.

```typescript
// ui/components/primitive/button/button.tsx
// Works in both web and React Native

// client/pages/home.tsx
import { Button } from "ui";

// iphone/src/screens/Home.tsx
import { Button } from "ui";  // Same component!
```

## Best Practices

### 1. Clear Boundaries
- Each app folder is self-contained
- Shared code only in `ui/`, `util/`, `shared/`
- No circular dependencies

### 2. Consistent Structure
- All frontend apps follow same structure
- All have `pages/`, `store/`, `api/`
- Easy to navigate

### 3. Shared Tooling
- Single ESLint config
- Single TypeScript config (with extends)
- Single Prettier config

### 4. Atomic Commits
- Changes span multiple apps
- All tests pass together
- Deploy together if needed

### 5. Documentation
- Each app has README.md
- Root README.md explains monorepo
- Architecture docs at root

## Troubleshooting

### TypeScript Can't Find Imports

**Problem:** `Cannot find module 'ui'`

**Solution:** Check `tsconfig.json` paths:
```json
{
  "compilerOptions": {
    "paths": {
      "ui/*": ["../ui/*"],
      "util/*": ["../util/*"],
      "shared/*": ["../shared/*"]
    }
  }
}
```

### Workspace Install Fails

**Problem:** `npm install` fails in workspace

**Solution:**
```bash
# Clear cache
npm cache clean --force

# Remove node_modules
rm -rf node_modules
rm -rf client/node_modules
rm -rf server/node_modules

# Reinstall
npm install
```

### Build Fails for One App

**Problem:** Client builds but server fails

**Solution:**
```bash
# Build individually
npm run build --workspace=server

# Check logs
npm run build --workspace=server --verbose
```

## Migration Guides

### From Single App to Monorepo

1. **Create new folder for existing app:**
   ```bash
   mkdir client
   mv app/ ui/ util/ client/
   ```

2. **Set up workspace:**
   ```bash
   # Update root package.json
   npm init -w client
   ```

3. **Update imports:**
   ```bash
   # Update tsconfig.json paths
   # Update vite.config.ts
   ```

### From Separate Repos to Monorepo

1. **Create monorepo structure**
2. **Copy each app into its folder**
3. **Extract shared code to `ui/`, `util/`, `shared/`**
4. **Update imports and configs**
5. **Set up workspaces**

## Examples

See [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md) for complete examples of each pattern.
