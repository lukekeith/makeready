import { Request, Response, NextFunction } from 'express'
import { prisma } from '../lib/prisma.js'
import { verifyOrganizationOwnership } from '../services/organization.js'
import { getParam } from '../lib/params.js'

/**
 * Authentication Middleware
 * Provides authorization checks for protected routes
 * Supports both User (Google OAuth) and Member (phone verification) authentication
 */

/**
 * Require user to be authenticated
 *
 * Accepts EITHER:
 * - Session authentication (Google OAuth via Passport)
 * - API key authentication (Bearer token with mr_ prefix)
 *
 * API key middleware must run BEFORE this middleware to set req.user from API key
 */
export const requireAuth = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Check for API key authentication (set by authenticateApiKey middleware)
  if (req.user && req.apiKeyId) {
    if ((req.user as any).isActive === false) {
      return res.status(403).json({
        success: false,
        error: 'User account is inactive',
      })
    }
    return next()
  }

  // Check for session authentication (Passport)
  if (req.isAuthenticated && req.isAuthenticated()) {
    if ((req.user as any)?.isActive === false) {
      return res.status(403).json({
        success: false,
        error: 'User account is inactive',
      })
    }
    return next()
  }

  return res.status(401).json({
    success: false,
    error: 'Not authenticated',
  })
}

/**
 * Require member to be authenticated (phone verification)
 * Checks for memberId in session and loads member data
 */
export const requireMemberAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const memberId = req.session.memberId

    if (!memberId) {
      return res.status(401).json({
        success: false,
        error: 'Member not authenticated',
      })
    }

    // Load member from database
    const member = await prisma.member.findUnique({
      where: { id: memberId },
      include: {
        organizations: {
          include: {
            organization: {
              select: {
                id: true,
                name: true,
                ownerId: true,
              },
            },
          },
        },
      },
    })

    if (!member) {
      // Member not found - clear invalid session
      req.session.memberId = undefined
      return res.status(401).json({
        success: false,
        error: 'Member not found',
      })
    }

    if (!member.isActive) {
      return res.status(403).json({
        success: false,
        error: 'Member account is inactive',
      })
    }

    // Attach member to request for use in route handlers
    req.member = member

    next()
  } catch (error) {
    console.error('Error in requireMemberAuth middleware:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

/**
 * Require member to have access to specific member resource
 * Member must be accessing their own resource
 * Checks req.params.memberId against authenticated member
 */
export const requireMemberAccess = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const authenticatedMemberId = req.session.memberId
    const targetMemberId = getParam(req.params.memberId)

    if (!authenticatedMemberId) {
      return res.status(401).json({
        success: false,
        error: 'Member not authenticated',
      })
    }

    if (!targetMemberId) {
      return res.status(400).json({
        success: false,
        error: 'Member ID required',
      })
    }

    // Member can only access their own resources
    if (authenticatedMemberId !== targetMemberId) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this member resource',
      })
    }

    // Load member data for use in route handlers
    const member = await prisma.member.findUnique({
      where: { id: authenticatedMemberId },
      include: {
        organizations: {
          include: {
            organization: {
              select: {
                id: true,
                name: true,
                ownerId: true,
              },
            },
          },
        },
      },
    })

    if (!member || !member.isActive) {
      return res.status(403).json({
        success: false,
        error: 'Member account not found or inactive',
      })
    }

    req.member = member

    next()
  } catch (error) {
    console.error('Error in requireMemberAccess middleware:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

/**
 * Require user to own the organization specified in params or body
 * Checks req.params.organizationId or req.body.organizationId
 */
export const requireOrgOwner = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = (req.user as any)?.id

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Not authenticated',
      })
    }

    const organizationId =
      req.params.organizationId || req.body.organizationId

    if (!organizationId) {
      return res.status(400).json({
        success: false,
        error: 'Organization ID required',
      })
    }

    const isOwner = await verifyOrganizationOwnership(userId, organizationId)

    if (!isOwner) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this organization',
      })
    }

    next()
  } catch (error) {
    console.error('Error in requireOrgOwner middleware:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

/**
 * Require user to be the member or own the member's organization
 * Supports both User (org owner) and Member (self) authentication
 * Checks req.params.memberId
 */
export const requireMemberOrOrgOwner = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = (req.user as any)?.id
    const authenticatedMemberId = req.session.memberId
    const targetMemberId = getParam(req.params.memberId)

    // Must be authenticated as either User or Member
    if (!userId && !authenticatedMemberId) {
      return res.status(401).json({
        success: false,
        error: 'Not authenticated',
      })
    }

    if (!targetMemberId) {
      return res.status(400).json({
        success: false,
        error: 'Member ID required',
      })
    }

    // Get member with organization info
    const member = await prisma.member.findUnique({
      where: { id: targetMemberId },
      include: {
        organizations: {
          include: {
            organization: {
              select: { ownerId: true },
            },
          },
        },
      },
    })

    if (!member) {
      return res.status(404).json({
        success: false,
        error: 'Member not found',
      })
    }

    // Check if authenticated member is accessing their own resource
    const isMember = authenticatedMemberId === targetMemberId

    // Otherwise the user must be able to MANAGE one of the member's orgs:
    // super admin, org owner, or any role-holder in that org. Previously this
    // recognized owners only, locking out non-owner group leaders/admins.
    let isOrgManager = false
    if (userId && !isMember) {
      const memberOrgIds = member.organizations.map((mo) => mo.organizationId)
      if (memberOrgIds.length > 0) {
        isOrgManager =
          (await isSuperAdmin(userId)) ||
          (await getManageableOrgIds(userId)).some((id) => memberOrgIds.includes(id))
      }
    }

    if (!isMember && !isOrgManager) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this member',
      })
    }

    // Store member data in request for route handler
    req.member = member

    next()
  } catch (error) {
    console.error('Error in requireMemberOrOrgOwner middleware:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

/**
 * Require user to have access to a group
 * User must own the organization that the group belongs to
 * Checks req.params.groupId
 */
export const requireGroupAccess = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = (req.user as any)?.id

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Not authenticated',
      })
    }

    const groupId = getParam(req.params.groupId)

    if (!groupId) {
      return res.status(400).json({
        success: false,
        error: 'Group ID required',
      })
    }

    // Get group
    const group = await prisma.group.findUnique({
      where: { id: groupId },
    })

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      })
    }

    // If group has an organization, check if user owns it
    let isOrgOwner = false
    if (group.organizationId) {
      const organization = await prisma.organization.findUnique({
        where: { id: group.organizationId },
        select: { ownerId: true },
      })
      isOrgOwner = organization?.ownerId === userId
    }

    if (!isOrgOwner) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this group',
      })
    }

    // Store group data in request for route handler
    ;(req as any).group = group

    next()
  } catch (error) {
    console.error('Error in requireGroupAccess middleware:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

/**
 * Require member and group to belong to same organization
 * Checks req.params.groupId and req.params.memberId or req.body.memberId
 */
export const requireSameOrganization = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const groupId = getParam(req.params.groupId)
    const memberId = getParam(req.params.memberId) || req.body.memberId

    if (!groupId || !memberId) {
      return res.status(400).json({
        success: false,
        error: 'Group ID and Member ID required',
      })
    }

    // Get group and member with organization IDs
    const [group, member] = await Promise.all([
      prisma.group.findUnique({
        where: { id: groupId },
        select: { organizationId: true },
      }),
      prisma.member.findUnique({
        where: { id: memberId },
        include: {
          organizations: {
            select: { organizationId: true },
          },
        },
      }),
    ])

    if (!group || !member) {
      return res.status(404).json({
        success: false,
        error: 'Group or member not found',
      })
    }

    // Verify member belongs to the group's organization
    const memberBelongsToOrg = member.organizations.some(
      (mo) => mo.organizationId === group.organizationId
    )

    if (!memberBelongsToOrg) {
      return res.status(403).json({
        success: false,
        error: 'Member and group must belong to the same organization',
      })
    }

    next()
  } catch (error) {
    console.error('Error in requireSameOrganization middleware:', error)
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
}

// ============================================================================
// NEW: Permission-Based Middleware (RBAC System)
// ============================================================================

import {
  hasPermission,
  canManageOrgContent,
  canMemberAccessContent,
  canModifyContent,
  getManageableOrgIds,
  isSuperAdmin,
  ContentType,
} from '../services/permission.js'

/**
 * NEW: Dynamic permission checking middleware factory
 *
 * Creates middleware that checks if authenticated user has a specific permission
 * for the resource being accessed.
 *
 * @param permission - Permission name (e.g., "event.create", "group.update")
 * @param resourceType - Type of resource (e.g., "event", "group", "organization")
 * @param getResourceId - Function to extract resource ID from request (optional)
 *
 * @example
 * // Check permission for organization-level resource
 * router.post('/:orgId/events',
 *   requireAuth,
 *   requirePermission('event.create', 'organization', (req) => req.params.orgId),
 *   createEvent
 * )
 *
 * @example
 * // Check permission for specific event
 * router.patch('/:orgId/events/:eventId',
 *   requireAuth,
 *   requirePermission('event.update', 'event', (req) => req.params.eventId),
 *   updateEvent
 * )
 */
export const requirePermission = (
  permission: string,
  resourceType?: string,
  getResourceId?: (req: Request) => string | undefined
) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = (req.user as any)?.id

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required',
        })
      }

      // Extract resource ID if function provided
      const resourceId = getResourceId ? getResourceId(req) : undefined

      // Check permission
      const hasAccess = await hasPermission(
        { userId },
        permission,
        resourceType,
        resourceId
      )

      if (!hasAccess) {
        return res.status(403).json({
          success: false,
          error: `Insufficient permissions: ${permission} required`,
        })
      }

      next()
    } catch (error) {
      console.error('Error in requirePermission middleware:', error)
      return res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
}

/**
 * Authorize a group management action (add/remove/transfer/role-change of
 * members).
 *
 * The group's CREATOR can ALWAYS manage their own group — even if that group is
 * not yet linked to an organization. This mirrors how the join-request handlers
 * authorize the creator directly, and keeps creators from being locked out of
 * their own groups by the org-scoped permission system (which denies any
 * resource with no organization).
 *
 * Anyone else falls back to the org-scoped `permission` check (e.g.
 * `group.update` / `group.invite`), so org owners/admins/leaders with the right
 * role can still manage groups across their organization — including, for a
 * transfer, the destination group when it belongs to their org.
 */
export const requireGroupManage = (
  permission: string,
  getGroupId: (req: Request) => string | undefined
) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = (req.user as any)?.id

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required',
        })
      }

      const groupId = getGroupId(req)
      if (!groupId) {
        return res.status(400).json({
          success: false,
          error: 'Group id required',
        })
      }

      const group = await prisma.group.findUnique({
        where: { id: groupId },
        select: { creatorId: true, organizationId: true },
      })

      if (!group) {
        return res.status(404).json({
          success: false,
          error: 'Group not found',
        })
      }

      // The creator, the group org's owner, any role-holder in that org, or a
      // super admin may manage the group — same rule as the group's content
      // (canManageOrgContent). This unblocks non-creator org owners/leaders.
      if (await canManageOrgContent(userId, group.organizationId, group.creatorId)) {
        return next()
      }

      // Fall back to a granular org permission (a role that explicitly carries
      // `permission`), in case a role grants it without broader org management.
      const hasAccess = await hasPermission({ userId }, permission, 'group', groupId)

      if (!hasAccess) {
        return res.status(403).json({
          success: false,
          error: `Insufficient permissions: ${permission} required`,
        })
      }

      next()
    } catch (error) {
      console.error('Error in requireGroupManage middleware:', error)
      return res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
}

/**
 * NEW: Member content access middleware factory
 *
 * Creates middleware that checks if authenticated member can access specific content
 * via SMS link (public, members-only, or group-specific content).
 *
 * @param contentType - Type of content (event, announcement, media, form)
 * @param getContentId - Function to extract content ID from request
 *
 * @example
 * // Check if member can view event
 * router.get('/member/events/:eventId',
 *   requireMemberContentAccess('event', (req) => req.params.eventId),
 *   viewEvent
 * )
 */
export const requireMemberContentAccess = (
  contentType: ContentType,
  getContentId: (req: Request) => string
) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const memberId = req.session.memberId

      if (!memberId) {
        return res.status(401).json({
          success: false,
          error: 'Member authentication required. Please verify your phone number.',
        })
      }

      const contentId = getContentId(req)

      if (!contentId) {
        return res.status(400).json({
          success: false,
          error: 'Content ID required',
        })
      }

      // Check if member can access content
      const hasAccess = await canMemberAccessContent(memberId, contentType, contentId)

      if (!hasAccess) {
        return res.status(403).json({
          success: false,
          error: 'You do not have access to this content. You may need to join the group first.',
        })
      }

      next()
    } catch (error) {
      console.error('Error in requireMemberContentAccess middleware:', error)
      return res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
}

/**
 * NEW: Content modification permission middleware factory
 *
 * Allows content modification if:
 * - User has update permission for the content type
 * - OR user is the content creator (can edit their own content)
 *
 * @param contentType - Type of content (event, announcement, media, form)
 * @param getContentId - Function to extract content ID from request
 *
 * @example
 * // Allow update if user has permission OR is creator
 * router.patch('/:orgId/events/:eventId',
 *   requireAuth,
 *   requireModifyPermission('event', (req) => req.params.eventId),
 *   updateEvent
 * )
 */
export const requireModifyPermission = (
  contentType: ContentType,
  getContentId: (req: Request) => string
) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = (req.user as any)?.id

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required',
        })
      }

      const contentId = getContentId(req)

      if (!contentId) {
        return res.status(400).json({
          success: false,
          error: 'Content ID required',
        })
      }

      // Check if user can modify content (permission OR ownership)
      const canModify = await canModifyContent(userId, contentType, contentId)

      if (!canModify) {
        return res.status(403).json({
          success: false,
          error: 'You do not have permission to modify this content',
        })
      }

      next()
    } catch (error) {
      console.error('Error in requireModifyPermission middleware:', error)
      return res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
}
