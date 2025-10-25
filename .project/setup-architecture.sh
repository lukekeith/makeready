#!/bin/bash

# Frontend Architecture - Zero-Manual-Work Setup
# Creates a fully configured React + MobX + Storybook project
#
# Usage:
#   1. mkdir my-new-project
#   2. cp -r .project my-new-project/
#   3. cd my-new-project
#   4. bash .project/setup-architecture.sh
#   5. Start building!

set -e  # Exit on error

PROJECT_ROOT="."
TEMPLATE_DIR=".project"

echo "🚀 Frontend Architecture - Zero-Manual-Work Setup"
echo "=================================================="
echo ""

# Determine if we're in the template directory or project root
if [ -f "setup-architecture.sh" ]; then
  # We're inside .project, so project root is parent
  PROJECT_ROOT=".."
  TEMPLATE_DIR="."
fi

echo "📁 Project root: $PROJECT_ROOT"
echo ""

# Prompt for project name
read -p "Enter project name (e.g., my-awesome-app): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="my-app"
fi

echo ""
echo "Setting up project: $PROJECT_NAME"
echo ""

# ============================================================================
# STEP 1: Create Folder Structure
# ============================================================================
echo "📁 Step 1/8: Creating folder structure..."

mkdir -p "$PROJECT_ROOT/ui/components/primitive"
mkdir -p "$PROJECT_ROOT/ui/components/domain"
mkdir -p "$PROJECT_ROOT/ui/components/domain-form"
mkdir -p "$PROJECT_ROOT/ui/components/layout"
mkdir -p "$PROJECT_ROOT/ui/components/table"
mkdir -p "$PROJECT_ROOT/ui/components/container"
mkdir -p "$PROJECT_ROOT/ui/components/domain-modal"
mkdir -p "$PROJECT_ROOT/ui/components/domain-panel"

mkdir -p "$PROJECT_ROOT/ui/stories/components"
mkdir -p "$PROJECT_ROOT/ui/stories/data"
mkdir -p "$PROJECT_ROOT/ui/stories/assets"

mkdir -p "$PROJECT_ROOT/ui/assets"

mkdir -p "$PROJECT_ROOT/app/client/pages"
mkdir -p "$PROJECT_ROOT/app/client/store/domain"
mkdir -p "$PROJECT_ROOT/app/client/store/ui/admin"
mkdir -p "$PROJECT_ROOT/app/client/store/ui/customer"
mkdir -p "$PROJECT_ROOT/app/client/api"
mkdir -p "$PROJECT_ROOT/app/client/styles"
mkdir -p "$PROJECT_ROOT/app/server"
mkdir -p "$PROJECT_ROOT/app/config"

mkdir -p "$PROJECT_ROOT/util/hooks"
mkdir -p "$PROJECT_ROOT/util/joi"
mkdir -p "$PROJECT_ROOT/util/storybook-containers"

mkdir -p "$PROJECT_ROOT/.storybook"
mkdir -p "$PROJECT_ROOT/dts"
mkdir -p "$PROJECT_ROOT/script"
mkdir -p "$PROJECT_ROOT/unit-test"

echo "✅ Folder structure created"

# ============================================================================
# STEP 2: Copy Documentation & Commands
# ============================================================================
echo ""
echo "📄 Step 2/8: Copying documentation and Claude commands..."

cp "$TEMPLATE_DIR/ARCHITECTURE_SPEC.md" "$PROJECT_ROOT/"
cp -r "$TEMPLATE_DIR/.claude" "$PROJECT_ROOT/"

echo "✅ Documentation and commands copied"

# ============================================================================
# STEP 3: Initialize Git
# ============================================================================
echo ""
echo "🔧 Step 3/8: Initializing git repository..."

cd "$PROJECT_ROOT"

if [ ! -d ".git" ]; then
  git init
  echo "✅ Git initialized"
else
  echo "✅ Git already initialized"
fi

# Create .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
package-lock.json
yarn.lock

# Build outputs
dist/
build/
.cache/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log
npm-debug.log*

# Testing
coverage/

# Misc
.project/
EOF

echo "✅ .gitignore created"

# ============================================================================
# STEP 4: Create package.json
# ============================================================================
echo ""
echo "📦 Step 4/8: Creating package.json..."

cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "main": "./dist/ui/index.js",
  "type": "module",
  "types": "./dist/types/ui/index.d.ts",
  "scripts": {
    "dev": "devops dev",
    "test": "devops test",
    "clean": "devops clean",
    "component": "devops component",
    "page": "devops page",
    "storybook": "devops storybook",
    "release": "devops release",
    "package": "devops package",
    "ts": "devops ts"
  },
  "devDependencies": {
    "@hookform/resolvers": "3.9.0",
    "@types/react": "18.3.16",
    "@types/react-dom": "18.3.5",
    "@types/react-transition-group": "4.4.11",
    "devops": "git+ssh://github.com/vega-studio/node-devops.git#5.2.26",
    "express": "4.21.1",
    "fuzzy": "0.1.3",
    "joi": "17.13.3",
    "mobx": "6.13.2",
    "mobx-react": "9.1.1",
    "react-hook-form": "7.53.0",
    "react-transition-group": "4.4.5",
    "typescript": "5.6.3",
    "vite": "5.4.10"
  },
  "dependencies": {},
  "keywords": [],
  "author": "",
  "license": "MIT"
}
EOF

echo "✅ package.json created"

# ============================================================================
# STEP 5: Create Core Configuration Files
# ============================================================================
echo ""
echo "⚙️  Step 5/8: Creating configuration files..."

# TypeScript Configuration
cat > tsconfig.json << 'EOF'
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
    "sourceMap": true,
    "paths": {
      "ui/*": ["./ui/*"],
      "app": ["./app"],
      "util": ["./util"],
      "config/*": ["./app/config/*"]
    }
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
EOF

# Vite Configuration
cat > vite.config.ts << 'EOF'
import * as Vite from "vite";
import path from "path";

export default async (): Promise<Vite.UserConfig> => {
  return {
    plugins: [],
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
        ui: path.resolve(process.env.PROJECT_ROOT || ".", "./ui"),
        util: path.resolve(process.env.PROJECT_ROOT || ".", "./util"),
        app: path.resolve(process.env.PROJECT_ROOT || ".", "./app"),
      },
    },
  };
};
EOF

# Build Configuration
cat > build.conf.ts << 'EOF'
export const BUILD_TARGETS = ["dev", "prod"];
EOF

# Storybook Main Config
cat > .storybook/main.js << 'EOF'
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
  ],
  addons: [
    "@storybook/preset-scss",
    "@storybook/addon-links",
    "@storybook/addon-essentials",
    "@storybook/addon-interactions",
    "@storybook/addon-a11y",
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
EOF

# Storybook Preview Config
cat > .storybook/preview.js << 'EOF'
export const parameters = {
  actions: { argTypesRegex: "^on[A-Z].*" },
  controls: {
    matchers: {
      color: /(background|color)$/i,
      date: /Date$/,
    },
  },
};
EOF

# Storybook Preview Head (CSS Variables)
cat > .storybook/preview-head.html << 'EOF'
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
    --color-primary-500: #EF4444;
    --color-primary-600: #DC2626;
    --color-primary-700: #B91C1C;

    /* Color System - Success */
    --color-success-500: #10B981;
    --color-success-600: #059669;
    --color-success-700: #047857;

    /* Color System - Warning */
    --color-warning-500: #F59E0B;
    --color-warning-600: #D97706;
    --color-warning-700: #B45309;

    /* Color System - Error */
    --color-error-500: #EF4444;
    --color-error-600: #DC2626;
    --color-error-700: #B91C1C;
  }

  /* Reset */
  *, ::before, ::after {
    box-sizing: border-box;
    border-width: 0;
    border-style: solid;
  }

  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  #storybook-root {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
EOF

echo "✅ Configuration files created"

# ============================================================================
# STEP 6: Create Core Utility Files
# ============================================================================
echo ""
echo "🔧 Step 6/8: Creating core utility files..."

# CVA Wrapper
cat > util/cva.ts << 'EOF'
import { cva as cvaPackage } from "class-variance-authority";

/**
 * Custom CVA wrapper that provides enum-like access to variants
 */
export const cva = <T>(...args: Parameters<typeof cvaPackage<T>>) => {
  const result = cvaPackage(...args);
  const variantOptions = args[1]?.variants;
  const defaults = args[1]?.defaultVariants;
  const enums = getEnums(variantOptions);

  return {
    variants: result,
    defaults,
    ...enums,
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

/**
 * Convert CVA options to Storybook argTypes
 */
export function cvaOptionsToStorybook(cvaResult: any) {
  const argTypes: any = {};

  for (const variantKey in cvaResult) {
    if (variantKey === "variants" || variantKey === "defaults") continue;

    const options = Object.keys(cvaResult[variantKey]);
    argTypes[variantKey] = {
      control: { type: "select" },
      options,
      defaultValue: cvaResult.defaults?.[variantKey],
    };
  }

  return argTypes;
}
EOF

# Classnames Utility
cat > util/classnames.ts << 'EOF'
/**
 * Simple classnames utility for composing class strings
 */
export function classnames(...classes: (string | undefined | null | false)[]) {
  return classes.filter(Boolean).join(" ");
}

export default classnames;
EOF

# When Utility
cat > util/when.ts << 'EOF'
/**
 * Conditional rendering utility
 * Usage: when(condition, <Component />)
 */
export function when<T>(condition: T | undefined | null | false, render: T | ((value: T) => React.ReactNode)): React.ReactNode {
  if (!condition) return null;
  if (typeof render === "function") {
    return (render as (value: T) => React.ReactNode)(condition);
  }
  return render as React.ReactNode;
}

export default when;
EOF

# Lifecycle Hook
cat > util/hooks/use-life-cycle.ts << 'EOF'
import { useEffect, useRef } from "react";

export interface ILifecycle {
  willMount?: () => boolean | void;
  didMount?: () => void;
  willUpdate?: () => void;
}

/**
 * Component lifecycle hook
 */
export function useLifecycle(lifecycle: ILifecycle) {
  const mountedRef = useRef(false);

  useEffect(() => {
    if (!mountedRef.current) {
      const shouldContinue = lifecycle.willMount?.();
      if (shouldContinue === false) return;

      mountedRef.current = true;
      lifecycle.didMount?.();
    } else {
      lifecycle.willUpdate?.();
    }
  });
}
EOF

# Storybook Center Container
cat > util/storybook-containers/center.tsx << 'EOF'
import React from "react";

export interface ICenter {
  children?: React.ReactNode;
  column?: boolean;
  row?: boolean;
  gap?: number;
}

export const Center: React.FC<ICenter> = ({ children, column, row, gap = 16 }) => (
  <div
    style={{
      display: "flex",
      flexDirection: column || (!row && !column) ? "column" : "row",
      alignItems: "center",
      justifyContent: "center",
      gap: `${gap}px`,
      padding: "20px",
      width: "100%",
      minHeight: "200px",
    }}
  >
    {children}
  </div>
);
EOF

echo "✅ Core utilities created"

# ============================================================================
# STEP 7: Create Base Store Files
# ============================================================================
echo ""
echo "🗄️  Step 7/8: Creating base store files..."

# Base Store Class
cat > app/client/store/store.tsx << 'EOF'
export interface IApplicationStore {
  domain: IDomainStore;
  session: ISessionStore;
  ui: IUIStore;
}

export interface IDomainStore {
  // Add domain stores here
}

export interface ISessionStore {
  // Session properties
}

export interface IUIStore {
  // UI stores
}

export class Store {
  application: IApplicationStore;

  constructor(app: IApplicationStore) {
    this.application = app;
  }
}
EOF

# Application Store
cat > app/client/store/application.store.tsx << 'EOF'
import { observable, action, makeObservable } from "mobx";
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

export const Application = new ApplicationStore();
EOF

# Domain Store
cat > app/client/store/domain.store.tsx << 'EOF'
import { makeObservable } from "mobx";
import { Store } from "./store";
import { ApplicationStore } from "./application.store";

export class DomainStore extends Store {
  // Add domain stores here
  // Example:
  // @observable users = new UsersDomain(this.application);

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }
}
EOF

# Session Store
cat > app/client/store/session.store.tsx << 'EOF'
import { observable, makeObservable } from "mobx";
import { Store } from "./store";
import { ApplicationStore } from "./application.store";

export class SessionStore extends Store {
  @observable queryParams: string = "";

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }
}
EOF

# UI Store
cat > app/client/store/ui.store.tsx << 'EOF'
import { observable, makeObservable } from "mobx";
import { Store } from "./store";
import { ApplicationStore } from "./application.store";

export class UIStore extends Store {
  @observable admin: any = {};
  @observable customer: any = {};

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }
}
EOF

echo "✅ Base store files created"

# ============================================================================
# STEP 8: Create Barrel Exports and Initial Files
# ============================================================================
echo ""
echo "📦 Step 8/8: Creating barrel exports and initial files..."

# UI Component Barrel Exports
for category in primitive domain domain-form layout table container domain-modal domain-panel; do
  cat > "ui/components/$category/index.ts" << EOF
// Export all $category components
// Components will be added here automatically by /component command
EOF
done

# Main UI Export
cat > ui/index.ts << 'EOF'
// Export all UI components
export * from "./components/primitive";
export * from "./components/domain";
export * from "./components/domain-form";
export * from "./components/layout";
export * from "./components/table";
export * from "./components/container";
export * from "./components/domain-modal";
export * from "./components/domain-panel";
EOF

# Util Index
cat > util/index.ts << 'EOF'
export * from "./cva";
export * from "./classnames";
export * from "./when";
export * from "./hooks/use-life-cycle";
export * from "./storybook-containers/center";
EOF

# README
cat > README.md << EOF
# $PROJECT_NAME

A React application built with MobX, Storybook, and TypeScript.

## Architecture

This project follows the architecture patterns documented in [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md).

## Getting Started

### Install Dependencies
\`\`\`bash
npm install
\`\`\`

### Start Development Server
\`\`\`bash
npm run dev
\`\`\`

### Start Storybook
\`\`\`bash
npm run storybook
\`\`\`

## Component Generation

Use Claude commands for AI-powered code generation:

\`\`\`bash
# Generate a component (interactive mode)
/component button

# Generate a page
/page home --with-store

# Add variants to a component
/variants button '{"size": ["Small", "Medium", "Large"]}'

# Generate a store
/store ui app.navigation
\`\`\`

See [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md) for complete documentation.

## Project Structure

\`\`\`
├── ui/                   # UI component library
│   ├── components/       # Components organized by category
│   └── stories/          # Storybook stories
├── app/                  # Application logic
│   ├── client/           # Client-side code
│   │   ├── pages/        # Page components
│   │   └── store/        # MobX stores
│   └── server/           # Server code
├── util/                 # Shared utilities
└── .claude/             # Claude AI commands
\`\`\`

## Scripts

- \`npm run dev\` - Start development server
- \`npm run storybook\` - Start Storybook
- \`npm run component\` - Generate component (devops CLI)
- \`npm run page\` - Generate page (devops CLI)
- \`npm run ts\` - Type check
- \`npm test\` - Run tests

## Documentation

- [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md) - Complete architecture documentation
- [\`.claude/commands/\`](./.claude/commands/) - Claude command documentation
EOF

echo "✅ Barrel exports and initial files created"

# ============================================================================
# STEP 9: Install Dependencies
# ============================================================================
echo ""
echo "📥 Step 9/9: Installing dependencies..."
echo "This may take a few minutes..."
echo ""

npm install

echo ""
echo "✅ Dependencies installed"

# ============================================================================
# Initial Git Commit
# ============================================================================
echo ""
echo "📝 Creating initial commit..."

git add .
git commit -m "Initial commit: Frontend architecture setup

- React + MobX + Storybook + TypeScript
- Component-driven development
- CVA variant system
- Claude AI commands for code generation
- Zero-manual-work setup complete"

echo "✅ Initial commit created"

# ============================================================================
# SUCCESS!
# ============================================================================
echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Project '$PROJECT_NAME' is ready to use!"
echo ""
echo "🎯 Next steps:"
echo ""
echo "1. Start Storybook:"
echo "   npm run storybook"
echo ""
echo "2. Generate your first component:"
echo "   /component button"
echo ""
echo "3. Generate a page:"
echo "   /page home --with-store"
echo ""
echo "4. Read the documentation:"
echo "   - ARCHITECTURE_SPEC.md for complete patterns"
echo "   - .claude/commands/ for Claude command guides"
echo ""
echo "🚀 Happy coding!"
echo ""
