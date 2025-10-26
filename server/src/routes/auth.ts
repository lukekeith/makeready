import { Router } from 'express'
import { passport } from '../config/passport'

const router = Router()

// Initiate Google OAuth flow
router.get('/google', passport.authenticate('google', { scope: ['profile', 'email'] }))

// Google OAuth callback
router.get(
  '/google/callback',
  passport.authenticate('google', { failureRedirect: `${process.env.CLIENT_URL}/login` }),
  (req, res) => {
    console.log('✅ Google OAuth callback successful')
    console.log('   Session ID:', req.sessionID)
    console.log('   User:', req.user)
    console.log('   Is Authenticated:', req.isAuthenticated())

    // Successful authentication, redirect to home
    res.redirect(`${process.env.CLIENT_URL}/home`)
  }
)

// Get current user
router.get('/me', (req, res) => {
  console.log('🔍 /auth/me called')
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
