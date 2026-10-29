/**
 * ui2-enrollments-browse SC3 (D11, D24, F4): enrolling a (group, program) deletes that pair's drafts in
 * its own try/catch after the welcome post — with or without draftId; a failing delete keeps the 200.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const draftDelete = vi.hoisted(() => ({ fail: false }))
vi.mock('../src/services/enrollment-draft.service.js', async (importOriginal) => {
  const real = await importOriginal<typeof import('../src/services/enrollment-draft.service.js')>()
  return {
    ...real,
    deleteDraftsForPair: async (groupId: string, studyProgramId: string) => {
      if (draftDelete.fail) throw new Error('simulated draft delete failure')
      return real.deleteDraftsForPair(groupId, studyProgramId)
    },
  }
})

import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('POST /api/enrollments promotes the pair\'s draft (D11, D24)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let orgId: string
  let groupId: string
  let memberId: string
  const programs: string[] = []

  const enroll = (studyProgramId: string, extra: Record<string, unknown> = {}) =>
    request(app)
      .post('/api/enrollments')
      .set('Authorization', bearer(owner.token))
      .send({
        groupId, studyProgramId, startDate: new Date().toISOString(),
        enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], timezone: 'America/Chicago', ...extra,
      })
  const draftFor = (studyProgramId: string) => prisma.enrollmentDraft.create({ data: { groupId, studyProgramId, createdById: owner.userId } })
  const draftsOf = (studyProgramId: string) => prisma.enrollmentDraft.count({ where: { groupId, studyProgramId } })

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `edp-owner-${stamp}@cl.test`, name: 'EDP Owner' })
    orgId = (await prisma.organization.create({ data: { name: `EDP Org ${stamp}`, ownerId: owner.userId } })).id
    groupId = (await prisma.group.create({ data: { name: `EDP Group ${stamp}`, code: `edp-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    memberId = (await prisma.member.create({ data: { firstName: 'Pat', lastName: 'Lee', phoneNumber: `+1557${String(stamp).slice(-7)}` } })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
    for (let i = 0; i < 5; i++) {
      const p = await prisma.studyProgram.create({
        data: { name: `EDP P${i} ${stamp}`, days: 2, creatorId: owner.userId, organizationId: orgId, isPublished: true, publishedAt: new Date() },
      })
      for (const day of [1, 2]) await prisma.lesson.create({ data: { studyProgramId: p.id, dayNumber: day } })
      programs.push(p.id)
    }
  })

  beforeEach(() => {
    draftDelete.fail = false
  })

  afterAll(async () => {
    await prisma.enrollment.deleteMany({ where: { groupId } })
    await prisma.enrollmentDraft.deleteMany({ where: { groupId } })
    await prisma.groupMember.deleteMany({ where: { memberId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.lesson.deleteMany({ where: { studyProgramId: { in: programs } } })
    await prisma.studyProgram.deleteMany({ where: { id: { in: programs } } })
    await prisma.post.deleteMany({ where: { groupId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId: owner.userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: owner.userId } })
  })

  it('with the draft\'s id: 200 and the draft is gone', async () => {
    const draft = await draftFor(programs[0])
    const res = await enroll(programs[0], { draftId: draft.id })
    expect(res.status).toBe(200)
    expect(await prisma.enrollmentDraft.count({ where: { id: draft.id } })).toBe(0)
  })

  it('without draftId (web LeaderApp, 1.0 iPhone): the pair\'s draft is still deleted (D24)', async () => {
    await draftFor(programs[1])
    const res = await enroll(programs[1])
    expect(res.status).toBe(200)
    expect(await draftsOf(programs[1])).toBe(0)
  })

  it('a stale (unknown) draftId is ignored; the pair\'s draft is deleted', async () => {
    await draftFor(programs[2])
    const res = await enroll(programs[2], { draftId: '00000000-0000-4000-8000-000000000000' })
    expect(res.status).toBe(200)
    expect(await draftsOf(programs[2])).toBe(0)
  })

  it('a draftId of another pair deletes nothing beyond this pair', async () => {
    const other = await draftFor(programs[4])
    await draftFor(programs[3])
    const res = await enroll(programs[3], { draftId: other.id })
    expect(res.status).toBe(200)
    expect(await draftsOf(programs[3])).toBe(0)
    expect(await prisma.enrollmentDraft.count({ where: { id: other.id } })).toBe(1)
  })

  it('a failing draft delete keeps the 200 and the enrollment (F4)', async () => {
    await prisma.enrollmentDraft.deleteMany({ where: { groupId, studyProgramId: programs[4] } })
    const draft = await draftFor(programs[4])
    draftDelete.fail = true
    const res = await enroll(programs[4], { draftId: draft.id })
    expect(res.status).toBe(200)
    expect(await prisma.enrollment.count({ where: { id: res.body.enrollment.id } })).toBe(1)
    expect(await prisma.enrollmentDraft.count({ where: { id: draft.id } })).toBe(1)
  })
})
