# Bootstrap New Web Project

This command bootstraps a complete web project from an empty folder with all the correct architecture patterns, Storybook, Tailwind + shadcn, and a working Hello World component.

## What This Command Does

1. ✅ Initializes Git repository
2. ✅ Creates complete folder structure (ui/, util/, client/, .storybook/)
3. ✅ Generates all configuration files (package.json, tsconfig.json, vite.config.ts, etc.)
4. ✅ Sets up Tailwind + shadcn with correct HSL format
5. ✅ Configures Storybook with PostCSS processing
6. ✅ Creates core utilities (CVA wrapper, classnames, when, useLifecycle)
7. ✅ Creates MobX store structure (ApplicationStore, Store base class)
8. ✅ Generates Hello World component with story
9. ✅ Installs all dependencies
10. ✅ Starts Storybook server
11. ✅ Creates initial Git commit

## Prerequisites

- Node.js 18+ installed
- Git installed
- Empty project folder (or existing folder you want to bootstrap)
- `.claude` folder copied to the project root

## Usage

```bash
# 1. Create new project folder
mkdir my-awesome-app
cd my-awesome-app

# 2. Copy .claude folder from reference project
cp -r /path/to/makeready/.claude ./

# 3. Run boot command in your IDE
/boot
```

The command will prompt you for:
- **Project name** (defaults to folder name)
- **Project description** (optional)
- **Author name** (optional)

## What Gets Created

### Folder Structure
```
my-awesome-app/
├── .claude/                    # ✅ Already exists (you copied it)
├── .storybook/                 # ✅ Created by /boot
│   ├── main.ts                 # Vite config with Tailwind inlined
│   └── preview.ts              # Theme setup, globals import
├── ui/                         # ✅ Created by /boot
│   ├── components/
│   │   ├── primitive/
│   │   │   └── hello-world/
│   │   │       ├── hello-world.tsx
│   │   │       ├── hello-world.scss
│   │   │       └── index.ts
│   │   ├── domain/
│   │   ├── layout/
│   │   └── index.ts
│   ├── stories/
│   │   └── components/
│   │       └── primitive/
│   │           └── hello-world.stories.tsx
│   ├── assets/
│   │   └── images/
│   └── index.ts
├── util/                       # ✅ Created by /boot
│   ├── cva.ts                  # Custom CVA wrapper
│   ├── classnames.ts           # Classnames utility
│   ├── when.tsx                # Conditional rendering
│   ├── useLifecycle.ts         # MobX lifecycle hook
│   └── index.ts
├── client/                     # ✅ Created by /boot
│   ├── src/
│   │   ├── pages/
│   │   ├── store/
│   │   │   ├── ApplicationStore.ts
│   │   │   ├── Store.ts
│   │   │   ├── DomainStore.ts
│   │   │   ├── SessionStore.ts
│   │   │   ├── UIStore.ts
│   │   │   ├── domain/
│   │   │   ├── session/
│   │   │   └── ui/
│   │   ├── styles/
│   │   │   ├── globals.css     # Tailwind + CSS variables (HSL)
│   │   │   └── colors.scss     # Color palette
│   │   ├── main.tsx
│   │   └── vite-env.d.ts
│   ├── index.html
│   ├── package.json
│   ├── tsconfig.json
│   ├── tsconfig.node.json
│   └── vite.config.ts
├── .gitignore                  # ✅ Created by /boot
├── package.json                # ✅ Created by /boot (root workspace)
├── tsconfig.json               # ✅ Created by /boot (root)
└── README.md                   # ✅ Created by /boot

After running: git init, npm install, npm run storybook (auto-started)
```

### Configuration Files

All configuration files are generated with the **exact working setup** from the MakeReady project:

- **package.json** - Root workspace with correct dependencies
- **tsconfig.json** - TypeScript config with path aliases
- **vite.config.ts** - Vite config with aliases
- **.storybook/main.ts** - Storybook with **inlined Tailwind config** (critical!)
- **.storybook/preview.ts** - Dark mode theme setup
- **globals.css** - CSS variables in **HSL format** (critical!)
- **tailwind.config.js** - NOT CREATED (config is inlined in Storybook)

### Dependencies Installed

**Root Package:**
```json
{
  "devDependencies": {
    "concurrently": "^8.2.2",
    "typescript": "^5.6.3",
    "vite-plugin-svgr": "^4.5.0",
    "@storybook/react-vite": "^8.6.14",
    "@storybook/react": "^8.6.14",
    "@storybook/addon-links": "^8.6.14",
    "@storybook/addon-essentials": "^8.6.14",
    "@storybook/addon-interactions": "^8.6.14",
    "@storybook/addon-themes": "^8.6.14",
    "@storybook/blocks": "^8.6.14",
    "@storybook/test": "^8.6.14"
  },
  "dependencies": {
    "tailwindcss": "^3.4.18",
    "postcss": "^8.5.6",
    "autoprefixer": "^10.4.21",
    "tailwindcss-animate": "^1.0.7",
    "tailwind-merge": "^2.6.0",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "mobx": "^6.15.0",
    "mobx-react": "^9.2.1",
    "lucide-react": "^0.454.0"
  }
}
```

**Client Package:**
```json
{
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "mobx": "^6.15.0",
    "mobx-react": "^9.2.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^6.0.11",
    "typescript": "^5.6.3",
    "sass": "^1.83.4"
  }
}
```

### Hello World Component

The bootstrap creates a working component with all patterns:

**ui/components/primitive/hello-world/hello-world.tsx:**
```typescript
import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./hello-world.scss";

export const HelloWorldCva = cva("HelloWorld", {
  variants: {
    variant: {
      Default: "HelloWorld--default",
      Primary: "HelloWorld--primary",
    },
  },
  defaultVariants: { variant: "Default" },
});

export interface IHelloWorld extends VariantProps<typeof HelloWorldCva.variants> {
  children?: React.ReactNode;
  className?: string;
}

export const HelloWorld = observer(
  React.forwardRef<HTMLDivElement, IHelloWorld>((props, ref) => {
    const {
      children = "Hello, World!",
      className,
      variant = HelloWorldCva.defaults?.variant,
    } = props;

    return (
      <div
        ref={ref}
        className={classnames(HelloWorldCva.variants({ variant }), className)}
      >
        {children}
      </div>
    );
  })
);

HelloWorld.displayName = "HelloWorld";
```

**ui/stories/components/primitive/hello-world.stories.tsx:**
```typescript
import type { Meta, StoryObj } from "@storybook/react";
import { HelloWorld, HelloWorldCva } from "ui/components/primitive/hello-world/hello-world";

const meta = {
  title: "Primitive/HelloWorld",
  component: HelloWorld,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: Object.keys(HelloWorldCva.variants.variant),
    },
  },
} satisfies Meta<typeof HelloWorld>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    variant: "Default",
    children: "Hello, World!",
  },
};

export const Primary: Story = {
  args: {
    variant: "Primary",
    children: "Welcome to your new project!",
  },
};
```

## Post-Bootstrap Steps

After `/boot` completes, you'll have:

1. ✅ **Storybook running** at http://localhost:6006
2. ✅ **Hello World component** visible in Storybook
3. ✅ **Git repository** initialized with first commit
4. ✅ **All dependencies** installed
5. ✅ **Complete architecture** ready to use

### Next Steps

```bash
# Generate your first component
/component button primitive

# Generate a page
/page home

# Generate a store
/store ui app.navigation

# Start development server (when ready)
npm run dev:client
```

## Troubleshooting

### Bootstrap fails partway through
- Check Node.js version: `node --version` (need 18+)
- Ensure folder is empty or has only `.claude/`
- Check write permissions
- Review error message for specific issue

### Storybook won't start
- This shouldn't happen - config is tested and working
- If it does, check `.storybook/main.ts` was created
- Verify `globals.css` uses HSL format (not hex)
- Run `npm install` again

### TypeScript errors
- Run `npm install` to ensure all deps installed
- Check `tsconfig.json` has correct path aliases
- Restart IDE/TypeScript server

### Component doesn't show in Storybook
- Check `ui/components/primitive/hello-world/` exists
- Verify story file in `ui/stories/components/primitive/`
- Check `ui/index.ts` exports HelloWorld
- Restart Storybook

## What Makes This Different

Unlike other bootstrapping tools, `/boot`:

✅ **Follows MakeReady architecture** - Exact patterns from working project
✅ **Tailwind + shadcn working** - HSL format, inlined config, PostCSS setup
✅ **Storybook pre-configured** - No setup headaches
✅ **MobX stores ready** - Complete store structure
✅ **CVA wrapper included** - Type-safe variants with enum access
✅ **Working component** - Not just empty folders
✅ **Git initialized** - With sensible .gitignore
✅ **One command** - No manual steps required

## Time Estimate

- **Command execution:** 2-3 minutes (dependency install)
- **Result:** Fully working project with component in Storybook
- **Total time to first component:** ~3 minutes

## Architecture Compliance

The bootstrapped project follows:
- ✅ Component separation (ui/ not client/src/components/)
- ✅ Custom CVA wrapper (util/cva)
- ✅ MobX store patterns (Domain/Session/UI)
- ✅ Storybook for all components
- ✅ Observer + forwardRef pattern
- ✅ SCSS with BEM naming
- ✅ Barrel exports

See `.project/ARCHITECTURE_SPEC.md` and `.project/TAILWIND_SHADCN_SETUP.md` in the bootstrapped project for complete details.

---

**Ready to bootstrap?** Run `/boot` and have a working project in 3 minutes!
