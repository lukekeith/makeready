import express from 'express'
import cors from 'cors'
import cookieParser from 'cookie-parser'
import compression from 'compression'
import dotenv from 'dotenv'
import session from 'express-session'
import connectPgSimple from 'connect-pg-simple'
import pg from 'pg'
import path from 'path'
import { fileURLToPath } from 'url'
import { passport } from './config/passport.js'
import authRoutes from './routes/auth.js'
import usersRoutes from './routes/users.js'
import verificationRoutes from './routes/verification.js'
import smsRoutes from './routes/sms.js'
import invitesRoutes from './routes/invites.js'
import qrcodeRoutes from './routes/qrcode.js'
import publicRoutes from './routes/public.js'
import betaRoutes from './routes/beta.js'
import statusRoutes from './routes/status.js'
import organizationsRoutes from './routes/organizations.js'
import membersRoutes from './routes/members.js'
import groupMembersRoutes from './routes/group-members.js'
import groupsRoutes from './routes/groups.js'
import rolesRoutes from './routes/roles.js'
import mediaRoutes from './routes/media.js'
import bibleRoutes from './routes/bible.js'
import searchRoutes from './routes/search.js'
import preferencesRoutes from './routes/preferences.js'
import programsRoutes from './routes/programs.js'
import videosRoutes from './routes/videos.js'
import enrollmentsRoutes from './routes/enrollments.js'
import postsRoutes from './routes/posts.js'
import joinRoutes from './routes/join.js'
import groupJoinRequestRoutes from './routes/group-join-requests.js'
import eventsRoutes from './routes/events.js'
import activityLogsRoutes from './routes/activity-logs.js'
import engagementRoutes from './routes/engagement.js'
import notesRoutes from './routes/notes.js'
import activityProgressRoutes from './routes/activity-progress.js'
import memberLessonsRoutes from './routes/member-lessons.js'
import apiKeysRoutes from './routes/api-keys.js'
import deviceTokensRoutes from './routes/device-tokens.js'
import notificationsRoutes from './routes/notifications.js'
import smsCampaignsRoutes from './routes/sms-campaigns.js'
import githubRoutes from './routes/github.js'
import templatesRoutes from './routes/templates.js'
import activitiesRoutes from './routes/activities.js'
import themesRoutes from './routes/themes.js'
import { studyPreviewApiRouter, studyPreviewPublicRouter, studyPreviewDevRouter, previewStateRouter } from './routes/study-preview.js'
import { prisma } from './lib/prisma.js'
import { setupSwagger } from './docs/swagger.js'
import { authenticateApiKey } from './middleware/api-key.js'
import { requireAuth } from './middleware/auth.js'
import { ensureAvatarBucket } from './services/storage.js'

// ES module compatibility: define __dirname
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config()

const app = express()
// MakeReady uses port 3010 to avoid conflicts with other projects
const PORT = process.env.PORT || 3010

// PostgreSQL session store setup
// Use DIRECT_URL if available to avoid PgBouncer prepared statement issues
const PgStore = connectPgSimple(session)
const pgPool = new pg.Pool({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  max: 20,                      // Increase from default 10 for better concurrency
  idleTimeoutMillis: 30000,     // Close idle connections after 30 seconds
  connectionTimeoutMillis: 5000, // Fail fast if can't connect
})

// Ensure session table exists on startup
// This table is NOT managed by Prisma, so it can be accidentally dropped during migrations
async function ensureSessionTable() {
  const client = await pgPool.connect()
  try {
    // Check if session table exists
    const result = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'session'
      ) as exists
    `)

    if (!result.rows[0]?.exists) {
      console.log('📦 Creating session table...')
      await client.query(`
        CREATE TABLE IF NOT EXISTS session (
          sid VARCHAR NOT NULL PRIMARY KEY,
          sess JSON NOT NULL,
          expire TIMESTAMP(6) NOT NULL
        )
      `)
      await client.query(`
        CREATE INDEX IF NOT EXISTS IDX_session_expire ON session (expire)
      `)
      console.log('✅ Session table created')
    }
  } catch (error) {
    console.error('❌ Failed to ensure session table:', error)
    // Don't throw - let connect-pg-simple try its own table creation
  } finally {
    client.release()
  }
}

// Run session table check immediately
ensureSessionTable()

// Trust proxy - required for Railway/Cloudflare (correct IP extraction for rate limiting)
app.set('trust proxy', 1)

// ============================================================================
// Security Layer 1: Helmet — security headers (HSTS, CSP, X-Frame, etc.)
// Must be first so all responses get hardened headers.
// ============================================================================
import helmet from 'helmet'
app.use(helmet({
  contentSecurityPolicy: false,   // API serves JSON, not HTML (except /logs, /activity)
  crossOriginEmbedderPolicy: false, // Allow embedding (iPhone WKWebView)
  hsts: { maxAge: 31536000, includeSubDomains: true }, // 1 year
}))

// ============================================================================
// Security Layer 2: Bot Guard — block scanner paths and bot user agents
// Runs before any middleware to reject probes cheaply (no session, no DB).
// ============================================================================
import { botGuard } from './middleware/bot-guard.js'
app.use(botGuard)

// ============================================================================
// Security Layer 3: Rate Limiting — tiered limits per endpoint group
// Disabled in test environment so test suites can run without throttling.
// ============================================================================
import rateLimit from 'express-rate-limit'

if (process.env.NODE_ENV !== 'test') {
  // General API rate limit: 200 req/min per IP
  const generalLimiter = rateLimit({
    windowMs: 60_000,
    max: 200,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Too many requests, please try again later' },
    skip: (req) => req.path === '/health' || req.path === '/robots.txt',
  })
  app.use('/api/', generalLimiter)

  // Auth endpoints: stricter limit — 10 req/min per IP
  const authLimiter = rateLimit({
    windowMs: 60_000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Too many authentication attempts, please wait' },
  })
  app.use('/auth/', authLimiter)
  app.use('/api/members/verify-phone', authLimiter)
  app.use('/api/members/confirm-verification', authLimiter)
}

// ============================================================================
// CORS configuration to allow credentials
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (like mobile apps, Postman, curl)
      if (!origin) return callback(null, true)

      const allowedOrigins = [
        process.env.CLIENT_URL,
        'https://app.makeready.org',
        'http://localhost:8000',
        'http://localhost:5173',
        'http://127.0.0.1:5173',
        'http://localhost:3010',   // Local API server (for /logs, /themes/preview pages)
      ].filter(Boolean)

      if (allowedOrigins.includes(origin)) {
        callback(null, true)
      } else if (process.env.NODE_ENV !== 'production') {
        callback(null, true) // Allow all origins in development only
      } else {
        callback(new Error('Not allowed by CORS'))
      }
    },
    credentials: true,
  })
)

// Compression middleware - reduces response sizes by 50-80%
// Must be before body parsing and routes
app.use(compression())

// Cookie parsing middleware (needed for preview token device-locking)
app.use(cookieParser())

// Body parsing middleware
// Increase limit for image uploads (base64 encoded images can be large)
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// Serve static files from public directory
// Resolve public/ from project root (works in both dev and production)
const publicPath = path.join(__dirname, '../public')
app.use(express.static(publicPath))

// Serve theme CSS files statically from themes/ directory
const themesPath = path.join(__dirname, '../themes')
app.get('/themes/preview', (_req, res) => {
  res.sendFile(path.join(publicPath, 'theme-preview.html'))
})
app.use('/themes', express.static(themesPath, {
  setHeaders: (res) => {
    res.setHeader('Cache-Control', 'public, max-age=3600')
  },
}))

// Session middleware (must be before passport)
// Uses PostgreSQL for session storage so sessions persist across server restarts
app.use(
  session({
    store: new PgStore({
      pool: pgPool,
      tableName: 'session', // Default table name
      pruneSessionInterval: 60 * 15, // Prune expired sessions every 15 minutes
      createTableIfMissing: true, // Auto-create session table if it doesn't exist
    }),
    secret: process.env.SESSION_SECRET || 'your-secret-key',
    resave: false,
    saveUninitialized: false,
    // rolling: true re-emits the session cookie on every response, so the
    // 30-day expiry window slides forward each time the user is active.
    // Combined with maxAge = 30 days that means a session ends only after
    // 30 days of full inactivity. Matches the Laravel-side SESSION_LIFETIME.
    rolling: true,
    cookie: {
      maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days, sliding (see rolling above)
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production', // HTTPS in production, HTTP in development
      sameSite: 'lax', // Must be 'lax' for OAuth redirects
      domain: undefined, // Let browser set the domain
    },
  })
)

// Initialize Passport
app.use(passport.initialize())
app.use(passport.session())

// API Key authentication middleware
// Must run after Passport but before routes
// Checks for Bearer token with mr_ prefix and authenticates if valid
app.use(authenticateApiKey)

// Request logging middleware — logs every API request to ActivityLog
// when VERBOSE_LOGGING=true. Runs after auth so req.user/session are available.
import { requestLogger } from './middleware/request-logger.js'
app.use(requestLogger)

// Setup Swagger API documentation
setupSwagger(app)

// Health check endpoint with database status
app.get('/health', async (_req, res) => {
  const health: {
    status: string
    service: string
    timestamp: string
    database?: { status: string; error?: string }
  } = {
    status: 'ok',
    // Stable fingerprint so clients (e.g. the iPhone app's local port healer)
    // can positively identify a MakeReady API vs. other dev servers on nearby ports.
    service: 'makeready',
    timestamp: new Date().toISOString(),
  }

  // Check database connection
  try {
    await prisma.$queryRaw`SELECT 1`
    health.database = { status: 'healthy' }
  } catch (error) {
    health.database = {
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error',
    }
    // Still return 200 so Railway healthcheck passes
    // The app can run without DB for some endpoints
  }

  res.json(health)
})

// System status endpoint
app.use('/api/status', statusRoutes)

// Public beta application routes (Google-authenticated submission, no app access granted)
app.use('/api/beta', betaRoutes)

// Public routes (no authentication required)
app.use('/public', publicRoutes)
app.use('/public/preview', studyPreviewPublicRouter)
app.use('/api/preview', previewStateRouter)

// Auth routes
app.use('/auth', authRoutes)

// Join routes (invite landing pages with OG meta tags)
app.use('/join', joinRoutes)

// Users routes
app.use('/api/users', usersRoutes)

// Verification routes (Twilio Verify API)
app.use('/api/verification', verificationRoutes)

// SMS routes (Twilio Programmable SMS)
app.use('/api/sms', smsRoutes)

// SMS Campaign routes (A2P campaign management)
app.use('/api/sms-campaigns', smsCampaignsRoutes)

// Invites routes (Group invitations)
app.use('/api/invites', invitesRoutes)

// QR Code routes (QR code generation)
app.use('/api/qrcode', qrcodeRoutes)

// Organization routes (Organization management)
app.use('/api/organizations', organizationsRoutes)

// Member routes (Member management)
app.use('/api/members', membersRoutes)

// Group CRUD routes
app.use('/api/groups', groupsRoutes)

// Group membership routes (Add/remove members from groups)
app.use('/api/groups', groupMembersRoutes)

// Group join request routes (Request/approval for group code joining)
app.use('/api/groups/:groupId/join-requests', groupJoinRequestRoutes)

// Admin: list join requests across all groups (super admin or API key only)
app.get('/api/admin/join-requests', requireAuth, async (req, res) => {
  try {
    const user = req.user as any
    if (!user?.isSuperAdmin && !req.apiKeyId) {
      return res.status(403).json({ success: false, error: 'Forbidden' })
    }

    const status = (req.query.status as string) || 'pending'
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 200)

    const requests = await prisma.groupJoinRequest.findMany({
      where: { status },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        member: {
          select: { id: true, firstName: true, lastName: true, phoneNumber: true },
        },
        group: {
          select: { id: true, name: true, code: true },
        },
      },
    })

    res.json({ success: true, requests, count: requests.length })
  } catch (error) {
    console.error('Error fetching admin join requests:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

// Admin: query activity logs (super admin or API key only)
app.get('/api/admin/activity-logs', requireAuth, async (req, res) => {
  try {
    const user = req.user as any
    if (!user?.isSuperAdmin && !req.apiKeyId) {
      return res.status(403).json({ success: false, error: 'Forbidden' })
    }

    const limit = Math.min(parseInt(req.query.limit as string) || 50, 500)
    const offset = parseInt(req.query.offset as string) || 0

    // Build filter
    const where: Record<string, unknown> = {}
    if (req.query.category) where.category = req.query.category
    if (req.query.type) where.activityType = { contains: req.query.type as string }
    if (req.query.status) where.status = req.query.status
    if (req.query.groupId) where.groupId = req.query.groupId
    if (req.query.memberId) where.memberId = req.query.memberId
    if (req.query.userId) where.userId = req.query.userId
    if (req.query.search) where.message = { contains: req.query.search as string, mode: 'insensitive' }
    if (req.query.since) where.createdAt = { gte: new Date(req.query.since as string) }
    if (req.query.route) where.route = { contains: req.query.route as string }

    const [logs, total] = await Promise.all([
      prisma.activityLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      prisma.activityLog.count({ where }),
    ])

    res.json({ success: true, logs, count: logs.length, total, offset, limit })
  } catch (error) {
    console.error('Error fetching activity logs:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

// Role management routes (RBAC - roles, permissions, assignments)
app.use('/api', rolesRoutes)

// Media management routes
app.use('/api', mediaRoutes)

// Bible routes
app.use('/api/bible', bibleRoutes)

// Smart search routes (direct refs + semantic search)
app.use('/api/search', searchRoutes)

// User preferences
app.use('/api/preferences', preferencesRoutes)

// Study program routes
app.use('/api', programsRoutes)

// Video routes (Cloudflare Stream)
app.use('/api/videos', videosRoutes)

// Enrollment routes (Group study program enrollments)
app.use('/api', enrollmentsRoutes)

// Posts routes (Group feed posts)
app.use('/api', postsRoutes)

// Events routes (CRUD, attendees, attachments)
app.use('/api', eventsRoutes)

// Activity ledger (user-facing activity feed)
app.use('/api/activities', activitiesRoutes)

// Activity logs routes (read-only logging for debugging)
app.use('/api/activity-logs', activityLogsRoutes)

// Engagement analytics (leader dashboard heatmap + weekly charts, sourced
// from real study progress rather than the request/audit log)
app.use('/api/engagement', engagementRoutes)

// API keys routes (CRUD for API key management)
app.use('/api/api-keys', apiKeysRoutes)

// Device tokens routes (APNs push notification registration)
app.use('/api/device-tokens', deviceTokensRoutes)
app.use('/api/notifications', notificationsRoutes)

// Notes routes (unified notes for SOAP, journals, etc.)
app.use('/api', notesRoutes)

// Activity progress routes (SOAP step tracking)
app.use('/api', activityProgressRoutes)

// Member lessons and enrollment progress routes
app.use('/api', memberLessonsRoutes)

// Lesson template routes (CRUD + duplicate + activity management)
app.use('/api', templatesRoutes)

// Theme routes (system + org themes for study content)
app.use('/api/themes', themesRoutes)

// Study preview routes (preview tokens for program creators)
app.use('/api/study-preview', studyPreviewApiRouter)

// GitHub activity routes (monorepo commit feed, classified by app folder)
app.use('/api/github', githubRoutes)

// ============================================================================
// Dev-only: Set member session for testing
// ============================================================================
if (process.env.NODE_ENV !== 'production') {
  app.post('/api/dev/auth/member/:memberId', async (req, res) => {
    const { memberId } = req.params

    // Verify member exists
    const member = await prisma.member.findUnique({
      where: { id: memberId },
    })

    if (!member) {
      return res.status(404).json({
        success: false,
        error: 'Member not found',
      })
    }

    // Set member session
    req.session.memberId = memberId
    req.session.save((err) => {
      if (err) {
        return res.status(500).json({
          success: false,
          error: 'Failed to save session',
        })
      }

      res.json({
        success: true,
        message: `Authenticated as member: ${member.firstName} ${member.lastName}`,
        memberId,
      })
    })
  })

  app.get('/api/dev/auth/status', (req, res) => {
    res.json({
      memberId: req.session.memberId || null,
      authenticated: !!req.session.memberId,
    })
  })

  app.use('/api/dev/preview', studyPreviewDevRouter)
}

// API routes
app.get('/api', (_req, res) => {
  res.json({ message: 'MakeReady API is running' })
})

// Performance dashboard
app.get('/performance', (_req, res) => {
  res.sendFile(path.join(publicPath, 'performance.html'))
})

// Activity page - combined GitHub commit feed
app.get('/activity', (_req, res) => {
  res.sendFile(path.join(publicPath, 'activity.html'))
})

// Activity logs viewer — injects API key so no login prompt needed (temporary beta tool)
import { readFileSync } from 'fs'
app.get('/logs', (_req, res) => {
  const html = readFileSync(path.join(publicPath, 'logs.html'), 'utf-8')
  const injected = html.replace('__INJECTED_API_KEY__', process.env.MAKEREADY_API_KEY || '')
  res.type('html').send(injected)
})

// Root route - serve landing page
app.get('/', (_req, res) => {
  res.sendFile(path.join(publicPath, 'index.html'))
})

// Export app for testing
export { app }

// Start HTTP server (skip in test environment)
if (process.env.NODE_ENV !== 'test') {
  // Initialize storage buckets
  ensureAvatarBucket().catch((error) => {
    console.warn('⚠️ Could not initialize avatar bucket:', error.message)
  })

  app.listen(PORT, () => {
    console.log(`🚀 MakeReady server running on http://localhost:${PORT}`)
    console.log(`📱 Environment: ${process.env.NODE_ENV || 'development'}`)

    // Start background jobs
    import('./jobs/cache-eviction.js').then(({ startCacheEvictionJob }) => {
      startCacheEvictionJob()
    }).catch((err) => {
      console.warn('⚠️ Could not start cache eviction job:', err.message)
    })
  })
}

