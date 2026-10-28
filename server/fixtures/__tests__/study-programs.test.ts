import { describe, expect, it, vi } from 'vitest'
import { FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_PROGRAM_IDS, fixtureId } from '../ids.js'
import {
  EMPTY_PROGRAM_ID,
  PRIVATE_PROGRAM_ID,
  RICH_PROGRAM_FIELDS,
  RICH_PROGRAM_ID,
  full,
} from '../screens/study-program-home.js'

function fakeCtx() {
  const prisma = { studyProgram: { update: vi.fn(), createMany: vi.fn() } }
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
})
