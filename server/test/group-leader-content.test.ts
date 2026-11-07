/**
 * Publishing a program that holds an incomplete read activity (integration). The read-block routes this
 * file once covered were removed with the 1.0 activity surface (text-activity SC8); the publish gate
 * survives until the publish rewrite, so the activity is seeded with no blocks directly.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Publish gate for an incomplete read activity', () => {
  let owner: TestUserWithToken // creator of the program + org owner
  let leader: TestUserWithToken // org role-holder, NOT the creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let programId: string
  let activityId: string
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
  })

  afterAll(async () => {
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

  it('blocks publishing a program that has an incomplete (0-block) read activity (400)', async () => {
    // The seeded read activity has zero blocks.
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .set('Authorization', bearer(owner.token))
      .send({ isPublished: true })
    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/cannot publish/i)
  })
})
