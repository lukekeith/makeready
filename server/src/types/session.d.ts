/**
 * Session Type Definitions
 * Extends express-session to support both User and Member authentication
 */

import 'express-session'
import { User, Member } from '../generated/prisma/index.js'

declare module 'express-session' {
  interface SessionData {
    /**
     * User ID from Google OAuth authentication
     * Set by Passport after successful OAuth flow
     */
    passport?: {
      user?: string // userId
    }

    /**
     * Member ID from phone verification authentication
     * Set after successful phone verification
     */
    memberId?: string

    /**
     * Timestamp when member session was created
     */
    memberAuthenticatedAt?: Date

    /**
     * Linked Member ID for User sessions (populated after User links to Member)
     */
    linkedMemberId?: string

    /**
     * Linked User ID for Member sessions (populated after Member links to User)
     */
    linkedUserId?: string
  }
}

declare global {
  namespace Express {
    interface Request {
      /**
       * User object (Google OAuth)
       * Populated by Passport's deserializeUser
       */
      user?: User

      /**
       * Member object (phone verification)
       * Populated by requireMemberAuth middleware
       */
      member?: Member

      /**
       * API Key ID when authenticated via API key
       * Populated by API key authentication middleware
       */
      apiKeyId?: string
    }
  }
}

export {}
