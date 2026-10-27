import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('../../lib/prisma.js', () => ({ prisma: {}, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  findManageableGroup: vi.fn(),
}))
vi.mock('../../services/group-history.js', () => ({ getGroupHistory: vi.fn() }))

import { findManageableGroup } from '../../services/permission.js'
import { getGroupHistory } from '../../services/group-history.js'
import groupsRoutes from '../groups.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupsRoutes)
  return a
}

const EVENT = { id: 'event:e1', occurredAt: '2026-10-22T13:00:00.000Z', kind: 'event_held', text: 'Held event at Corner Bakery', highlight: 'event at Corner Bakery' }

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(findManageableGroup).mockResolvedValue({ id: 'g1', organizationId: 'org1' })
  vi.mocked(getGroupHistory).mockResolvedValue([EVENT] as never)
})

describe('GET /api/groups/:id/history (D15, SC4)', () => {
  it('returns { success, events } with limit 20 by default', async () => {
    const res = await request(app()).get('/api/groups/g1/history')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, events: [EVENT] })
    expect(findManageableGroup).toHaveBeenCalledWith('u1', 'g1')
    expect(getGroupHistory).toHaveBeenCalledWith('g1', 20)
  })

  it('passes limit through', async () => {
    await request(app()).get('/api/groups/g1/history?limit=5')
    expect(getGroupHistory).toHaveBeenCalledWith('g1', 5)
  })

  it.each(['0', '51', 'abc', '2.5', ''])('400s limit=%s before reading anything', async (limit) => {
    const res = await request(app()).get(`/api/groups/g1/history?limit=${limit}`)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(getGroupHistory).not.toHaveBeenCalled()
  })

  it('404s a group outside the caller’s manage scope (or inactive)', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(app()).get('/api/groups/g-other/history')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Group not found' })
    expect(getGroupHistory).not.toHaveBeenCalled()
  })
})
