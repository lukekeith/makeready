# Git Multi-Repo Operations Guide

## Overview

MakeReady uses a **multi-repo structure** with three independent git repositories:

- `/client/.git` - Web client repository (React + MobX)
- `/server/.git` - Backend API repository (Express + Prisma)
- `/iphone/.git` - iPhone app repository (Swift/SwiftUI)

The root folder (`/Users/lukekeith/www/makeready`) has **NO git repository** - it serves only as a workspace coordinator.

---

## ⚠️ Critical Rules

1. **NEVER run git commands from the root folder** - it has no `.git` repository
2. **ALWAYS `cd` into the app directory first** before git operations
3. **For cross-app changes**, commit to each affected repository separately

---

## Determining Which Repo to Use

### File Path → Git Repository Mapping

| File Path | Git Repository | Command Prefix |
|-----------|----------------|----------------|
| `client/**/*` | `/client/.git` | `cd client &&` |
| `server/**/*` | `/server/.git` | `cd server &&` |
| `iphone/**/*` | `/iphone/.git` | `cd iphone &&` |
| `.claude/CLAUDE.md` | None (no git) | N/A |
| `.project/**/*` | None (no git) | N/A |

### Helper Function (Bash)

```bash
# Determine which git repo a file belongs to
function get_git_repo() {
  local file_path="$1"

  if [[ "$file_path" == *"/client/"* ]]; then
    echo "client"
  elif [[ "$file_path" == *"/server/"* ]]; then
    echo "server"
  elif [[ "$file_path" == *"/iphone/"* ]]; then
    echo "iphone"
  else
    echo "none"
  fi
}

# Example usage
repo=$(get_git_repo "client/src/pages/home/home.page.tsx")
echo "Repo: $repo"  # Output: Repo: client
```

---

## Common Operations

### 1. Check Status

```bash
# Client
cd client && git status

# Server
cd server && git status

# iPhone
cd iphone && git status

# All repos (run from root)
(cd client && echo "=== CLIENT ===" && git status) && \
(cd server && echo "=== SERVER ===" && git status) && \
(cd iphone && echo "=== iPHONE ===" && git status)
```

### 2. View Changes

```bash
# Client changes
cd client && git diff

# Server changes
cd server && git diff

# View all uncommitted changes across repos
echo "=== CLIENT CHANGES ===" && (cd client && git diff --stat) && \
echo "=== SERVER CHANGES ===" && (cd server && git diff --stat) && \
echo "=== iPHONE CHANGES ===" && (cd iphone && git diff --stat)
```

### 3. Commit to Single Repo

```bash
# Commit to client repo
cd client
git status
git add .
git commit -m "Add new component

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Commit to server repo
cd server
git add src/routes/users.ts
git commit -m "Add users API endpoint

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Commit to iPhone repo
cd iphone
git add MakeReady/HomeView.swift
git commit -m "Update home view

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 4. Cross-App Changes (Commit to Multiple Repos)

When a feature spans multiple apps (e.g., new API endpoint + client page to consume it):

```bash
# Step 1: Commit server changes
cd server
git add src/routes/tasks.ts src/index.ts prisma/schema.prisma
git commit -m "Add tasks API endpoints

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Step 2: Commit client changes
cd ../client
git add src/pages/tasks/ src/api/tasks.ts
git commit -m "Add tasks page and API integration

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Step 3: Verify both commits
echo "=== SERVER COMMIT ===" && (cd ../server && git log -1 --oneline)
echo "=== CLIENT COMMIT ===" && (cd ../client && git log -1 --oneline)
```

### 5. Push Changes

```bash
# Push client changes
cd client && git push origin main

# Push server changes
cd server && git push origin main

# Push iPhone changes
cd iphone && git push origin main

# Push all repos (run from root)
(cd client && git push origin main) && \
(cd server && git push origin main) && \
(cd iphone && git push origin main)
```

### 6. Pull Updates

```bash
# Pull client updates
cd client && git pull origin main

# Pull server updates
cd server && git pull origin main

# Pull iPhone updates
cd iphone && git pull origin main

# Pull all repos
(cd client && git pull origin main) && \
(cd server && git pull origin main) && \
(cd iphone && git pull origin main)
```

### 7. Create Branches

```bash
# Create feature branch in client
cd client
git checkout -b feature/new-dashboard
git push -u origin feature/new-dashboard

# Create feature branch in server
cd server
git checkout -b feature/tasks-api
git push -u origin feature/tasks-api

# For cross-app features, use same branch name
cd client && git checkout -b feature/user-profile
cd server && git checkout -b feature/user-profile
```

---

## Slash Command Integration

### `/component` - Client Components

```bash
# After creating component
cd client
git add ui/components/primitive/button/ ui/stories/components/primitive/ ui/index.ts
git commit -m "Add Button component"
```

### `/page` - Client Pages

```bash
# After creating page
cd client
git add src/pages/dashboard/
git commit -m "Add Dashboard page"
```

### `/store` - Client Stores

```bash
# After creating store
cd client
git add src/store/domain/users.domain.ts
git commit -m "Add Users domain store"
```

### `/api` - Server Routes

```bash
# After creating API
cd server
git add src/routes/tasks.ts src/index.ts prisma/schema.prisma prisma/migrations/
git commit -m "Add tasks API endpoints"
```

### `/rebuild-iphone` - iPhone App

```bash
# After making changes
cd iphone
git add MakeReady/
git commit -m "Rebuild iPhone app"
```

---

## Troubleshooting

### Problem: "Not a git repository" Error

**Cause:** Running git command from wrong directory (likely root)

**Solution:**
```bash
# Wrong (from root)
git status  # Error: not a git repository

# Correct
cd client && git status  # Works
```

### Problem: Changes in Multiple Repos

**Cause:** A feature touched multiple apps

**Solution:** Commit to each repo separately
```bash
# Check all repos
(cd client && git status) && \
(cd server && git status) && \
(cd iphone && git status)

# Commit to each affected repo
cd client && git add . && git commit -m "Client changes"
cd server && git add . && git commit -m "Server changes"
```

### Problem: Forgot Which Repo Has Changes

**Solution:** Check all repos at once
```bash
#!/bin/bash
for repo in client server iphone; do
  echo "=== $repo ==="
  (cd $repo && git status --short)
  echo
done
```

---

## Best Practices

### 1. Coordinated Commits

For features spanning multiple apps:
- Use descriptive commit messages mentioning the connection
- Reference issue numbers if applicable
- Keep commits atomic per repo

**Example:**
```bash
# Server commit
cd server
git commit -m "Add tasks API (#123)

- Create /api/tasks endpoints
- Update Prisma schema
- Add task model"

# Client commit
cd client
git commit -m "Add tasks page (#123)

- Create tasks page component
- Integrate with tasks API
- Add task list UI"
```

### 2. Branch Naming

Use consistent branch names across repos for related changes:

```bash
cd client && git checkout -b feature/user-authentication
cd server && git checkout -b feature/user-authentication
```

### 3. Pull Before Push

Always pull before pushing to avoid conflicts:

```bash
cd client
git pull origin main
git push origin main
```

### 4. Verify Commits

After committing, verify the commit was created:

```bash
cd client
git log -1 --oneline  # Shows latest commit
```

---

## Migration to Monorepo (Future)

If you later want to combine into a single git repo:

```bash
# 1. Create new monorepo
git init makeready-monorepo
cd makeready-monorepo

# 2. Add each repo as a subdirectory
git remote add client ../client
git fetch client
git merge client/main --allow-unrelated-histories

# 3. Move files to subdirectory
mkdir client
git mv * client/

# 4. Repeat for server and iphone

# 5. Clean up
git remote remove client
```

---

## Quick Reference

| Task | Client | Server | iPhone |
|------|--------|--------|--------|
| Status | `cd client && git status` | `cd server && git status` | `cd iphone && git status` |
| Commit | `cd client && git add . && git commit -m "..."` | `cd server && git add . && git commit -m "..."` | `cd iphone && git add . && git commit -m "..."` |
| Push | `cd client && git push` | `cd server && git push` | `cd iphone && git push` |
| Pull | `cd client && git pull` | `cd server && git pull` | `cd iphone && git pull` |
| Log | `cd client && git log` | `cd server && git log` | `cd iphone && git log` |
| Branch | `cd client && git checkout -b feature/x` | `cd server && git checkout -b feature/x` | `cd iphone && git checkout -b feature/x` |

---

## Summary

- **Multi-repo = three separate `.git` folders**
- **Always `cd` to the app directory first**
- **Cross-app changes = multiple commits (one per repo)**
- **Root folder has NO git repo**
- **Use slash commands that handle git automatically**
