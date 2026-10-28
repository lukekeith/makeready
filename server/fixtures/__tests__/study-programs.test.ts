import { describe, expect, it, vi } from 'vitest'
import { FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_PROGRAM_IDS, fixtureId } from '../ids.js'
import {
  EMPTY_PROGRAM_ID,
  PRIVATE_PROGRAM_COVER_USAGE_ID,
  PRIVATE_PROGRAM_ID,
  RICH_PROGRAM_FIELDS,
  RICH_PROGRAM_ID,
  full,
} from '../screens/study-program-home.js'

function fakeCtx(photo: { id: string; url: string } | null = null) {
  const prisma = {
    studyProgram: { update: vi.fn(), createMany: vi.fn() },
    media: { findFirst: vi.fn().mockResolvedValue(photo) },
    mediaUsage: { create: vi.fn() },
  }
  const ctx = { prisma, daysAgo: (n: number) => new Date(Date.UTC(2026, 9, 28 - n)) }
  return { prisma, ctx: ctx as unknown as Parameters<typeof full>[0] }
}

describe('study-program-home fixture layer (ui2-programs D17)', () => {
  it('uses fixed program ids clear of base', () => {
    expect(RICH_PROGRAM_ID).toBe(FIXTURE_PROGRAM_IDS.days21)
    expect([PRIVATE_PROGRAM_ID, EMPTY_PROGRAM_ID]).toEqual([fixtureId('program', 3), fixtureId('program', 4)])
  })

  it('fills every setting on Foundations of Faith with a leader other than its creator', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    expect(prisma.studyProgram.update).toHaveBeenCalledWith({ where: { id: RICH_PROGRAM_ID }, data: { ...RICH_PROGRAM_FIELDS } })
    expect(RICH_PROGRAM_FIELDS).toMatchObject({ leaderId: FIXTURE_LEADER_USER_ID, memberDirectoryAccess: 'NAMES_ONLY' })
  })

  it('adds a private program by Nathan and an empty program, both in the fixture org', async () => {
    const { prisma, ctx } = fakeCtx()
    await full(ctx)
    const rows = prisma.studyProgram.createMany.mock.calls[0][0].data
    expect(rows).toEqual([
      expect.objectContaining({ id: PRIVATE_PROGRAM_ID, isPrivate: true, creatorId: FIXTURE_LEADER_USER_ID, organizationId: FIXTURE_ORG_ID }),
      expect.objectContaining({ id: EMPTY_PROGRAM_ID, name: 'Empty Program', days: 0, organizationId: FIXTURE_ORG_ID }),
    ])
    expect(rows[1].coverImageUrl).toBeUndefined()
  })

  it('covers the private program with a fixture library photo, recorded as its PROGRAM_COVER usage', async () => {
    const { prisma, ctx } = fakeCtx({ id: 'm1', url: 'https://r2/library/2-john.jpg' })
    await full(ctx)
    expect(prisma.media.findFirst.mock.calls[0][0].where).toMatchObject({ organizationId: FIXTURE_ORG_ID, source: 'direct' })
    expect(prisma.studyProgram.update).toHaveBeenCalledWith({
      where: { id: PRIVATE_PROGRAM_ID },
      data: { coverImageUrl: 'https://r2/library/2-john.jpg' },
    })
    expect(prisma.mediaUsage.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ id: PRIVATE_PROGRAM_COVER_USAGE_ID, mediaId: 'm1', usageType: 'PROGRAM_COVER', resourceId: PRIVATE_PROGRAM_ID }),
    })
  })

  it('leaves the private program coverless when no images were placed', async () => {
    const { prisma, ctx } = fakeCtx(null)
    await full(ctx)
    expect(prisma.mediaUsage.create).not.toHaveBeenCalled()
    expect(prisma.studyProgram.update).not.toHaveBeenCalledWith(expect.objectContaining({ where: { id: PRIVATE_PROGRAM_ID } }))
  })
})
