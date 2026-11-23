import { randomUUID } from 'node:crypto'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const download = vi.hoisted(() => vi.fn(async (_key: string) => Buffer.alloc(5)))
vi.mock('../storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../storage.js')>()),
  downloadObject: download,
}))

vi.hoisted(() => { process.env.CLOUDFLARE_ACCOUNT_ID = 'acct'; process.env.CLOUDFLARE_API_TOKEN = 'tok' })

const { prisma } = await import('../../lib/prisma.js')
const { transcribeMemo, transcribeVideo, createGroqClient } = await import('../transcription.service.js')
const { videoIdsDueForTranscript } = await import('../videos.service.js')
const { createDownload, getDownload, deleteDownload } = await import('../cloudflare.js')

describe('transcription.service', () => {
  const stamp = Date.now()
  let userId: string
  let memo: { id: string }
  const okGroq = { transcribe: vi.fn(async () => ({ text: 'ok', segments: [] })) }

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-transcribe-${stamp}`, email: `transcribe-${stamp}@cl.test`, name: 'Transcribe Owner' } })).id
    vi.stubEnv('GROQ_API_KEY', 'k')
  })

  afterAll(async () => {
    vi.unstubAllEnvs()
    await prisma.voiceMemo.deleteMany({ where: { userId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  beforeEach(async () => {
    download.mockClear()
    await prisma.voiceMemo.deleteMany({ where: { userId } })
    memo = await prisma.voiceMemo.create({
      data: { userId, title: 'T', key: `memos/${userId}/x.m4a`, uploadStatus: 'ready', transcriptStatus: 'pending', recordedAt: new Date() },
    })
  })

  it('writes the Groq transcript and segments', async () => {
    const groq = { transcribe: vi.fn(async () => ({ text: ' hello world ', segments: [{ text: 'hello world', startMs: 0, endMs: 1200 }] })) }
    const splitAudio = vi.fn()
    expect(await transcribeMemo(memo.id, { groq, splitAudio })).toBe('ready')
    expect(splitAudio).not.toHaveBeenCalled()
    expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toMatchObject({ transcript: 'hello world',
      transcriptSegments: [{ text: 'hello world', startMs: 0, endMs: 1200 }], transcriptStatus: 'ready', transcriptSource: 'server', transcriptClaimedAt: null })
  })

  it('chunks over the cap and offsets their segments', async () => {
    download.mockResolvedValueOnce(Buffer.alloc(25))
    const splitAudio = vi.fn(async () => [{ audio: Buffer.alloc(12), offsetMs: 0 }, { audio: Buffer.alloc(13), offsetMs: 60000 }])
    const groq = { transcribe: vi.fn().mockResolvedValueOnce({ text: 'a', segments: [{ text: 'a', startMs: 0, endMs: 2000 }] })
                                     .mockResolvedValueOnce({ text: 'b', segments: [{ text: 'b', startMs: 0, endMs: 2000 }] }) }
    await transcribeMemo(memo.id, { groq, splitAudio, env: { ...process.env, GROQ_API_KEY: 'k', GROQ_MAX_UPLOAD_BYTES: '10' } })
    expect(splitAudio).toHaveBeenCalledWith(expect.any(Buffer), 10)
    const row = await prisma.voiceMemo.findUnique({ where: { id: memo.id } })
    expect(row!.transcript).toBe('a b')
    expect(row!.transcriptSegments).toEqual([{ text: 'a', startMs: 0, endMs: 2000 }, { text: 'b', startMs: 60000, endMs: 62000 }])
  })

  it('a missing key fails without counting an attempt', async () => {
    const groq = { transcribe: vi.fn() }
    expect(await transcribeMemo(memo.id, { groq, env: { ...process.env, GROQ_API_KEY: '' } })).toBe('no-key')
    expect(groq.transcribe).not.toHaveBeenCalled()
    expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toMatchObject({ transcriptStatus: 'failed', transcriptAttempts: 0 })
  })

  it('a Groq error counts an attempt and fails', async () => {
    const groq = { transcribe: vi.fn(async () => { throw new Error('502') }) }
    expect(await transcribeMemo(memo.id, { groq })).toBe('failed')
    expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toMatchObject({ transcriptStatus: 'failed', transcriptAttempts: 1, transcriptClaimedAt: null })
  })

  it('a fresh claim blocks a second run; a stale one does not', async () => {
    await prisma.voiceMemo.update({ where: { id: memo.id }, data: { transcriptClaimedAt: new Date(Date.now() - 60_000) } })
    expect(await transcribeMemo(memo.id, { groq: okGroq })).toBe('not-claimed')
    await prisma.voiceMemo.update({ where: { id: memo.id }, data: { transcriptClaimedAt: new Date(Date.now() - 11 * 60_000) } })
    expect(await transcribeMemo(memo.id, { groq: okGroq })).toBe('ready')
  })

  it('createGroqClient converts seconds to ms', async () => {
    const f = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(new Response('{"text":"hi","segments":[{"text":"hi","start":1.25,"end":2.5}]}'))
    expect((await createGroqClient('k').transcribe(Buffer.from('x'), 'm.m4a')).segments).toEqual([{ text: 'hi', startMs: 1250, endMs: 2500 }])
    expect(f.mock.calls[0][0]).toBe('https://api.groq.com/openai/v1/audio/transcriptions')
    f.mockRestore()
  })
})

describe('transcribeVideo', () => {
  const stamp = Date.now()
  let userId: string

  const seedVideo = async (owner: string, patch: Record<string, unknown> = {}) => {
    const id = randomUUID()
    await prisma.video.create({ data: { id, userId: owner, cloudflareUid: `uid-${id}`, playbackUrl: '', status: 'ready', transcriptStatus: 'pending', ...patch } })
    return id
  }
  const fakeGroq = (text: string, segments: { text: string; startMs: number; endMs: number }[]) => ({ transcribe: vi.fn(async () => ({ text, segments })) })
  const readyStream = () => ({
    getDownload: vi.fn().mockResolvedValue({ status: 'ready', url: 'https://dl/x.mp4' }), createDownload: vi.fn(), deleteDownload: vi.fn(),
  })

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-tvideo-${stamp}`, email: `tvideo-${stamp}@cl.test`, name: 'Video Transcribe' } })).id
  })
  afterAll(async () => {
    await prisma.video.deleteMany({ where: { userId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })
  beforeEach(async () => { await prisma.video.deleteMany({ where: { userId } }) })

  it('transcribes from the Stream download', async () => {
    const id = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending' })
    const stream = { getDownload: vi.fn().mockResolvedValue({ status: 'ready', url: 'https://dl/x.mp4' }), createDownload: vi.fn(), deleteDownload: vi.fn() }
    const out = await transcribeVideo(id, { env: { GROQ_API_KEY: 'k' }, stream, download: async () => Buffer.from('mp4'), extractAudio: async () => Buffer.from('m4a'), groq: fakeGroq('hello', [{ text: 'hello', startMs: 0, endMs: 500 }]) })
    expect(out).toBe('ready')
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ transcript: 'hello', transcriptStatus: 'ready', transcriptSource: 'server', transcriptClaimedAt: null })
    expect(stream.deleteDownload).toHaveBeenCalled()
  })

  it('waits for an in-progress download', async () => {
    const id = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending' })
    const stream = { getDownload: vi.fn().mockResolvedValue(null), createDownload: vi.fn().mockResolvedValue({ status: 'inprogress' }), deleteDownload: vi.fn() }
    expect(await transcribeVideo(id, { env: { GROQ_API_KEY: 'k' }, stream })).toBe('in-progress')
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ transcriptAttempts: 0, transcriptClaimedAt: null, transcriptStatus: 'pending' })
  })

  it('gives up after 3 attempts', async () => {
    const id = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending' })
    const deps = { env: { GROQ_API_KEY: 'k' }, stream: readyStream(), download: async () => { throw new Error('boom') } }
    for (let i = 0; i < 3; i++) expect(await transcribeVideo(id, deps)).toBe('failed')
    expect(await transcribeVideo(id, deps)).toBe('not-claimed')
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ transcriptAttempts: 3, transcriptStatus: 'failed' })
  })

  it('claims only ready videos, removed ones included', async () => {
    const pendingStream = await seedVideo(userId, { status: 'pending', transcriptStatus: 'pending' })
    const removed = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending', libraryRemovedAt: new Date() })
    const due = await videoIdsDueForTranscript()
    expect(due).toContain(removed)
    expect(due).not.toContain(pendingStream)
    expect(await transcribeVideo(pendingStream, { env: { GROQ_API_KEY: 'k' }, stream: readyStream() })).toBe('not-claimed')
  })

  it('a download that is not ready after create waits, and with no key does nothing', async () => {
    const id = await seedVideo(userId)
    const stream = readyStream()
    expect(await transcribeVideo(id, { env: { GROQ_API_KEY: '' }, stream })).toBe('no-key')
    expect(stream.getDownload).not.toHaveBeenCalled()
  })

  it('the Stream downloads client calls the downloads endpoint and reads result.default', async () => {
    const f = vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(new Response(JSON.stringify({ success: true, result: { default: { status: 'ready', url: 'https://dl/a.mp4' } } })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ success: true, result: {} })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ success: true, result: 'ok' })))
    expect(await getDownload('u1')).toEqual({ status: 'ready', url: 'https://dl/a.mp4' })
    expect(await getDownload('u1')).toBeNull()
    await deleteDownload('u1')
    expect(String(f.mock.calls[0][0])).toMatch(/\/stream\/u1\/downloads$/)
    expect((f.mock.calls[2][1] as RequestInit).method).toBe('DELETE')
    expect(typeof createDownload).toBe('function')
    f.mockRestore()
  })
})
