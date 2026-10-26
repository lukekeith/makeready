import { prisma } from '../lib/prisma.js'
import type { Organization, Member, Prisma } from '../generated/prisma/index.js'
import { memberAccessScope } from './member-access.js'

/**
 * Organization Service
 * Handles organization management and member access
 */

export interface OrganizationResult {
  success: boolean
  data?: Organization
  error?: string
}

export interface MembersResult {
  success: boolean
  data?: Member[]
  error?: string
}

export interface OrganizationsResult {
  success: boolean
  data?: Organization[]
  error?: string
}

/**
 * Get organization by ID
 * @param organizationId - Organization ID
 * @returns Organization object or error
 */
export async function getOrganization(
  organizationId: string
): Promise<OrganizationResult> {
  try {
    const organization = await prisma.organization.findUnique({
      where: { id: organizationId },
      include: {
        owner: {
          select: {
            id: true,
            name: true,
            email: true,
            picture: true,
          },
        },
      },
    })

    if (!organization) {
      return {
        success: false,
        error: 'Organization not found',
      }
    }

    return {
      success: true,
      data: organization,
    }
  } catch (error) {
    console.error('Error fetching organization:', error)
    return {
      success: false,
      error: 'Failed to fetch organization',
    }
  }
}

/**
 * Get organization by owner ID
 * @param ownerId - User ID of the organization owner
 * @returns Organization object or error
 */
export async function getOrganizationByOwner(
  ownerId: string
): Promise<OrganizationResult> {
  try {
    const organization = await prisma.organization.findUnique({
      where: { ownerId },
    })

    if (!organization) {
      return {
        success: false,
        error: 'Organization not found for this user',
      }
    }

    return {
      success: true,
      data: organization,
    }
  } catch (error) {
    console.error('Error fetching organization by owner:', error)
    return {
      success: false,
      error: 'Failed to fetch organization',
    }
  }
}

/**
 * Resolve the organization a user belongs to, for scoping group creation.
 *
 * A user "belongs to" an organization if they either OWN it
 * (`organizations.ownerId`) or hold any role in it (a `UserRole` row). This is
 * broader than {@link getOrganizationByOwner} on purpose: an org Owner/Admin
 * granted via a role — not just the original creator/owner — must be able to
 * create groups under that org, so the group's organization association is
 * always set correctly at creation time.
 *
 * Returns the organization id, or null if the user is in no organization.
 *
 * @param userId - User ID
 */
export async function resolveUserOrganizationId(
  userId: string
): Promise<string | null> {
  // Prefer an organization the user owns.
  const owned = await prisma.organization.findFirst({
    where: { ownerId: userId },
    select: { id: true },
  })
  if (owned) {
    return owned.id
  }

  // Otherwise, the organization granted via any role (Owner, Admin, Leader…).
  const role = await prisma.userRole.findFirst({
    where: { userId },
    select: { organizationId: true },
  })
  return role?.organizationId ?? null
}

/**
 * Every active organization a user owns or holds a role in — the owned one
 * first (ownerId is unique, so at most one), then role-held orgs by name
 * (ui2-members-browse D18: a non-owner Admin or Group Leader needs an org id
 * that the owner-only /my/organization cannot give them).
 */
export async function getUserOrganizations(userId: string): Promise<OrganizationsResult> {
  try {
    const [owned, roles] = await Promise.all([
      prisma.organization.findMany({ where: { ownerId: userId, isActive: true } }),
      prisma.userRole.findMany({ where: { userId }, select: { organizationId: true } }),
    ])
    const ownedIds = new Set(owned.map((o) => o.id))
    const roleOrgIds = [...new Set(roles.map((r) => r.organizationId))].filter((id) => !ownedIds.has(id))
    const roleHeld =
      roleOrgIds.length > 0
        ? await prisma.organization.findMany({
            where: { id: { in: roleOrgIds }, isActive: true },
            orderBy: [{ name: 'asc' }, { id: 'asc' }],
          })
        : []
    return { success: true, data: [...owned, ...roleHeld] }
  } catch (error) {
    console.error('Error fetching user organizations:', error)
    return { success: false, error: 'Failed to fetch organizations' }
  }
}

/**
 * Update organization name
 * @param organizationId - Organization ID
 * @param name - New organization name
 * @returns Updated organization or error
 */
export async function updateOrganizationName(
  organizationId: string,
  name: string
): Promise<OrganizationResult> {
  try {
    const organization = await prisma.organization.update({
      where: { id: organizationId },
      data: { name },
    })

    return {
      success: true,
      data: organization,
    }
  } catch (error) {
    console.error('Error updating organization:', error)
    return {
      success: false,
      error: 'Failed to update organization',
    }
  }
}

export interface OrgMemberListItem {
  id: string
  firstName: string | null
  lastName: string | null
  profilePicture: string | null
  googlePicture: string | null
  /** This org's MemberOrganization.joinedAt (D6). */
  joinedAt: Date
  /** Active memberships in active groups of this org (SC4). */
  groupCount: number
}

export interface OrgMembersQuery {
  includeInactive?: boolean
  search?: string
  groupId?: string
  /** A User.id from /api/group-leaders → members of groups with that creatorId. */
  leaderId?: string
}

export interface OrgMembersResult {
  success: boolean
  data?: OrgMemberListItem[]
  /** D15: how the iPhone learns the caller's D7 scope. groupIds is [] when all. */
  viewerScope?: { all: boolean; groupIds: string[] }
  error?: string
}

/** D6 search: whitespace-separated tokens, each matched on its own and AND-combined. */
export function searchTokens(search: string | undefined): string[] {
  return (search ?? '').split(/\s+/).filter((t) => t.length > 0)
}

/**
 * The org's member directory (ui2-members-browse SC4, SC9, D6, D7, D15).
 * Queried through member_organizations because Prisma cannot order Member by a
 * filtered to-many (the joinedAt of THIS org). An explicit select keeps the
 * payload to the contract's keys (F9 — no pagination in this child). A narrowed
 * caller (memberAccessScope → groups) sees only members of the groups they
 * created; a groupId or leaderId outside that scope answers an empty list.
 */
export async function getOrganizationMembers(
  organizationId: string,
  viewerUserId: string,
  options: OrgMembersQuery = {}
): Promise<OrgMembersResult> {
  try {
    const { includeInactive = false, search, groupId, leaderId } = options
    const scope = await memberAccessScope(viewerUserId, organizationId)
    const viewerScope = { all: scope.all, groupIds: scope.all ? [] : scope.groupIds }
    if (!scope.all) {
      const outside =
        scope.groupIds.length === 0 ||
        (groupId !== undefined && !scope.groupIds.includes(groupId)) ||
        (leaderId !== undefined && leaderId !== viewerUserId)
      if (outside) return { success: true, data: [], viewerScope }
    }

    const activeIn = (group: Prisma.GroupWhereInput): Prisma.MemberWhereInput => ({
      groupMemberships: { some: { isActive: true, group: { isActive: true, organizationId, ...group } } },
    })
    const and: Prisma.MemberWhereInput[] = []
    if (!includeInactive) and.push({ isActive: true })
    for (const token of searchTokens(search)) {
      and.push({
        OR: [
          { firstName: { contains: token, mode: 'insensitive' } },
          { lastName: { contains: token, mode: 'insensitive' } },
          { email: { contains: token, mode: 'insensitive' } },
          { phoneNumber: { contains: token } },
        ],
      })
    }
    if (groupId !== undefined) and.push(activeIn({ id: groupId }))
    if (leaderId !== undefined) and.push(activeIn({ creatorId: leaderId }))
    if (!scope.all) and.push(activeIn({ id: { in: scope.groupIds } }))

    const rows = await prisma.memberOrganization.findMany({
      where: { organizationId, member: { AND: and } },
      orderBy: [{ joinedAt: 'desc' }, { memberId: 'asc' }],
      select: {
        joinedAt: true,
        member: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profilePicture: true,
            googlePicture: true,
            _count: {
              select: {
                groupMemberships: { where: { isActive: true, group: { isActive: true, organizationId } } },
              },
            },
          },
        },
      },
    })

    return {
      success: true,
      viewerScope,
      data: rows.map(({ joinedAt, member }) => ({
        id: member.id,
        firstName: member.firstName,
        lastName: member.lastName,
        profilePicture: member.profilePicture,
        googlePicture: member.googlePicture,
        joinedAt,
        groupCount: member._count.groupMemberships,
      })),
    }
  } catch (error) {
    console.error('Error fetching organization members:', error)
    return { success: false, error: 'Failed to fetch members' }
  }
}

/**
 * Verify user owns organization
 * @param userId - User ID to check
 * @param organizationId - Organization ID to verify
 * @returns True if user owns organization, false otherwise
 */
export async function verifyOrganizationOwnership(
  userId: string,
  organizationId: string
): Promise<boolean> {
  try {
    const organization = await prisma.organization.findUnique({
      where: { id: organizationId },
      select: { ownerId: true },
    })

    return organization?.ownerId === userId
  } catch (error) {
    console.error('Error verifying organization ownership:', error)
    return false
  }
}

/**
 * Verify member belongs to organization
 * @param memberId - Member ID to check
 * @param organizationId - Organization ID to verify
 * @returns True if member belongs to organization, false otherwise
 */
export async function verifyMemberInOrganization(
  memberId: string,
  organizationId: string
): Promise<boolean> {
  try {
    const membership = await prisma.memberOrganization.findFirst({
      where: {
        memberId,
        organizationId,
      },
    })

    return !!membership
  } catch (error) {
    console.error('Error verifying member in organization:', error)
    return false
  }
}
