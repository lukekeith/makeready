/**
 * Group-leader / org-owner content authorization (integration).
 *
 * Reproduces and guards the production bug where a group leader / org owner who
 * did NOT personally create a study program was locked out (404/403) of its
 * content — because the content routes authorized by `creatorId` only. After
 * the fix (`canManageOrgContent`), anyone with a role in the resource's
 * organization can manage it; strangers still can't; the last-block rule holds.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Group-leader content authorization (read blocks)', () => {
  let owner: TestUserWithToken // creator of the program + org owner
  let leader: TestUserWithToken // org role-holder, NOT the creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let programId: string
  let activityId: string
  const blockIds: string[] = []
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `owner-${stamp}@cl.test`, name: 'Content Owner' })
    leader = await createUserWithApiKey({ email: `leader-${stamp}@cl.test`, name: 'Group Leader' })
    stranger = await createUserWithApiKey({ email: `stranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Content Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    // Leader is a role-holder in the org but did not create anything.
    const role = await prisma.role.create({
      data: { name: `Group Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    // Program created by the OWNER, scoped to the org.
    const program = await prisma.studyProgram.create({
      data: { name: `Program ${stamp}`, days: 7, creatorId: owner.userId, organizationId: orgId },
    })
    programId = program.id
    const lesson = await prisma.lesson.create({
      data: { studyProgramId: program.id, dayNumber: 1 },
    })
    const activity = await prisma.lessonActivity.create({
      data: { lessonId: lesson.id, activityType: 'READ', orderNumber: 1, title: 'Read' },
    })
    activityId = activity.id

    for (let i = 1; i <= 3; i++) {
      const block = await prisma.activityReadBlock.create({
        data: { lessonActivityId: activityId, orderNumber: i, content: `block ${i}` },
      })
      blockIds.push(block.id)
    }
  })

  afterAll(async () => {
    await prisma.activityReadBlock.deleteMany({ where: { lessonActivityId: activityId } })
    const lessons = await prisma.lesson.findMany({
      where: { studyProgram: { organizationId: orgId } },
      select: { id: true },
    })
    await prisma.lessonActivity.deleteMany({ where: { lessonId: { in: lessons.map((l) => l.id) } } })
    await prisma.lesson.deleteMany({ where: { id: { in: lessons.map((l) => l.id) } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  it('lets the program CREATOR edit a read block (baseline)', async () => {
    const res = await request(app)
      .patch(`/api/activities/${activityId}/read-blocks/${blockIds[0]}`)
      .set('Authorization', bearer(owner.token))
      .send({ content: 'edited by owner' })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader EDIT a read block (the fix — was 404)', async () => {
    const res = await request(app)
      .patch(`/api/activities/${activityId}/read-blocks/${blockIds[0]}`)
      .set('Authorization', bearer(leader.token))
      .send({ content: 'edited by leader' })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader DELETE a read block (the fix — was 404)', async () => {
    const res = await request(app)
      .delete(`/api/activities/${activityId}/read-blocks/${blockIds[2]}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger with no org relationship (404)', async () => {
    const res = await request(app)
      .delete(`/api/activities/${activityId}/read-blocks/${blockIds[1]}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  it('rejects unauthenticated requests (401)', async () => {
    const res = await request(app).delete(
      `/api/activities/${activityId}/read-blocks/${blockIds[1]}`
    )
    expect(res.status).toBe(401)
  })

  it('allows deleting the LAST read block of a PROGRAM activity (no min-1 rule — incomplete state)', async () => {
    // blockIds[2] already deleted; delete blockIds[1] then the last (blockIds[0]).
    await request(app)
      .delete(`/api/activities/${activityId}/read-blocks/${blockIds[1]}`)
      .set('Authorization', bearer(leader.token))
      .expect(200)

    const res = await request(app)
      .delete(`/api/activities/${activityId}/read-blocks/${blockIds[0]}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
  })

  it('blocks publishing a program that has an incomplete (0-block) read activity (400)', async () => {
    // The read activity now has zero blocks (from the previous test).
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .set('Authorization', bearer(owner.token))
      .send({ isPublished: true })
    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/cannot publish/i)
  })
})
