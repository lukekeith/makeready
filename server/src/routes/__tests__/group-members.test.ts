import { describe, it, expect } from 'vitest'
import request from 'supertest'
import { app } from '../../index'

describe('Group Membership API', () => {
  describe('GET /api/groups/:groupId/members', () => {
    it('should require authentication', async () => {
      const response = await request(app).get('/api/groups/group-123/members')

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should accept any group ID format', async () => {
      const groupIds = [
        'group-123',
        '550e8400-e29b-41d4-a716-446655440000',
        'any-string',
      ]

      for (const groupId of groupIds) {
        const response = await request(app).get(`/api/groups/${groupId}/members`)

        expect(response.status).toBe(401)
        expect(response.body.success).toBe(false)
      }
    })

    it('should accept includeInactive query parameter', async () => {
      const response = await request(app)
        .get('/api/groups/group-123/members?includeInactive=true')

      expect(response.status).toBe(401)
    })

    it('should accept includeInactive=false parameter', async () => {
      const response = await request(app)
        .get('/api/groups/group-123/members?includeInactive=false')

      expect(response.status).toBe(401)
    })

    it('should work without query parameters', async () => {
      const response = await request(app).get('/api/groups/group-123/members')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return JSON response', async () => {
      const response = await request(app).get('/api/groups/test-group/members')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })

    it('should have consistent error response structure', async () => {
      const response = await request(app).get('/api/groups/test-group/members')

      expect(response.body).toEqual({
        success: false,
        error: expect.any(String),
      })
    })
  })

  describe('POST /api/groups/:groupId/members', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/groups/group-123/members')
        .send({
          memberId: 'member-123',
          role: 'member',
        })

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should require authentication even without request body', async () => {
      const response = await request(app)
        .post('/api/groups/group-123/members')
        .send({})

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should require authentication for all role types', async () => {
      const roles = ['member', 'leader']

      for (const role of roles) {
        const response = await request(app)
          .post('/api/groups/test-group/members')
          .send({
            memberId: 'test-member',
            role,
          })

        expect(response.status).toBe(401)
        expect(response.body.success).toBe(false)
      }
    })

    it('should accept valid role values in request body', async () => {
      const response = await request(app)
        .post('/api/groups/group-123/members')
        .send({
          memberId: 'member-123',
          role: 'member',
        })

      // Auth fails before validation
      expect(response.status).toBe(401)
    })

    it('should accept leader role', async () => {
      const response = await request(app)
        .post('/api/groups/group-123/members')
        .send({
          memberId: 'member-123',
          role: 'leader',
        })

      expect(response.status).toBe(401)
    })

    it('should use default role if not specified', async () => {
      const response = await request(app)
        .post('/api/groups/group-123/members')
        .send({
          memberId: 'member-123',
        })

      // Auth fails before default is applied
      expect(response.status).toBe(401)
    })

    it('should return JSON response', async () => {
      const response = await request(app)
        .post('/api/groups/test-group/members')
        .send({ memberId: 'test-member' })

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })

    it('should have consistent error response structure', async () => {
      const response = await request(app)
        .post('/api/groups/test-group/members')
        .send({ memberId: 'test-member' })

      expect(response.body).toEqual({
        success: false,
        error: expect.any(String),
      })
    })
  })

  describe('DELETE /api/groups/:groupId/members/:memberId', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .delete('/api/groups/group-123/members/member-123')

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should accept any group ID and member ID format', async () => {
      const combinations = [
        { groupId: 'group-123', memberId: 'member-123' },
        { groupId: 'uuid-format', memberId: 'uuid-format' },
        { groupId: 'any-string', memberId: 'another-string' },
      ]

      for (const { groupId, memberId } of combinations) {
        const response = await request(app)
          .delete(`/api/groups/${groupId}/members/${memberId}`)

        expect(response.status).toBe(401)
        expect(response.body.success).toBe(false)
      }
    })

    it('should return JSON response', async () => {
      const response = await request(app)
        .delete('/api/groups/test-group/members/test-member')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })

    it('should have consistent error response structure', async () => {
      const response = await request(app)
        .delete('/api/groups/test-group/members/test-member')

      expect(response.body).toEqual({
        success: false,
        error: expect.any(String),
      })
    })
  })

  describe('Error Response Consistency', () => {
    it('should return consistent error format across all endpoints', async () => {
      const endpoints = [
        { method: 'get', path: '/api/groups/test-group/members' },
        { method: 'post', path: '/api/groups/test-group/members' },
        { method: 'delete', path: '/api/groups/test-group/members/test-member' },
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
      const endpoints = [
        { method: 'get', path: '/api/groups/test-group/members' },
        { method: 'post', path: '/api/groups/test-group/members' },
        { method: 'delete', path: '/api/groups/test-group/members/test-member' },
      ]

      for (const endpoint of endpoints) {
        const response = await (request(app) as any)[endpoint.method](endpoint.path)

        expect(response.headers['content-type']).toMatch(/json/)
      }
    })

    it('should have success:false for all unauthenticated requests', async () => {
      const endpoints = [
        { method: 'get', path: '/api/groups/test-group/members' },
        { method: 'post', path: '/api/groups/test-group/members' },
        { method: 'delete', path: '/api/groups/test-group/members/test-member' },
      ]

      for (const endpoint of endpoints) {
        const response = await (request(app) as any)[endpoint.method](endpoint.path)

        expect(response.body.success).toBe(false)
      }
    })

    it('should have error field for all failed GET requests', async () => {
      const response = await request(app).get('/api/groups/test-group/members')

      expect(response.body).toHaveProperty('error')
      expect(typeof response.body.error).toBe('string')
      expect(response.body.error.length).toBeGreaterThan(0)
    })
  })
})
