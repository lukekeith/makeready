# Project Template Contents

This directory contains everything needed to replicate the architecture in new projects.

## Files Included

### 📄 Documentation
- `ARCHITECTURE_SPEC.md` - Complete architecture specification
- `README.md` - Template usage guide
- `SETUP_SCRIPT.md` - Manual setup instructions
- `PACKAGE_LIST.md` - This file

### 🤖 Claude Commands
- `.claude/commands/component.md` - Component generation
- `.claude/commands/page.md` - Page generation
- `.claude/commands/variants.md` - Variant management
- `.claude/commands/store.md` - Store generation
- `.claude/commands/help-component.md` - Interactive guide
- `.claude/commands/list-categories.md` - Category browser

### 🔧 Setup Tools
- `setup-architecture.sh` - Automated setup script

## Files to Copy from Reference Project

These files should be copied from the reference project manually:

### Core Utilities (`util/`)
```
util/
├── cva.ts                          # CVA wrapper with enum generation
├── classnames.ts                   # Class composition utility
├── when.ts                         # Conditional rendering helper
├── hooks/
│   ├── use-life-cycle.ts          # Component lifecycle hook
│   └── use-paged-form.ts          # Multi-step form hook
└── storybook-containers/
    └── center.tsx                  # Story layout helper
```

### Configuration Files
```
.storybook/
├── main.js                         # Storybook configuration
├── preview.js                      # Storybook preview settings
└── preview-head.html               # Global styles and CSS variables

tsconfig.json                       # TypeScript configuration
vite.config.ts                      # Vite build configuration
```

### Base Store Classes (`app/client/store/`)
```
app/client/store/
├── store.tsx                       # Base store class
├── application.store.tsx           # Root singleton store
├── domain.store.tsx                # Domain stores container
├── session.store.tsx               # Session state store
└── ui.store.tsx                    # UI stores container
```

## Distribution Options

### Option 1: Copy Directory (Simplest)

```bash
# Copy entire template directory to new project
cp -r tax-guardian-client/.project /path/to/new-project/

# Run setup script
cd /path/to/new-project
bash .project/setup-architecture.sh .project
```

### Option 2: Git Repository (Recommended)

Create a separate git repository with the template:

```bash
# Initialize template repository
cd tax-guardian-client/.project
git init
git add .
git commit -m "Initial frontend architecture template"

# Push to remote
git remote add origin git@github.com:your-org/frontend-architecture-template.git
git push -u origin main
```

Then in new projects:

```bash
# Clone template
git clone git@github.com:your-org/frontend-architecture-template.git /tmp/template

# Run setup
bash /tmp/template/setup-architecture.sh /tmp/template

# Clean up
rm -rf /tmp/template
```

### Option 3: NPM Package (Advanced)

Package as an npm module for easy installation:

```bash
# In template directory, create package.json
npm init -y

# Publish to npm or private registry
npm publish
```

Then in new projects:

```bash
npx create-frontend-architecture
```

### Option 4: GitHub Template Repository (Best for Teams)

1. Create a GitHub repository
2. Mark it as a template repository in settings
3. Team members use "Use this template" button
4. Pre-configured with architecture

## Usage in New Projects

### Quick Setup (Using Script)

```bash
# 1. Copy template
cp -r /path/to/.project /path/to/new-project/

# 2. Run setup script
cd /path/to/new-project
bash .project/setup-architecture.sh .project

# 3. Install dependencies
npm install

# 4. Start Storybook
npm run storybook

# 5. Generate first component
/component button
```

### Manual Setup

Follow instructions in `SETUP_SCRIPT.md` for step-by-step manual setup.

## Updating the Template

When the architecture evolves:

1. Update files in `.project/`
2. Update `ARCHITECTURE_SPEC.md`
3. Update Claude commands in `.claude/`
4. Increment version in documentation
5. Commit changes
6. Push to template repository (if using Git)
7. Notify teams of available updates

## Maintenance

### Version History

Track major changes:

- **v1.0** (2025-10-25) - Initial template
  - Component/Page/Store/Variants commands
  - Interactive mode as default
  - Complete architecture spec

### Changelog

Document updates to:
- Architecture patterns
- Claude commands
- Utility functions
- Configuration files
- Dependencies

## Support

For questions or issues:
1. Read `ARCHITECTURE_SPEC.md`
2. Use `/help-component` command
3. Check reference project examples
4. Contact architecture team

## License

Specify license for template usage.
