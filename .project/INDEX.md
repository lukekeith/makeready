# Project Template - Complete Index

## Start Here

New to this template? Read in this order:

1. **[SUMMARY.md](./SUMMARY.md)** - Quick overview (5 min read)
2. **[QUICKSTART.md](./QUICKSTART.md)** - 4-step setup guide (2 min read)
3. **[ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md)** - Complete patterns (30 min read)
4. **[MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md)** - Multi-app guide (20 min read)

## All Documentation

### Setup & Getting Started
- **[README.md](./README.md)** - Features, setup, workflow
- **[QUICKSTART.md](./QUICKSTART.md)** - Fast 4-step setup
- **[SETUP_SCRIPT.md](./SETUP_SCRIPT.md)** - Manual setup instructions

### Architecture & Patterns
- **[ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md)** - Complete architecture specification
- **[MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md)** - Multi-app monorepo patterns
- **[SUMMARY.md](./SUMMARY.md)** - Quick reference guide

### Distribution & Setup
- **[PACKAGE_LIST.md](./PACKAGE_LIST.md)** - Template contents and distribution

### Claude Commands
- **[.claude/commands/component.md](./.claude/commands/component.md)** - Component generation
- **[.claude/commands/page.md](./.claude/commands/page.md)** - Page generation
- **[.claude/commands/variants.md](./.claude/commands/variants.md)** - Variant management
- **[.claude/commands/store.md](./.claude/commands/store.md)** - Store generation
- **[.claude/commands/help-component.md](./.claude/commands/help-component.md)** - Interactive guide
- **[.claude/commands/list-categories.md](./.claude/commands/list-categories.md)** - Category browser

## Quick Links

### Setup
- [Run setup script](./setup-architecture.sh)
- [Manual setup steps](./SETUP_SCRIPT.md)
- [Troubleshooting](./QUICKSTART.md#troubleshooting)

### Architecture
- [Monorepo structure](./ARCHITECTURE_SPEC.md#multi-app-monorepo-structure)
- [Component patterns](./ARCHITECTURE_SPEC.md#component-architecture)
- [MobX stores](./ARCHITECTURE_SPEC.md#state-management-with-mobx)
- [Storybook setup](./ARCHITECTURE_SPEC.md#storybook-integration)

### Multi-App
- [When to use monorepo](./MONOREPO_GUIDE.md#when-to-use-monorepo-structure)
- [Naming conventions](./MONOREPO_GUIDE.md#application-folder-naming)
- [Shared code strategy](./MONOREPO_GUIDE.md#shared-code-organization)
- [Common patterns](./MONOREPO_GUIDE.md#common-patterns)

### Claude Commands
- [Component generation](. /.claude/commands/component.md)
- [Interactive mode](. /.claude/commands/component.md#interactive-mode-default---recommended)
- [All commands](./.claude/commands/)

## By Use Case

### "I want to create a single web app"
1. Read [QUICKSTART.md](./QUICKSTART.md)
2. Run setup script
3. Generate components with `/component`
4. See [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md) for patterns

### "I want to create a full-stack app (web + backend)"
1. Read [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md#pattern-2-frontend--backend)
2. Run setup script
3. Add `/server` folder
4. Configure workspace in `package.json`

### "I want to add mobile apps"
1. Read [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md#pattern-3-multi-platform-web--mobile)
2. Add `/iphone` and `/android` folders
3. Share components from `/ui`
4. Share utilities from `/util`

### "I want to understand the architecture"
1. Read [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md)
2. Read [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md)
3. Check reference project examples

### "I want to distribute this template"
1. Read [PACKAGE_LIST.md](./PACKAGE_LIST.md)
2. Choose distribution method (Git, NPM, copy)
3. Share with team

## By Role

### Developer (First Time)
1. [QUICKSTART.md](./QUICKSTART.md) - Get started fast
2. [SUMMARY.md](./SUMMARY.md) - Understand structure
3. Generate first component with `/component`
4. Read [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md) as reference

### Architect
1. [ARCHITECTURE_SPEC.md](./ARCHITECTURE_SPEC.md) - Complete patterns
2. [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md) - Multi-app design
3. [PACKAGE_LIST.md](./PACKAGE_LIST.md) - Distribution options
4. Customize for your needs

### Team Lead
1. [README.md](./README.md) - Overview for team
2. [SETUP_SCRIPT.md](./SETUP_SCRIPT.md) - Setup process
3. [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md) - Multi-app strategy
4. Set up CI/CD from examples

### DevOps Engineer
1. [SETUP_SCRIPT.md](./SETUP_SCRIPT.md) - Automation details
2. [PACKAGE_LIST.md](./PACKAGE_LIST.md) - Distribution
3. [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md#cicd-configuration) - CI/CD patterns
4. Configure deployment pipelines

## Common Tasks

### Setup new project
```bash
mkdir my-app
cp -r .project my-app/
cd my-app
bash .project/setup-architecture.sh
```
**Docs:** [QUICKSTART.md](./QUICKSTART.md)

### Generate component
```bash
/component button
```
**Docs:** [.claude/commands/component.md](./.claude/commands/component.md)

### Add backend
```bash
mkdir server
# ... setup server
```
**Docs:** [MONOREPO_GUIDE.md](./MONOREPO_GUIDE.md#add-backend-api)

### Share with team
Choose method from [PACKAGE_LIST.md](./PACKAGE_LIST.md)

## File Organization

```
.project/
├── INDEX.md                          # ← You are here
├── SUMMARY.md                         # Quick overview
├── README.md                          # Features & setup
├── QUICKSTART.md                      # 4-step guide
├── ARCHITECTURE_SPEC.md               # Complete patterns
├── MONOREPO_GUIDE.md                  # Multi-app guide
├── PACKAGE_LIST.md                    # Distribution
├── SETUP_SCRIPT.md                    # Manual setup
├── setup-architecture.sh              # Automated setup
└── .claude/
    └── commands/                      # Claude AI commands
        ├── component.md
        ├── page.md
        ├── variants.md
        ├── store.md
        ├── help-component.md
        └── list-categories.md
```

## Version Information

- **Template Version:** 2.0
- **Last Updated:** 2025-10-25
- **Based On:** Tax Guardian Client Architecture
- **Changes:** Added multi-app monorepo support

## Support

Questions? Check:
1. Relevant documentation above
2. `ARCHITECTURE_SPEC.md` for patterns
3. `MONOREPO_GUIDE.md` for multi-app
4. Reference project examples

## Contributing

To update this template:
1. Modify files in `.project/`
2. Update version in all docs
3. Test setup script
4. Update `INDEX.md` (this file)
5. Commit and distribute

---

**Pro Tip:** Bookmark this file for quick navigation to all docs!
