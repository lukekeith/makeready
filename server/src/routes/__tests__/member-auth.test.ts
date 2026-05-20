/**
 * Member Authentication Tests
 *
 * Tests for member-level authentication system:
 * - Phone verification creates member session
 * - Member can access their own resources
 * - Member cannot access other members' resources
 * - GET /api/members/me
 * - GET /api/members/session
 * - POST /api/members/logout
 */

import { describe, it, expect, beforeEach, vi } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import * as twilioService from '../../services/twilio'

// Mock Twilio service
vi.mock('../../services/twilio', () => ({
  sendVerificationCode: vi.fn(),
  verifyCode: vi.fn(),
}))

describe('Member Authentication', () => {
  let testOrganization: any
  let testMember: any
  let otherMember: any
  const testPhoneNumber = '+15555551234'
  const otherPhoneNumber = '+15555554321'

  beforeEach(async () => {
    // Clean up test data - delete in correct order due to foreign key constraints
    await prisma.member.deleteMany({
      where: {
        phoneNumber: { in: [testPhoneNumber, otherPhoneNumber] },
      },
    })

    // Delete existing test organization and user
    await prisma.organization.deleteMany({
      where: {
        owner: {
          googleId: 'test-member-auth-google-id',
        },
      },
    })

    await prisma.user.deleteMany({
      where: {
        googleId: 'test-member-auth-google-id',
      },
    })

    // Create test organization
    const user = await prisma.user.create({
      data: {
        googleId: 'test-member-auth-google-id',
        email: 'member-auth-test@example.com',
        name: 'Member Auth Test User',
      },
    })

    testOrganization = await prisma.organization.create({
      data: {
        name: 'Test Organization',
        ownerId: user.id,
        isActive: true,
      },
    })

    // Create test members
    testMember = await prisma.member.create({
      data: {
        phoneNumber: testPhoneNumber,
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

    otherMember = await prisma.member.create({
      data: {
        phoneNumber: otherPhoneNumber,
        phoneVerified: true,
        firstName: 'Other',
        lastName: 'Member',
      },
    })

    // Link otherMember to organization
    await prisma.memberOrganization.create({
      data: {
        memberId: otherMember.id,
        organizationId: testOrganization.id,
      },
    })
  })

  describe('POST /api/members/confirm-verification - Session Creation', () => {
    it('should create member session after successful verification', async () => {
      const newPhone = '+15555559999'

      // Mock successful Twilio verification
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: newPhone,
          code: '123456',
          organizationId: testOrganization.id,
          firstName: 'New',
          lastName: 'Member',
        })

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data).toHaveProperty('id')
      expect(response.body.data.phoneNumber).toBe(newPhone)

      // Check that session cookie was set
      const cookies = response.headers['set-cookie']
      expect(cookies).toBeDefined()

      // Clean up
      await prisma.member.deleteMany({ where: { phoneNumber: newPhone } })
    })

    it('should create session for existing member on re-verification', async () => {
      // Mock successful Twilio verification
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data.id).toBe(testMember.id)

      // Check that session cookie was set
      const cookies = response.headers['set-cookie']
      expect(cookies).toBeDefined()
    })
  })

  describe('GET /api/members/session - Check Authentication', () => {
    it('should return not authenticated when no session', async () => {
      const response = await request(app).get('/api/members/session')

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.authenticated).toBe(false)
      expect(response.body.member).toBeNull()
    })

    it('should return authenticated member when session exists', async () => {
      // First, create a session by verifying phone
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Check session
      const response = await request(app)
        .get('/api/members/session')
        .set('Cookie', cookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.authenticated).toBe(true)
      expect(response.body.member).toHaveProperty('id', testMember.id)
      expect(response.body).toHaveProperty('authenticatedAt')
    })
  })

  describe('GET /api/members/me - Current Member Profile', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get('/api/members/me')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('not authenticated')
    })

    it('should return current member profile when authenticated', async () => {
      // Create session
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Get current member
      const response = await request(app)
        .get('/api/members/me')
        .set('Cookie', cookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data).toHaveProperty('id', testMember.id)
      expect(response.body.data).toHaveProperty('phoneNumber', testPhoneNumber)
      expect(response.body.data).toHaveProperty('firstName', 'Test')
    })
  })

  describe('POST /api/members/logout - Logout Member', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).post('/api/members/logout')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should successfully logout and clear session', async () => {
      // Create session
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Logout
      const logoutResponse = await request(app)
        .post('/api/members/logout')
        .set('Cookie', cookies)

      expect(logoutResponse.status).toBe(200)
      expect(logoutResponse.body.success).toBe(true)
      expect(logoutResponse.body.message).toContain('Logged out')

      // Verify session is cleared - try to access /me
      const meResponse = await request(app)
        .get('/api/members/me')
        .set('Cookie', cookies)

      expect(meResponse.status).toBe(401)
    })
  })

  describe('GET /api/members/:memberId - Access Control', () => {
    it('should allow member to access their own profile', async () => {
      // Create session
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Access own profile
      const response = await request(app)
        .get(`/api/members/${testMember.id}`)
        .set('Cookie', cookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data).toHaveProperty('id', testMember.id)
    })

    it('should prevent member from accessing another member profile', async () => {
      // Create session for testMember
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Try to access other member's profile
      const response = await request(app)
        .get(`/api/members/${otherMember.id}`)
        .set('Cookie', cookies)

      expect(response.status).toBe(403)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('permission')
    })
  })

  describe('PATCH /api/members/:memberId - Update Profile', () => {
    it('should allow member to update their own profile', async () => {
      // Create session
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Update own profile
      const response = await request(app)
        .patch(`/api/members/${testMember.id}`)
        .set('Cookie', cookies)
        .send({
          firstName: 'Updated',
          lastName: 'Name',
        })

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data.firstName).toBe('Updated')
      expect(response.body.data.lastName).toBe('Name')
    })

    it('should prevent member from updating another member profile', async () => {
      // Create session for testMember
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Try to update other member's profile
      const response = await request(app)
        .patch(`/api/members/${otherMember.id}`)
        .set('Cookie', cookies)
        .send({
          firstName: 'Hacked',
        })

      expect(response.status).toBe(403)
      expect(response.body.success).toBe(false)
    })
  })

  describe('GET /api/members/:memberId/groups - Group Access', () => {
    it('should allow member to view their own groups', async () => {
      // Create session
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // View own groups
      const response = await request(app)
        .get(`/api/members/${testMember.id}/groups`)
        .set('Cookie', cookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body).toHaveProperty('data')
      expect(response.body).toHaveProperty('count')
    })

    it('should prevent member from viewing another member groups', async () => {
      // Create session for testMember
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Try to view other member's groups
      const response = await request(app)
        .get(`/api/members/${otherMember.id}/groups`)
        .set('Cookie', cookies)

      expect(response.status).toBe(403)
      expect(response.body.success).toBe(false)
    })
  })

  describe('Session Persistence', () => {
    it('should maintain member session across multiple requests', async () => {
      // Create session
      vi.mocked(twilioService.verifyCode).mockResolvedValue({
        success: true,
        valid: true,
      })

      const verifyResponse = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: testPhoneNumber,
          code: '123456',
          organizationId: testOrganization.id,
        })

      const cookies = verifyResponse.headers['set-cookie']

      // Make multiple requests with same session
      const response1 = await request(app)
        .get('/api/members/me')
        .set('Cookie', cookies)

      const response2 = await request(app)
        .get('/api/members/session')
        .set('Cookie', cookies)

      const response3 = await request(app)
        .get(`/api/members/${testMember.id}`)
        .set('Cookie', cookies)

      expect(response1.status).toBe(200)
      expect(response2.status).toBe(200)
      expect(response3.status).toBe(200)

      expect(response1.body.data.id).toBe(testMember.id)
      expect(response2.body.member.id).toBe(testMember.id)
      expect(response3.body.data.id).toBe(testMember.id)
    })
  })
})
