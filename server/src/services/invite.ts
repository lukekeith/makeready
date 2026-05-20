import { randomBytes } from 'crypto';
import { sendSMS } from './twilio.js';
import { prisma } from '../lib/prisma.js';

/**
 * Invite Service
 * Handles group invitations via SMS
 */

export interface SendInviteResult {
  success: boolean;
  inviteId?: string;
  inviteUrl?: string;
  error?: string;
}

/**
 * Generate a secure random token for invite URLs
 * @returns 32-character hex string
 */
export function generateInviteToken(): string {
  return randomBytes(16).toString('hex');
}

/**
 * Send group invite via SMS
 * @param groupId - ID of the group
 * @param inviterId - ID of the user sending the invite
 * @param inviterName - Name of the inviter (for SMS message)
 * @param recipientPhone - Phone number of the recipient (E.164 format)
 * @param groupName - Name of the group (for SMS message)
 * @param baseUrl - Base URL for invite links (e.g., "https://makeready.app")
 * @returns Result object with invite details
 */
export async function sendGroupInvite(
  groupId: string,
  inviterId: string,
  inviterName: string,
  recipientPhone: string,
  groupName: string,
  baseUrl: string
): Promise<SendInviteResult> {
  try {
    // Generate unique token
    const token = generateInviteToken();

    // Set expiration to 7 days from now
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    // Create invite record in database
    const invite = await prisma.invite.create({
      data: {
        token,
        groupId,
        inviterId,
        recipientPhone,
        status: 'pending',
        expiresAt,
      },
    });

    // Look up group code for the URL
    const group = await prisma.group.findUnique({
      where: { id: groupId },
      select: { code: true },
    });

    // Generate invite URL pointing to the client's join flow
    const inviteUrl = group?.code
      ? `${baseUrl}/join/group/${group.code}?invite=${token}`
      : `${baseUrl}/join/group?invite=${token}`;

    // Create SMS message
    const message = `${inviterName} invited you to join "${groupName}" on MakeReady! Tap here to join: ${inviteUrl}. Msg & data rates may apply. Reply STOP to opt out, HELP for help.`;

    // Send SMS via Twilio
    const smsResult = await sendSMS(recipientPhone, message);

    if (!smsResult.success) {
      // Delete invite if SMS failed
      await prisma.invite.delete({ where: { id: invite.id } });

      return {
        success: false,
        error: smsResult.error || 'Failed to send SMS',
      };
    }

    console.log(`[Invite] Sent group invite to ${recipientPhone} for group ${groupId}`);

    return {
      success: true,
      inviteId: invite.id,
      inviteUrl,
    };
  } catch (error: any) {
    console.error('[Invite] Error sending group invite:', error.message);
    return {
      success: false,
      error: error.message || 'Failed to send invite',
    };
  }
}

/**
 * Get invite details by token
 * @param token - Invite token
 * @returns Invite with group and inviter details, or null if not found/expired
 */
export async function getInviteByToken(token: string) {
  try {
    const invite = await prisma.invite.findUnique({
      where: { token },
      include: {
        group: true,
        inviter: {
          select: {
            id: true,
            name: true,
            picture: true,
          },
        },
      },
    });

    if (!invite) {
      return null;
    }

    // Check if expired
    if (invite.expiresAt && new Date() > invite.expiresAt) {
      // Update status to expired
      await prisma.invite.update({
        where: { id: invite.id },
        data: { status: 'expired' },
      });
      return null;
    }

    // Check if already accepted
    if (invite.status === 'accepted') {
      return null;
    }

    return invite;
  } catch (error: any) {
    console.error('[Invite] Error getting invite:', error.message);
    return null;
  }
}

/**
 * Accept an invite and add member to group
 * @param inviteId - ID of the invite
 * @param userId - ID of the user accepting the invite (deprecated, not used)
 * @returns Success status
 *
 * NOTE: This function has been updated to work with the new Members-based architecture.
 * The userId parameter is kept for backwards compatibility but is not used.
 * Instead, the function uses the recipientPhone from the invite to find the member.
 */
export async function acceptInvite(
  inviteId: string,
  _userId: string // Prefixed with _ to indicate intentionally unused
): Promise<{ success: boolean; error?: string; groupId?: string }> {
  try {
    const invite = await prisma.invite.findUnique({
      where: { id: inviteId },
    });

    if (!invite) {
      return { success: false, error: 'Invite not found' };
    }

    if (invite.status !== 'pending') {
      return { success: false, error: 'Invite is no longer valid' };
    }

    if (invite.expiresAt && new Date() > invite.expiresAt) {
      return { success: false, error: 'Invite has expired' };
    }

    // Validate groupId exists
    if (!invite.groupId) {
      return { success: false, error: 'Invalid invite: no group specified' };
    }

    // TODO: Refactor to use Members instead of Users
    // For now, find member by phone number from invite
    if (!invite.recipientPhone) {
      return { success: false, error: 'Invite missing recipient phone number' };
    }

    // Find member by phone number
    const member = await prisma.member.findUnique({
      where: { phoneNumber: invite.recipientPhone },
    });

    if (!member) {
      return { success: false, error: 'Member not found for this phone number' };
    }

    // Check if member is already in group
    const existingMembership = await prisma.groupMember.findFirst({
      where: {
        groupId: invite.groupId,
        memberId: member.id,
      },
    });

    if (existingMembership) {
      // Mark invite as accepted even if already a member
      await prisma.invite.update({
        where: { id: inviteId },
        data: {
          status: 'accepted',
          acceptedAt: new Date(),
        },
      });

      return {
        success: true,
        groupId: invite.groupId,
      };
    }

    // Add member to group and mark invite as accepted
    await prisma.$transaction([
      prisma.groupMember.create({
        data: {
          groupId: invite.groupId,
          memberId: member.id,
          role: 'member',
        },
      }),
      prisma.invite.update({
        where: { id: inviteId },
        data: {
          status: 'accepted',
          acceptedAt: new Date(),
        },
      }),
    ]);

    console.log(`[Invite] Member ${member.id} (phone: ${member.phoneNumber}) accepted invite ${inviteId} and joined group ${invite.groupId}`);

    return {
      success: true,
      groupId: invite.groupId,
    };
  } catch (error: any) {
    console.error('[Invite] Error accepting invite:', error.message);
    return {
      success: false,
      error: error.message || 'Failed to accept invite',
    };
  }
}
