# Frontend Architecture Template

**Zero-Manual-Work Setup** for React + MobX + Storybook + TypeScript projects with AI-powered component generation.

## Features

- ✅ **Component-Driven Development** via Storybook
- ✅ **Type-Safe Variants** using CVA (Class Variance Authority)
- ✅ **Observable State** with MobX (Domain/Session/UI separation)
- ✅ **AI-Powered Generation** via Claude commands
- ✅ **Automated Setup** - No manual file copying required
- ✅ **DevOps Integration** - Built-in build and deployment tools

## Quick Start

### 1. Create New Project

```bash
# Create project directory
mkdir my-awesome-app

# Copy template into project
cp -r /path/to/.project my-awesome-app/

# Navigate to project
cd my-awesome-app
```

### 2. Run Setup Script

```bash
# Run the automated setup
bash .project/setup-architecture.sh
```

**The script will:**
- ✅ Prompt for project name
- ✅ Create complete folder structure
- ✅ Generate all configuration files
- ✅ Install all dependencies (including devops)
- ✅ Create core utility files
- ✅ Set up MobX stores
- ✅ Configure Storybook
- ✅ Initialize git with initial commit
- ✅ **Everything ready - zero manual work!**

### 3. Start Building

```bash
# Start Storybook
npm run storybook

# Generate your first component (in Cursor/IDE)
/component button

# Generate a page
/page home --with-store

# Start dev server
npm run dev
```

## What Gets Installed

### Dependencies

**Core Libraries:**
- `mobx` - Observable state management
- `mobx-react` - React bindings for MobX
- `react-hook-form` - Form validation
- `typescript` - Type safety
- `vite` - Build tool and dev server

**DevOps:**
- `devops` (from vega-studio) - Component/page generation, builds, releases

**Storybook:**
- `@storybook/react-vite` - Storybook with Vite
- `@storybook/addon-essentials` - Core addons
- `@storybook/addon-a11y` - Accessibility testing
- `@storybook/addon-interactions` - Interaction testing

**Validation:**
- `joi` - Schema validation for forms

**Utilities:**
- `react-transition-group` - Animations
- `fuzzy` - Fuzzy search

### Project Structure Created

```
my-awesome-app/
├── .claude/
│   └── commands/              # AI generation commands
├── .storybook/                # Storybook configuration
├── ui/
│   ├── components/
│   │   ├── primitive/        # Base components
│   │   ├── domain/           # Business components
│   │   ├── domain-form/      # Form components
│   │   ├── layout/           # Layout templates
│   │   ├── table/            # Data tables
│   │   ├── container/        # Containers
│   │   ├── domain-modal/     # Modals
│   │   └── domain-panel/     # Panels
│   ├── stories/              # Storybook stories
│   └── assets/               # Images, icons, fonts
├── app/
│   ├── client/
│   │   ├── pages/            # Page components
│   │   ├── store/            # MobX stores
│   │   │   ├── domain/       # API/data stores
│   │   │   └── ui/           # UI state stores
│   │   ├── api/              # API clients
│   │   └── styles/           # Global styles
│   ├── server/               # Server code
│   └── config/               # Environment configs
├── util/
│   ├── cva.ts                # CVA wrapper
│   ├── classnames.ts         # Class utility
│   ├── when.ts               # Conditional rendering
│   └── hooks/                # Custom React hooks
├── dts/                      # TypeScript definitions
├── script/                   # Build scripts
├── unit-test/                # Tests
├── ARCHITECTURE_SPEC.md      # Complete documentation
├── README.md                 # Project readme
├── package.json              # Dependencies & scripts
├── tsconfig.json             # TypeScript config
├── vite.config.ts            # Vite config
└── build.conf.ts             # Build targets
```

### Configuration Files Created

All configuration files are automatically generated:

- ✅ `package.json` - With all dependencies and npm scripts
- ✅ `tsconfig.json` - Strict TypeScript with decorators enabled
- ✅ `vite.config.ts` - Vite with path aliases
- ✅ `.storybook/main.js` - Storybook with addons
- ✅ `.storybook/preview.js` - Storybook preview config
- ✅ `.storybook/preview-head.html` - CSS variables and global styles
- ✅ `.gitignore` - Ignore node_modules, dist, etc.
- ✅ `README.md` - Project-specific documentation

### Core Files Created

All core utility and store files are automatically generated:

**Utilities:**
- `util/cva.ts` - CVA wrapper with enum generation
- `util/classnames.ts` - Class composition utility
- `util/when.ts` - Conditional rendering helper
- `util/hooks/use-life-cycle.ts` - Component lifecycle hook
- `util/storybook-containers/center.tsx` - Story layout helper

**Stores:**
- `app/client/store/store.tsx` - Base store class
- `app/client/store/application.store.tsx` - Root singleton
- `app/client/store/domain.store.tsx` - Domain stores container
- `app/client/store/session.store.tsx` - Session state
- `app/client/store/ui.store.tsx` - UI stores container

**Barrel Exports:**
- All component category index files
- Main UI export file
- Util export file

## Claude AI Commands

The template includes AI-powered code generation commands:

### `/component` - Generate Components

```bash
# Interactive mode (recommended)
/component button

# Direct mode
/component avatar primitive --variants '{"size": ["Small", "Medium", "Large"]}' --with-logic --with-styles
```

**Generates:**
- Component file with CVA variants
- SCSS styles
- Storybook story
- Props store (MobX)
- Updates barrel exports

### `/page` - Generate Pages

```bash
# Generate page with store
/page user-management --layout AdminLayout --with-store
```

**Generates:**
- Page component
- UI store with computed props
- Route configuration
- Page styles

### `/variants` - Add/Modify Variants

```bash
# Add variants to existing component
/variants button '{"size": ["Small", "Medium", "Large"]}' --stories --styles
```

### `/store` - Generate Stores

```bash
# Create UI store
/store ui admin.notifications --computed '[{"name": "notificationPanel", "component": "NotificationPanel"}]'
```

### Helper Commands

```bash
# Show available categories
/list-categories

# Component generation guide
/help-component
```

## NPM Scripts

All devops scripts are pre-configured:

```bash
npm run dev              # Start dev server
npm run storybook        # Start Storybook
npm run component        # Generate component (devops CLI)
npm run page            # Generate page (devops CLI)
npm test                # Run tests
npm run ts              # Type check
npm run clean           # Clean build artifacts
npm run release         # Build for production
```

## Setup Time

**Total time: ~5-10 minutes**
- Script execution: ~2 minutes
- Dependency installation: ~3-8 minutes (depending on network)
- Manual work: **0 minutes**

## Requirements

- Node.js 18+ and npm
- Git
- SSH access to vega-studio/node-devops (for devops package)
- VS Code or Cursor (for Claude commands)

## Workflow Example

```bash
# 1. Create and setup project (one time)
mkdir my-app && cp -r .project my-app/
cd my-app
bash .project/setup-architecture.sh
# Enter project name when prompted
# Wait for dependencies to install
# ✅ Done! Project ready

# 2. Open in Cursor
cursor .

# 3. Start Storybook
npm run storybook

# 4. Generate components using Claude
/component button
# Follow interactive prompts
# ✅ Component generated and visible in Storybook

# 5. Generate a page
/page dashboard --with-store
# ✅ Page with store created

# 6. Start dev server
npm run dev
# ✅ Application running
```

## What Makes This Different

### vs Manual Setup
- ❌ Manual: Copy 50+ files, install deps, configure tools
- ✅ Template: One script, everything done

### vs Create React App
- ❌ CRA: Basic setup, no architecture patterns
- ✅ Template: Complete architecture, AI generation, MobX, Storybook

### vs Other Templates
- ❌ Other: Partial setup, manual configuration
- ✅ Template: Zero manual work, production-ready patterns

## Customization

After setup, customize for your needs:

### Update Project Info
Edit `package.json`:
- Update `name`, `author`, `license`
- Add repository URL
- Add additional scripts

### Customize Colors
Edit `.storybook/preview-head.html`:
- Update CSS custom properties
- Add your color palette

### Add Categories
Create new component categories:
```bash
mkdir ui/components/my-category
/component my-component my-category
```

## Distribution

### Option 1: Copy Template Folder
```bash
cp -r /path/to/.project /new-project/
```

### Option 2: Git Repository (Recommended)
```bash
# Create template repo
cd .project
git init
git remote add origin git@github.com:your-org/frontend-template.git
git add .
git commit -m "Frontend architecture template"
git push -u origin main

# Use in new projects
git clone git@github.com:your-org/frontend-template.git my-new-project
cd my-new-project
bash setup-architecture.sh
```

### Option 3: GitHub Template
1. Create GitHub repo from `.project/`
2. Mark as "Template Repository" in settings
3. Team clicks "Use this template"

## Troubleshooting

### Script Fails
- Ensure you have write permissions
- Check Node.js version (18+)
- Verify git is installed

### Devops Package Fails to Install
- Check SSH access to github.com/vega-studio/node-devops
- Verify SSH key is added to GitHub
- Try: `ssh -T git@github.com`

### TypeScript Errors
- Run `npm run ts` to see errors
- Check tsconfig.json paths are correct
- Ensure all dependencies installed

### Storybook Won't Start
- Delete `node_modules` and reinstall
- Check `.storybook/main.js` paths
- Run `npm run storybook` with `--debug` flag

## Documentation

- **ARCHITECTURE_SPEC.md** - Complete architecture patterns and best practices
- **.claude/commands/** - Claude command documentation
- **README.md** (generated) - Project-specific guide

## Support

For questions or issues:
1. Read ARCHITECTURE_SPEC.md
2. Use `/help-component` command
3. Check example implementations in reference project

## Updates

When the template evolves:
1. Pull latest template changes
2. Review changelog
3. Update existing projects as needed

## License

MIT
