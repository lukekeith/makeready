/**
 * Program DELETE authorization (integration).
 *
 * Guards the deliberate carve-out from the org-content rule
 * (monday#12622983805): org role-holders may EDIT org programs
 * (`mutationFilter` / `canManageOrgContent`), but program DELETION is
 * creator-only — a non-creator org leader's DELETE reads as 404 and the
 * program stays active. Auth is real end-to-end via API-key bearer tokens
 * (same harness as group-leader-content.test.ts).
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Program DELETE authorization (creator-only)', () => {
  let owner: TestUserWithToken // creator of the program + org owner
  let leader: TestUserWithToken // org role-holder, NOT the creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let programId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `del-owner-${stamp}@cl.test`, name: 'Delete Owner' })
    leader = await createUserWithApiKey({ email: `del-leader-${stamp}@cl.test`, name: 'Delete Leader' })
    stranger = await createUserWithApiKey({ email: `del-stranger-${stamp}@cl.test`, name: 'Delete Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Delete Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    // Leader is a role-holder in the org but did not create the program.
    const role = await prisma.role.create({
      data: { name: `Group Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    const program = await prisma.studyProgram.create({
      data: { name: `Deletable Program ${stamp}`, days: 7, creatorId: owner.userId, organizationId: orgId },
    })
    programId = program.id
  })

  afterAll(async () => {
    await prisma.studyProgram.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  it('denies a STRANGER deleting the program (404)', async () => {
    const res = await request(app)
      .delete(`/api/programs/${programId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  it('denies a NON-creator org leader deleting the program (404) — leaders can only delete their own', async () => {
    const res = await request(app)
      .delete(`/api/programs/${programId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(404)

    // The program is untouched.
    const program = await prisma.studyProgram.findUnique({ where: { id: programId } })
    expect(program?.isActive).toBe(true)
  })

  it('still lets a NON-creator org leader EDIT the program (org-content rule unchanged)', async () => {
    const res = await request(app)
      .patch(`/api/programs/${programId}`)
      .set('Authorization', bearer(leader.token))
      .send({ description: 'edited by leader' })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets the CREATOR delete the program (soft-delete)', async () => {
    const res = await request(app)
      .delete(`/api/programs/${programId}`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)

    const program = await prisma.studyProgram.findUnique({ where: { id: programId } })
    expect(program?.isActive).toBe(false)
  })

  it('rejects unauthenticated requests (401)', async () => {
    const res = await request(app).delete(`/api/programs/${programId}`)
    expect(res.status).toBe(401)
  })
})
