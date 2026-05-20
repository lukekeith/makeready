# CI/CD Pipeline for MakeReady Server

This document describes the CI/CD pipeline for the MakeReady API server (Express + Prisma + Railway).

---

## Stack Overview

| Layer | Technology |
|-------|------------|
| Backend | Express.js + TypeScript |
| ORM | Prisma |
| Database | PostgreSQL (Railway, pgvector) |
| Testing | Vitest |
| CI/CD | GitHub Actions |
| Deployment | Railway |

---

## Pipeline Architecture

```
Push to branch
      │
      ▼
┌─────────────────────────────────────────┐
│  Parallel Jobs (fast feedback)          │
├─────────────────────────────────────────┤
│  ┌──────────┐  ┌──────┐  ┌─────────┐   │
│  │ Typecheck│  │ Lint │  │  Tests  │   │
│  └────┬─────┘  └───┬──┘  └────┬────┘   │
│       │            │          │         │
│       └────────────┼──────────┘         │
│                    │                    │
│                    ▼                    │
│              ┌──────────┐               │
│              │  Build   │               │
│              └────┬─────┘               │
│                   │                     │
└───────────────────┼─────────────────────┘
                    │
        (main branch only)
                    │
                    ▼
      ┌─────────────────────────┐
      │  Deploy Migrations      │
      │  (production database)  │
      └────────────┬────────────┘
                   │
                   ▼
      ┌─────────────────────────┐
      │  Trigger Railway Deploy │
      │  (via webhook)          │
      └─────────────────────────┘
```

---

## Workflow File

**File: `.github/workflows/ci.yml`**

### Jobs Overview

| Job | Purpose | Runs Parallel |
|-----|---------|---------------|
| `typecheck` | TypeScript compilation check | Yes |
| `lint` | ESLint code quality | Yes |
| `test` | Vitest with PostgreSQL | Yes |
| `build` | TypeScript build | After above pass |
| `deploy-migrations` | Prisma migrate deploy | Main branch only |

### Key Features

1. **Parallel execution** - typecheck, lint, and test run simultaneously
2. **TypeScript strict mode** - enforces strict type checking before any deployment
3. **PostgreSQL service container** - real database for server tests
4. **Coverage reporting** - uploaded to Codecov
5. **Gated deployment** - migrations only deploy after all checks pass
6. **Railway integration** - auto-deploys after CI/CD workflow succeeds

---

## Setup Instructions

### 1. GitHub Secrets

Add these secrets in your repository settings (Settings → Secrets → Actions):

| Secret | Description | Where to Find |
|--------|-------------|---------------|
| `PRODUCTION_DATABASE_URL` | Production Prisma connection string | Railway Dashboard → Postgres Plugin → Connect |
| `PRODUCTION_DIRECT_URL` | Direct connection (bypasses pooler) | Railway Dashboard → Postgres Plugin → Connect |

### 2. Railway CI/CD Integration

Railway is configured to wait for GitHub CI/CD checks to pass before deploying:

1. Go to Railway Dashboard → Your Project → MakeReady API service
2. Settings → Triggers
3. Enable "Wait for CI/CD" - Railway will auto-deploy after all GitHub checks pass

This ensures:
- No deployment until TypeScript strict checks pass
- No deployment until ESLint passes
- No deployment until all server tests pass
- No deployment until build succeeds
- Migrations deploy to production before Railway deploys the app

### 3. GitHub Environment

Create a `production` environment in GitHub:

1. Settings → Environments → New environment
2. Name: `production`
3. (Optional) Add protection rules like required reviewers

### 4. Branch Protection (Recommended)

1. Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require status checks to pass before merging
   - ✅ Require: `typecheck`, `lint`, `test`, `build`
   - ✅ Require branches to be up to date before merging

---

## Database Migrations

### Golden Rule

**Prisma migrations are the source of truth.** Never use `db push` in production.

### Development Workflow

```bash
# 1. Make schema changes in prisma/schema.prisma

# 2. Create migration
npx prisma migrate dev --name add_new_feature

# 3. Commit migration files
git add prisma/migrations/
git commit -m "Add new_feature migration"

# 4. Push to GitHub - CI will test and deploy
git push
```

### Deployment Flow

```
Developer creates migration
           │
           ▼
    Push to develop
           │
           ▼
    CI runs all tests
           │
           ▼
    PR to main branch
           │
           ▼
    CI runs all tests
           │
           ▼
    Merge to main
           │
           ▼
    CI deploys migrations
           │
           ▼
    Railway deploys app
```

### What NOT to Do

| Command | OK in Dev | OK in Production |
|---------|-----------|------------------|
| `prisma migrate dev` | ✅ | ❌ Never |
| `prisma migrate deploy` | ✅ | ✅ (via CI only) |
| `prisma db push` | ✅ | ❌ Never |
| `prisma migrate reset` | ✅ | ❌ Never |

---

## Local Testing

```bash
# Run tests locally (same as CI)
npm run test:ci

# Run type check
npx tsc --noEmit

# Run lint
npm run lint

# Build
npm run build:only
```

---

## Troubleshooting

### Migrations Failed in CI

1. Check the "Deploy Migrations" job logs
2. Ensure `PRODUCTION_DATABASE_URL` and `PRODUCTION_DIRECT_URL` secrets are set
3. Verify the migration files are committed to git

### Railway Not Deploying

1. Check that all GitHub CI/CD checks passed
2. Verify Railway "Wait for CI/CD" is enabled in service settings
3. Check Railway Dashboard for any deploy errors
4. Ensure the push was to the `main` branch

### Tests Failing in CI but Passing Locally

1. Ensure you're using the same Node version (20)
2. Run `npm ci` instead of `npm install` locally
3. Check for environment-dependent tests

---

## Environment Variables

### CI Environment (GitHub Actions)

Set automatically in workflow:
- `NODE_ENV=test`
- `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/makeready_test`
- `DIRECT_URL=postgresql://postgres:postgres@localhost:5432/makeready_test`
- `SESSION_SECRET=test-secret-key`
- `CLIENT_URL=http://localhost:5173`
- `PORT=3001`

### Production Environment (Railway)

Set in Railway Dashboard:
- `NODE_ENV=production`
- `DATABASE_URL` (from Railway Postgres)
- `DIRECT_URL` (from Railway Postgres)
- `SESSION_SECRET` (secure random string)
- `CLIENT_URL` (your frontend URL)
- Plus all other app-specific env vars

---

## Summary

| Aspect | Approach |
|--------|----------|
| Schema changes | Prisma migrations only |
| Testing | Vitest with PostgreSQL service (server tests only) |
| Type safety | TypeScript strict mode (`--strict` flag) |
| Code quality | ESLint |
| Deployment gate | All CI jobs must pass (typecheck, lint, test, build) |
| Migration deployment | Automatic on main branch after all checks pass |
| App deployment | Railway auto-deploys after CI/CD workflow succeeds |
