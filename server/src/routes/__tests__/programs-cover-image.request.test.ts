/**
 * ui2-programs D11 (SC3, SC7): POST /api/programs/:id/cover-image takes the group route's body —
 * the rendered cover plus an optional original and framing — and returns them top-level.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  studyProgram: { findFirst: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
}))
const saveCover = vi.hoisted(() => vi.fn())
const captureToLibrary = vi.hoisted(() => vi.fn())
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  programManageFilter: vi.fn().mockResolvedValue({ organizationId: 'o1' }),
}))
vi.mock('../../services/group-cover.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/group-cover.js')>()),
  saveCover,
}))
vi.mock('../../services/media-library.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-library.js')>()),
  captureToLibrary,
}))
vi.mock('../../services/media-metadata.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-metadata.js')>()),
  extractImageMetadata: vi
    .fn()
    .mockResolvedValue({ width: 1, height: 1, aspectRatio: 1, dominantColor: null, fileHash: 'h', exifData: null }),
}))

import programsRoutes from '../programs.js'

function app() {
  const a = express()
  a.use(express.json({ limit: '10mb' }))
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key', isAuthenticated: () => true })
    next()
  })
  a.use('/api', programsRoutes)
  return a
}

const framing = { scale: 1.5, rotation: 0, offsetX: 0.1, offsetY: -0.1 }

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.studyProgram.findFirst.mockResolvedValue({
    id: 'p1',
    name: 'Foundations',
    organizationId: 'o1',
    coverOriginalUrl: 'https://img.test/programs/old-original.jpeg',
  })
  prismaMock.studyProgram.findUnique.mockResolvedValue({ id: 'p1', creator: { name: 'L' }, leader: null })
  saveCover.mockResolvedValue({
    coverImageUrl: 'https://img.test/programs/program-p1-1.jpeg',
    coverOriginalUrl: 'https://img.test/programs/program-p1-1-original.jpeg',
    coverFraming: { ...framing, flipped: false, quarterTurns: 0 },
    renderedBuffer: Buffer.from('x'),
    renderedSize: 1,
    isNewImage: true,
  })
})

describe('POST /api/programs/:id/cover-image (D11)', () => {
  it('saves the rendered cover, original and framing as a program cover and returns them top-level', async () => {
    const res = await request(app())
      .post('/api/programs/p1/cover-image')
      .send({ imageData: 'AAAA', contentType: 'image/jpeg', originalData: 'BBBB', framing })
    expect(res.status).toBe(200)
    expect(saveCover).toHaveBeenCalledWith(
      { kind: 'program', id: 'p1', coverOriginalUrl: 'https://img.test/programs/old-original.jpeg' },
      expect.objectContaining({ imageData: 'AAAA', originalData: 'BBBB' }),
    )
    expect(res.body).toMatchObject({
      success: true,
      coverImageUrl: 'https://img.test/programs/program-p1-1.jpeg',
      coverOriginalUrl: 'https://img.test/programs/program-p1-1-original.jpeg',
      coverFraming: { scale: 1.5 },
      program: { id: 'p1', creatorName: 'L' },
    })
    expect(captureToLibrary.mock.calls[0][0]).toMatchObject({ organizationId: 'o1', usageType: 'PROGRAM_COVER' })
  })

  it('still takes the legacy body', async () => {
    const res = await request(app()).post('/api/programs/p1/cover-image').send({ imageData: 'AAAA' })
    expect(res.status).toBe(200)
    expect(saveCover.mock.calls[0][1]).toMatchObject({ imageData: 'AAAA', framing: undefined, originalData: undefined })
  })

  it('400s originalData without framing', async () => {
    const res = await request(app()).post('/api/programs/p1/cover-image').send({ imageData: 'AAAA', originalData: 'BBBB' })
    expect(res.status).toBe(400)
    expect(saveCover).not.toHaveBeenCalled()
  })

  it('404s a program the caller cannot manage', async () => {
    prismaMock.studyProgram.findFirst.mockResolvedValue(null)
    expect((await request(app()).post('/api/programs/p1/cover-image').send({ imageData: 'AAAA' })).status).toBe(404)
  })
})
