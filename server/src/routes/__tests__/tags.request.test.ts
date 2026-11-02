import express from 'express'
import request from 'supertest'
import { describe, expect, it, vi } from 'vitest'

const listTagCategories = vi.hoisted(() => vi.fn())
vi.mock('../../services/tag-categories.js', () => ({ listTagCategories }))

import tagsRoutes from '../tags.js'

function app(user?: Record<string, unknown>) {
  const a = express()
  a.use((req, _res, next) => {
    if (user) Object.assign(req, { user, apiKeyId: 'test-key', isAuthenticated: () => true })
    else Object.assign(req, { isAuthenticated: () => false })
    next()
  })
  a.use('/api/tags', tagsRoutes)
  return a
}

describe('GET /api/tags/categories (tag-categories §Contract)', () => {
  it('401 without a session', async () => {
    await request(app()).get('/api/tags/categories').expect(401)
    expect(listTagCategories).not.toHaveBeenCalled()
  })

  it('returns the categories', async () => {
    const categories = [{ key: 'bible-books', name: 'Books of the Bible', position: 1, tags: [{ tag: 'genesis', label: 'Genesis', position: 1 }] }]
    listTagCategories.mockResolvedValueOnce(categories)
    const res = await request(app({ id: 'u1', isActive: true })).get('/api/tags/categories').expect(200)
    expect(res.body).toEqual({ success: true, categories })
  })

  it('500 with { success: false } when the service throws', async () => {
    listTagCategories.mockRejectedValueOnce(new Error('db down'))
    const res = await request(app({ id: 'u1', isActive: true })).get('/api/tags/categories').expect(500)
    expect(res.body).toEqual({ success: false, error: 'Internal server error' })
  })
})
