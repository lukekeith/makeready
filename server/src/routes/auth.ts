import { Router } from 'express'
import { passport } from '../config/passport'
import signature from 'cookie-signature'

const router = Router()

// Initiate Google OAuth flow
router.get('/google', (req, res, next) => {
  const platform = req.query.platform as string
  const state = platform === 'ios' ? 'platform:ios' : 'platform:web'

  passport.authenticate('google', {
    scope: ['profile', 'email'],
    state: state
  })(req, res, next)
})

// Temporary storage for auth codes (in production, use Redis)
const authCodes = new Map<string, { sessionId: string, userId: string, expiresAt: number }>()

// Google OAuth callback
router.get(
  '/google/callback',
  passport.authenticate('google', { failureRedirect: `${process.env.CLIENT_URL}/login` }),
  (req, res) => {
    console.log('✅ Google OAuth callback successful')
    console.log('   Session ID:', req.sessionID)
    console.log('   User:', req.user)
    console.log('   Is Authenticated:', req.isAuthenticated())
    console.log('   State:', req.query.state)

    // Successful authentication, redirect based on platform from state parameter
    const state = req.query.state as string
    if (state === 'platform:ios') {
      // Generate one-time authorization code for iOS
      const authCode = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)
      const user = req.user as any

      // Store auth code with session info (expires in 5 minutes)
      authCodes.set(authCode, {
        sessionId: req.sessionID,
        userId: user.id,
        expiresAt: Date.now() + 5 * 60 * 1000
      })

      console.log('   Generated auth code:', authCode)
      console.log('   Redirecting to iOS app')

      // Redirect to iOS app with auth code
      res.redirect(`makeready://auth/callback?code=${authCode}`)
    } else {
      // Redirect to web client
      console.log('   Redirecting to web client')
      res.redirect(`${process.env.CLIENT_URL}/home`)
    }
  }
)

// Exchange auth code for session
router.post('/exchange', (req, res) => {
  const { code } = req.body
  console.log('🔄 Auth code exchange requested:', code)

  if (!code) {
    console.log('❌ No code provided')
    return res.status(400).json({ error: 'Code required' })
  }

  const authData = authCodes.get(code)

  if (!authData) {
    console.log('❌ Invalid or expired code')
    return res.status(401).json({ error: 'Invalid or expired code' })
  }

  if (authData.expiresAt < Date.now()) {
    console.log('❌ Code expired')
    authCodes.delete(code)
    return res.status(401).json({ error: 'Code expired' })
  }

  // Delete code (one-time use)
  authCodes.delete(code)

  // Sign the session ID with the session secret (same as express-session uses)
  const sessionSecret = process.env.SESSION_SECRET || 'your-secret-key'
  const signedSessionId = 's:' + signature.sign(authData.sessionId, sessionSecret)

  console.log('✅ Code valid, returning signed session cookie')
  console.log('   Raw session ID:', authData.sessionId)
  console.log('   Signed cookie:', signedSessionId.substring(0, 30) + '...')

  // Return the signed session cookie value
  res.json({
    sessionId: signedSessionId,
    userId: authData.userId
  })
})

// Get current user
router.get('/me', (req, res) => {
  console.log('🔍 /auth/me called')
  console.log('   Cookie header:', req.headers.cookie)
  console.log('   Session ID:', req.sessionID)
  console.log('   Is Authenticated:', req.isAuthenticated())
  console.log('   User:', req.user)

  if (req.isAuthenticated()) {
    console.log('✅ User authenticated:', req.user)
    res.json({ user: req.user })
  } else {
    console.log('❌ User not authenticated')
    res.status(401).json({ error: 'Not authenticated' })
  }
})

// Logout
router.post('/logout', (req, res) => {
  req.logout((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' })
    }
    res.json({ message: 'Logged out successfully' })
  })
})

export default router
