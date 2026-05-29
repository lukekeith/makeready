import { Router } from 'express'
import { passport } from '../config/passport.js'
import signature from 'cookie-signature'
import { OAuth2Client } from 'google-auth-library'
import { logSuccess, logFailure } from '../lib/activity-log.js'
import { ActivityTypes } from '../lib/activity-types.js'
import { prisma } from '../lib/prisma.js'
import { linkGoogleProfile, type GoogleProfile } from '../services/member-google.js'
import { linkMemberViaGoogle, getLinkedUser } from '../services/account-linking.js'
import { createVerifyService } from '../services/twilio.js'

const router = Router()

/**
 * Check if a User has access to the iOS app
 * Only group leaders and above can access the iPhone app
 * @param userId - User ID to check
 * @returns true if user can access iOS app
 */
async function canAccessIosApp(userId: string): Promise<boolean> {
  // Super Admin always has access
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { isSuperAdmin: true, isActive: true },
  })
  if (!user?.isActive) return false
  if (user.isSuperAdmin) return true

  // Organization owner always has access
  const ownedOrg = await prisma.organization.findFirst({
    where: { ownerId: userId, isActive: true },
  })
  if (ownedOrg) return true

  // Check for leadership RBAC roles (Owner, Admin, Group Leader)
  const leadershipRole = await prisma.userRole.findFirst({
    where: {
      userId,
      role: { name: { in: ['Owner', 'Admin', 'Group Leader'] } },
    },
  })
  return leadershipRole !== null
}

// Temporary storage for profile link tokens (in production, use Redis)
const profileLinkTokens = new Map<string, { memberId: string, expiresAt: number }>()

// Temporary storage for account link tokens (in production, use Redis)
const accountLinkTokens = new Map<string, { memberId: string, expiresAt: number }>()

/**
 * @openapi
 * /auth/google:
 *   get:
 *     tags: [Authentication]
 *     summary: Initiate Google OAuth flow
 *     description: |
 *       Redirects to Google OAuth consent screen. Use `platform=ios` for mobile apps.
 *
 *       **iOS Flow:**
 *       1. Open this URL in ASWebAuthenticationSession
 *       2. After consent, redirects to `makeready://auth/callback?code=xxx`
 *       3. Exchange code via `POST /auth/exchange`
 *
 *       **Web Flow:**
 *       1. Redirect browser to this URL
 *       2. After consent, redirects to `/member/groups` with session cookie set
 *     parameters:
 *       - in: query
 *         name: platform
 *         schema:
 *           type: string
 *           enum: [ios, web]
 *         description: Platform type (affects redirect behavior)
 *     responses:
 *       302:
 *         description: Redirects to Google OAuth consent screen
 */
router.get('/google', (req, res, next) => {
  const platform = req.query.platform as string
  const state = platform === 'ios' ? 'platform:ios' : 'platform:web'

  // Log OAuth initiation (fire and forget)
  logSuccess(ActivityTypes.AUTH.GOOGLE_LOGIN_INITIATED, req, { platform })

  passport.authenticate('google', {
    scope: ['profile', 'email'],
    state: state
  })(req, res, next)
})

// Temporary storage for auth codes (in production, use Redis)
const authCodes = new Map<string, { sessionId: string, userId: string, expiresAt: number }>()

/**
 * @openapi
 * /auth/google/callback:
 *   get:
 *     tags: [Authentication]
 *     summary: Google OAuth callback
 *     description: |
 *       Handles Google OAuth callback. Not called directly by clients.
 *
 *       **iOS:** Redirects to `makeready://auth/callback?code=xxx`
 *       **Web:** Redirects to `/groups` with session cookie set
 *     parameters:
 *       - in: query
 *         name: code
 *         schema:
 *           type: string
 *         description: OAuth authorization code from Google
 *       - in: query
 *         name: state
 *         schema:
 *           type: string
 *         description: Platform state (platform:ios or platform:web)
 *     responses:
 *       302:
 *         description: Redirects based on platform
 *       500:
 *         description: Authentication failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get(
  '/google/callback',
  (req, res, next) => {
    console.log('🔵 OAuth callback received')
    console.log('   Query:', req.query)

    // IMPORTANT: Preserve memberId before OAuth login, as req.logIn() regenerates the session
    // This is needed for profile-linking flow where member is already authenticated
    const preservedMemberId = req.session.memberId
    if (preservedMemberId) {
      console.log('   Preserving memberId for profile linking:', preservedMemberId)
    }

    passport.authenticate('google', { failureRedirect: `${process.env.CLIENT_URL}/login` }, (err: any, user: any, info: any) => {
      if (err) {
        console.error('❌ Passport authentication error:', err)
        logFailure(ActivityTypes.AUTH.GOOGLE_LOGIN_FAILED, req, {
          errorMessage: err.message,
        })
        return res.status(500).json({ error: 'Authentication failed', details: err.message })
      }
      if (!user) {
        console.log('❌ No user returned from passport:', info)
        logFailure(ActivityTypes.AUTH.GOOGLE_CALLBACK_ERROR, req, {
          errorMessage: info?.message || 'No user returned',
        })
        return res.redirect(`${process.env.CLIENT_URL}/login`)
      }
      req.logIn(user, (loginErr) => {
        if (loginErr) {
          console.error('❌ Login error:', loginErr)
          logFailure(ActivityTypes.AUTH.GOOGLE_LOGIN_FAILED, req, {
            errorMessage: loginErr.message,
          })
          return res.status(500).json({ error: 'Login failed', details: loginErr.message })
        }

        // Restore memberId after session regeneration (for profile linking flow)
        if (preservedMemberId) {
          req.session.memberId = preservedMemberId
          console.log('   Restored memberId after OAuth:', preservedMemberId)
        }

        // Continue to success handler
        next()
      })
    })(req, res, next)
  },
  async (req, res) => {
    console.log('✅ Google OAuth callback successful')
    console.log('   Session ID:', req.sessionID)
    console.log('   User:', req.user)
    console.log('   Is Authenticated:', req.isAuthenticated())
    console.log('   State:', req.query.state)

    const user = req.user as any
    const state = req.query.state as string

    // Handle profile linking flow (for Members, NOT login)
    if (state?.startsWith('link-profile:')) {
      // Extract memberId and token from state
      const parts = state.split(':')
      const memberId = parts[1]
      const token = parts[2]

      // Verify token is valid
      const tokenData = profileLinkTokens.get(token)
      if (!tokenData || tokenData.memberId !== memberId || tokenData.expiresAt < Date.now()) {
        console.log('❌ Invalid or expired profile link token')
        logFailure(ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_FAILED, req, {
          memberId,
          errorMessage: 'Invalid or expired token',
        })
        // Log out the Passport user but preserve member session
        return new Promise<void>((resolve) => {
          req.logout(() => {
            req.session.memberId = memberId
            req.session.save(() => {
              res.redirect(`${process.env.CLIENT_URL}/member/home?error=link_expired`)
              resolve()
            })
          })
        })
      }

      // Delete token (one-time use)
      profileLinkTokens.delete(token)

      // Link Google profile to member
      const googleProfile: GoogleProfile = {
        googleId: user.googleId,
        email: user.email,
        name: user.name,
        picture: user.picture,
      }

      const linkResult = await linkGoogleProfile(memberId, googleProfile)

      // Log out the Passport user (Google) but preserve member session
      // We need to restore memberId after logout since logout clears session data
      return new Promise<void>((resolve) => {
        req.logout(() => {
          // Restore member session after logging out Passport user
          req.session.memberId = memberId
          req.session.save((saveErr) => {
            if (saveErr) {
              console.error('❌ Failed to save session after profile link:', saveErr)
            }

            if (!linkResult.success) {
              console.log('❌ Failed to link Google profile:', linkResult.error)
              logFailure(ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_FAILED, req, {
                memberId,
                errorMessage: linkResult.error,
              })
              const errorMsg = encodeURIComponent(linkResult.error || 'Failed to link Google account')
              res.redirect(`${process.env.CLIENT_URL}/member/home?error=${errorMsg}`)
            } else {
              console.log('✅ Google profile linked successfully for member:', memberId)
              logSuccess(ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_SUCCESS, req, {
                memberId,
                googleEmail: user.email,
              })
              res.redirect(`${process.env.CLIENT_URL}/member/home?profile_linked=true`)
            }
            resolve()
          })
        })
      })
    }

    // Handle account linking flow (Member -> User bidirectional linking)
    if (state?.startsWith('link-account:')) {
      // Extract memberId and token from state
      const parts = state.split(':')
      const memberId = parts[1]
      const token = parts[2]

      // Verify token is valid
      const tokenData = accountLinkTokens.get(token)
      if (!tokenData || tokenData.memberId !== memberId || tokenData.expiresAt < Date.now()) {
        console.log('❌ Invalid or expired account link token')
        logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_FAILED, req, {
          memberId,
          errorMessage: 'Invalid or expired token',
        })
        // Log out the Passport user but preserve member session
        return new Promise<void>((resolve) => {
          req.logout(() => {
            req.session.memberId = memberId
            req.session.save(() => {
              res.redirect(`${process.env.CLIENT_URL}/member/home?error=link_expired`)
              resolve()
            })
          })
        })
      }

      // Delete token (one-time use)
      accountLinkTokens.delete(token)

      // Link Member to User via Google
      const googleProfile = {
        googleId: user.googleId,
        email: user.email,
        name: user.name,
        picture: user.picture,
      }

      const linkResult = await linkMemberViaGoogle(memberId, googleProfile)

      if (!linkResult.success) {
        console.log('❌ Failed to link accounts:', linkResult.error)
        logFailure(ActivityTypes.AUTH.ACCOUNT_LINK_FAILED, req, {
          memberId,
          googleId: user.googleId,
          errorMessage: linkResult.error,
        })
        // Log out the Passport user but preserve member session so they can try again
        const errorMsg = encodeURIComponent(linkResult.error || 'Failed to link accounts')
        return new Promise<void>((resolve) => {
          req.logout(() => {
            req.session.memberId = memberId
            req.session.save(() => {
              res.redirect(`${process.env.CLIENT_URL}/member/home?error=${errorMsg}`)
              resolve()
            })
          })
        })
      }

      console.log('✅ Account linked successfully: Member', memberId, '-> User', linkResult.data?.userId)

      // Log success (use re-link type if applicable)
      const activityType = linkResult.data?.previousUserId
        ? ActivityTypes.AUTH.ACCOUNT_LINK_RELINKED
        : ActivityTypes.AUTH.ACCOUNT_LINK_SUCCESS

      logSuccess(activityType, req, {
        memberId,
        userId: linkResult.data?.userId,
        googleEmail: user.email,
        previousUserId: linkResult.data?.previousUserId,
      })

      // Keep the user logged in (they now have a User session)
      // Update session with linked Member ID
      req.session.linkedMemberId = memberId

      return res.redirect(`${process.env.CLIENT_URL}/member/home?account_linked=true`)
    }

    const platform = state === 'platform:ios' ? 'ios' : 'web'

    // Log successful login
    logSuccess(ActivityTypes.AUTH.GOOGLE_LOGIN_SUCCESS, req, {
      userId: user.id,
      userEmail: user.email,
      platform,
    })

    // Successful authentication, redirect based on platform from state parameter
    if (state === 'platform:ios') {
      // Check if user has access to iOS app (group leaders and above only)
      const hasAccess = await canAccessIosApp(user.id)
      if (!hasAccess) {
        console.log('❌ User does not have access to iOS app:', user.id)
        logFailure(ActivityTypes.AUTH.IOS_ACCESS_DENIED, req, {
          userId: user.id,
          userEmail: user.email,
          errorMessage: 'Only group leaders can access the MakeReady app',
        })
        // Log out the user
        req.logout(() => {})
        const errorMsg = encodeURIComponent('Only group leaders can access the MakeReady app.')
        return res.redirect(`makeready://auth/error?message=${errorMsg}`)
      }

      // Generate one-time authorization code for iOS
      const authCode = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)

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
      // Web client: auto-set memberId for linked members
      const linkedMember = await prisma.member.findFirst({
        where: { userId: user.id, isActive: true },
        select: { id: true },
      })
      if (linkedMember) {
        req.session.memberId = linkedMember.id
        console.log('   Auto-set memberId for linked member:', linkedMember.id)
      }

      // Redirect to web client
      console.log('   Redirecting to web client')
      res.redirect(`${process.env.CLIENT_URL}/member/groups`)
    }
  }
)

/**
 * @openapi
 * /auth/exchange:
 *   post:
 *     tags: [Authentication]
 *     summary: Exchange auth code for session (iOS only)
 *     description: |
 *       Exchanges the one-time auth code from OAuth callback for a signed session ID.
 *       iOS apps use this to establish authenticated sessions.
 *
 *       The returned `sessionId` should be stored and sent as the `connect.sid` cookie.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - code
 *             properties:
 *               code:
 *                 type: string
 *                 description: Auth code from callback redirect
 *     responses:
 *       200:
 *         description: Session established
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 sessionId:
 *                   type: string
 *                   description: Signed session cookie value
 *                 userId:
 *                   type: string
 *                   description: Authenticated user ID
 *       400:
 *         description: Code required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Invalid or expired code
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/exchange', (req, res) => {
  const { code } = req.body
  console.log('🔄 Auth code exchange requested:', code)

  if (!code) {
    console.log('❌ No code provided')
    logFailure(ActivityTypes.AUTH.AUTH_CODE_EXCHANGE_FAILED, req, {
      errorMessage: 'No code provided',
    })
    return res.status(400).json({ error: 'Code required' })
  }

  const authData = authCodes.get(code)

  if (!authData) {
    console.log('❌ Invalid or expired code')
    logFailure(ActivityTypes.AUTH.AUTH_CODE_EXCHANGE_FAILED, req, {
      errorMessage: 'Invalid or expired code',
    })
    return res.status(401).json({ error: 'Invalid or expired code' })
  }

  if (authData.expiresAt < Date.now()) {
    console.log('❌ Code expired')
    authCodes.delete(code)
    logFailure(ActivityTypes.AUTH.AUTH_CODE_EXPIRED, req, {
      userId: authData.userId,
      errorMessage: 'Auth code expired',
    })
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

  // Log successful exchange
  logSuccess(ActivityTypes.AUTH.AUTH_CODE_EXCHANGE_SUCCESS, req, {
    userId: authData.userId,
  })

  // Return the signed session cookie value
  res.json({
    sessionId: signedSessionId,
    userId: authData.userId
  })
})

/**
 * @openapi
 * /auth/me:
 *   get:
 *     tags: [Authentication]
 *     summary: Get current authenticated user
 *     description: Returns the currently authenticated user's profile.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: User profile
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
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

/**
 * @openapi
 * /auth/logout:
 *   post:
 *     tags: [Authentication]
 *     summary: Logout current user
 *     description: Destroys the current user session.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Logged out successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Logged out successfully
 *       500:
 *         description: Logout failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/logout', (req, res) => {
  const user = req.user as any
  const userId = user?.id

  req.logout((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' })
    }

    // Log successful logout
    if (userId) {
      logSuccess(ActivityTypes.AUTH.USER_LOGOUT, req, { userId })
    }

    res.json({ message: 'Logged out successfully' })
  })
})

/**
 * @openapi
 * /auth/google/link-profile:
 *   get:
 *     tags: [Authentication]
 *     summary: Initiate Google profile linking for Members
 *     description: |
 *       Initiates OAuth flow to link a Google account to a Member profile.
 *       This is for profile sync only - Members still authenticate via phone.
 *
 *       Requires member session. The linked Google profile data (picture, email)
 *       will be stored on the Member record but NOT used for authentication.
 *     security:
 *       - memberSession: []
 *     responses:
 *       302:
 *         description: Redirects to Google OAuth consent screen
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/google/link-profile', (req, res, next) => {
  const memberId = req.session.memberId

  if (!memberId) {
    return res.status(401).json({
      success: false,
      error: 'Member authentication required. Please log in with your phone number first.',
    })
  }

  // Generate a secure token to verify the callback
  const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)

  // Store token with member ID (expires in 10 minutes)
  profileLinkTokens.set(token, {
    memberId,
    expiresAt: Date.now() + 10 * 60 * 1000,
  })

  // Log profile linking initiation
  logSuccess(ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_INITIATED, req, { memberId })

  // State format: link-profile:{memberId}:{token}
  const state = `link-profile:${memberId}:${token}`

  passport.authenticate('google', {
    scope: ['profile', 'email'],
    state,
  })(req, res, next)
})

/**
 * @openapi
 * /auth/google/link-profile/url:
 *   get:
 *     tags: [Authentication]
 *     summary: Get Google profile linking URL
 *     description: |
 *       Returns the URL to initiate Google profile linking.
 *       Useful for mobile apps that need to open the URL in a browser.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Linking URL
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 url:
 *                   type: string
 *                   description: URL to open in browser for linking
 *       401:
 *         description: Member not authenticated
 */
router.get('/google/link-profile/url', (req, res) => {
  const memberId = req.session.memberId

  if (!memberId) {
    return res.status(401).json({
      success: false,
      error: 'Member authentication required',
    })
  }

  // Generate a secure token to verify the callback
  const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)

  // Store token with member ID (expires in 10 minutes)
  profileLinkTokens.set(token, {
    memberId,
    expiresAt: Date.now() + 10 * 60 * 1000,
  })

  // Build the OAuth URL manually
  const clientId = process.env.GOOGLE_CLIENT_ID
  const callbackUrl = process.env.GOOGLE_CALLBACK_URL
  const state = `link-profile:${memberId}:${token}`
  const scope = encodeURIComponent('profile email')

  const url = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${encodeURIComponent(callbackUrl!)}&response_type=code&scope=${scope}&state=${encodeURIComponent(state)}`

  res.json({
    success: true,
    url,
  })
})

// ============================================================================
// Account Linking Endpoints (Member -> User via Google)
// ============================================================================

/**
 * @openapi
 * /auth/google/link-account:
 *   get:
 *     tags: [Authentication, Account Linking]
 *     summary: Initiate Google account linking for Members
 *     description: |
 *       Initiates OAuth flow to link a Member account to a User account.
 *       This creates a bidirectional link allowing the Member to also authenticate as a User.
 *
 *       Requires member session. After successful linking:
 *       - Member.userId will be set to the User's ID
 *       - User.linkedMember will reference the Member
 *       - Member can now access User-only features
 *
 *       **Note:** This is different from profile linking (`/auth/google/link-profile`),
 *       which only syncs Google profile data without creating account linkage.
 *     security:
 *       - memberSession: []
 *     responses:
 *       302:
 *         description: Redirects to Google OAuth consent screen
 *       401:
 *         description: Member not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/google/link-account', async (req, res, next) => {
  const memberId = req.session.memberId

  if (!memberId) {
    return res.status(401).json({
      success: false,
      error: 'Member authentication required. Please log in with your phone number first.',
    })
  }

  // Check if member already has a linked User
  const linkedUser = await getLinkedUser(memberId)
  if (linkedUser) {
    return res.status(400).json({
      success: false,
      error: `Already linked to a User account (${linkedUser.email}). Unlink first to link to a different account.`,
      linkedUserId: linkedUser.id,
    })
  }

  // Generate a secure token to verify the callback
  const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)

  // Store token with member ID (expires in 10 minutes)
  accountLinkTokens.set(token, {
    memberId,
    expiresAt: Date.now() + 10 * 60 * 1000,
  })

  // Log account linking initiation
  logSuccess(ActivityTypes.AUTH.ACCOUNT_LINK_GOOGLE_INITIATED, req, { memberId })

  // State format: link-account:{memberId}:{token}
  const state = `link-account:${memberId}:${token}`

  passport.authenticate('google', {
    scope: ['profile', 'email'],
    state,
    prompt: 'select_account',
  })(req, res, next)
})

/**
 * @openapi
 * /auth/google/link-account/url:
 *   get:
 *     tags: [Authentication, Account Linking]
 *     summary: Get Google account linking URL
 *     description: |
 *       Returns the URL to initiate Google account linking.
 *       Useful for mobile apps that need to open the URL in a browser.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Linking URL
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 url:
 *                   type: string
 *                   description: URL to open in browser for account linking
 *       400:
 *         description: Already linked to a User
 *       401:
 *         description: Member not authenticated
 */
router.get('/google/link-account/url', async (req, res) => {
  const memberId = req.session.memberId

  if (!memberId) {
    return res.status(401).json({
      success: false,
      error: 'Member authentication required',
    })
  }

  // Check if member already has a linked User
  const linkedUser = await getLinkedUser(memberId)
  if (linkedUser) {
    return res.status(400).json({
      success: false,
      error: `Already linked to a User account (${linkedUser.email}). Unlink first.`,
      linkedUserId: linkedUser.id,
    })
  }

  // Generate a secure token to verify the callback
  const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)

  // Store token with member ID (expires in 10 minutes)
  accountLinkTokens.set(token, {
    memberId,
    expiresAt: Date.now() + 10 * 60 * 1000,
  })

  // Build the OAuth URL manually
  const clientId = process.env.GOOGLE_CLIENT_ID
  const callbackUrl = process.env.GOOGLE_CALLBACK_URL
  const state = `link-account:${memberId}:${token}`
  const scope = encodeURIComponent('profile email')

  const url = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${encodeURIComponent(callbackUrl!)}&response_type=code&scope=${scope}&state=${encodeURIComponent(state)}&prompt=select_account`

  res.json({
    success: true,
    url,
  })
})

/**
 * @openapi
 * /auth/me/linked-user:
 *   get:
 *     tags: [Authentication, Account Linking]
 *     summary: Get linked User account for current Member
 *     description: Returns the User account linked to the authenticated Member, if any.
 *     security:
 *       - memberSession: []
 *     responses:
 *       200:
 *         description: Linked User (or null if not linked)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 user:
 *                   type: object
 *                   nullable: true
 *                   properties:
 *                     id:
 *                       type: string
 *                     email:
 *                       type: string
 *                     name:
 *                       type: string
 *                     picture:
 *                       type: string
 *       401:
 *         description: Member not authenticated
 */
router.get('/me/linked-user', async (req, res) => {
  try {
    const memberId = req.session.memberId

    if (!memberId) {
      return res.status(401).json({
        success: false,
        error: 'Member authentication required',
      })
    }

    const user = await getLinkedUser(memberId)

    res.json({
      success: true,
      user: user
        ? {
            id: user.id,
            email: user.email,
            name: user.name,
            picture: user.picture,
          }
        : null,
    })
  } catch (error) {
    console.error('[API] Error in /auth/me/linked-user:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

// ============================================================================
// Google Token Exchange (for server-side clients like Laravel)
// ============================================================================

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID)

/**
 * @openapi
 * /auth/google/token-exchange:
 *   post:
 *     tags: [Authentication]
 *     summary: Exchange a Google ID token for an API session
 *     description: |
 *       Accepts a Google ID token obtained from a server-side OAuth flow (e.g. Laravel,
 *       Rails, or any backend client) and returns a signed session cookie.
 *
 *       **Flow:**
 *       1. Your backend authenticates the user via Google OAuth and obtains an ID token
 *       2. Send the ID token to this endpoint
 *       3. The API verifies the token with Google, finds or creates the User
 *       4. Returns a signed session ID to use as the `connect.sid` cookie
 *
 *       The returned `sessionId` should be sent as the `Cookie: connect.sid=<value>`
 *       header on all subsequent API requests.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - idToken
 *             properties:
 *               idToken:
 *                 type: string
 *                 description: Google ID token from your OAuth flow
 *     responses:
 *       200:
 *         description: Session established
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 sessionId:
 *                   type: string
 *                   description: Signed session cookie value (use as connect.sid)
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     email:
 *                       type: string
 *                     name:
 *                       type: string
 *                     picture:
 *                       type: string
 *       400:
 *         description: Missing idToken
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Invalid or expired token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/google/token-exchange', async (req, res) => {
  try {
    const { idToken } = req.body

    if (!idToken) {
      return res.status(400).json({
        success: false,
        error: 'idToken is required',
      })
    }

    // Verify the ID token with Google
    let ticket
    try {
      ticket = await googleClient.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      })
    } catch (err) {
      console.error('❌ Google token verification failed:', err)
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired Google token',
      })
    }

    const payload = ticket.getPayload()
    if (!payload || !payload.sub || !payload.email) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token payload',
      })
    }

    const googleId = payload.sub
    const email = payload.email
    const name = payload.name || ''
    const picture = payload.picture || ''

    // Find or create user (same logic as passport strategy)
    let user = await prisma.user.findUnique({
      where: { googleId },
    })

    if (user && !user.isActive) {
      return res.status(403).json({
        success: false,
        error: 'User account is inactive',
      })
    }

    if (!user) {
      const result = await prisma.$transaction(async (tx) => {
        const newUser = await tx.user.create({
          data: { googleId, email, name, picture },
        })

        const organization = await tx.organization.create({
          data: {
            name: newUser.name,
            ownerId: newUser.id,
            isActive: true,
          },
        })

        const updatedUser = await tx.user.update({
          where: { id: newUser.id },
          data: { organizationId: organization.id },
        })

        return { user: updatedUser, organization }
      })

      user = result.user
      console.log('✅ New user created via token exchange:', user.email)

      // Provision Twilio Verify service (async, non-blocking)
      createVerifyService(result.organization.name)
        .then(async (verifyResult) => {
          if (verifyResult.success && verifyResult.serviceSid) {
            await prisma.organization.update({
              where: { id: result.organization.id },
              data: { twilioVerifyServiceSid: verifyResult.serviceSid },
            })
          }
        })
        .catch((error) => {
          console.error('❌ Error provisioning Twilio Verify service:', error)
        })
    } else {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { email, name, picture },
      })
      console.log('✅ User updated via token exchange:', user.email)
    }

    // Create a session for this user by logging them in via Passport
    req.login(user, (loginErr) => {
      if (loginErr) {
        console.error('❌ Session creation failed:', loginErr)
        return res.status(500).json({
          success: false,
          error: 'Failed to create session',
        })
      }

      // Sign the session ID (same format as express-session cookie)
      const sessionSecret = process.env.SESSION_SECRET || 'your-secret-key'
      const signedSessionId = 's:' + signature.sign(req.sessionID, sessionSecret)

      logSuccess(ActivityTypes.AUTH.GOOGLE_LOGIN_SUCCESS, req, {
        userId: user!.id,
        userEmail: user!.email,
        platform: 'token-exchange',
      })

      console.log('✅ Token exchange successful for:', user!.email)

      res.json({
        success: true,
        sessionId: signedSessionId,
        user: {
          id: user!.id,
          email: user!.email,
          name: user!.name,
          picture: user!.picture,
        },
      })
    })
  } catch (error) {
    console.error('❌ Token exchange error:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

// ============================================================================
// Dev-Only Login (bypasses Google OAuth for local development)
// ============================================================================

/**
 * POST /auth/dev-login
 * Creates a real session for a user by email. Only available in development.
 * Used by the iPhone app when the environment is set to "Local" so OAuth
 * doesn't need to work over a LAN IP.
 */
router.post('/dev-login', async (req, res) => {
  if (process.env.NODE_ENV !== 'development') {
    return res.status(404).json({ error: 'Not found' })
  }

  const { email } = req.body
  if (!email) {
    return res.status(400).json({ success: false, error: 'Email is required' })
  }

  try {
    const user = await prisma.user.findUnique({ where: { email } })
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' })
    }

    // Create a real Passport session for this user
    await new Promise<void>((resolve, reject) => {
      req.logIn(user, (err) => {
        if (err) return reject(err)
        resolve()
      })
    })

    console.log(`🔓 Dev login: ${user.email} (${user.id})`)

    // Return session cookie info so the iOS app can store it
    const sessionCookie = req.sessionID
    const secret = process.env.SESSION_SECRET!
    const signed = 's:' + signature.sign(sessionCookie, secret)

    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarURL: user.picture,
      },
      sessionCookie: signed,
    })
  } catch (error) {
    console.error('❌ Dev login error:', error)
    res.status(500).json({ success: false, error: 'Login failed' })
  }
})

export default router
