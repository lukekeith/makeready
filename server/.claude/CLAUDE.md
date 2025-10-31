# Claude Code Instructions for MakeReady Server

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

## 📦 Database Management

### Prisma Schema

Located at `prisma/schema.prisma`

**Example Model:**
```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  picture   String?
  googleId  String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### Common Commands

```bash
# Create migration
npx prisma migrate dev --name migration_name

# Generate Prisma client
npx prisma generate

# Reset database (development only!)
npx prisma migrate reset

# Open Prisma Studio
npx prisma studio

# Validate schema
npx prisma validate
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

# Database
DATABASE_URL="postgresql://user@localhost:5432/makeready?schema=public"
```

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

1. Edit `prisma/schema.prisma`
2. Run `npx prisma migrate dev --name description`
3. Update affected routes
4. Test changes

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
