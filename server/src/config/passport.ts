import passport from 'passport'
import { Strategy as GoogleStrategy } from 'passport-google-oauth20'
import { prisma } from '../lib/prisma'
import type { User } from '../generated/prisma'

passport.use(
  new GoogleStrategy(
    {
      clientID: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      callbackURL: process.env.GOOGLE_CALLBACK_URL!,
    },
    async (accessToken, refreshToken, profile, done) => {
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
          // Create new user
          user = await prisma.user.create({
            data: {
              googleId: profile.id,
              email,
              name,
              picture,
            },
          })
          console.log('✅ New user created:', user.email)
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

        return done(null, user)
      } catch (error) {
        console.error('❌ Passport error:', error)
        return done(error as Error)
      }
    }
  )
)

// Serialize user to session
passport.serializeUser((user: any, done) => {
  done(null, user.id)
})

// Deserialize user from session
passport.deserializeUser(async (id: string, done) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id },
    })
    if (user) {
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
