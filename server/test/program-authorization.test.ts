/**
 * Program-level mutation authorization (integration).
 *
 * Program-level mutations (rename/publish, add/edit/reorder lessons, cover
 * image, delete) historically funnelled through `mutationFilter`, which was
 * creator-only — so a non-creator org owner / group leader could edit a
 * program's activities (already org-scoped) but could NOT rename it, reorder
 * its lessons, or delete it (404). After the fix, `mutationFilter` is org-aware
 * (creator / org owner / role-holder / super admin), matching
 * `canManageOrgContent`. Strangers still fall through to 404; unauth gets 401.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Program-level mutation authorization', () => {
  let owner: TestUserWithToken // creator of the program + org owner
  let leader: TestUserWithToken // org role-holder, NOT the creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let programId: string
  const lessonIds: string[] = []
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `powner-${stamp}@cl.test`, name: 'Program Owner' })
    leader = await createUserWithApiKey({ email: `pleader-${stamp}@cl.test`, name: 'Program Leader' })
    stranger = await createUserWithApiKey({ email: `pstranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Program Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    // Leader holds a role in the org but created nothing.
    const role = await prisma.role.create({
      data: { name: `Program Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    // Program created by the OWNER, scoped to the org, with two lessons.
    const program = await prisma.studyProgram.create({
      data: { name: `Program ${stamp}`, days: 2, creatorId: owner.userId, organizationId: orgId },
    })
    programId = program.id
    for (let day = 1; day <= 2; day++) {
      const lesson = await prisma.lesson.create({
        data: { studyProgramId: program.id, dayNumber: day },
      })
      lessonIds.push(lesson.id)
    }
  })

  afterAll(async () => {
    await prisma.lesson.deleteMany({ where: { studyProgramId: programId } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  it('lets the program CREATOR rename it (baseline)', async () => {
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .set('Authorization', bearer(owner.token))
      .send({ name: `Renamed by owner ${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader RENAME the program (the fix — was 404)', async () => {
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .set('Authorization', bearer(leader.token))
      .send({ name: `Renamed by leader ${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger renaming the program (404)', async () => {
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ name: 'Renamed by stranger' })
    expect(res.status).toBe(404)
  })

  it('rejects unauthenticated rename (401)', async () => {
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .send({ name: 'Renamed by nobody' })
    expect(res.status).toBe(401)
  })

  it('lets a NON-creator org leader REORDER lessons (the fix — was 404)', async () => {
    const res = await request(app)
      .post(`/api/programs/${programId}/reorder-lessons`)
      .set('Authorization', bearer(leader.token))
      .send({ lessonOrder: [lessonIds[1], lessonIds[0]] })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger reordering lessons (404)', async () => {
    const res = await request(app)
      .post(`/api/programs/${programId}/reorder-lessons`)
      .set('Authorization', bearer(stranger.token))
      .send({ lessonOrder: [lessonIds[0], lessonIds[1]] })
    expect(res.status).toBe(404)
  })

  it('lets a NON-creator org leader DELETE the program (the fix — was 404)', async () => {
    const res = await request(app)
      .delete(`/api/programs/${programId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
