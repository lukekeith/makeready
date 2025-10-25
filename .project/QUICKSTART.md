# Quick Start Guide

## Create a New Project in 4 Steps

### Step 1: Create Project Directory
```bash
mkdir my-awesome-app
```

### Step 2: Copy Project Template
```bash
cp -r /path/to/.project my-awesome-app/
```

### Step 3: Run Setup Script
```bash
cd my-awesome-app
bash .project/setup-architecture.sh
```

**The script will prompt you for:**
- Project name (e.g., "my-awesome-app")

**Then automatically:**
- ✅ Create folder structure
- ✅ Generate all configuration files
- ✅ Install dependencies (including devops)
- ✅ Create core utilities and stores
- ✅ Configure Storybook
- ✅ Initialize git with initial commit

### Step 4: Start Building
```bash
# Start Storybook
npm run storybook

# In your IDE (Cursor/VS Code), generate components:
/component button

# Generate pages:
/page home --with-store

# Start dev server:
npm run dev
```

## Complete Workflow Example

```bash
# Create project
mkdir tax-app && cd tax-app

# Copy template (adjust path to where you store .project)
cp -r ../tax-guardian-client/.project ./

# Run setup
bash .project/setup-architecture.sh
# Enter "tax-app" when prompted for name
# Wait ~5-10 minutes for dependencies to install

# Open in Cursor
cursor .

# Start Storybook
npm run storybook

# Generate your first component
/component badge
# Follow interactive prompts
# Choose variants, props, etc.

# Component is now visible in Storybook!
```

## What You Get

After setup completes, you have a **fully working project** with:

### ✅ Complete Architecture
- React + TypeScript + Vite
- MobX stores (Domain/Session/UI)
- Storybook for component development
- CVA for type-safe variants

### ✅ Zero Manual Work
- All dependencies installed
- All configuration files created
- All core utilities implemented
- All base stores created
- Git initialized with first commit

### ✅ AI-Powered Development
- `/component` - Generate components
- `/page` - Generate pages
- `/variants` - Add/modify variants
- `/store` - Generate stores

### ✅ DevOps Ready
- `npm run component` - Component generator (CLI)
- `npm run page` - Page generator (CLI)
- `npm run dev` - Development server
- `npm run storybook` - Component development
- `npm run release` - Production build

## Time to First Component

- **Setup:** 5-10 minutes (automatic)
- **First component:** 2 minutes (with Claude)
- **Total:** ~12 minutes from zero to working app

## Common Commands

```bash
# Development
npm run dev                 # Start dev server
npm run storybook          # Start Storybook

# Generation (Claude AI)
/component button          # Generate component
/page home --with-store    # Generate page with store
/variants button {...}     # Add variants
/store ui app.nav          # Generate store

# Generation (DevOps CLI)
npm run component          # Interactive component generator
npm run page              # Interactive page generator

# Quality
npm run ts                # Type check
npm test                  # Run tests
npm run clean             # Clean build artifacts

# Build
npm run release           # Production build
npm run package           # Package for distribution
```

## Folder Structure

After setup, your project will have:

### Single App (Default)
```
my-awesome-app/
├── .claude/              # AI commands
├── .storybook/           # Storybook config
├── ui/                   # Shared components
├── util/                 # Shared utilities
├── client/               # Web client app
│   ├── pages/
│   ├── store/
│   └── ...
└── package.json
```

### Multi-App Monorepo (Optional)
```
my-awesome-app/
├── .claude/
├── .storybook/
├── ui/                   # Shared UI (ALL apps)
├── util/                 # Shared utilities (ALL apps)
├── shared/               # Shared types/constants
├── client/               # 🌐 Web client
├── admin/                # 🔐 Admin portal
├── server/               # 🖥️  Backend API
├── iphone/               # 📱 iOS app
├── models/               # 🧠 ML models
└── package.json          # Workspace root
```

**See:** [MONOREPO_GUIDE.md](.project/MONOREPO_GUIDE.md) for multi-app setup.

## Next Steps

1. **Read the docs:**
   - `ARCHITECTURE_SPEC.md` - Complete architecture patterns
   - `MONOREPO_GUIDE.md` - Multi-app monorepo guide
   - `.claude/commands/` - Claude command documentation

2. **Generate components:**
   - Start with primitives (Button, Input, etc.)
   - Build up to domain components
   - Create layouts and pages

3. **Set up your design system:**
   - Update colors in `.storybook/preview-head.html`
   - Add your brand fonts
   - Customize component styles

4. **Add more apps (optional):**
   - Add backend: `mkdir server && cd server && npm init`
   - Add mobile: `mkdir iphone && npx react-native init`
   - Add ML: `mkdir models && touch requirements.txt`
   - See `MONOREPO_GUIDE.md` for patterns

5. **Connect to APIs:**
   - Create domain stores in `client/store/domain/`
   - Use Claude: `/store domain users --api "API.Users"`

## Troubleshooting

### Script fails
- Check Node.js version (18+)
- Verify git is installed
- Ensure write permissions

### Dependencies fail to install
- Check SSH access: `ssh -T git@github.com`
- Verify SSH key is added to GitHub
- Try: `npm cache clean --force`

### Storybook won't start
- Delete `node_modules` and reinstall
- Check `.storybook/main.js` paths
- Run with debug: `npm run storybook -- --debug`

## Support

- **Architecture:** Read `ARCHITECTURE_SPEC.md`
- **Commands:** Use `/help-component`
- **Examples:** Check reference project
