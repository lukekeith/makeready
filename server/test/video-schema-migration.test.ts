/**
 * video-recorder SC1–SC7, SC10: the Video transcript + libraryRemovedAt columns, their defaults and
 * the two indexes, on the test DB.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'

const { prisma } = await import('../src/lib/prisma.js')

const stamp = Date.now()
let userId: string

beforeAll(async () => {
  const user = await prisma.user.create({
    data: { googleId: `gid-vsm-${stamp}`, email: `vsm-${stamp}@test.local`, name: 'Video Schema' },
  })
  userId = user.id
})

afterAll(async () => {
  await prisma.video.deleteMany({ where: { userId } })
  await prisma.user.delete({ where: { id: userId } })
  await prisma.$disconnect()
})

describe('Video transcript and Library columns', () => {
  it('existing rows default to transcriptStatus none and attempts 0', async () => {
    const v = await prisma.video.create({ data: { cloudflareUid: `mig-${stamp}`, playbackUrl: '', userId } })
    expect(v.transcriptStatus).toBe('none')
    expect(v.transcriptAttempts).toBe(0)
    expect(v.transcript).toBeNull()
    expect(v.libraryRemovedAt).toBeNull()
  })

  it('the two indexes exist', async () => {
    const rows = await prisma.$queryRaw<{ indexdef: string }[]>`
      SELECT indexdef FROM pg_indexes WHERE tablename = 'videos'`
    const defs = rows.map((r) => r.indexdef)
    expect(defs.some((d) => d.includes('("userId", "createdAt", id)'))).toBe(true)
    expect(defs.some((d) => d.includes('(status, "createdAt")'))).toBe(true)
  })
})
