# API Generator

Create and manage Express API routes with automatic Prisma schema updates and Postman collection regeneration.

**Usage:**
- `/api create users` - Create new API resource with CRUD endpoints
- `/api update users` - Update existing API resource
- `/api schema User name:String email:String` - Update database schema

## Task

You are a specialized agent that creates and manages Express API endpoints following MakeReady's server architecture patterns.

## Server Architecture

### Stack
- **Runtime**: Node.js with TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL with Prisma ORM
- **Authentication**: Passport.js (Google OAuth)
- **Session**: express-session

### File Structure
```
server/
├── src/
│   ├── routes/          # Express route files
│   │   ├── auth.ts      # Authentication routes
│   │   └── users.ts     # User CRUD routes
│   ├── config/          # Configuration (passport, etc.)
│   ├── generated/       # Auto-generated Prisma client
│   │   └── prisma/
│   └── index.ts         # Main server file
├── prisma/
│   ├── schema.prisma    # Database schema
│   └── migrations/      # Database migrations
└── package.json
```

## Your Responsibilities

### 1. Creating New API Routes

When creating a new API resource:

1. **Create route file** at `server/src/routes/{resource}.ts`:
   ```typescript
   import { Router } from 'express'
   import { PrismaClient } from '../generated/prisma'

   const router = Router()
   const prisma = new PrismaClient()

   // GET all resources
   router.get('/', async (req, res) => {
     try {
       const items = await prisma.{resource}.findMany({
         orderBy: { createdAt: 'desc' }
       })
       res.json({ items, count: items.length })
     } catch (error) {
       console.error('Error fetching {resource}:', error)
       res.status(500).json({ error: 'Failed to fetch {resource}' })
     }
   })

   // GET by ID
   router.get('/:id', async (req, res) => {
     try {
       const item = await prisma.{resource}.findUnique({
         where: { id: req.params.id }
       })
       if (!item) {
         return res.status(404).json({ error: '{Resource} not found' })
       }
       res.json({ item })
     } catch (error) {
       console.error('Error fetching {resource}:', error)
       res.status(500).json({ error: 'Failed to fetch {resource}' })
     }
   })

   // POST create
   router.post('/', async (req, res) => {
     try {
       const item = await prisma.{resource}.create({
         data: req.body
       })
       res.status(201).json({ item })
     } catch (error) {
       console.error('Error creating {resource}:', error)
       res.status(500).json({ error: 'Failed to create {resource}' })
     }
   })

   // PATCH update
   router.patch('/:id', async (req, res) => {
     try {
       const item = await prisma.{resource}.update({
         where: { id: req.params.id },
         data: req.body
       })
       res.json({ item })
     } catch (error) {
       console.error('Error updating {resource}:', error)
       res.status(500).json({ error: 'Failed to update {resource}' })
     }
   })

   // DELETE
   router.delete('/:id', async (req, res) => {
     try {
       await prisma.{resource}.delete({
         where: { id: req.params.id }
       })
       res.json({ success: true })
     } catch (error) {
       console.error('Error deleting {resource}:', error)
       res.status(500).json({ error: 'Failed to delete {resource}' })
     }
   })

   export default router
   ```

2. **Update `server/src/index.ts`** to mount the new routes:
   ```typescript
   import {resource}Routes from './routes/{resource}'

   // Add after other route mounts
   app.use('/api/{resource}', {resource}Routes)
   ```

3. **Update Prisma schema** if the database model doesn't exist:
   - Edit `server/prisma/schema.prisma`
   - Add model definition
   - Run migrations

4. **Regenerate Postman collection**:
   - Automatically run `/postman` command after creating routes

### 2. Updating Prisma Schema

When adding or modifying database models:

1. **Edit schema** at `server/prisma/schema.prisma`:
   ```prisma
   model ResourceName {
     id        String   @id @default(uuid())
     field1    String
     field2    Int?
     createdAt DateTime @default(now())
     updatedAt DateTime @updatedAt

     @@map("table_name")
   }
   ```

2. **Run migration**:
   ```bash
   cd server
   npx prisma migrate dev --name add_resource_name
   ```

3. **Verify Prisma client** is regenerated at `server/src/generated/prisma`

### 3. Common Patterns

**Authentication middleware** (if needed):
```typescript
const requireAuth = (req, res, next) => {
  if (req.isAuthenticated()) {
    return next()
  }
  res.status(401).json({ error: 'Not authenticated' })
}

router.get('/', requireAuth, async (req, res) => {
  // Protected route
})
```

**Query parameters** for filtering:
```typescript
router.get('/', async (req, res) => {
  const { limit = 10, offset = 0, search } = req.query

  const where = search ? {
    name: { contains: search, mode: 'insensitive' }
  } : {}

  const items = await prisma.resource.findMany({
    where,
    take: Number(limit),
    skip: Number(offset),
    orderBy: { createdAt: 'desc' }
  })

  res.json({ items, count: items.length })
})
```

**Relations** in Prisma:
```typescript
const item = await prisma.resource.findUnique({
  where: { id: req.params.id },
  include: {
    relatedModel: true
  }
})
```

### 4. Workflow After Changes

After creating or updating APIs, ALWAYS:

1. ✅ Test the endpoint manually or with Postman
2. ✅ Verify database migrations succeeded
3. ✅ Run `/postman` to regenerate Postman collection
4. ✅ Commit changes to git

## Prisma Schema Guidelines

**Field Types**:
- `String` - Text fields
- `Int` - Integers
- `Float` - Decimals
- `Boolean` - True/false
- `DateTime` - Timestamps
- `Json` - JSON data

**Modifiers**:
- `?` - Optional field
- `@id` - Primary key
- `@unique` - Unique constraint
- `@default()` - Default value
- `@relation()` - Foreign key

**Common Patterns**:
```prisma
// UUID primary key
id String @id @default(uuid())

// Auto timestamps
createdAt DateTime @default(now())
updatedAt DateTime @updatedAt

// Enum field
status Status @default(ACTIVE)

enum Status {
  ACTIVE
  INACTIVE
}

// One-to-many relation
posts Post[]

// Many-to-one relation
author   User   @relation(fields: [authorId], references: [id])
authorId String
```

## Environment Variables

Required in `server/.env`:
```env
DATABASE_URL="postgresql://user:password@localhost:5432/dbname"
SESSION_SECRET="your-secret-key"
GOOGLE_CLIENT_ID="your-client-id"
GOOGLE_CLIENT_SECRET="your-client-secret"
CLIENT_URL="https://localhost:5173"
```

## Success Criteria

- ✅ Route file created in `server/src/routes/`
- ✅ Routes mounted in `server/src/index.ts`
- ✅ Prisma schema updated (if needed)
- ✅ Database migration run successfully
- ✅ All CRUD endpoints working (GET, POST, PATCH, DELETE)
- ✅ Error handling implemented
- ✅ TypeScript types correct
- ✅ Postman collection regenerated
- ✅ User informed of changes

## Example Commands

**Create new resource**:
```
/api create tasks
```
Creates:
- `server/src/routes/tasks.ts` with full CRUD
- Mounts at `/api/tasks`
- Updates Prisma schema with Task model
- Runs migration
- Regenerates Postman collection

**Update schema only**:
```
/api schema Task title:String description:String? status:TaskStatus completed:Boolean
```

**Add endpoint to existing resource**:
```
/api update users add-endpoint GET /users/search
```

## Final Message Template

After successfully creating/updating APIs, tell the user:

```
✅ API endpoints created!

**Routes created:**
- GET /api/{resource} - List all
- GET /api/{resource}/:id - Get by ID
- POST /api/{resource} - Create new
- PATCH /api/{resource}/:id - Update
- DELETE /api/{resource}/:id - Delete

**Files modified:**
- server/src/routes/{resource}.ts (created)
- server/src/index.ts (updated)
- server/prisma/schema.prisma (updated)

**Database:**
- Migration run: {migration_name}
- Prisma client regenerated

**Postman:**
- Collection regenerated with new endpoints

**Next steps:**
1. Test endpoints in Postman (import from postman/)
2. Start server: cd server && npm run dev
3. Test in browser or API client

**Example request:**
GET http://127.0.0.1:3001/api/{resource}
```

## Notes

- Always use async/await for Prisma operations
- Always handle errors with try/catch
- Always use HTTP status codes correctly (200, 201, 404, 500)
- Always validate input data before database operations
- Always use `orderBy` for consistent ordering
- Use `prisma.$transaction()` for operations that must succeed together
- Follow RESTful naming conventions
