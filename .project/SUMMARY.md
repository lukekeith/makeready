# Project Template Summary

## What You Have

A **complete full-stack project template** with:

✅ Multi-app monorepo support
✅ React + MobX + Storybook
✅ AI-powered code generation
✅ Zero-manual-work setup
✅ Production-ready patterns

## Key Updates

### Version 2.0 - Multi-App Monorepo Architecture

The template now supports **multiple applications** in a single repository:

- 🌐 **Web clients** (React + Vite)
- 🖥️ **Backend APIs** (Node.js + Express)
- 📱 **Mobile apps** (React Native)
- 🧠 **ML models** (Python)
- 💻 **Desktop apps** (Electron)
- And more...

## Documentation Structure

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **README.md** | Quick start, features, setup | First time setup |
| **QUICKSTART.md** | 4-step setup guide | When creating new project |
| **ARCHITECTURE_SPEC.md** | Complete patterns | When building features |
| **MONOREPO_GUIDE.md** | Multi-app patterns | When adding more apps |
| **PACKAGE_LIST.md** | Distribution options | When sharing template |
| **SETUP_SCRIPT.md** | Manual setup | If script fails |

## Quick Reference

### Single Frontend App

```
project/
├── ui/          # Components
├── util/        # Utilities
├── client/      # Web app
└── package.json
```

**Use when:** Just need a web application.

### Multi-App Monorepo

```
project/
├── ui/          # Shared components
├── util/        # Shared utilities
├── shared/      # Shared types
├── client/      # Web app
├── server/      # Backend
├── iphone/      # iOS app
└── package.json # Workspace root
```

**Use when:** Building full-stack with frontend + backend + mobile.

## Folder Naming Conventions

| App Type | Folder Name | Technology |
|----------|-------------|------------|
| Web client | `/client` | React + Vite |
| Admin portal | `/admin` | React + Vite |
| Backend API | `/server` | Node.js |
| iOS app | `/iphone` | React Native |
| Android app | `/android` | React Native |
| ML models | `/models` | Python |
| Desktop | `/desktop` | Electron |

**Rule:** Use clear, specific names. `/client` not `/app`, `/server` not `/backend-service`.

## Shared Code

### `/ui` - Components
- Used by all React-based apps
- Contains Storybook
- Import: `import { Button } from "ui"`

### `/util` - Utilities
- Used by all apps
- Pure functions
- Import: `import { classnames } from "util"`

### `/shared` - Types/Constants
- Used by all apps
- Cross-platform code
- Import: `import { User } from "shared/types"`

## Getting Started

### 1. Create Project
```bash
mkdir my-app
cp -r /path/to/.project my-app/
cd my-app
```

### 2. Run Setup
```bash
bash .project/setup-architecture.sh
# Enter project name when prompted
# Wait for dependencies to install (~5-10 min)
```

### 3. Start Building
```bash
npm run storybook           # Component development
/component button           # Generate component (Claude)
npm run dev                 # Start dev server
```

## Adding More Apps

### Add Backend API

```bash
mkdir server
cd server
npm init -y

# Create structure
mkdir -p src/{routes,controllers,models,middleware}
touch src/index.ts

# Install dependencies
npm install express
npm install -D typescript @types/express
```

**Update root package.json:**
```json
{
  "workspaces": ["client", "server"],
  "scripts": {
    "dev": "concurrently \"npm run dev:client\" \"npm run dev:server\"",
    "dev:client": "npm run dev --workspace=client",
    "dev:server": "npm run dev --workspace=server"
  }
}
```

### Add iOS App

```bash
mkdir iphone
cd iphone
npx react-native init MyApp --template react-native-template-typescript
```

**Share components:**
```typescript
// iphone/src/screens/Home.tsx
import { Button } from "ui";  // Reuse web components!
```

### Add Python ML Service

```bash
mkdir models
cd models

# Create structure
mkdir -p src/{training,inference}
touch src/api.py requirements.txt

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask numpy scikit-learn
pip freeze > requirements.txt
```

## Claude Commands

### Generate Components
```bash
/component button                    # Interactive mode
/component avatar primitive --with-logic --with-styles
```

### Generate Pages
```bash
/page dashboard --with-store
```

### Add Variants
```bash
/variants button '{"size": ["Small", "Medium", "Large"]}'
```

### Generate Stores
```bash
/store ui admin.notifications
```

## Common Patterns

### Pattern 1: Shared Types

```typescript
// shared/types/user.ts
export interface User {
  id: string;
  name: string;
}

// client/pages/profile.tsx
import { User } from "shared/types";

// server/routes/users.ts
import { User } from "shared/types";
```

### Pattern 2: Shared Constants

```typescript
// shared/constants/api.ts
export const API_URL = "https://api.example.com";

// client/api/client.ts
import { API_URL } from "shared/constants";

// iphone/src/api/client.ts
import { API_URL } from "shared/constants";
```

### Pattern 3: Component Reuse

```typescript
// ui/components/primitive/button/button.tsx
export const Button = () => { ... };

// client/pages/home.tsx
import { Button } from "ui";

// iphone/src/screens/Home.tsx
import { Button } from "ui";  // Same component!
```

## Deployment

### Single App
```bash
npm run build
npm run deploy
```

### Multi-App (Independent)
```bash
npm run build --workspace=client
npm run deploy --workspace=client

npm run build --workspace=server
npm run deploy --workspace=server
```

### Multi-App (Together)
```bash
npm run build --workspaces
npm run deploy
```

## Best Practices

1. **Clear boundaries** - Each app is self-contained
2. **Shared code only in ui/util/shared** - No circular dependencies
3. **Consistent structure** - All apps follow same patterns
4. **Document everything** - Each app has README
5. **Test together** - Ensure all apps work as system

## Troubleshooting

### Can't import from `ui/`
**Fix:** Check `tsconfig.json` paths:
```json
{
  "compilerOptions": {
    "paths": {
      "ui/*": ["../ui/*"],
      "util/*": ["../util/*"]
    }
  }
}
```

### Workspace install fails
**Fix:**
```bash
rm -rf node_modules */node_modules
npm cache clean --force
npm install
```

### Build fails for one app
**Fix:**
```bash
npm run build --workspace=server --verbose
# Check logs for specific error
```

## Resources

- **ARCHITECTURE_SPEC.md** - Complete architecture patterns
- **MONOREPO_GUIDE.md** - Detailed monorepo guide
- **.claude/commands/** - Claude command docs
- **Reference project** - tax-guardian-client

## Next Steps

1. ✅ Set up project with script
2. ✅ Generate first component
3. ✅ Add more apps as needed
4. ✅ Share code via ui/util/shared
5. ✅ Deploy independently or together

---

**Template Version:** 2.0
**Last Updated:** 2025-10-25
**License:** MIT
