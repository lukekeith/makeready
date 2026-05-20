import { prisma } from '../lib/prisma.js'
import type { Member, User } from '../generated/prisma/index.js'
import { uploadMemberAvatar } from './storage.js'

/**
 * Account Linking Service
 * Handles bidirectional linking between User (Google OAuth) and Member (phone verified) accounts
 *
 * Flows:
 * 1. User -> Member: User verifies phone to link to existing/new Member account
 * 2. Member -> User: Member authenticates via Google to link to existing/new User account
 */

/**
 * Download an image from a URL and return as Buffer
 * @param imageUrl - URL of the image to download
 * @returns Buffer of the image data, or null if failed
 */
async function downloadImage(imageUrl: string): Promise<{ buffer: Buffer; mimeType: string } | null> {
  try {
    const response = await fetch(imageUrl)
    if (!response.ok) {
      console.warn(`Failed to download image from ${imageUrl}: ${response.status}`)
      return null
    }

    const contentType = response.headers.get('content-type') || 'image/jpeg'
    const arrayBuffer = await response.arrayBuffer()
    const buffer = Buffer.from(arrayBuffer)

    return { buffer, mimeType: contentType }
  } catch (error) {
    console.warn('Error downloading image:', error)
    return null
  }
}

/**
 * Download a profile picture from URL, upload to R2, and update Member's profilePicture
 * @param memberId - Member ID to update
 * @param pictureUrl - URL of the picture to download (e.g., Google profile picture)
 * @returns true if successful, false otherwise
 */
export async function syncProfilePictureFromUrl(
  memberId: string,
  pictureUrl: string
): Promise<boolean> {
  try {
    // Download the image
    const imageData = await downloadImage(pictureUrl)
    if (!imageData) {
      console.warn(`Could not download profile picture for member ${memberId}`)
      return false
    }

    // Upload to R2 storage
    const uploadResult = await uploadMemberAvatar(memberId, imageData.buffer, imageData.mimeType)
    if (!uploadResult.success || !uploadResult.url) {
      console.warn(`Could not upload profile picture for member ${memberId}: ${uploadResult.error}`)
      return false
    }

    // Update member's profilePicture
    await prisma.member.update({
      where: { id: memberId },
      data: { profilePicture: uploadResult.url },
    })

    console.log(`✅ Synced profile picture for member ${memberId} from external URL`)
    return true
  } catch (error) {
    console.error('Error syncing profile picture:', error)
    return false
  }
}

export interface LinkResult {
  success: boolean
  data?: {
    userId: string
    memberId: string
    memberPhoneNumber: string
    previousUserId?: string
    created?: boolean
  }
  error?: string
}

export interface GoogleProfile {
  googleId: string
  email: string
  name?: string
  picture?: string
}

/**
 * Link a Member to a User account (core function used by both flows)
 * @param memberId - Member ID to link
 * @param userId - User ID to link to
 * @param options - Additional options
 * @returns LinkResult with success status and linked IDs
 */
export async function linkMemberToUser(
  memberId: string,
  userId: string,
  _options?: {
    syncProfile?: boolean
  }
): Promise<LinkResult> {
  try {
    // Find the member
    const member = await prisma.member.findUnique({
      where: { id: memberId },
      select: {
        id: true,
        userId: true,
        phoneNumber: true,
        firstName: true,
        lastName: true,
        profilePicture: true,
      },
    })

    if (!member) {
      return {
        success: false,
        error: 'Member not found',
      }
    }

    // Find the user
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        picture: true,
        linkedMember: {
          select: { id: true, phoneNumber: true },
        },
      },
    })

    if (!user) {
      return {
        success: false,
        error: 'User not found',
      }
    }

    // Check if user already has a different Member linked
    if (user.linkedMember && user.linkedMember.id !== memberId) {
      return {
        success: false,
        error: `User already has a linked Member account (${user.linkedMember.phoneNumber}). Unlink the existing Member first.`,
      }
    }

    // Track if this is a re-link (Member was linked to a different User)
    const previousUserId = member.userId && member.userId !== userId ? member.userId : undefined

    // Link the member to the user
    const updatedMember = await prisma.member.update({
      where: { id: memberId },
      data: {
        userId: userId,
        userLinkedAt: new Date(),
      },
    })

    console.log(`✅ Member ${memberId} linked to User ${userId}${previousUserId ? ` (re-linked from ${previousUserId})` : ''}`)

    // Sync profile picture from User if member doesn't have one
    if (!member.profilePicture && user.picture) {
      // Do this async - don't block the response
      syncProfilePictureFromUrl(memberId, user.picture).catch(err => {
        console.warn('Failed to sync profile picture during account linking:', err)
      })
    }

    return {
      success: true,
      data: {
        userId,
        memberId,
        memberPhoneNumber: updatedMember.phoneNumber,
        previousUserId,
      },
    }
  } catch (error: any) {
    console.error('Error linking Member to User:', error)
    return {
      success: false,
      error: error.message || 'Failed to link accounts',
    }
  }
}

/**
 * Find or create a Member by phone number (for Flow 1: User links phone)
 * @param phoneNumber - Phone number in E.164 format
 * @returns Object with member and created flag
 */
export async function findOrCreateMemberByPhone(
  phoneNumber: string
): Promise<{
  success: boolean
  data?: {
    member: Member
    created: boolean
  }
  error?: string
}> {
  try {
    // Check if member exists with this phone number
    let member = await prisma.member.findUnique({
      where: { phoneNumber },
    })

    if (member) {
      return {
        success: true,
        data: {
          member,
          created: false,
        },
      }
    }

    // Create new member with verified phone
    member = await prisma.member.create({
      data: {
        phoneNumber,
        phoneVerified: true,
        lastVerifiedAt: new Date(),
      },
    })

    console.log(`✅ Created new Member for phone: ${phoneNumber}`)

    return {
      success: true,
      data: {
        member,
        created: true,
      },
    }
  } catch (error: any) {
    console.error('Error finding/creating Member by phone:', error)
    return {
      success: false,
      error: error.message || 'Failed to find or create Member',
    }
  }
}

/**
 * Link a Member to a User via Google OAuth (for Flow 2: Member links Google)
 * Finds or creates a User by googleId, then links the Member
 * @param memberId - Member ID to link
 * @param googleProfile - Google profile data from OAuth
 * @returns LinkResult with success status
 */
export async function linkMemberViaGoogle(
  memberId: string,
  googleProfile: GoogleProfile
): Promise<LinkResult> {
  try {
    // Find the member first
    const member = await prisma.member.findUnique({
      where: { id: memberId },
      select: { id: true, userId: true, phoneNumber: true, profilePicture: true },
    })

    if (!member) {
      return {
        success: false,
        error: 'Member not found',
      }
    }

    // Find existing user by googleId
    let user = await prisma.user.findUnique({
      where: { googleId: googleProfile.googleId },
      include: {
        linkedMember: {
          select: { id: true, phoneNumber: true },
        },
      },
    })

    if (user) {
      // User exists - check if they already have a different Member linked
      if (user.linkedMember && user.linkedMember.id !== memberId) {
        return {
          success: false,
          error: `This Google account is already linked to a different Member (${user.linkedMember.phoneNumber}). Unlink that Member first.`,
        }
      }
    } else {
      // Create new User from Google profile
      user = await prisma.user.create({
        data: {
          googleId: googleProfile.googleId,
          email: googleProfile.email,
          name: googleProfile.name || googleProfile.email.split('@')[0],
          picture: googleProfile.picture,
        },
        include: {
          linkedMember: {
            select: { id: true, phoneNumber: true },
          },
        },
      })

      console.log(`✅ Created new User from Google: ${user.email}`)
    }

    // Track if this is a re-link
    const previousUserId = member.userId && member.userId !== user.id ? member.userId : undefined

    // Link the member to the user
    const updatedMember = await prisma.member.update({
      where: { id: memberId },
      data: {
        userId: user.id,
        userLinkedAt: new Date(),
      },
    })

    console.log(`✅ Member ${memberId} linked to User ${user.id} via Google${previousUserId ? ` (re-linked from ${previousUserId})` : ''}`)

    // Sync profile picture from Google if member doesn't have one
    if (!member.profilePicture && googleProfile.picture) {
      // Do this async - don't block the response
      syncProfilePictureFromUrl(memberId, googleProfile.picture).catch(err => {
        console.warn('Failed to sync profile picture during account linking:', err)
      })
    }

    return {
      success: true,
      data: {
        userId: user.id,
        memberId,
        memberPhoneNumber: updatedMember.phoneNumber,
        previousUserId,
        created: !user.linkedMember,
      },
    }
  } catch (error: any) {
    console.error('Error linking Member via Google:', error)
    return {
      success: false,
      error: error.message || 'Failed to link accounts via Google',
    }
  }
}

/**
 * Unlink a Member from their linked User account
 * @param memberId - Member ID to unlink
 * @returns LinkResult with success status
 */
export async function unlinkMemberFromUser(
  memberId: string
): Promise<LinkResult> {
  try {
    const member = await prisma.member.findUnique({
      where: { id: memberId },
      select: { id: true, userId: true, phoneNumber: true },
    })

    if (!member) {
      return {
        success: false,
        error: 'Member not found',
      }
    }

    if (!member.userId) {
      return {
        success: false,
        error: 'Member is not linked to a User account',
      }
    }

    const previousUserId = member.userId

    // Unlink by setting userId to null
    await prisma.member.update({
      where: { id: memberId },
      data: {
        userId: null,
        userLinkedAt: null,
      },
    })

    console.log(`✅ Member ${memberId} unlinked from User ${previousUserId}`)

    return {
      success: true,
      data: {
        userId: previousUserId,
        memberId,
        memberPhoneNumber: member.phoneNumber,
        previousUserId,
      },
    }
  } catch (error: any) {
    console.error('Error unlinking Member from User:', error)
    return {
      success: false,
      error: error.message || 'Failed to unlink accounts',
    }
  }
}

/**
 * Get the linked Member for a User
 * @param userId - User ID to lookup
 * @returns Member if linked, null otherwise
 */
export async function getLinkedMember(
  userId: string
): Promise<Member | null> {
  const member = await prisma.member.findUnique({
    where: { userId },
  })
  return member
}

/**
 * Get the linked User for a Member
 * @param memberId - Member ID to lookup
 * @returns User if linked, null otherwise
 */
export async function getLinkedUser(
  memberId: string
): Promise<User | null> {
  const member = await prisma.member.findUnique({
    where: { id: memberId },
    select: { userId: true },
  })

  if (!member?.userId) {
    return null
  }

  const user = await prisma.user.findUnique({
    where: { id: member.userId },
  })
  return user
}
