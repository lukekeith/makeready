import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const getVideo = vi.hoisted(() => vi.fn())
vi.mock('../cloudflare.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../cloudflare.js')>()),
  getVideo,
}))

const { prisma } = await import('../../lib/prisma.js')
const { createVideo, createVideoBody } = await import('../videos.service.js')
const { assertDocumentMediaAllowed } = await import('../content-media.service.js')

describe('videos.service createVideo', () => {
  const stamp = Date.now()
  let n = 0
  const uid = () => `vc-${stamp}-${++n}`
  let userId: string
  let otherUserId: string
  let orgOwnerId: string
  let orgId: string

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-vc-a-${stamp}`, email: `vc-a-${stamp}@cl.test`, name: 'VC A' } })).id
    otherUserId = (await prisma.user.create({ data: { googleId: `gid-vc-b-${stamp}`, email: `vc-b-${stamp}@cl.test`, name: 'VC B' } })).id
    orgOwnerId = (await prisma.user.create({ data: { googleId: `gid-vc-c-${stamp}`, email: `vc-c-${stamp}@cl.test`, name: 'VC C' } })).id
    orgId = (await prisma.organization.create({ data: { name: `VC Org ${stamp}`, ownerId: orgOwnerId } })).id
  })

  afterAll(async () => {
    const users = [userId, otherUserId, orgOwnerId]
    await prisma.media.deleteMany({ where: { uploadedBy: { in: users } } })
    await prisma.video.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  beforeEach(() => {
    getVideo.mockReset()
    getVideo.mockResolvedValue({ success: false, error: 'not configured' })
  })

  it('sets transcriptStatus by what the body carries', async () => {
    const a = await createVideo(userId, { cloudflareUid: uid(), transcript: 'hi', transcriptSegments: [{ text: 'hi', startMs: 0, endMs: 400 }], source: 'recording' })
    expect(a.video).toMatchObject({ transcriptStatus: 'ready', transcriptSource: 'on_device', transcript: 'hi' })
    const b = await createVideo(userId, { cloudflareUid: uid(), source: 'import' })
    expect(b.video).toMatchObject({ transcriptStatus: 'pending', transcriptSource: null })
    const c = await createVideo(userId, { cloudflareUid: uid() })
    expect(c.video.transcriptStatus).toBe('none')
  })

  it.each([
    [{ cloudflareUid: 'x', extra: 1 }],
    [{ cloudflareUid: 'x', transcript: 'a'.repeat(20_001) }],
    [{ cloudflareUid: 'x', transcriptSegments: Array.from({ length: 2001 }, () => ({ text: 'a', startMs: 0, endMs: 1 })) }],
    [{ cloudflareUid: 'x', transcriptSegments: [{ text: 'a'.repeat(1001), startMs: 0, endMs: 1 }] }],
    [{ cloudflareUid: 'x', transcriptSegments: [{ text: 'a', startMs: 5, endMs: 1 }] }],
  ])('rejects %j', (body) => {
    expect(createVideoBody.safeParse(body).success).toBe(false)
  })

  it('is idempotent for its owner', async () => {
    const u = uid()
    const first = await createVideo(userId, { cloudflareUid: u })
    expect(first.status).toBe(201)
    const again = await createVideo(userId, { cloudflareUid: u })
    expect(again).toMatchObject({ status: 200, video: { id: first.video.id } })
    await expect(createVideo(otherUserId, { cloudflareUid: u })).rejects.toMatchObject({ status: 409 })
  })

  it('catches P2002 on a concurrent duplicate', async () => {
    const u = uid()
    const [a, b] = await Promise.all([createVideo(userId, { cloudflareUid: u }), createVideo(userId, { cloudflareUid: u })])
    expect(a.video.id).toBe(b.video.id)
    expect([a.status, b.status].sort()).toEqual([200, 201])
    expect(await prisma.video.count({ where: { cloudflareUid: u } })).toBe(1)
  })

  it('refuses a Stream upload minted for another user', async () => {
    getVideo.mockResolvedValue({ success: true, video: { status: { state: 'queued' }, meta: { userId: otherUserId } } })
    await expect(createVideo(userId, { cloudflareUid: uid() })).rejects.toMatchObject({ status: 403 })
  })

  it('creates a Media row per video before returning', async () => {
    const one = await createVideo(orgOwnerId, { cloudflareUid: uid(), source: 'recording' })
    const two = await createVideo(orgOwnerId, { cloudflareUid: uid(), source: 'recording' })
    expect(await prisma.media.count({ where: { videoId: one.video.id } })).toBe(1)
    expect(await prisma.media.count({ where: { videoId: two.video.id } })).toBe(1)
    await expect(assertDocumentMediaAllowed(prisma, orgOwnerId, { videoIds: [two.video.id], mediaIds: [] })).resolves.not.toThrow()
  })

  it('creates the Video without a Media row when the caller has no org', async () => {
    const r = await createVideo(userId, { cloudflareUid: uid() })
    expect(await prisma.media.count({ where: { videoId: r.video.id } })).toBe(0)
  })
})
