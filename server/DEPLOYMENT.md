# MakeReady Server Deployment Guide

## 🏗️ Architecture Overview

We use a **three-tier deployment pipeline** with environment promotion:

```
GitHub (develop) → Dev → Staging → Production
                    ↓       ↓          ↓
                  Dev DB  Stg DB   Prod DB
```

- **Development**: Auto-deploys from `develop` branch, runs tests
- **Staging**: Manual promotion from dev (no GitHub deploy)
- **Production**: Manual promotion from staging (no GitHub deploy)

---

## 📋 Quick Reference

### Environment URLs

| Environment | Server URL | Database | Client URL |
|-------------|-----------|----------|------------|
| **Development** | https://dev.makeready.org | Railway Postgres Dev | https://dev-client.makeready.org |
| **Staging** | https://staging.makeready.org | Railway Postgres Staging | https://staging-client.makeready.org |
| **Production** | https://app.makeready.org | Railway Postgres Production | https://client.makeready.org |

### Database Projects

| Environment | Database | Region |
|-------------|----------|--------|
| Development | Railway Postgres Dev | us-east-2 |
| Staging | Railway Postgres Staging | us-east-2 |
| Production | Railway Postgres Production | us-east-2 |

---

## 🚀 Initial Setup

### Step 1: Configure Railway Databases

#### 1.1 Set Up Development Database

1. Go to your Railway project dashboard
2. Add a **PostgreSQL** plugin to the development environment
3. Enable the `pgvector` and `uuid-ossp` extensions
4. Copy the `DATABASE_URL` from the plugin's connection settings

#### 1.2 Set Up Staging Database

Repeat above steps for the staging environment.

#### 1.3 Fill in Environment Files

Edit `.env.development`:
```bash
DATABASE_URL="postgresql://postgres:PASSWORD@HOST:PORT/railway"
```

Edit `.env.staging` with staging database credentials.

Edit `.env.test` with **dev database credentials** (tests use dev DB, not production!).

---

### Step 2: Migrate Database Schemas

Once you've filled in the environment files:

```bash
# Migrate dev database (applies all migrations from production schema)
./scripts/sync-schema-to-dev.sh

# Migrate staging database
./scripts/migrate-staging-db.sh
```

This copies your production schema to dev and staging databases.

---

### Step 3: Configure Railway Environments

#### 3.1 Create Development Environment

1. Go to Railway dashboard → Your project
2. Click your service (makeready-server)
3. Go to **Settings → Environments**
4. Click **"New Environment"**
5. Configure:
   - **Name**: `development`
   - **Source**: Connect to GitHub → Select `develop` branch
   - **Auto-deploy**: ✅ Enabled
6. Add **Environment Variables**:
   ```
   NODE_ENV=development
   DATABASE_URL=<from .env.development>
   GOOGLE_CLIENT_ID=<your-google-client-id>
   GOOGLE_CLIENT_SECRET=<your-google-client-secret>
   GOOGLE_CALLBACK_URL=https://dev.makeready.org/auth/google/callback
   SESSION_SECRET=<generate random string>
   CLIENT_URL=https://dev-client.makeready.org
   TWILIO_ACCOUNT_SID=<your-twilio-account-sid>
   TWILIO_AUTH_TOKEN=<your-twilio-auth-token>
   TWILIO_VERIFY_SERVICE_ID=<your-twilio-verify-service-id>
   TWILIO_PHONE_NUMBER=<your-twilio-phone-number>
   ```

7. Configure **Build Settings**:
   - **Build Command**: `npm run build`
   - **Start Command**: `./.railway/deploy.sh && npm start`

8. Add **Custom Domain**: `dev.makeready.org`

#### 3.2 Create Staging Environment

1. Click **"New Environment"**
2. Configure:
   - **Name**: `staging`
   - **Source**: ⚠️ **None** (promotion only!)
   - **Auto-deploy**: ❌ Disabled
3. Add same environment variables but use **staging database credentials**
4. Update URLs:
   - `GOOGLE_CALLBACK_URL=https://staging.makeready.org/auth/google/callback`
   - `CLIENT_URL=https://staging-client.makeready.org`
5. Add **Custom Domain**: `staging.makeready.org`

#### 3.3 Configure Production Environment

1. Select existing `production` environment
2. **Disable auto-deploy from GitHub** (if enabled)
3. Change **Source** to **Promotion Only**
4. Verify environment variables are correct
5. Domain should already be `app.makeready.org`

---

## 🔄 Daily Workflow

### Development → Staging → Production

#### Step 1: Develop and Test Locally

```bash
# Work on feature branch
git checkout -b feature/my-feature

# Make changes
# ...

# Test locally
npm run dev

# Run tests
npm test

# Commit changes
git add .
git commit -m "Add feature"

# Push to develop branch
git checkout develop
git merge feature/my-feature
git push origin develop
```

#### Step 2: Automatic Dev Deployment

- Railway automatically deploys to **development** environment
- Deployment script runs:
  1. Database migrations (`npx prisma migrate deploy`)
  2. Test suite (`npm run test:ci`)
  3. If tests pass → deployment succeeds
  4. If tests fail → deployment fails

#### Step 3: Promote Dev → Staging

Once dev is stable and tests pass:

**Via Railway Dashboard:**
1. Go to **development** environment
2. Find the successful deployment
3. Click **"Promote"**
4. Select **staging** environment
5. Confirm promotion

**Via Railway CLI:**
```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Promote dev to staging
railway environment promote development staging
```

#### Step 4: Manual QA in Staging

- Test on https://staging.makeready.org
- Verify all features work
- Check database migrations applied correctly
- Get team approval

#### Step 5: Promote Staging → Production

Once staging is approved:

**Via Railway Dashboard:**
1. Go to **staging** environment
2. Find the successful deployment
3. Click **"Promote"**
4. Select **production** environment
5. Confirm promotion

**Via Railway CLI:**
```bash
railway environment promote staging production
```

---

## 🧪 Running Tests

### Local Tests

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run CI tests (what runs in dev deployment)
npm run test:ci
```

### Important: Tests Use Dev Database

Tests now use `.env.test` which points to the **dev database**, NOT production!

This prevents test data from polluting production.

---

## 🗄️ Database Management

### Creating a New Migration

```bash
# Make changes to prisma/schema.prisma
# Then create migration:
npx prisma migrate dev --name add_new_field

# This creates a migration file in prisma/migrations/
# Commit this file to git
git add prisma/
git commit -m "Add migration: add_new_field"
git push
```

### Applying Migrations Manually

If you need to manually apply migrations to a specific environment:

```bash
# Dev database
./scripts/migrate-dev-db.sh

# Staging database
./scripts/migrate-staging-db.sh

# Production database (use with caution!)
DATABASE_URL="<prod_url>" npx prisma migrate deploy
```

### Syncing Schema to New Database

If you create a fresh database and need to sync the schema:

```bash
# Sync production schema to dev
./scripts/sync-schema-to-dev.sh
```

---

## 🔐 Security Best Practices

1. **Never commit `.env` files** - They're in `.gitignore`
2. **Use different SESSION_SECRET for each environment**
3. **Dev/Staging databases should NOT contain production data**
4. **Test migrations in dev before promoting to staging**
5. **Always test in staging before promoting to production**
6. **Production is promotion-only** - Never deploy directly from GitHub

---

## 🚨 Troubleshooting

### Tests Failing in Dev Deployment

1. Check Railway logs for error details
2. Run tests locally: `npm run test:ci`
3. Fix failing tests
4. Push to `develop` branch
5. Railway will auto-deploy again

### Migration Errors

If migration fails:

1. Check Prisma migration logs
2. Verify database connection
3. Check for schema conflicts
4. Roll back migration if needed: `npx prisma migrate reset`

### Promotion Fails

1. Check target environment logs
2. Verify environment variables are set correctly
3. Ensure database URL is correct for target environment
4. Check if migrations need to be run manually

### Need to Rollback Production

1. Go to Railway → Production environment
2. Find previous successful deployment
3. Click **"Redeploy"**
4. Confirm redeployment

---

## 📞 Support

If you encounter issues:

1. Check Railway logs
2. Check Railway Postgres database logs
3. Review this guide
4. Contact team lead

---

## ✅ Checklist for New Features

- [ ] Feature developed and tested locally
- [ ] All tests passing locally (`npm test`)
- [ ] Merged to `develop` branch
- [ ] Dev deployment successful (auto)
- [ ] Tests passing in dev environment
- [ ] Promoted to staging
- [ ] Manual QA completed in staging
- [ ] Team approval received
- [ ] Promoted to production
- [ ] Verified in production
- [ ] Monitoring for errors

---

## 🎯 Environment Promotion Summary

| From | To | Trigger | Tests Run | Approval Required |
|------|-----|---------|-----------|-------------------|
| GitHub `develop` | Development | Automatic (on push) | Yes (automated) | No |
| Development | Staging | Manual promotion | No | Yes (passing dev tests) |
| Staging | Production | Manual promotion | No | Yes (QA approval) |

---

*Last updated: 2025-11-18*
