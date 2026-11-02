import { leaderInvitationWhere, toLegacyInvite, prepareInvitationSend, finishInvitationSend, ensureInvitationGroupCode, acceptInvitationById } from './invitation.js';
import { randomBytes } from 'crypto';
import { prisma } from '../lib/prisma.js';
import { sendCampaignSms } from './sms-campaign.js';

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
 * @param recipientName - Optional name of the invitee (stored on the invite, not used in the SMS)
 * @returns Result object with invite details
 */
export async function sendGroupInvite(
  groupId: string,
  inviterId: string,
  inviterName: string,
  recipientPhone: string,
  groupName: string,
  baseUrl: string,
  recipientName?: string
): Promise<SendInviteResult> {
  try {
    // Generate unique token
    const token = generateInviteToken();

    // Set expiration to 7 days from now
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    const prepared = await prepareInvitationSend({ token, groupId, inviterId, recipientPhone, recipientName, expiresAt });
    const invite = prepared.row;
    const code = prepared.crossRequest && !prepared.code ? await ensureInvitationGroupCode(groupId) : prepared.code;
    const inviteUrl = prepared.crossRequest
      ? `${baseUrl}/join/group/${code}`
      : code ? `${baseUrl}/join/group/${code}?invite=${token}` : `${baseUrl}/join/group?invite=${token}`;

    // Send SMS via campaign system
    const smsResult = await sendCampaignSms({
      templateSlug: 'group-invite-v1',
      recipientPhone,
      context: {
        'inviter.name': inviterName,
        'group.name': groupName,
        'joinUrl': inviteUrl,
      },
      sentById: inviterId,
      metadata: { groupId, inviteId: invite.id },
    }).catch((error: unknown) => ({ success: false, error: error instanceof Error ? error.message : 'Failed to send SMS' }));

    const committed = await finishInvitationSend(invite.id, prepared.crossRequest, inviterId, recipientPhone, smsResult.success);
    if (!smsResult.success || !committed) {
      return { success: false, error: smsResult.error || (!smsResult.success ? 'Failed to send SMS' : 'Invite is no longer valid') };
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
    const invite = await prisma.invitation.findFirst({
      where: leaderInvitationWhere({ token }),
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

    if (invite.expiresAt && new Date() > invite.expiresAt) return null;

    // Check if already accepted
    if (invite.status === 'accepted' || invite.status === 'withdrawn') {
      return null;
    }

    if (!invite.inviter) return null;
    return { ...toLegacyInvite(invite), group: invite.group, inviter: invite.inviter };
  } catch (error: any) {
    console.error('[Invite] Error getting invite:', error.message);
    return null;
  }
}

/**
 * Accept an invite and add member to group
 * @param inviteId - ID of the invite
 * @param userId - ID of the user accepting the invite, recorded as the event actor
 * @returns Success status
 *
 * NOTE: This function has been updated to work with the new Members-based architecture.
 * The userId parameter is retained for audit attribution. Membership identity uses the recipientPhone from the invite to find the member.
 */
export async function acceptInvite(
  inviteId: string,
  userId: string
): Promise<{ success: boolean; error?: string; groupId?: string }> {
  try { return await acceptInvitationById(inviteId, userId); }
  catch (error: any) { return { success: false, error: error.message || 'Failed to accept invite' }; }
}
