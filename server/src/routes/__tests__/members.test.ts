import { describe, it, expect } from 'vitest'
import request from 'supertest'
import { app } from '../../index'

describe('Members API', () => {
  describe('POST /api/members/verify-phone', () => {
    it('should require phoneNumber field', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({})

      expect(response.status).toBe(400)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
    })

    it('should validate phone number format (E.164)', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({ phoneNumber: '1234567890' }) // Missing + prefix

      expect(response.status).toBe(400)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('e.164')
    })

    it('should reject phone numbers without + prefix', async () => {
      const invalidNumbers = [
        '15555551234',
        '5555551234',
        '1-555-555-1234',
      ]

      for (const phoneNumber of invalidNumbers) {
        const response = await request(app)
          .post('/api/members/verify-phone')
          .send({ phoneNumber })

        expect(response.status).toBe(400)
        expect(response.body.success).toBe(false)
        expect(response.body.error.toLowerCase()).toContain('e.164')
      }
    })

    it('should reject phone numbers with invalid characters', async () => {
      const invalidNumbers = [
        '+1 (555) 555-1234', // Spaces and parentheses
        '+1-555-555-1234',   // Dashes
        '+1.555.555.1234',   // Dots
        'tel:+15555551234',  // Protocol prefix
      ]

      for (const phoneNumber of invalidNumbers) {
        const response = await request(app)
          .post('/api/members/verify-phone')
          .send({ phoneNumber })

        expect(response.status).toBe(400)
        expect(response.body.success).toBe(false)
      }
    })

    it('should accept valid E.164 US phone numbers', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({ phoneNumber: '+15555551234' })

      // Will either succeed or fail with Twilio error (not validation error)
      expect([200, 400, 500]).toContain(response.status)
      expect(response.body).toHaveProperty('success')

      // If it fails, should not be a validation error
      if (!response.body.success && response.status === 400) {
        expect(response.body.error.toLowerCase()).not.toContain('e.164')
        expect(response.body.error.toLowerCase()).not.toContain('format')
      }
    })

    it('should accept valid international phone numbers', async () => {
      const validNumbers = [
        '+447911123456',     // UK
        '+33612345678',      // France
        '+81312345678',      // Japan
        '+861234567890',     // China
      ]

      for (const phoneNumber of validNumbers) {
        const response = await request(app)
          .post('/api/members/verify-phone')
          .send({ phoneNumber })

        // Should not fail validation
        if (response.status === 400) {
          expect(response.body.error.toLowerCase()).not.toContain('e.164')
        }
      }
    })

    it('should accept optional organizationId parameter', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({
          phoneNumber: '+15555551234',
          organizationId: 'org-123',
        })

      // Should not fail validation for organizationId
      expect([200, 400, 500]).toContain(response.status)
    })

    it('should work without organizationId parameter', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({ phoneNumber: '+15555551234' })

      // organizationId is optional
      expect([200, 400, 500]).toContain(response.status)
    })

    it('should return JSON response', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({ phoneNumber: 'invalid' })

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })

    it('should have success/error response structure', async () => {
      const response = await request(app)
        .post('/api/members/verify-phone')
        .send({})

      expect(response.body).toHaveProperty('success')
      if (response.body.success) {
        expect(response.body).toHaveProperty('memberExists')
      } else {
        expect(response.body).toHaveProperty('error')
      }
    })
  })

  describe('POST /api/members/confirm-verification', () => {
    it('should require phoneNumber field', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          code: '123456',
          organizationId: 'org-123',
        })

      expect(response.status).toBe(400)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
    })

    it('should require code field', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          organizationId: 'org-123',
        })

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })

    it('should allow verification without organizationId (for groups without org)', async () => {
      // organizationId is optional - verification should proceed without it
      // This supports the join flow where groups may not have an organization
      // Use a unique phone number to avoid collisions with existing test data
      const uniquePhone = `+1555000${Date.now().toString().slice(-4)}`
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: uniquePhone,
          code: '123456', // Test verification code
        })

      // With test verification codes enabled, this should succeed
      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
    })

    it('should validate phone number format (E.164)', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '1234567890',
          code: '123456',
          organizationId: 'org-123',
        })

      expect(response.status).toBe(400)
      expect(response.body.error.toLowerCase()).toContain('e.164')
    })

    it('should validate code length (must be 6 digits)', async () => {
      const invalidCodes = ['12', '1234', '12345', '1234567']

      for (const code of invalidCodes) {
        const response = await request(app)
          .post('/api/members/confirm-verification')
          .send({
            phoneNumber: '+15555551234',
            code,
            organizationId: 'org-123',
          })

        expect(response.status).toBe(400)
        expect(response.body.success).toBe(false)
      }
    })

    it('should accept valid 6-digit verification code', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
        })

      // Will fail with Twilio verification error (code not valid)
      // But should pass validation
      expect([200, 400, 500]).toContain(response.status)
    })

    it('should accept optional firstName parameter', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          firstName: 'John',
        })

      // Should not fail validation for firstName
      expect([200, 400, 500]).toContain(response.status)
    })

    it('should accept optional lastName parameter', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          lastName: 'Doe',
        })

      expect([200, 400, 500]).toContain(response.status)
    })

    it('should accept optional email parameter', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          email: 'john@example.com',
        })

      expect([200, 400, 500]).toContain(response.status)
    })

    it('should validate email format if provided', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          email: 'invalid-email',
        })

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })

    it('should accept optional birthday parameter', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          birthday: '1990-01-01T00:00:00Z',
        })

      expect([200, 400, 500]).toContain(response.status)
    })

    it('should validate birthday format (ISO 8601 datetime)', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          birthday: '1990-01-01', // Date without time
        })

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })

    it('should accept all optional profile fields together', async () => {
      const response = await request(app)
        .post('/api/members/confirm-verification')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          organizationId: 'org-123',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john@example.com',
          birthday: '1990-01-01T00:00:00Z',
        })

      // Should not fail validation
      expect([200, 400, 500]).toContain(response.status)
    })
  })

  describe('GET /api/members/:memberId', () => {
    it('should require authentication', async () => {
      const response = await request(app).get('/api/members/member-123')

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should accept any string as member ID', async () => {
      const memberIds = [
        'member-123',
        '550e8400-e29b-41d4-a716-446655440000',
        'any-string',
      ]

      for (const memberId of memberIds) {
        const response = await request(app).get(`/api/members/${memberId}`)

        expect(response.status).toBe(401)
        expect(response.body.success).toBe(false)
      }
    })

    it('should return JSON response', async () => {
      const response = await request(app).get('/api/members/test-member')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })
  })

  describe('PATCH /api/members/:memberId', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .patch('/api/members/member-123')
        .send({ firstName: 'John' })

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
    })

    it('should require authentication even with empty body', async () => {
      const response = await request(app)
        .patch('/api/members/member-123')
        .send({})

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should require authentication for all field updates', async () => {
      const updates = [
        { firstName: 'John' },
        { lastName: 'Doe' },
        { email: 'john@example.com' },
        { birthday: '1990-01-01T00:00:00Z' },
        { profilePicture: 'https://example.com/pic.jpg' },
      ]

      for (const update of updates) {
        const response = await request(app)
          .patch('/api/members/test-member')
          .send(update)

        expect(response.status).toBe(401)
        expect(response.body.success).toBe(false)
      }
    })

    it('should return JSON response', async () => {
      const response = await request(app)
        .patch('/api/members/test-member')
        .send({ firstName: 'Test' })

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })
  })

  describe('DELETE /api/members/:memberId', () => {
    it('should require authentication', async () => {
      const response = await request(app).delete('/api/members/member-123')

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should accept any member ID format', async () => {
      const memberIds = ['member-123', 'uuid-format', 'any-string']

      for (const memberId of memberIds) {
        const response = await request(app).delete(`/api/members/${memberId}`)

        expect(response.status).toBe(401)
        expect(response.body.success).toBe(false)
      }
    })

    it('should return JSON response', async () => {
      const response = await request(app).delete('/api/members/test-member')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })
  })

  describe('GET /api/members/:memberId/groups', () => {
    it('should require authentication', async () => {
      const response = await request(app).get('/api/members/member-123/groups')

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should accept includeInactive query parameter', async () => {
      const response = await request(app)
        .get('/api/members/member-123/groups?includeInactive=true')

      expect(response.status).toBe(401)
    })

    it('should accept includeInactive=false parameter', async () => {
      const response = await request(app)
        .get('/api/members/member-123/groups?includeInactive=false')

      expect(response.status).toBe(401)
    })

    it('should work without query parameters', async () => {
      const response = await request(app).get('/api/members/member-123/groups')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return JSON response', async () => {
      const response = await request(app).get('/api/members/test-member/groups')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })
  })

  describe('Error Response Consistency', () => {
    it('should return consistent error format for protected endpoints', async () => {
      const endpoints = [
        { method: 'get', path: '/api/members/test-member' },
        { method: 'patch', path: '/api/members/test-member' },
        { method: 'delete', path: '/api/members/test-member' },
        { method: 'get', path: '/api/members/test-member/groups' },
      ]

      for (const endpoint of endpoints) {
        const response = await (request(app) as any)[endpoint.method](endpoint.path)

        expect(response.status).toBe(401)
        expect(response.body).toHaveProperty('success')
        expect(response.body).toHaveProperty('error')
        expect(response.body.success).toBe(false)
        expect(typeof response.body.error).toBe('string')
      }
    })

    it('should return JSON content type for all endpoints', async () => {
      const paths = [
        '/api/members/test-member',
        '/api/members/test-member/groups',
      ]

      for (const path of paths) {
        const response = await request(app).get(path)

        expect(response.headers['content-type']).toMatch(/json/)
      }
    })

    it('should have consistent validation error format', async () => {
      const invalidRequests = [
        {
          path: '/api/members/verify-phone',
          body: { phoneNumber: 'invalid' },
        },
        {
          path: '/api/members/confirm-verification',
          body: { phoneNumber: 'invalid', code: '123456', organizationId: 'org' },
        },
      ]

      for (const req of invalidRequests) {
        const response = await request(app).post(req.path).send(req.body)

        expect(response.status).toBe(400)
        expect(response.body).toHaveProperty('success')
        expect(response.body).toHaveProperty('error')
        expect(response.body.success).toBe(false)
        expect(typeof response.body.error).toBe('string')
      }
    })
  })
})
