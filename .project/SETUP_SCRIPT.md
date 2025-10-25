# Automated Setup Script

Run this script to automatically set up the architecture in a new project.

## Usage

```bash
# From your new project root
bash setup-architecture.sh /path/to/project
```

## What the Script Does

1. ✅ Copies ARCHITECTURE_SPEC.md
2. ✅ Copies .claude commands
3. ✅ Creates folder structure
4. ✅ Copies core utility files (if available)
5. ✅ Copies configuration templates
6. ✅ Updates package.json with dependencies
7. ✅ Initializes git (if not already initialized)
8. ✅ Creates initial commit with architecture

## Manual Steps After Running Script

After the script completes, you'll need to:

### 1. Install Dependencies
```bash
npm install
```

### 2. Customize Configuration

Edit these files for your project:
- `ARCHITECTURE_SPEC.md` - Update project name
- `.storybook/main.js` - Update project paths
- `vite.config.ts` - Update project-specific settings
- `tsconfig.json` - Adjust paths if needed

### 3. Set Up Design System

Copy CSS custom properties to `.storybook/preview-head.html`:
- Color palette
- Typography scale
- Spacing system
- Border radius values

### 4. Create First Components

```bash
# Launch Storybook
npm run storybook

# In another terminal, use Claude to generate components
/component button
```

### 5. Set Up Stores

```bash
# Create domain store
/store domain users --api "API.Users"

# Create UI store
/store ui app.navigation
```

### 6. Verify Setup

- [ ] Storybook launches successfully
- [ ] TypeScript compiles without errors
- [ ] Claude commands work in IDE
- [ ] Can generate components
- [ ] Can generate pages
- [ ] Can generate stores

## Troubleshooting

### Claude Commands Not Working

Make sure:
- `.claude/commands/` directory exists
- Command files have `.md` extension
- Files are properly formatted markdown

### TypeScript Errors

Check:
- `tsconfig.json` paths are correct
- Dependencies are installed
- `util/` directory has required files

### Storybook Won't Start

Verify:
- `.storybook/main.js` paths are correct
- `ui/` directory structure exists
- Storybook dependencies installed

### Import Errors

Ensure:
- `tsconfig.json` has correct path mappings
- `vite.config.ts` has matching aliases
- Files use correct import paths
