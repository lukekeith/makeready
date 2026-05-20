# Sync Production Database to Local

Pull a full copy of the production PostgreSQL database into the local Docker environment.

## Prerequisites

- Local postgres must be running (`/dev-start` or `docker compose up -d postgres`)
- Railway CLI installed and authenticated

## Instructions

### 1. Check Prerequisites

Verify Railway CLI is installed:

```bash
command -v railway && echo "Railway CLI installed" || echo "ERROR: Install Railway CLI with: npm i -g @railway/cli"
```

If not installed, tell the user to run `npm i -g @railway/cli` and then `railway login`.

Verify local postgres is running:

```bash
docker ps --filter "name=makeready-postgres" --format "{{.Names}}" | grep -q makeready-postgres && echo "Postgres running" || echo "ERROR: Run /dev-start first"
```

### 2. Get Production Database URL

Try to get it from Railway:

```bash
cd /Users/lukekeith/www/makeready/server && railway variables get DATABASE_URL 2>/dev/null
```

If this fails (not linked or not logged in), tell the user to:
1. Run `railway login` (ask them to type `! railway login` in the prompt)
2. Run `railway link` in the server directory to link to the correct project/service

Once they have Railway linked, retry getting the DATABASE_URL.

### 3. Dump Production Database

```bash
pg_dump "PRODUCTION_DATABASE_URL_HERE" --no-owner --no-acl --clean --if-exists > /tmp/makeready_prod_dump.sql
```

Replace `PRODUCTION_DATABASE_URL_HERE` with the actual URL from step 2.

Show the dump file size:

```bash
du -h /tmp/makeready_prod_dump.sql
```

### 4. Restore to Local Database

```bash
docker exec -i makeready-postgres psql -U postgres -d makeready_dev < /tmp/makeready_prod_dump.sql
```

Note: You may see some warnings about objects not existing (from `--clean --if-exists`) — these are safe to ignore.

### 5. Clean Up

```bash
rm -f /tmp/makeready_prod_dump.sql
```

### 6. Verify

Check that data was restored:

```bash
docker exec makeready-postgres psql -U postgres -d makeready_dev -c "SELECT count(*) as users FROM \"users\";"
docker exec makeready-postgres psql -U postgres -d makeready_dev -c "SELECT count(*) as groups FROM \"groups\";"
docker exec makeready-postgres psql -U postgres -d makeready_dev -c "SELECT count(*) as lessons FROM \"lessons\";"
```

Tell the user the sync is complete and show the row counts. The local environment at http://localhost:8000 now has production data.
