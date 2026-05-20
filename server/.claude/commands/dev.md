# Start Development Environment

**Purpose:** Start all servers needed for local development with iPhone and web client apps.

This command sets up the complete local development environment including:
- Local PostgreSQL database (via Docker)
- MakeReady API server with Bonjour advertising (for iPhone device discovery)
- Optionally the web client dev server

---

## Quick Start

Run everything in sequence:

```bash
# 1. Start local PostgreSQL (if not running)
cd /Users/lukekeith/www/makeready/server && docker-compose -f docker-compose.local.yml up -d

# 2. Wait for database to be ready
sleep 3

# 3. Start server with Bonjour advertising (for iPhone discovery)
cd /Users/lukekeith/www/makeready/server && npm run dev:advertise
```

---

## Step-by-Step Process

### 1. Start Local PostgreSQL Database

Check if the local database container is already running:

```bash
cd /Users/lukekeith/www/makeready/server
docker ps --filter "name=makeready-postgres" --format "{{.Names}}"
```

If not running, start it:

```bash
docker-compose -f docker-compose.local.yml up -d
```

Wait for the database to be ready:

```bash
sleep 3
docker-compose -f docker-compose.local.yml logs --tail=5
```

Expected output should show PostgreSQL is ready to accept connections.

### 2. Verify Database Connection

Test the database connection:

```bash
docker exec makeready-postgres pg_isready -U postgres
```

Expected output: `/var/run/postgresql:5432 - accepting connections`

### 3. Apply Database Migrations (if needed)

If this is a fresh database or there are pending migrations:

```bash
npx prisma migrate deploy
```

### 4. Seed Development Data (if needed)

If the database is empty, seed it with test data:

```bash
npm run db:seed:dev
```

This creates:
- Test user (luke@test.com)
- Test organization
- Test groups
- Sample study program with lessons
- Sample events and posts

### 5. Start API Server with Bonjour

Start the server with Bonjour advertising enabled (allows iPhone physical devices to discover the local server):

```bash
npm run dev:advertise
```

This runs:
- Bonjour service advertising `_makeready._tcp` on the local network
- API server on http://localhost:3001 with hot reload

Expected output:
```
📡 Advertising MakeReady dev server via Bonjour
   Service: _makeready._tcp
   Port: 3001
🚀 MakeReady server running on http://localhost:3001
📱 HTTP enabled for iOS Simulator development
```

### 6. Start Web Client (Optional, in separate terminal)

Open a new terminal and run:

```bash
cd /Users/lukekeith/www/makeready/client && npm run dev
```

Expected output:
```
VITE v5.x.x  ready in xxx ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
```

---

## Verification

### Test API Health

```bash
curl http://localhost:3001/api/status
```

Expected response:
```json
{
  "success": true,
  "status": "operational",
  "database": { "status": "healthy" }
}
```

### Test Bonjour Discovery

On your iPhone (connected to the same network), the MakeReady app should automatically discover the local server when built via Xcode.

To verify Bonjour is advertising:

```bash
dns-sd -B _makeready._tcp
```

Should show: `makeready-dev-server`

---

## Environment Configuration

The local development environment uses these settings in `.env`:

```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5434/makeready_dev"
DIRECT_URL="postgresql://postgres:postgres@localhost:5434/makeready_dev"
TEST_VERIFICATION_CODES=123456,000000
CLIENT_URL=http://localhost:5173
```

**Note:** Port 5434 is used for local PostgreSQL to avoid conflicts with system PostgreSQL.

---

## Troubleshooting

### Port 3001 Already in Use

Kill existing processes:

```bash
lsof -ti:3001 | xargs kill -9 2>/dev/null
pkill -f "tsx watch src/index.ts" 2>/dev/null
```

### Database Connection Failed

Check if Docker container is running:

```bash
docker ps -a --filter "name=makeready-postgres"
```

Restart if needed:

```bash
docker-compose -f docker-compose.local.yml down
docker-compose -f docker-compose.local.yml up -d
```

### Bonjour Not Advertising

Make sure bonjour package is installed:

```bash
npm install
```

Check if the script exists:

```bash
ls scripts/advertise-bonjour.cjs
```

### iPhone Can't Find Local Server

1. Ensure iPhone and Mac are on the same WiFi network
2. Check Mac's firewall allows incoming connections on port 3001
3. Verify the app was built from Xcode (not TestFlight/App Store)

---

## Stop Development Environment

### Stop Server

Press `Ctrl+C` in the terminal running `npm run dev:advertise`

Or kill processes:

```bash
pkill -f "tsx watch src/index.ts"
pkill -f "advertise-bonjour.cjs"
```

### Stop Database

```bash
cd /Users/lukekeith/www/makeready/server
docker-compose -f docker-compose.local.yml down
```

### Stop Web Client

Press `Ctrl+C` in the terminal running the Vite dev server

---

## Summary of Services

| Service | URL | Purpose |
|---------|-----|---------|
| PostgreSQL | localhost:5434 | Local database |
| API Server | http://localhost:3001 | Backend API with Bonjour |
| Web Client | http://localhost:5173 | Web app (optional) |
| Bonjour | _makeready._tcp | iPhone device discovery |

---

## API Documentation (MCP Server)

The **MakeReady API** MCP server is automatically available via `.mcp.json` (no manual startup needed). It provides 4 tools for querying API docs on demand:

| Tool | Purpose |
|------|---------|
| `list_api_endpoints` | Browse endpoints, filter by tag/method/path |
| `get_endpoint_detail` | Full docs for a specific endpoint |
| `get_schema` | Data model definitions (Member, Group, etc.) |
| `search_api` | Free-text search across all endpoints |

These replace the old `/client-api-docs` and `/iphone-api-docs` commands — no need to generate static doc files.

---

## Test Credentials

For local development with phone verification:

- **Test verification code:** `123456` (works for any phone number)
- **Test user email:** luke@test.com (seeded via `npm run db:seed:dev`)
