/**
 * Activity Logging Service
 *
 * This file provides easy-to-edit log templates and a simple API for logging activities.
 * To add/modify log messages, edit the LOG_TEMPLATES object below.
 */

import { Request } from 'express'
import { prisma } from './prisma.js'
import { ActivityTypes, AnyActivityType } from './activity-types.js'
import { LogCategory, LogStatus, Prisma } from '../generated/prisma/index.js'

// ============================================================================
// LOG TEMPLATES - Easy to edit messages for each activity type
// ============================================================================

export const LOG_TEMPLATES: Record<string, { message: (ctx: LogContext) => string }> = {
  // AUTH Templates
  [ActivityTypes.AUTH.GOOGLE_LOGIN_INITIATED]: {
    message: (ctx: LogContext) =>
      `Google OAuth initiated from ${ctx.platform || 'web'}`,
  },
  [ActivityTypes.AUTH.GOOGLE_LOGIN_SUCCESS]: {
    message: (ctx: LogContext) =>
      `User ${ctx.userEmail || ctx.userId} logged in via Google OAuth`,
  },
  [ActivityTypes.AUTH.GOOGLE_LOGIN_FAILED]: {
    message: (ctx: LogContext) =>
      `Google OAuth login failed: ${ctx.errorMessage || 'Unknown error'}`,
  },
  [ActivityTypes.AUTH.GOOGLE_CALLBACK_ERROR]: {
    message: (ctx: LogContext) =>
      `Google OAuth callback error: ${ctx.errorMessage || 'Authentication rejected'}`,
  },
  [ActivityTypes.AUTH.AUTH_CODE_EXCHANGE_SUCCESS]: {
    message: (ctx: LogContext) =>
      `iOS auth code exchanged successfully for user ${ctx.userId}`,
  },
  [ActivityTypes.AUTH.AUTH_CODE_EXCHANGE_FAILED]: {
    message: (ctx: LogContext) =>
      `iOS auth code exchange failed: ${ctx.errorMessage || 'Invalid or expired code'}`,
  },
  [ActivityTypes.AUTH.AUTH_CODE_EXPIRED]: {
    message: () => `Auth code expired for exchange attempt`,
  },
  [ActivityTypes.AUTH.PHONE_VERIFICATION_SENT]: {
    message: (ctx: LogContext) =>
      `Verification code sent to ${maskPhone(ctx.phoneNumber)}`,
  },
  [ActivityTypes.AUTH.PHONE_VERIFICATION_SEND_FAILED]: {
    message: (ctx: LogContext) =>
      `Failed to send verification code to ${maskPhone(ctx.phoneNumber)}: ${ctx.errorMessage}`,
  },
  [ActivityTypes.AUTH.PHONE_VERIFICATION_SUCCESS]: {
    message: (ctx: LogContext) =>
      `Phone ${maskPhone(ctx.phoneNumber)} verified successfully`,
  },
  [ActivityTypes.AUTH.PHONE_VERIFICATION_FAILED]: {
    message: (ctx: LogContext) =>
      `Phone verification failed for ${maskPhone(ctx.phoneNumber)}: ${ctx.errorMessage}`,
  },
  [ActivityTypes.AUTH.PHONE_VERIFICATION_INVALID_CODE]: {
    message: (ctx: LogContext) =>
      `Invalid verification code entered for ${maskPhone(ctx.phoneNumber)}`,
  },
  [ActivityTypes.AUTH.MEMBER_LOGIN_SUCCESS]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} authenticated via phone verification`,
  },
  [ActivityTypes.AUTH.MEMBER_LOGIN_FAILED]: {
    message: (ctx: LogContext) =>
      `Member login failed: ${ctx.errorMessage || 'Invalid credentials'}`,
  },
  [ActivityTypes.AUTH.MEMBER_SESSION_CHECK]: {
    message: (ctx: LogContext) =>
      `Member session check: ${ctx.isAuthenticated ? 'authenticated' : 'not authenticated'}`,
  },
  [ActivityTypes.AUTH.MEMBER_LOGOUT]: {
    message: (ctx: LogContext) => `Member ${ctx.memberId} logged out`,
  },
  [ActivityTypes.AUTH.USER_SESSION_CHECK]: {
    message: (ctx: LogContext) =>
      `User session check: ${ctx.isAuthenticated ? 'authenticated' : 'not authenticated'}`,
  },
  [ActivityTypes.AUTH.USER_LOGOUT]: {
    message: (ctx: LogContext) => `User ${ctx.userId} logged out`,
  },
  // Google profile linking (Members)
  [ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_INITIATED]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} initiated Google profile linking`,
  },
  [ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_SUCCESS]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} linked Google profile (${ctx.googleEmail})`,
  },
  [ActivityTypes.AUTH.GOOGLE_PROFILE_LINK_FAILED]: {
    message: (ctx: LogContext) =>
      `Google profile linking failed for member ${ctx.memberId}: ${ctx.errorMessage || 'Unknown error'}`,
  },
  [ActivityTypes.AUTH.GOOGLE_PROFILE_ALREADY_LINKED]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} already has a Google profile linked`,
  },
  [ActivityTypes.AUTH.GOOGLE_PROFILE_UNLINKED]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} unlinked Google profile`,
  },
  [ActivityTypes.AUTH.GOOGLE_PROFILE_SYNCED]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} synced profile picture from Google`,
  },
  // iOS app access
  [ActivityTypes.AUTH.IOS_ACCESS_DENIED]: {
    message: (ctx: LogContext) =>
      `iOS app access denied for user ${ctx.userEmail || ctx.userId}: ${ctx.errorMessage || 'Not a group leader'}`,
  },
  // Account linking (bidirectional User <-> Member)
  [ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_SEND]: {
    message: (ctx: LogContext) =>
      `User ${ctx.userId} initiated phone linking to ${ctx.phoneNumber}`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_SEND_FAILED]: {
    message: (ctx: LogContext) =>
      `Phone linking failed for user ${ctx.userId}: ${ctx.errorMessage || 'Failed to send code'}`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_VERIFY]: {
    message: (ctx: LogContext) =>
      `User ${ctx.userId} verified phone ${ctx.phoneNumber} for account linking`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_PHONE_VERIFY_FAILED]: {
    message: (ctx: LogContext) =>
      `Phone verification failed for user ${ctx.userId}: ${ctx.errorMessage || 'Invalid code'}`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_GOOGLE_INITIATED]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} initiated Google account linking`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_SUCCESS]: {
    message: (ctx: LogContext) =>
      `Account linked: Member ${ctx.memberId} -> User ${ctx.userId}`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_FAILED]: {
    message: (ctx: LogContext) =>
      `Account linking failed for member ${ctx.memberId}: ${ctx.errorMessage || 'Unknown error'}`,
  },
  [ActivityTypes.AUTH.ACCOUNT_LINK_RELINKED]: {
    message: (ctx: LogContext) =>
      `Account re-linked: Member ${ctx.memberId} -> User ${ctx.userId} (was: ${ctx.previousUserId})`,
  },
  [ActivityTypes.AUTH.ACCOUNT_UNLINK_SUCCESS]: {
    message: (ctx: LogContext) =>
      `Account unlinked: Member ${ctx.memberId} from User ${ctx.userId}`,
  },
  [ActivityTypes.AUTH.ACCOUNT_UNLINK_FAILED]: {
    message: (ctx: LogContext) =>
      `Account unlinking failed for member ${ctx.memberId}: ${ctx.errorMessage || 'Unknown error'}`,
  },

  // JOIN Templates
  [ActivityTypes.JOIN.GROUP_REQUEST_SUBMITTED]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} submitted join request for group ${ctx.groupName || ctx.groupId}`,
  },
  [ActivityTypes.JOIN.GROUP_REQUEST_APPROVED]: {
    message: (ctx: LogContext) =>
      `Join request approved: Member ${ctx.memberId} added to group ${ctx.groupName || ctx.groupId}`,
  },
  [ActivityTypes.JOIN.GROUP_REQUEST_REJECTED]: {
    message: (ctx: LogContext) =>
      `Join request rejected for member ${ctx.memberId} in group ${ctx.groupName || ctx.groupId}`,
  },
  [ActivityTypes.JOIN.GROUP_REQUEST_DUPLICATE]: {
    message: (ctx: LogContext) =>
      `Duplicate join request from member ${ctx.memberId} for group ${ctx.groupId}`,
  },
  [ActivityTypes.JOIN.GROUP_ALREADY_MEMBER]: {
    message: (ctx: LogContext) =>
      `Member ${ctx.memberId} already belongs to group ${ctx.groupId}`,
  },
  [ActivityTypes.JOIN.GROUP_CODE_LOOKUP]: {
    message: (ctx: LogContext) =>
      `Group code lookup: ${ctx.groupCode} -> ${ctx.groupName || 'found'}`,
  },
  [ActivityTypes.JOIN.GROUP_CODE_NOT_FOUND]: {
    message: (ctx: LogContext) => `Group code not found: ${ctx.groupCode}`,
  },
  [ActivityTypes.JOIN.INVITE_ACCEPTED]: {
    message: (ctx: LogContext) =>
      `Invite accepted: User joined group ${ctx.groupName || ctx.groupId}`,
  },
  [ActivityTypes.JOIN.INVITE_FAILED]: {
    message: (ctx: LogContext) =>
      `Invite acceptance failed: ${ctx.errorMessage}`,
  },
  [ActivityTypes.JOIN.INVITE_EXPIRED]: {
    message: () => `Invite expired or already used`,
  },
  [ActivityTypes.JOIN.INVITE_NOT_FOUND]: {
    message: (ctx: LogContext) =>
      `Invite not found: ${ctx.inviteToken || 'unknown'}`,
  },
  [ActivityTypes.JOIN.EVENT_RSVP_SUBMITTED]: {
    message: (ctx: LogContext) =>
      `RSVP submitted: ${ctx.rsvpStatus} for event ${ctx.eventId}`,
  },
  [ActivityTypes.JOIN.EVENT_RSVP_UPDATED]: {
    message: (ctx: LogContext) =>
      `RSVP updated to ${ctx.rsvpStatus} for event ${ctx.eventId}`,
  },
  [ActivityTypes.JOIN.EVENT_RSVP_FAILED]: {
    message: (ctx: LogContext) =>
      `RSVP failed for event ${ctx.eventId}: ${ctx.errorMessage}`,
  },
  [ActivityTypes.JOIN.EVENT_PUBLIC_RSVP]: {
    message: (ctx: LogContext) =>
      `Public RSVP: ${ctx.rsvpStatus} from ${maskPhone(ctx.phoneNumber)} for event ${ctx.eventCode || ctx.eventId}`,
  },
  [ActivityTypes.JOIN.EVENT_MEMBER_INVITE]: {
    message: (ctx: LogContext) =>
      `${ctx.inviteCount || 'Members'} invited to event ${ctx.eventId}`,
  },
  [ActivityTypes.JOIN.ENROLLMENT_CREATED]: {
    message: (ctx: LogContext) =>
      `Group ${ctx.groupName || ctx.groupId} enrolled in study program ${ctx.programName || ctx.studyProgramId}`,
  },
  [ActivityTypes.JOIN.ENROLLMENT_FAILED]: {
    message: (ctx: LogContext) =>
      `Enrollment failed for group ${ctx.groupId}: ${ctx.errorMessage}`,
  },

  // ACCESS Templates
  [ActivityTypes.ACCESS.LESSON_VIEWED]: {
    message: (ctx: LogContext) =>
      `Lesson ${ctx.lessonId} (Day ${ctx.dayNumber}) viewed`,
  },
  [ActivityTypes.ACCESS.LESSON_CODE_LOOKUP]: {
    message: (ctx: LogContext) => `Lesson code lookup: ${ctx.lessonCode}`,
  },
  [ActivityTypes.ACCESS.PROFILE_VIEWED]: {
    message: (ctx: LogContext) =>
      `Profile viewed: ${ctx.targetMemberId || ctx.targetUserId}`,
  },
}

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

export interface LogContext {
  // Actor
  userId?: string
  memberId?: string
  userEmail?: string

  // Request
  route?: string
  method?: string
  platform?: string
  isAuthenticated?: boolean

  // Resources
  groupId?: string
  groupName?: string
  groupCode?: string
  eventId?: string
  eventCode?: string
  enrollmentId?: string
  studyProgramId?: string
  programName?: string
  lessonId?: string
  lessonCode?: string
  dayNumber?: number
  inviteId?: string
  inviteToken?: string
  organizationId?: string
  targetMemberId?: string
  targetUserId?: string

  // Phone
  phoneNumber?: string

  // Google profile linking
  googleEmail?: string
  googleId?: string

  // Account linking
  previousUserId?: string
  memberExists?: boolean
  created?: boolean

  // Status details
  errorCode?: string
  errorMessage?: string
  warningMessage?: string

  // RSVP
  rsvpStatus?: string
  inviteCount?: number

  // Extra metadata
  metadata?: Prisma.InputJsonValue
}

interface LogOptions {
  activityType: AnyActivityType
  status: LogStatus
  req?: Request
  context: LogContext
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Mask phone number for privacy in logs
 * +12145551234 -> +1214***1234
 */
function maskPhone(phone?: string): string {
  if (!phone) return '[unknown]'
  if (phone.length < 8) return '***'
  return phone.slice(0, 4) + '***' + phone.slice(-4)
}

/**
 * Extract client IP from request (handles proxies)
 */
function getClientIp(req?: Request): string | undefined {
  if (!req) return undefined
  const forwarded = req.headers['x-forwarded-for']
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim()
  }
  return req.ip || req.socket.remoteAddress
}

/**
 * Extract user agent from request
 */
function getUserAgent(req?: Request): string | undefined {
  return req?.headers['user-agent']?.substring(0, 500) // Truncate long user agents
}

/**
 * Determine category from activity type
 */
function getCategoryFromType(activityType: AnyActivityType): LogCategory {
  if (activityType.startsWith('AUTH_')) return LogCategory.AUTH
  if (activityType.startsWith('JOIN_')) return LogCategory.JOIN
  if (activityType.startsWith('ACCESS_')) return LogCategory.ACCESS
  return LogCategory.AUTH // Default fallback
}

// ============================================================================
// MAIN LOGGING FUNCTION
// ============================================================================

/**
 * Log an activity to the database
 *
 * @example
 * await logActivity({
 *   activityType: ActivityTypes.AUTH.GOOGLE_LOGIN_SUCCESS,
 *   status: LogStatus.SUCCESS,
 *   req,
 *   context: {
 *     userId: user.id,
 *     userEmail: user.email,
 *   }
 * })
 */
export async function logActivity(options: LogOptions): Promise<void> {
  const { activityType, status, req, context } = options

  try {
    // Get template for message generation
    const template = LOG_TEMPLATES[activityType]
    const message = template?.message(context) || `Activity: ${activityType}`

    // Determine category
    const category = getCategoryFromType(activityType)

    // Create log entry
    await prisma.activityLog.create({
      data: {
        category,
        activityType,
        status,

        // Actor
        userId: context.userId,
        memberId: context.memberId,
        actorIp: getClientIp(req),
        userAgent: getUserAgent(req),

        // Request context
        route: context.route || req?.originalUrl || req?.path || '',
        method: context.method || req?.method || 'UNKNOWN',

        // Related resources
        groupId: context.groupId,
        eventId: context.eventId,
        enrollmentId: context.enrollmentId,
        lessonId: context.lessonId,
        organizationId: context.organizationId,
        inviteId: context.inviteId,

        // Message and errors
        message,
        errorCode: context.errorCode,
        errorMessage: status === LogStatus.FAILURE ? context.errorMessage : undefined,
        warningMessage: status === LogStatus.WARNING ? context.warningMessage : undefined,
        metadata: context.metadata,
      },
    })
  } catch (error) {
    // Log errors to console but don't throw - logging should never break the app
    console.error('[ActivityLog] Failed to log activity:', error)
  }
}

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

/**
 * Log a successful activity
 */
export async function logSuccess(
  activityType: AnyActivityType,
  req: Request,
  context: LogContext
): Promise<void> {
  return logActivity({ activityType, status: LogStatus.SUCCESS, req, context })
}

/**
 * Log a failed activity
 */
export async function logFailure(
  activityType: AnyActivityType,
  req: Request,
  context: LogContext
): Promise<void> {
  return logActivity({ activityType, status: LogStatus.FAILURE, req, context })
}

/**
 * Log a warning activity
 */
export async function logWarning(
  activityType: AnyActivityType,
  req: Request,
  context: LogContext
): Promise<void> {
  return logActivity({ activityType, status: LogStatus.WARNING, req, context })
}
