# Claude Code Instructions for MakeReady Server

## 🚂 Railway CLI

Before running any Railway CLI commands, link to the MakeReady API service:

```bash
railway link -p b69d7c6d-dedf-44f9-a416-3949f32d2870 -s f5dc2315-9c49-4c85-b32d-99418eeba49d -e 47a94190-6ea6-48fd-b9db-9973f4f5912a
```

This ensures Railway commands target the correct project/service.

**⚠️ NEVER use Railway CLI to access production data.** Always use the MakeReady API with the API key from `.env`:

```bash
source .env
curl -H "Authorization: Bearer $MAKEREADY_API_KEY" "https://api.makeready.org/api/..."
```

The API key (`MAKEREADY_API_KEY` in `.env`) provides authenticated access to all production endpoints without needing Railway CLI, direct DB connections, or network tunneling.

## 🌐 MakeReady Client MCP Server

The `makeready-client` MCP server provides live documentation about the web client app (`../client`, hosted at `app.makeready.org`). **You MUST use this MCP server** whenever you are:

- **Building or modifying API responses** that the client consumes (check routes/components to understand expected data shapes)
- **Generating URLs or links** that point to client pages (use `list_routes` to get correct paths)
- **Creating redirect URLs** in auth flows or server responses
- **Adding fields to API endpoints** that map to client UI components
- **Designing new endpoints** that will be consumed by specific client pages or stores

### Available Tools

| Tool | When to Use |
|------|-------------|
| `mcp__makeready-client__list_routes` | Look up client routes/paths before generating any URL or link |
| `mcp__makeready-client__get_route_detail` | Get full details on a specific route including controller source |
| `mcp__makeready-client__list_components` | Understand what UI components exist and their data needs |
| `mcp__makeready-client__get_component_detail` | Get props/variants for a specific component |
| `mcp__makeready-client__list_pages` | See all pages and their layouts |
| `mcp__makeready-client__list_stores` | Understand client-side state management (domain/UI stores) |
| `mcp__makeready-client__search_client` | Search across routes, components, pages, and stores by keyword |

### Key Rule

**Never hardcode or guess client URLs/routes.** Always query the MCP server to get the correct paths. The client app is at `https://app.makeready.org` in production and `http://localhost:5173` in development.

## 🎯 Overview

This is the **MakeReady API Server** - an Express.js backend with Prisma ORM, Google OAuth authentication, and RESTful API endpoints.

**Technology Stack:**
- **Framework**: Express.js + TypeScript
- **Database**: PostgreSQL with Prisma ORM
- **Authentication**: Passport.js with Google OAuth 2.0
- **Session Management**: express-session
- **Validation**: Zod
- **Development**: tsx (TypeScript execution)

## 🏗️ Architecture

```
server/
├── src/
│   ├── index.ts           # Main server entry point
│   ├── config/
│   │   └── passport.ts    # Passport authentication config
│   └── routes/
│       ├── auth.ts        # Authentication routes
│       ├── users.ts       # User endpoints
│       └── ...            # Other API routes
├── prisma/
│   └── schema.prisma      # Database schema
└── .env                   # Environment variables (not in git)
```

## 🤖 Sub-Agent Commands

### `/schema` - Apply Schema Changes

**Run this after ANY changes to YAML schema files.**

Guides you through validating, generating, and applying database schema changes.

**Usage:**
```
/schema
```

**What it does:**
1. Validates YAML schema syntax
2. Generates Atlas HCL and Prisma schema from YAML
3. Creates a migration for any changes
4. Applies the migration to local database
5. Regenerates Prisma client

---

### `/docs` - Update API Documentation

**Run this to ensure all API endpoints have OpenAPI documentation.**

Checks documentation coverage across all route files and guides you through adding missing docs.

**Usage:**
```
/docs
```

**What it does:**
1. Scans all route files for @openapi blocks
2. Compares against actual endpoint count
3. Identifies undocumented endpoints
4. Guides you through adding missing documentation
5. Builds to compile docs into JS (required for production)
6. Optionally deploys to update production docs

**Important:** OpenAPI docs are read from compiled `dist/routes/*.js` files in production, so always run `npm run build:only` after adding documentation.

---

### `/sync-dev` - Sync Development Database

**Sync local development database with production data.**

Wipes the local database and copies all data from production for local testing.

**Usage:**
```
/sync-dev
```

**What it does:**
1. Gets production DATABASE_URL from Railway
2. Dumps production database using pg_dump
3. Drops and recreates local database (makeready_dev)
4. Enables required PostgreSQL extensions (uuid-ossp, vector)
5. Restores production dump to local
6. Regenerates Prisma client

**Warning:** This completely replaces your local database with production data.

---

### `/api` - Create and Manage API Endpoints

Creates Express routes with full CRUD operations, updates Prisma schema, and regenerates Postman collection.

**Usage:**
```
/api create tasks
/api update users
/api schema Task title:String completed:Boolean userId:String
```

**What it does:**
1. Creates route file in `src/routes/[resource].ts`
2. Generates CRUD endpoints (GET, POST, PATCH, DELETE)
3. Updates `prisma/schema.prisma` if database changes needed
4. Runs `npx prisma migrate dev` to update database
5. Mounts routes in `src/index.ts`
6. Regenerates Postman collection

**API Endpoint Template:**
```typescript
import { Router } from 'express'
import { db } from '../db'
import { z } from 'zod'

const router = Router()

// GET /api/tasks - List all tasks
router.get('/', async (req, res) => {
  try {
    const tasks = await db.task.findMany()
    res.json({ tasks })
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch tasks' })
  }
})

// POST /api/tasks - Create task
const createTaskSchema = z.object({
  title: z.string(),
  completed: z.boolean().optional(),
})

router.post('/', async (req, res) => {
  try {
    const data = createTaskSchema.parse(req.body)
    const task = await db.task.create({ data })
    res.json({ task })
  } catch (error) {
    res.status(400).json({ error: 'Invalid request' })
  }
})

export default router
```

### `/postman` - Regenerate Postman Collection

Scans all routes and generates updated Postman collection for API testing.

**Usage:**
```
/postman
```

**Output:**
- Generates `postman/MakeReady.postman_collection.json`
- Includes all API endpoints with examples
- Auto-configured with environment variables

## 🔐 Authentication Flow

### Google OAuth (iOS + Web)

**Flow for iOS:**
1. iOS app opens: `GET /auth/google?platform=ios`
2. User authenticates with Google
3. Server redirects to: `http://localhost:3001/auth/google/callback`
4. Server generates auth code and redirects to: `makeready://auth/callback?code=xxx`
5. iOS app exchanges code: `POST /auth/exchange { code }`
6. Server returns signed session cookie
7. iOS app uses cookie for authenticated requests

**Flow for Web:**
1. Web app redirects to: `GET /auth/google`
2. User authenticates with Google
3. Server redirects to: `http://localhost:3001/auth/google/callback`
4. Server redirects to: `${CLIENT_URL}/home`
5. Browser stores session cookie automatically

**Authentication Endpoints:**
- `GET /auth/google` - Initiate OAuth flow
- `GET /auth/google/callback` - OAuth callback (handles both web and iOS)
- `POST /auth/exchange` - Exchange auth code for session (iOS only)
- `GET /auth/me` - Get current user
- `POST /auth/logout` - Logout

## 📦 Database Management - Schema-First Approach

This project uses a **YAML schema-first workflow** with Atlas for migrations and Prisma for ORM. All schema changes MUST go through the YAML files.

### Source of Truth: YAML Schema

```
schema/
├── schema.yaml       # Main schema definition (models, fields, relations)
├── enums.yaml        # Enum definitions
└── extensions.yaml   # PostgreSQL extensions (uuid-ossp, vector)
```

**NEVER edit these files directly:**
- `prisma/schema.prisma` - Generated from YAML
- `atlas/.schema.hcl` - Generated from YAML

### Schema Change Workflow

**IMPORTANT: After ANY changes to YAML schema files, run the `/schema` command:**

```
/schema
```

This slash command will guide you through:
1. Validating the YAML schema
2. Generating HCL and Prisma schemas
3. Creating a migration
4. Applying the migration locally
5. Regenerating the Prisma client

**Manual steps (if not using /schema):**

```bash
# 1. Edit the YAML schema files in schema/
# Example: Add new field to Member model in schema/schema.yaml

# 2. Validate, generate, migrate, and update Prisma
npm run schema:validate
npm run schema:generate
npm run schema:diff
npm run migrate:apply
npx prisma generate
npm run migrate:status
```

### Available Commands

| Command | Description |
|---------|-------------|
| `npm run schema:validate` | Validate YAML schema syntax |
| `npm run schema:generate` | Generate HCL + Prisma from YAML |
| `npm run schema:diff` | Create migration for schema changes |
| `npm run migrate:apply` | Apply pending migrations |
| `npm run migrate:status` | Check migration status |

### YAML Schema Syntax

**Adding a new field:**
```yaml
models:
  Member:
    fields:
      newField:
        type: string      # string, int, boolean, datetime, uuid, json, text, enum
        nullable: true    # Optional, default is required
        unique: true      # Optional
        default: "value"  # Optional
        description: "Field description"
```

**Adding a relation:**
```yaml
models:
  Member:
    relations:
      organization:
        type: many_to_one
        target: Organization
        fields: [organizationId]
        references: [id]
        onDelete: Cascade  # Cascade, SetNull, NoAction, Restrict
```

**Adding an index:**
```yaml
models:
  Member:
    indexes:
      - fields: [organizationId]
      - fields: [firstName, lastName]
        unique: true
```

### Field Types

| YAML Type | PostgreSQL | Prisma |
|-----------|------------|--------|
| `uuid` | uuid | String @id @default(uuid()) |
| `string` | varchar | String |
| `text` | text | String |
| `int` | integer | Int |
| `float` | double precision | Float |
| `boolean` | boolean | Boolean |
| `datetime` | timestamp | DateTime |
| `json` | jsonb | Json |
| `decimal` | decimal(p,s) | Decimal |
| `enum` | enum | Enum type |
| `string_array` | text[] | String[] |

### Local Development Setup

The local Postgres container (makeready-postgres on port 5434) has pgvector and uuid-ossp extensions pre-installed.

```bash
# Start local database
npm run db:local:start

# Apply migrations to local
npm run migrate:apply
```

### ⚠️ Critical Rules

1. **NEVER run `npx prisma migrate dev`** - Use Atlas workflow instead
2. **NEVER edit `prisma/schema.prisma` directly** - Edit `schema/schema.yaml`
3. **NEVER edit `atlas/.schema.hcl` directly** - It's auto-generated
4. **ALWAYS run `/schema` after editing YAML schema files**
5. **ALWAYS review generated migrations before applying**
6. **ALWAYS commit migration files** to version control after creating them

### Legacy Prisma Commands (Still Available)

```bash
# Generate Prisma client (after migrations)
npx prisma generate

# Open Prisma Studio (read-only exploration)
npx prisma studio
```

## 🔧 Environment Variables

Create `.env` file with:

```env
PORT=3001
NODE_ENV=development

# Google OAuth
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
GOOGLE_CALLBACK_URL=http://localhost:3001/auth/google/callback

# Session Secret
SESSION_SECRET=your_secret_key_here

# Client URL
CLIENT_URL=http://localhost:5173

# Database (Railway Postgres with pgvector)
DATABASE_URL="postgresql://user@localhost:5432/makeready?schema=public"
DIRECT_URL="postgresql://user@localhost:5432/makeready?schema=public"

# Cloudflare R2 Storage (S3-compatible)
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key_id
R2_SECRET_ACCESS_KEY=your_r2_secret_access_key
R2_BUCKET_NAME=makeready-media
R2_PUBLIC_URL=https://images.makeready.org
```

### Production Infrastructure

| Service | Provider | Details |
|---------|----------|---------|
| Database | Railway (pgvector) | `pgvector.railway.internal:5432` / `hopper.proxy.rlwy.net:33058` |
| Image Storage | Cloudflare R2 | S3-compatible, `makeready-media` bucket |
| Video Storage | Cloudflare Stream | Unchanged |
| API Hosting | Railway | `api.makeready.org` |

## 🚀 Development Commands

```bash
# Start development server (with hot reload)
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Run tests
npm test

# Lint code
npm run lint
```

## 🛡️ Security Best Practices

1. **Never commit .env files** - Credentials stay local
2. **Validate all inputs** - Use Zod schemas
3. **Authenticate requests** - Check `req.isAuthenticated()`
4. **Use proper HTTP status codes** - 200, 400, 401, 404, 500
5. **Handle errors gracefully** - Always use try/catch
6. **CORS configuration** - Only allow trusted origins

## 📋 API Best Practices

1. **RESTful conventions**:
   - GET for reading
   - POST for creating
   - PATCH for updating
   - DELETE for deleting

2. **Consistent response format**:
```typescript
// Success
{ data: {...}, message: "Success" }

// Error
{ error: "Error message" }
```

3. **Route organization**:
   - One file per resource
   - Mount in `index.ts`
   - Group related endpoints

4. **Error handling**:
```typescript
router.get('/', async (req, res) => {
  try {
    // Route logic
  } catch (error) {
    console.error('Error:', error)
    res.status(500).json({ error: 'Internal server error' })
  }
})
```

## 🔍 Debugging

**Server logs:**
```bash
# Development server logs go to console
npm run dev
```

**Check database:**
```bash
# Open Prisma Studio
npx prisma studio
```

**Test endpoints:**
- Use Postman collection in `/postman`
- Or use curl: `curl http://localhost:3001/api/users`

## 🎯 Common Tasks

### Add New API Endpoint

1. Use `/api` command to scaffold
2. Update Prisma schema if database changes needed
3. Run migration
4. Mount routes in `src/index.ts`
5. Regenerate Postman collection with `/postman`
6. Test endpoints

### Update Database Schema

**Use the `/schema` slash command:**

1. Edit `schema/schema.yaml` to add/modify fields
2. Run `/schema` to generate, migrate, and update everything
3. Review and commit the generated migration files
4. Update affected routes if needed
5. Test changes

### Add Authentication to Route

```typescript
// Require authentication
router.get('/protected', (req, res) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Not authenticated' })
  }

  // Route logic
  res.json({ user: req.user })
})
```

## 📖 Additional Resources

- [Express.js Docs](https://expressjs.com/)
- [Prisma Docs](https://www.prisma.io/docs/)
- [Passport.js Docs](http://www.passportjs.org/)
- [Zod Docs](https://zod.dev/)
