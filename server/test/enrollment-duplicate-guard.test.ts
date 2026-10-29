/**
 * enroll-picker-hide-enrolled D6: POST /api/enrollments refuses a second enrollment of a (group, program)
 * whose endDate has not passed (active or upcoming); a pair whose enrollments all ended enrolls again.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'

import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('POST /api/enrollments refuses a second current enrollment of a pair (enroll-picker-hide-enrolled D6)', () => {
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
    owner = await createUserWithApiKey({ email: `dup-owner-${stamp}@cl.test`, name: 'DUP Owner' })
    orgId = (await prisma.organization.create({ data: { name: `DUP Org ${stamp}`, ownerId: owner.userId } })).id
    groupId = (await prisma.group.create({ data: { name: `DUP Group ${stamp}`, code: `dup-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    memberId = (await prisma.member.create({ data: { firstName: 'Pat', lastName: 'Lee', phoneNumber: `+1558${String(stamp).slice(-7)}` } })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
    for (let i = 0; i < 5; i++) {
      const p = await prisma.studyProgram.create({
        data: { name: `DUP P${i} ${stamp}`, days: 2, creatorId: owner.userId, organizationId: orgId, isPublished: true, publishedAt: new Date() },
      })
      for (const day of [1, 2]) await prisma.lesson.create({ data: { studyProgramId: p.id, dayNumber: day } })
      programs.push(p.id)
    }
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

  const enrollmentOf = (studyProgramId: string, startDate: Date, endDate: Date) =>
    prisma.enrollment.create({
      data: { groupId, studyProgramId, startDate, endDate, enabledDays: JSON.stringify(['Mon']) },
    })
  const day = 24 * 60 * 60 * 1000

  it('a current (active) enrollment of the pair → 409 already_enrolled, nothing created, the draft kept', async () => {
    const existing = await enrollmentOf(programs[0], new Date(Date.now() - 7 * day), new Date(Date.now() + 7 * day))
    await draftFor(programs[0])
    const res = await enroll(programs[0])
    expect(res.status).toBe(409)
    expect(res.body).toMatchObject({ success: false, error: 'already_enrolled', enrollmentId: existing.id })
    expect(await prisma.enrollment.count({ where: { groupId, studyProgramId: programs[0] } })).toBe(1)
    expect(await draftsOf(programs[0])).toBe(1)
  })

  it('an upcoming enrollment of the pair also counts as current → 409', async () => {
    await enrollmentOf(programs[1], new Date(Date.now() + 7 * day), new Date(Date.now() + 30 * day))
    const res = await enroll(programs[1])
    expect(res.status).toBe(409)
    expect(res.body.error).toBe('already_enrolled')
  })

  it('a pair whose only enrollment ended yesterday enrolls again', async () => {
    await enrollmentOf(programs[2], new Date(Date.now() - 30 * day), new Date(Date.now() - day))
    const res = await enroll(programs[2])
    expect(res.status).toBe(200)
    expect(await prisma.enrollment.count({ where: { groupId, studyProgramId: programs[2] } })).toBe(2)
  })

  it('another program in the same group is unaffected', async () => {
    const res = await enroll(programs[3])
    expect(res.status).toBe(200)
  })
})
