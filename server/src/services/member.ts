import { prisma } from '../lib/prisma.js'
import type { Member, Group, Prisma } from '../generated/prisma/index.js'
import { type MemberViewer, visibleMemberOrgIds } from './member-access.js'

/**
 * Member Service
 * Handles member management, phone verification, and profile updates
 */

export interface MemberResult {
  success: boolean
  data?: Member
  error?: string
}

export interface MembersResult {
  success: boolean
  data?: Member[]
  error?: string
}

export interface GroupsResult {
  success: boolean
  data?: Group[]
  error?: string
}

export interface ScopedGroupsResult extends GroupsResult {
  /** The member is outside the caller's D7 scope in every org → 404. */
  notFound?: boolean
}

const memberWithOrganizations = {
  include: {
    organizations: { include: { organization: { select: { id: true, name: true, ownerId: true } } } },
  },
} satisfies Prisma.MemberDefaultArgs

export type MemberWithOrganizations = Prisma.MemberGetPayload<typeof memberWithOrganizations>

export interface ScopedMemberResult {
  success: boolean
  data?: MemberWithOrganizations & { isGroupLeader: boolean }
  error?: string
}

export interface CreateMemberData {
  organizationId?: string  // Optional: Member can be created without an organization
  phoneNumber: string
  phoneVerified?: boolean
  smsConsent?: boolean
  smsConsentAt?: Date
  firstName?: string
  lastName?: string
  email?: string
  birthday?: Date
  profilePicture?: string
}

export interface UpdateMemberData {
  firstName?: string
  lastName?: string
  email?: string
  gender?: string | null
  birthday?: Date | null
  profilePicture?: string | null
  phoneVerified?: boolean
  lastVerifiedAt?: Date
  smsConsent?: boolean
  smsConsentAt?: Date | null
}

/**
 * Find member by phone number
 * @param phoneNumber - Phone number in E.164 format
 * @returns Member object or null if not found
 */
export async function getMemberByPhone(
  phoneNumber: string
): Promise<MemberResult> {
  try {
    const member = await prisma.member.findUnique({
      where: { phoneNumber },
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
      return {
        success: false,
        error: 'Member not found',
      }
    }

    return {
      success: true,
      data: member,
    }
  } catch (error) {
    console.error('Error finding member by phone:', error)
    return {
      success: false,
      error: 'Failed to find member',
    }
  }
}

/**
 * Get member by ID
 * @param memberId - Member ID
 * @returns Member object or error
 */
export async function getMember(memberId: string): Promise<MemberResult> {
  try {
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
      return {
        success: false,
        error: 'Member not found',
      }
    }

    return {
      success: true,
      data: member,
    }
  } catch (error) {
    console.error('Error fetching member:', error)
    return {
      success: false,
      error: 'Failed to fetch member',
    }
  }
}

/**
 * Create new member
 * @param data - Member creation data
 * @returns Created member or error
 */
export async function createMember(
  data: CreateMemberData
): Promise<MemberResult> {
  try {
    // Check if member with this phone already exists
    const existing = await prisma.member.findUnique({
      where: { phoneNumber: data.phoneNumber },
    })

    if (existing) {
      return {
        success: false,
        error: 'Member with this phone number already exists',
      }
    }

    // Use transaction to create member and optionally join to organization
    const member = await prisma.$transaction(async (tx) => {
      // Create member
      const newMember = await tx.member.create({
        data: {
          phoneNumber: data.phoneNumber,
          phoneVerified: data.phoneVerified ?? false,
          smsConsent: data.smsConsent ?? false,
          smsConsentAt: data.smsConsentAt ?? null,
          firstName: data.firstName,
          lastName: data.lastName,
          email: data.email,
          birthday: data.birthday,
          profilePicture: data.profilePicture,
          isActive: true,
          lastVerifiedAt: data.phoneVerified ? new Date() : null,
        },
      })

      // Create MemberOrganization relationship only if organizationId is provided
      if (data.organizationId) {
        await tx.memberOrganization.create({
          data: {
            memberId: newMember.id,
            organizationId: data.organizationId,
          },
        })
      }

      // Return member with organizations included
      return tx.member.findUnique({
        where: { id: newMember.id },
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
    })

    console.log('✅ Member created:', member?.phoneNumber)

    return {
      success: true,
      data: member!,
    }
  } catch (error) {
    console.error('Error creating member:', error)
    return {
      success: false,
      error: 'Failed to create member',
    }
  }
}

/**
 * Update member profile
 * @param memberId - Member ID
 * @param data - Update data
 * @returns Updated member or error
 */
export async function updateMember(
  memberId: string,
  data: UpdateMemberData
): Promise<MemberResult> {
  try {
    const member = await prisma.member.update({
      where: { id: memberId },
      data: {
        ...data,
        updatedAt: new Date(),
      },
    })

    return {
      success: true,
      data: member,
    }
  } catch (error) {
    console.error('Error updating member:', error)
    return {
      success: false,
      error: 'Failed to update member',
    }
  }
}

/**
 * Mark phone as verified for member
 * @param memberId - Member ID
 * @returns Updated member or error
 */
export async function verifyMemberPhone(
  memberId: string
): Promise<MemberResult> {
  return updateMember(memberId, {
    phoneVerified: true,
    lastVerifiedAt: new Date(),
  })
}

/**
 * Soft delete member (sets isActive = false)
 * @param memberId - Member ID
 * @returns Updated member or error
 */
export async function deleteMember(memberId: string): Promise<MemberResult> {
  try {
    // Use transaction to soft delete member and their group memberships
    const result = await prisma.$transaction(async (tx) => {
      // Soft delete member
      const member = await tx.member.update({
        where: { id: memberId },
        data: { isActive: false },
      })

      // Soft delete all group memberships
      await tx.groupMember.updateMany({
        where: { memberId },
        data: { isActive: false },
      })

      return member
    })

    return {
      success: true,
      data: result,
    }
  } catch (error) {
    console.error('Error deleting member:', error)
    return {
      success: false,
      error: 'Failed to delete member',
    }
  }
}

/**
 * Get all groups a member belongs to
 * @param memberId - Member ID
 * @param includeInactive - Include inactive groups
 * @returns Array of groups or error
 */
export async function getMemberGroups(
  memberId: string,
  includeInactive: boolean = false,
  organizationIds?: string[]
): Promise<GroupsResult> {
  try {
    const where: any = {
      memberId,
    }

    if (!includeInactive) {
      where.isActive = true
      where.group = { isActive: true }
    }

    // D16: a scoped caller sees only the member's groups in the orgs it sees the member in.
    if (organizationIds) {
      where.group = { ...(where.group ?? {}), organizationId: { in: organizationIds } }
    }

    const memberships = await prisma.groupMember.findMany({
      where,
      include: {
        group: {
          include: {
            creator: {
              select: {
                id: true,
                name: true,
                email: true,
                picture: true,
              },
            },
            _count: {
              select: { members: { where: { isActive: true } } },
            },
          },
        },
      },
      orderBy: {
        joinedAt: 'desc',
      },
    })

    const groups = memberships.map((m) => ({
      ...m.group,
      memberCount: m.group._count.members,
      joinedAt: m.joinedAt,
    }))

    return {
      success: true,
      data: groups,
    }
  } catch (error) {
    console.error('Error fetching member groups:', error)
    return {
      success: false,
      error: 'Failed to fetch groups',
    }
  }
}

/**
 * GET /api/members/:id for the UI 2.0 member page (ui2-members-browse D7, D8,
 * SC8). A user sees the member only through orgs memberAccessScope covers;
 * outside every one -> "Member not found" (the route answers 404). The payload
 * keeps only those orgs in organizations[], and isGroupLeader = the linked user
 * created an active group in one of them. A member reading itself is unscoped.
 */
export async function getScopedMember(memberId: string, viewer: MemberViewer): Promise<ScopedMemberResult> {
  try {
    const member = await prisma.member.findUnique({ where: { id: memberId }, ...memberWithOrganizations })
    if (!member) return { success: false, error: 'Member not found' }
    const visible = await visibleMemberOrgIds(viewer, memberId)
    if (viewer.kind === 'user' && visible.length === 0) return { success: false, error: 'Member not found' }

    const organizations = member.organizations.filter((mo) => visible.includes(mo.organizationId))
    const isGroupLeader =
      member.userId !== null &&
      visible.length > 0 &&
      (await prisma.group.count({
        where: { creatorId: member.userId, isActive: true, organizationId: { in: visible } },
      })) > 0

    return { success: true, data: { ...member, organizations, isGroupLeader } }
  } catch (error) {
    console.error('Error fetching scoped member:', error)
    return { success: false, error: 'Failed to fetch member' }
  }
}

/** GET /api/members/:id/groups under D7 + D16; a member reading itself is unchanged. */
export async function getScopedMemberGroups(
  memberId: string,
  viewer: MemberViewer,
  includeInactive: boolean = false
): Promise<ScopedGroupsResult> {
  if (viewer.kind === 'self') return getMemberGroups(memberId, includeInactive)
  try {
    const visible = await visibleMemberOrgIds(viewer, memberId)
    if (visible.length === 0) return { success: false, error: 'Member not found', notFound: true }
    return getMemberGroups(memberId, includeInactive, visible)
  } catch (error) {
    console.error('Error fetching scoped member groups:', error)
    return { success: false, error: 'Failed to fetch groups' }
  }
}

/**
 * Add member to group
 * @param memberId - Member ID
 * @param groupId - Group ID
 * @param role - Member role in group (default: "member")
 * @returns Success status
 */
export async function addMemberToGroup(
  memberId: string,
  groupId: string,
  role: string = 'member'
): Promise<{ success: boolean; error?: string; reactivated?: boolean }> {
  try {
    // Check if member is already in group
    const existing = await prisma.groupMember.findFirst({
      where: {
        groupId,
        memberId,
      },
    })

    if (existing) {
      // If membership exists but is inactive, reactivate it. The same row is
      // revived, so all of the member's existing group data is preserved.
      if (!existing.isActive) {
        await prisma.groupMember.update({
          where: { id: existing.id },
          data: { isActive: true, role },
        })
        return { success: true, reactivated: true }
      }

      return {
        success: false,
        error: 'Member is already in this group',
      }
    }

    // Create new group membership
    await prisma.groupMember.create({
      data: {
        groupId,
        memberId,
        role,
        isActive: true,
      },
    })

    return { success: true, reactivated: false }
  } catch (error) {
    console.error('Error adding member to group:', error)
    return {
      success: false,
      error: 'Failed to add member to group',
    }
  }
}

/**
 * Remove member from group (soft delete)
 * @param memberId - Member ID
 * @param groupId - Group ID
 * @returns Success status
 */
export async function removeMemberFromGroup(
  memberId: string,
  groupId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    await prisma.groupMember.updateMany({
      where: {
        groupId,
        memberId,
      },
      data: {
        isActive: false,
      },
    })

    return { success: true }
  } catch (error) {
    console.error('Error removing member from group:', error)
    return {
      success: false,
      error: 'Failed to remove member from group',
    }
  }
}

/**
 * Add existing member to an organization
 * @param memberId - Member ID
 * @param organizationId - Organization ID
 * @returns Success status
 */
export async function addMemberToOrganization(
  memberId: string,
  organizationId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    // Check if relationship already exists
    const existing = await prisma.memberOrganization.findFirst({
      where: {
        memberId,
        organizationId,
      },
    })

    if (existing) {
      return {
        success: false,
        error: 'Member is already part of this organization',
      }
    }

    // Create MemberOrganization relationship
    await prisma.memberOrganization.create({
      data: {
        memberId,
        organizationId,
      },
    })

    console.log(`✅ Member ${memberId} added to organization ${organizationId}`)

    return { success: true }
  } catch (error) {
    console.error('Error adding member to organization:', error)
    return {
      success: false,
      error: 'Failed to add member to organization',
    }
  }
}

/**
 * Remove member from organization
 * @param memberId - Member ID
 * @param organizationId - Organization ID
 * @returns Success status
 */
export async function removeMemberFromOrganization(
  memberId: string,
  organizationId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    // Delete MemberOrganization relationship
    await prisma.memberOrganization.deleteMany({
      where: {
        memberId,
        organizationId,
      },
    })

    console.log(
      `✅ Member ${memberId} removed from organization ${organizationId}`
    )

    return { success: true }
  } catch (error) {
    console.error('Error removing member from organization:', error)
    return {
      success: false,
      error: 'Failed to remove member from organization',
    }
  }
}
