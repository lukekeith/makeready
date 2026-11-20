import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const headObject = vi.hoisted(() => vi.fn())
const presignPut = vi.hoisted(() => vi.fn(async (key: string) => `https://r2.test/${key}?sig=1`))
vi.mock('../storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../storage.js')>()),
  headObject,
  presignPut,
}))

const { prisma } = await import('../../lib/prisma.js')
const { createMemo, remintUpload, completeMemo, setTranscriptionRunner } = await import('../memos.service.js')

describe('memos.service lifecycle', () => {
  const stamp = Date.now()
  let userId: string
  let otherUserId: string
  const runner = vi.fn()
  let previousRunner: ReturnType<typeof setTranscriptionRunner>

  const body = (patch: Record<string, unknown> = {}) => ({
    title: 'Memo 1', durationMs: 1000, fileSize: 10, recordedAt: '2026-11-20T10:00:00.000Z', waveformPeaks: Array(10).fill(0.5), ...patch,
  })

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-memo-a-${stamp}`, email: `memo-a-${stamp}@cl.test`, name: 'Memo A' } })).id
    otherUserId = (await prisma.user.create({ data: { googleId: `gid-memo-b-${stamp}`, email: `memo-b-${stamp}@cl.test`, name: 'Memo B' } })).id
    previousRunner = setTranscriptionRunner(runner)
  })

  afterAll(async () => {
    setTranscriptionRunner(previousRunner)
    await prisma.voiceMemo.deleteMany({ where: { userId: { in: [userId, otherUserId] } } })
    await prisma.user.deleteMany({ where: { id: { in: [userId, otherUserId] } } })
  })

  beforeEach(() => {
    headObject.mockReset()
    presignPut.mockClear()
    runner.mockClear()
  })

  it('create returns a pending memo and a 15-min PUT ticket; an on-device transcript completes ready', async () => {
    const { memo, upload } = await createMemo(userId, body({ fileSize: 5000 }))
    expect(memo).toMatchObject({ uploadStatus: 'pending', transcriptStatus: 'none', url: null, urlExpiresAt: null, mimeType: 'audio/mp4' })
    expect(presignPut).toHaveBeenCalledWith(`memos/${userId}/${memo.id}.m4a`, 'audio/mp4', 5000, 900)
    expect(upload).toMatchObject({ method: 'PUT', headers: { 'Content-Type': 'audio/mp4', 'Content-Length': '5000' } })
    expect(Date.parse(upload.expiresAt) - Date.now()).toBeGreaterThan(890_000)
    const od = await createMemo(userId, body({ fileSize: 5000, transcript: 'hi', transcriptSegments: [{ text: 'hi', startMs: 0, endMs: 500 }] }))
    headObject.mockResolvedValueOnce({ contentLength: 5000 })  // D10, D33: on-device transcript → ready, nothing started
    expect(await completeMemo(userId, od.memo.id)).toMatchObject({ transcriptStatus: 'ready', transcriptSource: 'on_device', transcript: 'hi' })
    expect(runner).not.toHaveBeenCalled()
  })

  it('complete without a transcript starts the fallback once', async () => {
    const { memo } = await createMemo(userId, body({ fileSize: 5000 }))
    headObject.mockResolvedValueOnce({ contentLength: 5000 })
    expect(await completeMemo(userId, memo.id)).toMatchObject({ uploadStatus: 'ready', transcriptStatus: 'pending' })
    expect(runner).toHaveBeenCalledTimes(1); expect(runner).toHaveBeenCalledWith(memo.id)
    expect(await completeMemo(userId, memo.id)).toMatchObject({ uploadStatus: 'ready' }) // D30: again → same, no HEAD, no run
    expect(headObject).toHaveBeenCalledTimes(1); expect(runner).toHaveBeenCalledTimes(1)
    await expect(completeMemo(otherUserId, memo.id)).rejects.toMatchObject({ status: 404, message: 'Memo not found' })
  })

  it('complete refuses a missing or wrong-size object with 409', async () => {
    const { memo } = await createMemo(userId, body({ fileSize: 5000 }))
    headObject.mockResolvedValueOnce(null)
    await expect(completeMemo(userId, memo.id)).rejects.toMatchObject({ status: 409, message: 'Uploaded file not found' })
    headObject.mockResolvedValueOnce({ contentLength: 4999 })
    await expect(completeMemo(userId, memo.id)).rejects.toMatchObject({ status: 409, message: 'Uploaded file size does not match' })
  })

  it('re-mint answers a pending memo, 409 when ready, 404 for another user', async () => {
    const { memo } = await createMemo(userId, body({ fileSize: 5000 }))
    expect((await remintUpload(userId, memo.id)).headers['Content-Length']).toBe('5000')
    await expect(remintUpload(otherUserId, memo.id)).rejects.toMatchObject({ status: 404, message: 'Memo not found' })
    headObject.mockResolvedValueOnce({ contentLength: 5000 }); await completeMemo(userId, memo.id)
    await expect(remintUpload(userId, memo.id)).rejects.toMatchObject({ status: 409, message: 'Memo already uploaded' })
  })
})
