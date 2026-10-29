/**
 * Enrollment authorization (integration).
 *
 * Enrollment routes historically authorized by `createdById` (the enrolling
 * user) ONLY — and the group-scoped routes by the group `creatorId` only — so a
 * non-creator org owner / group leader was locked out (404) of enrollments in
 * their own org: viewing, editing, deleting, listing a group's enrollments, and
 * editing scheduled activities. After the fix these are org-scoped
 * (`enrollmentManageFilter` / `groupManageFilter` / `canManageGroupId`):
 * the creator, the owning group's creator, the org owner, any org role-holder,
 * or a super admin. Strangers still get 404; unauth gets 401.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Enrollment authorization (org-scoped management)', () => {
  let owner: TestUserWithToken // creator of the group/program/enrollment + org owner
  let leader: TestUserWithToken // org role-holder, NOT the creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let groupId: string
  let programId: string
  let enrollmentId: string
  let scheduledActivityId: string
  let foreignOrgId: string
  let foreignProgramId: string
  let memberId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `eowner-${stamp}@cl.test`, name: 'Enroll Owner' })
    leader = await createUserWithApiKey({ email: `eleader-${stamp}@cl.test`, name: 'Enroll Leader' })
    stranger = await createUserWithApiKey({ email: `estranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Enroll Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    const role = await prisma.role.create({
      data: { name: `Enroll Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    const group = await prisma.group.create({
      data: { name: `Group ${stamp}`, code: `egrp-${stamp}`, creatorId: owner.userId, organizationId: orgId },
    })
    groupId = group.id

    const program = await prisma.studyProgram.create({
      data: { name: `Program ${stamp}`, days: 7, creatorId: owner.userId, organizationId: orgId },
    })
    programId = program.id
    const lesson = await prisma.lesson.create({
      data: { studyProgramId: program.id, dayNumber: 1 },
    })

    const start = new Date('2026-01-01T00:00:00.000Z')
    const end = new Date('2026-01-31T00:00:00.000Z')
    const enrollment = await prisma.enrollment.create({
      data: {
        groupId,
        studyProgramId: program.id,
        createdById: owner.userId,
        startDate: start,
        endDate: end,
        enabledDays: JSON.stringify(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
      },
    })
    enrollmentId = enrollment.id

    const schedule = await prisma.lessonSchedule.create({
      data: { enrollmentId: enrollment.id, lessonId: lesson.id, scheduledDate: start },
    })
    const activity = await prisma.scheduledLessonActivity.create({
      data: { lessonScheduleId: schedule.id, orderNumber: 1, title: 'Read', type: 'READ' },
    })
    scheduledActivityId = activity.id

    // ui2-enrollment-create T12: the group has an active member (D5) so a POST reaches the program
    // lookup; the stranger's published program in their own org is outside the owner's read scope.
    memberId = (await prisma.member.create({
      data: { firstName: 'Auth', lastName: 'Member', phoneNumber: `+1556${String(stamp).slice(-7)}` },
    })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
    foreignOrgId = (await prisma.organization.create({
      data: { name: `Foreign Org ${stamp}`, ownerId: stranger.userId },
    })).id
    foreignProgramId = (await prisma.studyProgram.create({
      data: {
        name: `Foreign Program ${stamp}`, days: 1, creatorId: stranger.userId, organizationId: foreignOrgId,
        isPublished: true, publishedAt: new Date(),
      },
    })).id
    await prisma.lesson.create({ data: { studyProgramId: foreignProgramId, dayNumber: 1 } })
  })

  afterAll(async () => {
    const schedules = await prisma.lessonSchedule.findMany({
      where: { enrollment: { groupId } },
      select: { id: true },
    })
    await prisma.scheduledLessonActivity.deleteMany({
      where: { lessonScheduleId: { in: schedules.map((s) => s.id) } },
    })
    await prisma.lessonSchedule.deleteMany({ where: { enrollment: { groupId } } })
    await prisma.enrollment.deleteMany({ where: { groupId } })
    await prisma.groupMember.deleteMany({ where: { memberId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    const orgIds = [orgId, foreignOrgId]
    await prisma.lesson.deleteMany({ where: { studyProgram: { organizationId: { in: orgIds } } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgIds } } })
    await prisma.group.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgIds } } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  // ─── View enrollment ─────────────────────────────────────────────────────────

  it('lets the CREATOR view the enrollment (baseline)', async () => {
    const res = await request(app)
      .get(`/api/enrollments/${enrollmentId}`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader VIEW the enrollment (the fix — was 404)', async () => {
    const res = await request(app)
      .get(`/api/enrollments/${enrollmentId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger viewing the enrollment (404)', async () => {
    const res = await request(app)
      .get(`/api/enrollments/${enrollmentId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  it('rejects unauthenticated view (401)', async () => {
    const res = await request(app).get(`/api/enrollments/${enrollmentId}`)
    expect(res.status).toBe(401)
  })

  // ─── Edit enrollment ─────────────────────────────────────────────────────────

  it('lets a NON-creator org leader EDIT the enrollment (the fix — was 404)', async () => {
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set('Authorization', bearer(leader.token))
      .send({ requireResponse: true })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger editing the enrollment (404)', async () => {
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ requireResponse: false })
    expect(res.status).toBe(404)
  })

  // ─── List a group's enrollments ────────────────────────────────────────────────

  it('lets a NON-creator org leader LIST the group enrollments (the fix — was 404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/enrollments`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger listing the group enrollments (404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/enrollments`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  // ─── Edit a scheduled activity ──────────────────────────────────────────────────

  it('lets a NON-creator org leader EDIT a scheduled activity (the fix — was 404)', async () => {
    const res = await request(app)
      .patch(`/api/scheduled-activities/${scheduledActivityId}`)
      .set('Authorization', bearer(leader.token))
      .send({ title: `Edited by leader ${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger editing a scheduled activity (404)', async () => {
    const res = await request(app)
      .patch(`/api/scheduled-activities/${scheduledActivityId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ title: 'Edited by stranger' })
    expect(res.status).toBe(404)
  })

  // ─── Create an enrollment (ui2-enrollment-create T12) ───────────────────────────

  it('404s the owner enrolling their group in a program outside their read scope (T12)', async () => {
    const res = await request(app)
      .post('/api/enrollments')
      .set('Authorization', bearer(owner.token))
      .send({
        groupId,
        studyProgramId: foreignProgramId,
        startDate: new Date().toISOString(),
        enabledDays: ['Mon', 'Wed', 'Fri'],
      })
    expect(res.status).toBe(404)
    expect(res.body.error).toBe('Study program not found')
  })

  // ─── Delete enrollment (last — cascades to schedules) ───────────────────────────

  it('lets a NON-creator org leader DELETE the enrollment (the fix — was 404)', async () => {
    const res = await request(app)
      .delete(`/api/enrollments/${enrollmentId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
