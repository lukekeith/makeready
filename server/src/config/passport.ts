import passport from 'passport'
import { Strategy as GoogleStrategy } from 'passport-google-oauth20'
import { prisma } from '../lib/prisma.js'
import { createVerifyService } from '../services/twilio.js'
import type { User } from '../generated/prisma/index.js'

passport.use(
  new GoogleStrategy(
    {
      clientID: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      callbackURL: process.env.GOOGLE_CALLBACK_URL!,
    },
    async (_accessToken, _refreshToken, profile, done) => {
      try {
        // Extract user info from Google profile
        const email = profile.emails?.[0]?.value || ''
        const picture = profile.photos?.[0]?.value || ''
        const name = profile.displayName || ''

        if (!email) {
          return done(new Error('No email found in Google profile'))
        }

        // Find or create user in database
        let user = await prisma.user.findUnique({
          where: { googleId: profile.id },
        })

        if (!user) {
          // Create new user with organization in a transaction
          const result = await prisma.$transaction(async (tx) => {
            // Create the user first
            const newUser = await tx.user.create({
              data: {
                googleId: profile.id,
                email,
                name,
                picture,
              },
            })

            // Create organization for the user
            const organization = await tx.organization.create({
              data: {
                name: newUser.name, // Default organization name to user's name
                ownerId: newUser.id,
                isActive: true,
              },
            })

            // Link user to their organization
            const updatedUser = await tx.user.update({
              where: { id: newUser.id },
              data: { organizationId: organization.id },
            })

            return { user: updatedUser, organization }
          })

          user = result.user
          console.log('✅ New user created:', user.email)
          console.log('✅ Organization created:', result.organization.name)

          // Provision Twilio Verify service for the organization (async, non-blocking)
          createVerifyService(result.organization.name)
            .then(async (verifyResult) => {
              if (verifyResult.success && verifyResult.serviceSid) {
                await prisma.organization.update({
                  where: { id: result.organization.id },
                  data: { twilioVerifyServiceSid: verifyResult.serviceSid },
                })
                console.log('✅ Twilio Verify service provisioned for:', result.organization.name)
              } else {
                console.error('❌ Failed to provision Twilio Verify service:', verifyResult.error)
              }
            })
            .catch((error) => {
              console.error('❌ Error provisioning Twilio Verify service:', error)
            })
        } else {
          // Update existing user info
          user = await prisma.user.update({
            where: { id: user.id },
            data: {
              email,
              name,
              picture,
            },
          })
          console.log('✅ User updated:', user.email)
        }

        if (!user.isActive) {
          console.log('❌ Inactive user denied Google login:', user.email)
          return done(null, false, { message: 'User account is inactive' })
        }

        return done(null, user)
      } catch (error) {
        console.error('❌ Passport error:', error)
        return done(error as Error)
      }
    }
  )
)

// Session data structure for caching user
interface SessionData {
  id: string
  data: User
  fetchedAt: number
}

// How long before we refresh user data from DB (5 minutes)
const SESSION_STALE_THRESHOLD = 5 * 60 * 1000

// Serialize user to session - store full user data to avoid DB lookups
passport.serializeUser((user: any, done) => {
  const sessionData: SessionData = {
    id: user.id,
    data: user,
    fetchedAt: Date.now(),
  }
  done(null, sessionData)
})

// Deserialize user from session - use cached data when fresh
passport.deserializeUser(async (session: SessionData | string, done) => {
  try {
    // Handle legacy sessions that only stored user ID as string
    if (typeof session === 'string') {
      const user = await prisma.user.findUnique({ where: { id: session } })
      if (user) {
        if (!user.isActive) {
          done(new Error('User account is inactive'))
          return
        }
        done(null, user)
      } else {
        done(new Error('User not found'))
      }
      return
    }

    // Check if cached data is still fresh
    const isFresh = session.fetchedAt && Date.now() - session.fetchedAt < SESSION_STALE_THRESHOLD
    if (isFresh && session.data) {
      if (session.data.isActive === false) {
        done(new Error('User account is inactive'))
        return
      }
      // Use cached data - no DB query needed
      done(null, session.data)
      return
    }

    // Data is stale, refresh from database
    const user = await prisma.user.findUnique({
      where: { id: session.id },
    })
    if (user) {
      if (!user.isActive) {
        done(new Error('User account is inactive'))
        return
      }
      done(null, user)
    } else {
      done(new Error('User not found'))
    }
  } catch (error) {
    done(error as Error)
  }
})

export { passport }
export type { User }
