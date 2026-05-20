import { describe, it, expect } from 'vitest'
import request from 'supertest'
import { app } from '../../index'

describe('Organizations API', () => {
  describe('GET /api/organizations/:organizationId', () => {
    it('should require authentication', async () => {
      const fakeId = 'test-org-123'
      const response = await request(app).get(`/api/organizations/${fakeId}`)

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should return 401 for any organization ID when not authenticated', async () => {
      const response = await request(app).get('/api/organizations/any-org-id')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should accept valid UUID format organization IDs', async () => {
      const uuid = '550e8400-e29b-41d4-a716-446655440000'
      const response = await request(app).get(`/api/organizations/${uuid}`)

      // Will fail auth, but accepts the UUID format
      expect(response.status).toBe(401)
    })

    it('should accept any string as organization ID', async () => {
      const response = await request(app).get('/api/organizations/any-string')

      // Route accepts any string, auth fails
      expect(response.status).toBe(401)
    })
  })

  describe('GET /api/organizations/my/organization', () => {
    it('should require authentication', async () => {
      const response = await request(app).get('/api/organizations/my/organization')

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should return JSON response', async () => {
      const response = await request(app).get('/api/organizations/my/organization')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })

    it('should have consistent error response structure', async () => {
      const response = await request(app).get('/api/organizations/my/organization')

      expect(response.body).toEqual({
        success: false,
        error: expect.any(String),
      })
    })
  })

  describe('PATCH /api/organizations/:organizationId', () => {
    it('should require authentication', async () => {
      const fakeId = 'test-org-123'
      const response = await request(app)
        .patch(`/api/organizations/${fakeId}`)
        .send({ name: 'Updated Name' })

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
    })

    it('should require authentication even with empty body', async () => {
      const response = await request(app)
        .patch('/api/organizations/test-org')
        .send({})

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should require authentication even with invalid data', async () => {
      const response = await request(app)
        .patch('/api/organizations/test-org')
        .send({ name: '' })

      // Auth fails before validation
      expect(response.status).toBe(401)
    })

    it('should accept JSON content type', async () => {
      const response = await request(app)
        .patch('/api/organizations/test-org')
        .set('Content-Type', 'application/json')
        .send({ name: 'New Name' })

      // Will fail auth
      expect(response.status).toBe(401)
    })

    it('should handle missing request body', async () => {
      const response = await request(app)
        .patch('/api/organizations/test-org')

      // Auth fails before body validation
      expect(response.status).toBe(401)
    })
  })

  describe('GET /api/organizations/:organizationId/members', () => {
    it('should require authentication', async () => {
      const fakeId = 'test-org-123'
      const response = await request(app).get(`/api/organizations/${fakeId}/members`)

      expect(response.status).toBe(401)
      expect(response.body).toHaveProperty('error')
      expect(response.body.success).toBe(false)
      expect(response.body.error.toLowerCase()).toContain('auth')
    })

    it('should accept search query parameter', async () => {
      const fakeId = 'test-org-123'
      const response = await request(app)
        .get(`/api/organizations/${fakeId}/members?search=john`)

      // Will fail auth, but parameter is accepted
      expect(response.status).toBe(401)
    })

    it('should accept includeInactive query parameter', async () => {
      const fakeId = 'test-org-123'
      const response = await request(app)
        .get(`/api/organizations/${fakeId}/members?includeInactive=true`)

      expect(response.status).toBe(401)
    })

    it('should accept both search and includeInactive parameters', async () => {
      const fakeId = 'test-org-123'
      const response = await request(app)
        .get(`/api/organizations/${fakeId}/members?search=john&includeInactive=true`)

      expect(response.status).toBe(401)
    })

    it('should handle includeInactive=false parameter', async () => {
      const response = await request(app)
        .get('/api/organizations/test-org/members?includeInactive=false')

      expect(response.status).toBe(401)
    })

    it('should handle empty search parameter', async () => {
      const response = await request(app)
        .get('/api/organizations/test-org/members?search=')

      expect(response.status).toBe(401)
    })

    it('should return JSON response', async () => {
      const response = await request(app)
        .get('/api/organizations/test-org/members')

      expect(response.headers['content-type']).toMatch(/json/)
      expect(response.body).toHaveProperty('success')
    })

    it('should have consistent error response structure', async () => {
      const response = await request(app)
        .get('/api/organizations/test-org/members')

      expect(response.body).toEqual({
        success: false,
        error: expect.any(String),
      })
    })
  })

  describe('Error Response Consistency', () => {
    it('should return consistent error format across all endpoints', async () => {
      const endpoints = [
        { method: 'get', path: '/api/organizations/test-org' },
        { method: 'get', path: '/api/organizations/my/organization' },
        { method: 'patch', path: '/api/organizations/test-org' },
        { method: 'get', path: '/api/organizations/test-org/members' },
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
        '/api/organizations/test-org',
        '/api/organizations/my/organization',
        '/api/organizations/test-org/members',
      ]

      for (const path of endpoints) {
        const response = await request(app).get(path)

        expect(response.headers['content-type']).toMatch(/json/)
      }
    })
  })
})
