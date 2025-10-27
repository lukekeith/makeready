import express from 'express'
import https from 'https'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import cors from 'cors'
import dotenv from 'dotenv'
import session from 'express-session'
import { passport } from './config/passport'
import authRoutes from './routes/auth'
import usersRoutes from './routes/users'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config()

const app = express()
const PORT = process.env.PORT || 3001

// CORS configuration to allow credentials
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (like mobile apps, Postman, curl)
      if (!origin) return callback(null, true)

      // Allow localhost and 127.0.0.1 for development
      const allowedOrigins = [
        'https://localhost:5173',
        'https://127.0.0.1:5173',
        'http://localhost:5173',
        'http://127.0.0.1:5173',
        process.env.CLIENT_URL
      ].filter(Boolean)

      if (allowedOrigins.includes(origin)) {
        callback(null, true)
      } else {
        callback(null, true) // Allow all origins in development
      }
    },
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
      secure: false, // HTTP for local development (iOS Simulator)
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

// Users routes
app.use('/api/users', usersRoutes)

// API routes
app.get('/api', (req, res) => {
  res.json({ message: 'MakeReady API is running' })
})

// Start HTTP server for local development (iOS Simulator)
app.listen(PORT, () => {
  console.log(`🚀 MakeReady server running on http://localhost:${PORT}`)
  console.log(`📱 HTTP enabled for iOS Simulator development`)
})
