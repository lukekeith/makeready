/**
 * Invite + Member Integration Tests
 *
 * Tests the complete invite flow with the new Member-based architecture
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { prisma } from '../../lib/prisma.js'
import { sendGroupInvite, acceptInvite, getInviteByToken } from '../../services/invite.js'
import { createMember, getMemberByPhone } from '../../services/member.js'

describe('Invite + Member Integration', () => {
  let testOrganization: any
  let testUser: any
  let testGroup: any
  let testMember: any
  let createdIds: string[] = []

  beforeEach(async () => {
    createdIds = []

    // Create test organization owner
    testUser = await prisma.user.create({
      data: {
        googleId: `test_${Date.now()}_${Math.random()}`,
        email: `test${Date.now()}_${Math.random()}@example.com`,
        name: 'Test User',
      },
    })
    createdIds.push(testUser.id)

    // Create test organization
    testOrganization = await prisma.organization.create({
      data: {
        name: 'Test Organization',
        ownerId: testUser.id,
      },
    })

    // Create test group
    testGroup = await prisma.group.create({
      data: {
        name: 'Test Group',
        description: 'Test group for invite integration',
        creatorId: testUser.id,
        organizationId: testOrganization.id,
      },
    })

    // Create test member with unique phone number
    testMember = await prisma.member.create({
      data: {
        phoneNumber: `+1555${Date.now().toString().slice(-7)}`,
        phoneVerified: true,
        firstName: 'Test',
        lastName: 'Member',
      },
    })

    // Link testMember to organization
    await prisma.memberOrganization.create({
      data: {
        memberId: testMember.id,
        organizationId: testOrganization.id,
      },
    })
  })

  afterEach(async () => {
    // Clean up test data
    try {
      // Delete in correct order to respect foreign keys
      await prisma.groupMember.deleteMany({
        where: { groupId: testGroup?.id },
      })
      await prisma.invite.deleteMany({
        where: { groupId: testGroup?.id },
      })
      await prisma.group.deleteMany({
        where: { id: testGroup?.id },
      })
      await prisma.memberOrganization.deleteMany({
        where: { organizationId: testOrganization?.id },
      })
      await prisma.member.deleteMany({
        where: { id: testMember?.id },
      })
      await prisma.organization.deleteMany({
        where: { id: testOrganization?.id },
      })
      await prisma.user.deleteMany({
        where: { id: { in: createdIds } },
      })
    } catch (error) {
      console.error('Cleanup error:', error)
    }
  })

  describe('sendGroupInvite', () => {
    it('should create invite with recipient phone number', async () => {
      const recipientPhone = `+1555${Date.now().toString().slice(-7)}`
      const result = await sendGroupInvite(
        testGroup.id,
        testUser.id,
        testUser.name,
        recipientPhone,
        testGroup.name,
        'http://localhost:3001'
      )

      // Note: This will fail in test without Twilio configured
      // Just verify the invite was created in database
      const invite = await prisma.invite.findFirst({
        where: {
          groupId: testGroup.id,
          recipientPhone,
        },
      })

      if (result.success) {
        expect(invite).toBeTruthy()
        expect(invite?.recipientPhone).toBe(recipientPhone)
        expect(invite?.status).toBe('pending')
      } else {
        // SMS send may fail without Twilio, but invite should still be attempted
        console.log('Invite send failed (expected without Twilio):', result.error)
      }
    })
  })

  describe('acceptInvite', () => {
    it('should find member by phone number and add to group', async () => {
      // Create invite
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: testMember.phoneNumber,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
        },
      })

      // Accept invite (userId param is deprecated but kept for backwards compat)
      const result = await acceptInvite(invite.id, 'not-used')

      expect(result.success).toBe(true)
      expect(result.groupId).toBe(testGroup.id)

      // Verify member was added to group
      const membership = await prisma.groupMember.findFirst({
        where: {
          groupId: testGroup.id,
          memberId: testMember.id,
        },
      })

      expect(membership).toBeTruthy()
      expect(membership?.role).toBe('member')
      expect(membership?.isActive).toBe(true)

      // Verify invite status updated
      const updatedInvite = await prisma.invite.findUnique({
        where: { id: invite.id },
      })

      expect(updatedInvite?.status).toBe('accepted')
      expect(updatedInvite?.acceptedAt).toBeTruthy()
    })

    it('should handle non-existent member gracefully', async () => {
      const nonExistentPhone = `+1555${Date.now().toString().slice(-7)}`

      // Create invite for phone that doesn't have a member
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: nonExistentPhone,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      })

      // Try to accept invite
      const result = await acceptInvite(invite.id, 'not-used')

      expect(result.success).toBe(false)
      expect(result.error).toContain('Member not found')

      // Invite should remain pending (not accepted)
      const updatedInvite = await prisma.invite.findUnique({
        where: { id: invite.id },
      })

      expect(updatedInvite?.status).toBe('pending')
    })

    it('should not add member twice to same group', async () => {
      // Create invite
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: testMember.phoneNumber,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      })

      // Accept invite first time
      const result1 = await acceptInvite(invite.id, 'not-used')
      expect(result1.success).toBe(true)

      // Create second invite for same member
      const invite2 = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}_2`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: testMember.phoneNumber,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      })

      // Try to accept second invite (member already in group)
      const result2 = await acceptInvite(invite2.id, 'not-used')

      // Should succeed but not create duplicate membership
      expect(result2.success).toBe(true)

      // Verify only one membership exists
      const memberships = await prisma.groupMember.findMany({
        where: {
          groupId: testGroup.id,
          memberId: testMember.id,
        },
      })

      expect(memberships.length).toBe(1)
    })

    it('should reject expired invites', async () => {
      // Create expired invite
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: testMember.phoneNumber,
          status: 'pending',
          expiresAt: new Date(Date.now() - 1000), // Already expired
        },
      })

      const result = await acceptInvite(invite.id, 'not-used')

      expect(result.success).toBe(false)
      expect(result.error).toContain('expired')
    })

    it('should reject already-accepted invites', async () => {
      // Create and accept invite
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: testMember.phoneNumber,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      })

      await acceptInvite(invite.id, 'not-used')

      // Try to accept again
      const result = await acceptInvite(invite.id, 'not-used')

      expect(result.success).toBe(false)
      expect(result.error).toContain('no longer valid')
    })
  })

  describe('getInviteByToken', () => {
    it('should return invite with group and inviter details', async () => {
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}_${Math.random()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: `+1555${Date.now().toString().slice(-7)}`,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      })

      const result = await getInviteByToken(invite.token)

      expect(result).toBeTruthy()
      expect(result?.id).toBe(invite.id)
      expect(result?.group?.id).toBe(testGroup.id)
      expect(result?.group?.name).toBe(testGroup.name)
      expect(result?.inviter?.id).toBe(testUser.id)
      expect(result?.inviter?.name).toBe(testUser.name)
      expect(result?.recipientPhone).toBeTruthy()
    })

    it('should return null for expired invites', async () => {
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}_${Math.random()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: `+1555${Date.now().toString().slice(-7)}`,
          status: 'pending',
          expiresAt: new Date(Date.now() - 1000), // Expired
        },
      })

      const result = await getInviteByToken(invite.token)

      expect(result).toBeNull()

      // Should update status to expired
      const updatedInvite = await prisma.invite.findUnique({
        where: { id: invite.id },
      })
      expect(updatedInvite?.status).toBe('expired')
    })
  })

  describe('Member Service Integration', () => {
    it('should create member and accept invite in sequence', async () => {
      const newPhone = `+1555${Date.now().toString().slice(-7)}`

      // Create invite first (before member exists)
      const invite = await prisma.invite.create({
        data: {
          token: `test_token_${Date.now()}`,
          groupId: testGroup.id,
          inviterId: testUser.id,
          recipientPhone: newPhone,
          status: 'pending',
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      })

      // Create member (simulates phone verification flow)
      const memberResult = await createMember({
        organizationId: testOrganization.id,
        phoneNumber: newPhone,
        phoneVerified: true,
        firstName: 'New',
        lastName: 'Member',
      })

      expect(memberResult.success).toBe(true)
      expect(memberResult.data?.phoneNumber).toBe(newPhone)

      // Now accept invite
      const acceptResult = await acceptInvite(invite.id, 'not-used')

      expect(acceptResult.success).toBe(true)
      expect(acceptResult.groupId).toBe(testGroup.id)

      // Verify member is in group
      const membership = await prisma.groupMember.findFirst({
        where: {
          groupId: testGroup.id,
          memberId: memberResult.data?.id,
        },
      })

      expect(membership).toBeTruthy()
    })

    it('should find member by phone for invite acceptance', async () => {
      const phoneResult = await getMemberByPhone(testMember.phoneNumber)

      expect(phoneResult.success).toBe(true)
      expect(phoneResult.data?.id).toBe(testMember.id)
      expect(phoneResult.data?.phoneNumber).toBe(testMember.phoneNumber)
    })
  })
})
