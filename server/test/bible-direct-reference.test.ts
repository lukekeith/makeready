/** bible-verse-picker D9: a direct-reference hit returns canonical, sliced chapter text. */
import type { Server } from 'node:http'
import express from 'express'
import request from 'supertest'
import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest'

const mockResolveBibleId = vi.fn()
const mockGetChapterVerses = vi.fn()

vi.mock('../src/lib/prisma.js', () => ({ prisma: { searchHistory: { create: vi.fn().mockResolvedValue({}) } } }))
vi.mock('../src/services/bible-metadata.js', () => ({ resolveBibleId: mockResolveBibleId }))
vi.mock('../src/services/bible-chapter.js', () => ({ getChapterVerses: mockGetChapterVerses }))

const { default: searchRoutes } = await import('../src/routes/search.js')

const app = express()
app.use(express.json())
app.use('/api/search', searchRoutes)
const server: Server = await new Promise((resolve) => {
  const s = app.listen(0, '127.0.0.1', () => resolve(s))
})
afterAll(() => {
  server.closeAllConnections()
  server.close()
})

const smart = (body: object) => request(server).post('/api/search/smart').send(body)
const chapter = { verses: [15, 16, 17, 18].map((v) => ({ verse: v, text: `v${v}` })), copyright: 'PD', fumsToken: 't' }

beforeEach(() => {
  vi.clearAllMocks()
  mockResolveBibleId.mockResolvedValue('bib')
  mockGetChapterVerses.mockResolvedValue(chapter)
})

describe('handleDirectReference', () => {
  it('a direct reference returns canonical, sliced chapter text', async () => {
    const res = await smart({ query: 'John 3:16-17', translation: 'ENGKJV', record: false }).expect(200)
    expect(res.body.type).toBe('direct')
    expect(res.body.verses.map((v: any) => v.text)).toEqual(['v16', 'v17'])
    expect(res.body.copyright).toBe('PD')
  })

  it('a single verse returns just that verse, with the chapter fumsToken', async () => {
    const res = await smart({ query: 'John 3:16', translation: 'ENGKJV', record: false }).expect(200)
    expect(res.body.verses).toEqual([{ verse: 16, text: 'v16', reference: 'John 3:16' }])
    expect(res.body.fumsToken).toBe('t')
    expect(res.body.total).toBe(1)
  })

  it('a bare chapter returns the whole chapter', async () => {
    const res = await smart({ query: 'John 3', translation: 'ENGKJV', record: false }).expect(200)
    expect(res.body.verses.map((v: any) => v.verse)).toEqual([15, 16, 17, 18])
  })
})
