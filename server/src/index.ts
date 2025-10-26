import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import session from 'express-session'
import { passport } from './config/passport'
import authRoutes from './routes/auth'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 3001

// CORS configuration to allow credentials
app.use(
  cors({
    origin: process.env.CLIENT_URL || 'http://localhost:5173',
    credentials: true,
  })
)

// Body parsing middleware
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Session middleware (must be before passport)
app.use(
  session({
    secret: process.env.SESSION_SECRET || 'your-secret-key',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 24 * 60 * 60 * 1000, // 24 hours
      httpOnly: true,
      secure: false, // Set to false for localhost development
      sameSite: 'lax', // Must be 'lax' for OAuth redirects
      domain: undefined, // Let browser set the domain
    },
  })
)

// Initialize Passport
app.use(passport.initialize())
app.use(passport.session())

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// Auth routes
app.use('/auth', authRoutes)

// API routes
app.get('/api', (req, res) => {
  res.json({ message: 'MakeReady API is running' })
})

app.listen(PORT, () => {
  console.log(`🚀 MakeReady server running on http://localhost:${PORT}`)
})
