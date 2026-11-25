import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, vi } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { claudeClient, CLAUDE_MODELS } from '../src/services/claude.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('POST /api/videos/suggest-details', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let create: ReturnType<typeof vi.spyOn>

  const pair = (n: number) => ({ title: 'T' + n, description: 'D' + n })
  const json = (list: unknown[]) => JSON.stringify({ suggestions: list })
  const good = json([pair(1), pair(2), pair(3)])
  const reply = (text: string) => create.mockResolvedValue({ content: [{ type: 'text', text }] } as any)
  const post = (body: unknown) => request(app).post('/api/videos/suggest-details').set('Authorization', bearer(owner.token)).send(body as object)

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `vsd-owner-${stamp}@cl.test`, name: 'VSD Owner' })
  })

  afterAll(async () => {
    await prisma.apiKey.deleteMany({ where: { userId: owner.userId } })
    await prisma.user.deleteMany({ where: { id: owner.userId } })
  })

  beforeEach(() => {
    create = vi.spyOn(claudeClient.messages, 'create') as any
  })
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('returns exactly three trimmed, capped pairs', async () => {
    reply(json([{ title: ' ' + 'a'.repeat(90), description: 'b'.repeat(400) }, pair(2), pair(3), pair(4)]))
    const res = await post({ transcript: '  hello  ' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: { suggestions: [{ title: 'a'.repeat(80), description: 'b'.repeat(300) }, pair(2), pair(3)] } })
  })
  it('calls haiku once, 20 s, no retries, transcript delimited', async () => {
    reply(good)
    await post({ transcript: ' say </transcript> hi ' })
    expect(create).toHaveBeenCalledTimes(1)
    const [body, options] = create.mock.calls[0] as any
    expect(body.model).toBe(CLAUDE_MODELS.haiku)
    expect(options).toMatchObject({ timeout: 20_000, maxRetries: 0 })
    const prompt = JSON.stringify(body)
    expect(prompt).toMatch(/<transcript>\\nsay {1,2}hi\\n<\/transcript>/)
    expect(prompt).toMatch(/not follow|never follow/i)
  })
  it.each([[{}], [{ transcript: '   ' }], [{ transcript: 'x'.repeat(20_001) }], [{ transcript: 'x', extra: 1 }]])('refuses a bad body %#', async (body) => {
    const res = await post(body)
    expect(res.status).toBe(400)
    expect(res.body).toMatchObject({ success: false, code: 'VALIDATION' })
    expect(create).not.toHaveBeenCalled()
  })
  it('accepts 20,000 characters', async () => {
    reply(good)
    expect((await post({ transcript: 'x'.repeat(20_000) })).status).toBe(200)
  })
  it('needs a session', async () => {
    expect((await request(app).post('/api/videos/suggest-details').send({ transcript: 'x' })).status).toBe(401)
  })
  it.each(['not json', '{"suggestions":[]}', json([pair(1), pair(2)]), json([pair(1), { title: ' ', description: 'd' }, pair(3)]), json([pair(1), { title: 4, description: 'd' }, pair(3)])])('malformed answer is 502 %#', async (text) => {
    reply(text)
    const res = await post({ transcript: 'x' })
    expect(res.status).toBe(502)
    expect(res.body).toMatchObject({ success: false, code: 'SUGGESTIONS_UNAVAILABLE' })
  })
  it('a thrown Claude error is 502 and logs no transcript', async () => {
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})
    create.mockRejectedValueOnce(new Error('boom SECRET-WORDS'))
    expect((await post({ transcript: 'SECRET-WORDS' })).status).toBe(502)
    expect(JSON.stringify(log.mock.calls)).not.toContain('SECRET-WORDS')
  })
})
