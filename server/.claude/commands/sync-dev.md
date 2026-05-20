# Sync Development Database

Sync the local development database with production by copying the entire production database from Railway.

**WARNING:** This will completely wipe your local development database and replace it with production data.

## Instructions

Execute these steps in order:

### 1. Ensure Local Database is Running

```bash
# Start local PostgreSQL if not running
npm run db:local:start

# Wait for it to be ready
sleep 3
```

### 2. Get Production Database URL

```bash
# Link to the pgvector service to get the public DATABASE_URL
railway link -p b69d7c6d-dedf-44f9-a416-3949f32d2870 -s b987072c-a0e4-418a-bea2-45d359817473 -e 47a94190-6ea6-48fd-b9db-9973f4f5912a

# Get the public DATABASE_URL (accessible from outside Railway)
railway variables --json | jq -r '.DATABASE_URL'
```

Store this URL for the next steps. It should look like:
`postgres://postgres:PASSWORD@hopper.proxy.rlwy.net:33058/railway`

**Important:** Must use the public URL (proxy), not the internal URL (`.railway.internal`).

After getting the URL, re-link to the API service:
```bash
railway link -p b69d7c6d-dedf-44f9-a416-3949f32d2870 -s f5dc2315-9c49-4c85-b32d-99418eeba49d -e 47a94190-6ea6-48fd-b9db-9973f4f5912a
```

### 3. Dump Production Database

```bash
# Create a dump of production (use the DATABASE_URL from step 2)
pg_dump "PRODUCTION_DATABASE_URL_HERE" --no-owner --no-acl -Fc > /tmp/makeready_prod_dump.dump
```

**Note:** The `-Fc` flag creates a custom format dump which is faster to restore.
**Note:** If pg_dump version mismatch, use `/opt/homebrew/opt/postgresql@17/bin/pg_dump` instead.

### 4. Drop and Recreate Local Database

```bash
# Drop existing local database and recreate it
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -c "DROP DATABASE IF EXISTS makeready_dev;"
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -c "CREATE DATABASE makeready_dev;"

# Enable required extensions
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d makeready_dev -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d makeready_dev -c "CREATE EXTENSION IF NOT EXISTS \"vector\";"
```

### 5. Restore Production Dump to Local

```bash
# Restore the dump to local database
PGPASSWORD=postgres pg_restore -h localhost -p 5434 -U postgres -d makeready_dev --no-owner --no-acl /tmp/makeready_prod_dump.dump
```

**Note:** You may see errors about `extensions.vector` type — this is expected. The verses table may need to be created manually with `vector(384)` instead of `extensions.vector(384)`. See the migration notes for details.

### 6. Regenerate Prisma Client

```bash
# Regenerate Prisma client to ensure types are in sync
npx prisma generate
```

### 7. Cleanup

```bash
# Remove the dump file
rm /tmp/makeready_prod_dump.dump
```

## Quick Sync (Combined Command)

After getting the production DATABASE_URL, run this single command block:

```bash
# Set production URL (replace with actual URL from Railway pgvector service)
PROD_URL="postgres://postgres:PASSWORD@hopper.proxy.rlwy.net:33058/railway"

# Dump production
pg_dump "$PROD_URL" --no-owner --no-acl -Fc > /tmp/makeready_prod_dump.dump && \

# Drop and recreate local
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -c "DROP DATABASE IF EXISTS makeready_dev;" && \
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -c "CREATE DATABASE makeready_dev;" && \
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d makeready_dev -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" && \
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d makeready_dev -c "CREATE EXTENSION IF NOT EXISTS \"vector\";" && \

# Restore to local
PGPASSWORD=postgres pg_restore -h localhost -p 5434 -U postgres -d makeready_dev --no-owner --no-acl /tmp/makeready_prod_dump.dump && \

# Regenerate Prisma
npx prisma generate && \

# Cleanup
rm /tmp/makeready_prod_dump.dump

echo "✅ Local database synced with production!"
```

## Local Database Connection Details

| Setting | Value |
|---------|-------|
| Host | localhost |
| Port | 5434 |
| User | postgres |
| Password | postgres |
| Database | makeready_dev |

## Production Database (Railway pgvector)

| Setting | Value |
|---------|-------|
| Service | pgvector |
| Internal Host | pgvector.railway.internal:5432 |
| Public Host | hopper.proxy.rlwy.net:33058 |
| Database | railway |

## Troubleshooting

**"database is being accessed by other users"**
- Stop the dev server first: Kill any running `npm run dev` processes
- Or force disconnect:
```bash
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'makeready_dev' AND pid <> pg_backend_pid();"
```

**"pg_dump: server version mismatch"**
- Use the matching pg_dump version: `/opt/homebrew/opt/postgresql@17/bin/pg_dump`
- Or install: `brew install postgresql@17`

**"pg_dump: command not found"**
- Install PostgreSQL client tools: `brew install libpq && brew link --force libpq`

**"Railway CLI not found"**
- Install Railway CLI: `npm install -g @railway/cli`
- Then link to API service: `railway link -p b69d7c6d-dedf-44f9-a416-3949f32d2870 -s f5dc2315-9c49-4c85-b32d-99418eeba49d -e 47a94190-6ea6-48fd-b9db-9973f4f5912a`

## Success Criteria

After sync:
- [ ] Local database contains production data
- [ ] Prisma client regenerated
- [ ] Dev server can connect and query data
