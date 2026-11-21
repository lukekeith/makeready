import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const download = vi.hoisted(() => vi.fn(async (_key: string) => Buffer.alloc(5)))
vi.mock('../storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../storage.js')>()),
  downloadObject: download,
}))

const { prisma } = await import('../../lib/prisma.js')
const { transcribeMemo, createGroqClient } = await import('../transcription.service.js')

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
