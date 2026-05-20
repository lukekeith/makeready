import { prisma } from '../lib/prisma.js'
import type { Member } from '../generated/prisma/index.js'

/**
 * Member Google Profile Linking Service
 * Handles linking Google accounts to Member profiles for profile sync (NOT authentication)
 */

export interface GoogleProfile {
  googleId: string
  email: string
  name?: string
  picture?: string
}

export interface MemberGoogleResult {
  success: boolean
  data?: Member
  error?: string
}

/**
 * Link a Google profile to a Member
 * This is for profile sync only - Members authenticate via phone
 * @param memberId - Member ID to link
 * @param googleProfile - Google profile data from OAuth
 * @returns Updated member or error
 */
export async function linkGoogleProfile(
  memberId: string,
  googleProfile: GoogleProfile
): Promise<MemberGoogleResult> {
  try {
    // Check if this Google ID is already linked to a User (can't use same Google for both)
    const existingUser = await prisma.user.findUnique({
      where: { googleId: googleProfile.googleId },
      select: { id: true, email: true },
    })

    if (existingUser) {
      return {
        success: false,
        error: 'This Google account is already used for User authentication. Members cannot link the same Google account.',
      }
    }

    // Check if this Google ID is already linked to another Member
    const existingMember = await prisma.member.findUnique({
      where: { googleId: googleProfile.googleId },
      select: { id: true, phoneNumber: true },
    })

    if (existingMember && existingMember.id !== memberId) {
      return {
        success: false,
        error: 'This Google account is already linked to another member.',
      }
    }

    // Check if member exists
    const member = await prisma.member.findUnique({
      where: { id: memberId },
    })

    if (!member) {
      return {
        success: false,
        error: 'Member not found',
      }
    }

    // Check if member already has a different Google account linked
    if (member.googleId && member.googleId !== googleProfile.googleId) {
      return {
        success: false,
        error: 'Member already has a different Google account linked. Unlink first.',
      }
    }

    // Link Google profile to member
    const updatedMember = await prisma.member.update({
      where: { id: memberId },
      data: {
        googleId: googleProfile.googleId,
        googleEmail: googleProfile.email,
        googlePicture: googleProfile.picture || null,
        googleLinkedAt: new Date(),
      },
    })

    console.log(`✅ Google profile linked to member ${memberId}`)

    return {
      success: true,
      data: updatedMember,
    }
  } catch (error) {
    console.error('Error linking Google profile:', error)
    return {
      success: false,
      error: 'Failed to link Google profile',
    }
  }
}

/**
 * Unlink Google profile from a Member
 * @param memberId - Member ID to unlink
 * @returns Updated member or error
 */
export async function unlinkGoogleProfile(
  memberId: string
): Promise<MemberGoogleResult> {
  try {
    const member = await prisma.member.findUnique({
      where: { id: memberId },
    })

    if (!member) {
      return {
        success: false,
        error: 'Member not found',
      }
    }

    if (!member.googleId) {
      return {
        success: false,
        error: 'Member does not have a Google account linked',
      }
    }

    // Clear Google profile data
    const updatedMember = await prisma.member.update({
      where: { id: memberId },
      data: {
        googleId: null,
        googleEmail: null,
        googlePicture: null,
        googleLinkedAt: null,
      },
    })

    console.log(`✅ Google profile unlinked from member ${memberId}`)

    return {
      success: true,
      data: updatedMember,
    }
  } catch (error) {
    console.error('Error unlinking Google profile:', error)
    return {
      success: false,
      error: 'Failed to unlink Google profile',
    }
  }
}

/**
 * Sync profile picture from linked Google account to Member's profilePicture
 * @param memberId - Member ID to sync
 * @returns Updated member or error
 */
export async function syncGoogleProfile(
  memberId: string
): Promise<MemberGoogleResult> {
  try {
    const member = await prisma.member.findUnique({
      where: { id: memberId },
    })

    if (!member) {
      return {
        success: false,
        error: 'Member not found',
      }
    }

    if (!member.googleId) {
      return {
        success: false,
        error: 'Member does not have a Google account linked',
      }
    }

    if (!member.googlePicture) {
      return {
        success: false,
        error: 'Linked Google account does not have a profile picture',
      }
    }

    // Update member's profile picture with Google picture
    const updatedMember = await prisma.member.update({
      where: { id: memberId },
      data: {
        profilePicture: member.googlePicture,
      },
    })

    console.log(`✅ Synced Google profile picture for member ${memberId}`)

    return {
      success: true,
      data: updatedMember,
    }
  } catch (error) {
    console.error('Error syncing Google profile:', error)
    return {
      success: false,
      error: 'Failed to sync Google profile',
    }
  }
}

/**
 * Get Member by Google ID
 * Used during OAuth callback to check if a Google account is already linked
 * @param googleId - Google ID to lookup
 * @returns Member or null
 */
export async function getMemberByGoogleId(
  googleId: string
): Promise<MemberGoogleResult> {
  try {
    const member = await prisma.member.findUnique({
      where: { googleId },
      include: {
        organizations: {
          include: {
            organization: {
              select: {
                id: true,
                name: true,
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
    console.error('Error finding member by Google ID:', error)
    return {
      success: false,
      error: 'Failed to find member',
    }
  }
}
