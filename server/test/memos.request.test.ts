import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const presignPut = vi.hoisted(() => vi.fn(async (key: string) => `https://r2.test/put/${key}`))
const presignGet = vi.hoisted(() => vi.fn(async (key: string) => `https://r2.test/get/${key}`))
const headObject = vi.hoisted(() => vi.fn())
const deleteFromR2 = vi.hoisted(() => vi.fn(async (_key: string) => {}))
vi.mock('../src/services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/storage.js')>()),
  presignPut,
  presignGet,
  headObject,
  deleteFromR2,
}))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')

describe('/api/memos (§Contract)', () => {
  const stamp = Date.now()
  const api = request(app)
  let token: string
  let otherToken: string
  let adminToken: string
  const userIds: string[] = []

  const as = (req: request.Test, t = token) => req.set('Authorization', bearer(t))
  const body = {
    title: 'Memo 1',
    durationMs: 1000,
    fileSize: 5000,
    recordedAt: '2026-11-10T10:00:00.000Z',
    waveformPeaks: Array.from({ length: 10 }, () => 0.5),
  }
  const post = (b: Record<string, unknown>, t = token) => as(request(app).post('/api/memos'), t).send(b)
  const createReadyMemo = async (t: string) => {
    const { body: created } = await post(body, t)
    headObject.mockResolvedValueOnce({ contentLength: body.fileSize })
    await as(api.patch(`/api/memos/${created.memo.id}/complete`), t).send({})
    return created.memo.id as string
  }

  beforeAll(async () => {
    const [a, b, c] = await Promise.all([
      createUserWithApiKey({ email: `mreq-a-${stamp}@t.test`, name: 'Req A' }),
      createUserWithApiKey({ email: `mreq-b-${stamp}@t.test`, name: 'Req B' }),
      createUserWithApiKey({ email: `mreq-c-${stamp}@t.test`, name: 'Req C', isSuperAdmin: true }),
    ])
    token = a.token; otherToken = b.token; adminToken = c.token
    userIds.push(a.userId, b.userId, c.userId)
  })

  beforeEach(async () => {
    headObject.mockReset(); deleteFromR2.mockClear()
    await prisma.voiceMemo.deleteMany({ where: { userId: { in: userIds } } })
  })

  afterAll(async () => {
    await prisma.voiceMemo.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  it('POST /api/memos creates and returns an upload ticket', async () => {
    const res = await post(body)
    expect(res.status).toBe(201)
    expect(res.body.memo).toMatchObject({ title: 'Memo 1', uploadStatus: 'pending', url: null, urlExpiresAt: null })
    expect(res.body.upload).toMatchObject({ method: 'PUT', headers: { 'Content-Type': 'audio/mp4', 'Content-Length': String(body.fileSize) } })
  })

  it('POST /api/memos refuses an unknown key and bad peaks with 400', async () => {
    expect((await post({ ...body, color: 'red' })).status).toBe(400)
    expect((await post({ ...body, waveformPeaks: [0.1] })).status).toBe(400)
    expect((await post({ ...body, fileSize: 104_857_601 })).status).toBe(400)
    expect((await request(app).post('/api/memos').send(body)).status).toBe(401)
  })

  it('complete, re-mint and complete-again follow D13, D29, D30', async () => {
    const { body: created } = await post(body); const id = created.memo.id
    expect((await as(api.post(`/api/memos/${id}/upload`)).send({})).status).toBe(200)
    headObject.mockResolvedValueOnce(null)
    expect((await as(api.patch(`/api/memos/${id}/complete`)).send({})).status).toBe(409)
    headObject.mockResolvedValueOnce({ contentLength: body.fileSize })
    const done = await as(api.patch(`/api/memos/${id}/complete`)).send({})
    expect(done.status).toBe(200); expect(done.body.memo).toMatchObject({ uploadStatus: 'ready', transcriptStatus: 'pending' })
    const again = await as(api.patch(`/api/memos/${id}/complete`)).send({})
    expect(again.status).toBe(200); expect(again.body.memo).toEqual(done.body.memo)
    expect((await as(api.post(`/api/memos/${id}/upload`)).send({})).status).toBe(409)
    expect((await as(api.patch(`/api/memos/${id}/complete`)).send({ x: 1 })).status).toBe(400)
  })

  it('list, detail, rename and delete answer per §Contract; another user gets 404', async () => {
    const id = await createReadyMemo(token)
    const list = await as(api.get('/api/memos?q=memo&limit=10'))
    expect(list.status).toBe(200); expect(list.body.total).toBe(1); expect(list.body.memos[0]).toHaveProperty('transcriptPreview')
    expect((await as(api.get('/api/memos?limit=0'))).status).toBe(400)
    presignGet.mockResolvedValueOnce('https://signed.test/get')
    const detail = await as(api.get(`/api/memos/${id}`))
    expect(detail.body.memo.url).toBe('https://signed.test/get'); expect(detail.body.memo.urlExpiresAt).toEqual(expect.any(String))
    expect((await as(api.get(`/api/memos/${id}`), otherToken)).status).toBe(404)
    expect((await as(api.patch(`/api/memos/${id}`)).send({ title: 'x', transcript: 'y' })).status).toBe(400)
    const renamed = await as(api.patch(`/api/memos/${id}`)).send({ title: ' Renamed ' })
    expect(renamed.body.memo.title).toBe('Renamed')
    expect((await as(api.delete(`/api/memos/${id}`))).status).toBe(204)
    expect((await as(api.get('/api/memos'))).body.total).toBe(0)
  })

  it('user hard-delete purges memo objects first', async () => {
    const doomed = await createUserWithApiKey({ email: `doomed-${stamp}@t.test`, name: 'Doomed' })
    userIds.push(doomed.userId)
    const id = await createReadyMemo(doomed.token)
    const key = (await prisma.voiceMemo.findUnique({ where: { id } }))!.key
    expect((await as(api.delete(`/api/users/${doomed.userId}`), adminToken)).status).toBe(200)
    expect(deleteFromR2).toHaveBeenCalledWith(key)
    expect(await prisma.voiceMemo.count({ where: { id } })).toBe(0)
  })
})
