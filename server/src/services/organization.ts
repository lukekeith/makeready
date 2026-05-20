import { prisma } from '../lib/prisma.js'
import type { Organization, Member } from '../generated/prisma/index.js'

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

/**
 * Get all members for an organization
 * @param organizationId - Organization ID
 * @param options - Query options (includeInactive, search)
 * @returns Array of members or error
 */
export async function getOrganizationMembers(
  organizationId: string,
  options: {
    includeInactive?: boolean
    search?: string
  } = {}
): Promise<MembersResult> {
  try {
    const { includeInactive = false, search } = options

    const where: any = {
      organizations: {
        some: {
          organizationId,
        },
      },
    }

    if (!includeInactive) {
      where.isActive = true
    }

    if (search) {
      where.OR = [
        { firstName: { contains: search, mode: 'insensitive' } },
        { lastName: { contains: search, mode: 'insensitive' } },
        { phoneNumber: { contains: search } },
        { email: { contains: search, mode: 'insensitive' } },
      ]
    }

    const members = await prisma.member.findMany({
      where,
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
    })

    return {
      success: true,
      data: members,
    }
  } catch (error) {
    console.error('Error fetching organization members:', error)
    return {
      success: false,
      error: 'Failed to fetch members',
    }
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
