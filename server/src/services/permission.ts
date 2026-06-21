import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'

/**
 * Permission Service - Core RBAC Logic
 *
 * This service provides permission checking functions for the RBAC system.
 */

// ============================================================================
// Type Definitions
// ============================================================================

export type ContentType = 'media'
export type ContentVisibility = 'public' | 'members' | 'group'

export interface Subject {
  userId?: string
  memberId?: string
}

// ============================================================================
// Super Admin Check
// ============================================================================

/**
 * Check if a user is a platform-wide Super Admin
 *
 * Super Admins bypass all permission checks
 */
export async function isSuperAdmin(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { isSuperAdmin: true },
  })

  return user?.isSuperAdmin ?? false
}

// ============================================================================
// Role and Permission Retrieval
// ============================================================================

/**
 * Get all roles assigned to a user within an organization
 */
export async function getUserRolesForOrg(
  userId: string,
  organizationId: string
): Promise<Array<{ id: string; name: string; isSystem: boolean }>> {
  const userRoles = await prisma.userRole.findMany({
    where: {
      userId,
      organizationId,
    },
    include: {
      role: {
        select: {
          id: true,
          name: true,
          isSystem: true,
        },
      },
    },
  })

  return userRoles.map((ur) => ur.role)
}

/**
 * Get all permissions for a specific role
 */
export async function getPermissionsForRole(
  roleId: string
): Promise<string[]> {
  const rolePermissions = await prisma.rolePermission.findMany({
    where: { roleId },
    include: {
      permission: {
        select: { name: true },
      },
    },
  })

  return rolePermissions.map((rp) => rp.permission.name)
}

/**
 * Check if a specific role has a specific permission
 */
export async function roleHasPermission(
  roleId: string,
  permissionName: string
): Promise<boolean> {
  const rolePermission = await prisma.rolePermission.findFirst({
    where: {
      roleId,
      permission: {
        name: permissionName,
      },
    },
  })

  return rolePermission !== null
}

// ============================================================================
// Resource Organization Lookup
// ============================================================================

/**
 * Get the organization ID for a given resource
 *
 * Used to determine which organization's roles to check
 */
export async function getOrganizationForResource(
  resourceType: string,
  resourceId: string
): Promise<string | null> {
  switch (resourceType) {
    case 'organization':
      return resourceId

    case 'group': {
      const group = await prisma.group.findUnique({
        where: { id: resourceId },
        select: { organizationId: true },
      })
      return group?.organizationId ?? null
    }

    case 'media': {
      const media = await prisma.media.findUnique({
        where: { id: resourceId },
        select: { organizationId: true },
      })
      return media?.organizationId ?? null
    }

    default:
      return null
  }
}

// ============================================================================
// Core Permission Checker
// ============================================================================

/**
 * Main permission checking function
 *
 * Checks if a subject (user or member) has a specific permission
 * for a given resource.
 *
 * @param subject - { userId, memberId } of the requester
 * @param permission - Permission name (e.g., "event.create")
 * @param resourceType - Type of resource (e.g., "event", "group")
 * @param resourceId - ID of the specific resource (optional)
 * @returns true if subject has permission, false otherwise
 *
 * @example
 * // Check if user can create events in an organization
 * await hasPermission(
 *   { userId: "user-123" },
 *   "event.create",
 *   "organization",
 *   "org-456"
 * )
 *
 * @example
 * // Check if user can update a specific event
 * await hasPermission(
 *   { userId: "user-123" },
 *   "event.update",
 *   "event",
 *   "event-789"
 * )
 */
export async function hasPermission(
  subject: Subject,
  permission: string,
  resourceType?: string,
  resourceId?: string
): Promise<boolean> {
  // Only users have permissions, members do not (members use content access checks)
  if (!subject.userId) {
    return false
  }

  // 1. Check for Super Admin (platform-wide bypass)
  if (await isSuperAdmin(subject.userId)) {
    console.log(`✅ [Permission] User ${subject.userId} is Super Admin - GRANTED`)
    return true
  }

  // 2. Determine organization scope
  let organizationId: string | null = null

  if (resourceType && resourceId) {
    organizationId = await getOrganizationForResource(resourceType, resourceId)
  } else if (resourceType === 'organization' && resourceId) {
    organizationId = resourceId
  }

  if (!organizationId) {
    console.log(
      `❌ [Permission] Could not determine organization for resource ${resourceType}:${resourceId}`
    )
    return false
  }

  // 2b. Organization owners implicitly hold every permission in their own org.
  // hasPermission otherwise only consults UserRole rows, so a non-role-holding
  // org owner was locked out of permissioned resources (e.g. media) in their own
  // organization. This mirrors canManageOrgContent's owner branch.
  const ownsOrg = await prisma.organization.findFirst({
    where: { id: organizationId, ownerId: subject.userId },
    select: { id: true },
  })
  if (ownsOrg) {
    console.log(
      `✅ [Permission] User ${subject.userId} owns organization ${organizationId} - GRANTED`
    )
    return true
  }

  // 3. Get user's roles for this organization
  const userRoles = await getUserRolesForOrg(subject.userId, organizationId)

  if (userRoles.length === 0) {
    console.log(
      `❌ [Permission] User ${subject.userId} has no roles in organization ${organizationId}`
    )
    return false
  }

  // 4. Check each role for the permission
  for (const role of userRoles) {
    if (await roleHasPermission(role.id, permission)) {
      console.log(
        `✅ [Permission] User ${subject.userId} has permission "${permission}" via role "${role.name}"`
      )
      return true
    }
  }

  console.log(
    `❌ [Permission] User ${subject.userId} does not have permission "${permission}" in organization ${organizationId}`
  )
  return false
}

/**
 * Can this user manage an org-owned content resource (study program, lesson,
 * activity, read block, etc.)?
 *
 * Content routes historically authorized by `creatorId` ONLY — so a group
 * leader or org owner who didn't personally CREATE the program was locked out
 * (404/403) of content in their own organization. This recognizes the broader
 * org relationship instead:
 *   - the original creator, OR
 *   - a platform Super Admin, OR
 *   - the organization's owner (`organizations.ownerId`), OR
 *   - any role-holder in the organization (Owner / Admin / Group Leader / …, a
 *     `UserRole` row) — same basis the media library uses.
 *
 * Pass the resource's `organizationId` and `creatorId` (either may be null).
 */
export async function canManageOrgContent(
  userId: string | undefined | null,
  organizationId: string | null | undefined,
  creatorId: string | null | undefined
): Promise<boolean> {
  if (!userId) return false

  // The creator can always manage what they created.
  if (creatorId && creatorId === userId) return true

  // Platform super admins bypass.
  if (await isSuperAdmin(userId)) return true

  // Beyond the creator, access is scoped to the resource's organization.
  if (!organizationId) return false

  // Organization owner.
  const ownedOrg = await prisma.organization.findFirst({
    where: { id: organizationId, ownerId: userId },
    select: { id: true },
  })
  if (ownedOrg) return true

  // Any role assignment in that organization (Owner/Admin/Group Leader/…).
  const role = await prisma.userRole.findFirst({
    where: { userId, organizationId },
    select: { id: true },
  })
  return role !== null
}

/**
 * Org IDs a user can manage: organizations they own (`organizations.ownerId`)
 * plus any organization they hold a role in. Shared by the per-model "manage"
 * filters below (the filter form of canManageOrgContent).
 */
export async function getManageableOrgIds(userId: string): Promise<string[]> {
  const [owned, roles] = await Promise.all([
    prisma.organization.findMany({ where: { ownerId: userId }, select: { id: true } }),
    prisma.userRole.findMany({ where: { userId }, select: { organizationId: true } }),
  ])
  return Array.from(
    new Set([...owned.map((o) => o.id), ...roles.map((r) => r.organizationId)])
  )
}

/**
 * Prisma where-fragment selecting the groups a user may MANAGE — the filter
 * form of `canManageOrgContent` for the Group model: groups they created OR any
 * group in an org they own / hold a role in. Super admins match every group
 * (`{}`). Spread into a `group.findFirst/findMany` where alongside
 * `{ id, isActive: true }`; a non-matching group falls through and reads as 404.
 */
export async function groupManageFilter(userId: string): Promise<Prisma.GroupWhereInput> {
  if (await isSuperAdmin(userId)) return {}
  const orgIds = await getManageableOrgIds(userId)
  return orgIds.length > 0
    ? { OR: [{ creatorId: userId }, { organizationId: { in: orgIds } }] }
    : { creatorId: userId }
}

/**
 * Prisma where-fragment selecting the enrollments a user may MANAGE: ones they
 * created (`createdById`) OR ones whose group they can manage (group creator /
 * org owner / role-holder). Super admins match all enrollments (`{}`). Spread
 * into an `enrollment.findFirst` where alongside `{ id }`; a non-matching
 * enrollment reads as 404.
 */
export async function enrollmentManageFilter(
  userId: string
): Promise<Prisma.EnrollmentWhereInput> {
  if (await isSuperAdmin(userId)) return {}
  const orgIds = await getManageableOrgIds(userId)
  const groupCond: Prisma.GroupWhereInput =
    orgIds.length > 0
      ? { OR: [{ creatorId: userId }, { organizationId: { in: orgIds } }] }
      : { creatorId: userId }
  return { OR: [{ createdById: userId }, { group: groupCond }] }
}

/**
 * Can this user manage content scoped to a specific group (by id)? Resolves the
 * group's org and creator, then defers to `canManageOrgContent`. Useful when the
 * group id is reachable but the org isn't already loaded (e.g. a scheduled
 * activity → schedule → enrollment → groupId chain).
 */
export async function canManageGroupId(
  userId: string,
  groupId: string | null | undefined
): Promise<boolean> {
  if (!groupId) return false
  const group = await prisma.group.findUnique({
    where: { id: groupId },
    select: { organizationId: true, creatorId: true },
  })
  if (!group) return false
  return canManageOrgContent(userId, group.organizationId, group.creatorId)
}

// ============================================================================
// Member Content Access Checker
// ============================================================================

/**
 * Get content object by type and ID
 */
async function getContent(
  contentType: ContentType,
  contentId: string
): Promise<{
  organizationId: string
  groupId: string | null
  visibility: string
} | null> {
  switch (contentType) {
    case 'media': {
      const media = await prisma.media.findUnique({
        where: { id: contentId },
        select: {
          organizationId: true,
          groupId: true,
          visibility: true,
        },
      })
      return media
    }

    default:
      return null
  }
}

/**
 * Check if member is part of a specific group
 */
export async function isGroupMember(
  memberId: string,
  groupId: string
): Promise<boolean> {
  const groupMember = await prisma.groupMember.findUnique({
    where: {
      groupId_memberId: {
        groupId,
        memberId,
      },
    },
    select: {
      isActive: true,
    },
  })

  return groupMember?.isActive ?? false
}

/**
 * Check if member is part of an organization
 */
export async function isOrganizationMember(
  memberId: string,
  organizationId: string
): Promise<boolean> {
  const memberOrg = await prisma.memberOrganization.findUnique({
    where: {
      memberId_organizationId: {
        memberId,
        organizationId,
      },
    },
  })

  return memberOrg !== null
}

/**
 * Check if a member can access specific content
 *
 * Members access content via SMS links. This function checks:
 * - If content is public (anyone can view)
 * - If content is members-only (member must belong to organization)
 * - If content is group-specific (member must belong to specific group)
 *
 * @param memberId - ID of the member
 * @param contentType - Type of content (event, announcement, media, form)
 * @param contentId - ID of the specific content
 * @returns true if member can access, false otherwise
 *
 * @example
 * // Check if member can view an event
 * await canMemberAccessContent("member-123", "event", "event-456")
 */
export async function canMemberAccessContent(
  memberId: string,
  contentType: ContentType,
  contentId: string
): Promise<boolean> {
  // 1. Get content details
  const content = await getContent(contentType, contentId)

  if (!content) {
    console.log(`❌ [Member Access] Content not found: ${contentType}:${contentId}`)
    return false
  }

  // 2. Public content - always accessible
  if (content.visibility === 'public') {
    console.log(
      `✅ [Member Access] Content ${contentType}:${contentId} is public - GRANTED`
    )
    return true
  }

  // 3. Member must be verified
  const member = await prisma.member.findUnique({
    where: { id: memberId },
    select: {
      phoneVerified: true,
      isActive: true,
    },
  })

  if (!member || !member.phoneVerified || !member.isActive) {
    console.log(
      `❌ [Member Access] Member ${memberId} is not verified or inactive`
    )
    return false
  }

  // 4. Group-specific content - member must belong to the specific group
  if (content.groupId) {
    const isMember = await isGroupMember(memberId, content.groupId)
    if (isMember) {
      console.log(
        `✅ [Member Access] Member ${memberId} belongs to group ${content.groupId} - GRANTED`
      )
      return true
    } else {
      console.log(
        `❌ [Member Access] Member ${memberId} does not belong to group ${content.groupId} - DENIED`
      )
      return false
    }
  }

  // 5. Organization-wide members content - member must belong to organization
  const isMember = await isOrganizationMember(memberId, content.organizationId)
  if (isMember) {
    console.log(
      `✅ [Member Access] Member ${memberId} belongs to organization ${content.organizationId} - GRANTED`
    )
    return true
  } else {
    console.log(
      `❌ [Member Access] Member ${memberId} does not belong to organization ${content.organizationId} - DENIED`
    )
    return false
  }
}

// ============================================================================
// Helper Functions for Resource Ownership
// ============================================================================

/**
 * Check if a user created a specific piece of content
 *
 * Used for allowing content creators to edit/delete their own content
 */
export async function isContentCreator(
  userId: string,
  contentType: ContentType,
  contentId: string
): Promise<boolean> {
  switch (contentType) {
    case 'media': {
      const media = await prisma.media.findUnique({
        where: { id: contentId },
        select: { uploadedBy: true },
      })
      return media?.uploadedBy === userId
    }

    default:
      return false
  }
}

/**
 * Check if user can modify specific content
 *
 * Allows if:
 * - User has update permission for the content type
 * - OR user is the content creator
 */
export async function canModifyContent(
  userId: string,
  contentType: ContentType,
  contentId: string
): Promise<boolean> {
  // Check permission
  const hasUpdatePermission = await hasPermission(
    { userId },
    `${contentType}.update`,
    contentType,
    contentId
  )

  if (hasUpdatePermission) {
    return true
  }

  // Check if user is creator
  return await isContentCreator(userId, contentType, contentId)
}
