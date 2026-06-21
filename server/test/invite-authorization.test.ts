/**
 * Invite authorization (integration).
 *
 * Invite routes historically authorized by group `creatorId` (create/send) or
 * the invite `inviterId` (update/delete) ONLY — so a non-creator org owner /
 * group leader couldn't invite to, or manage invites for, a group in their own
 * org. After the fix these are org-scoped via `canManageOrgContent`: the group
 * creator/inviter, the group org's owner, any org role-holder, or a super admin.
 * Strangers still get 403; unauth gets 401.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Invite authorization (org-scoped management)', () => {
  let owner: TestUserWithToken // group creator + org owner + inviter
  let leader: TestUserWithToken // org role-holder, NOT the creator/inviter
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let groupId: string
  let inviteId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `iowner-${stamp}@cl.test`, name: 'Invite Owner' })
    leader = await createUserWithApiKey({ email: `ileader-${stamp}@cl.test`, name: 'Invite Leader' })
    stranger = await createUserWithApiKey({ email: `istranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Invite Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    const role = await prisma.role.create({
      data: { name: `Invite Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    const group = await prisma.group.create({
      data: { name: `Group ${stamp}`, code: `igrp-${stamp}`, creatorId: owner.userId, organizationId: orgId },
    })
    groupId = group.id

    // An invite created by the OWNER for the group (for update/delete tests).
    const invite = await prisma.invite.create({
      data: { token: `tok-${stamp}`, inviterId: owner.userId, groupId },
    })
    inviteId = invite.id
  })

  afterAll(async () => {
    await prisma.invite.deleteMany({ where: { groupId } })
    await prisma.group.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  // ─── Create an invite for the group ─────────────────────────────────────────────

  it('lets a NON-creator org leader CREATE an invite for the group (the fix — was 403)', async () => {
    const res = await request(app)
      .post('/api/invites')
      .set('Authorization', bearer(leader.token))
      .send({ groupId })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger creating an invite for the group (403)', async () => {
    const res = await request(app)
      .post('/api/invites')
      .set('Authorization', bearer(stranger.token))
      .send({ groupId })
    expect(res.status).toBe(403)
  })

  it('rejects unauthenticated invite creation (401)', async () => {
    const res = await request(app).post('/api/invites').send({ groupId })
    expect(res.status).toBe(401)
  })

  // ─── Update an invite created by someone else ───────────────────────────────────

  it('lets a NON-inviter org leader UPDATE the owner\'s invite (the fix — was 403)', async () => {
    const res = await request(app)
      .patch(`/api/invites/${inviteId}`)
      .set('Authorization', bearer(leader.token))
      .send({ status: 'expired' })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger updating the invite (403)', async () => {
    const res = await request(app)
      .patch(`/api/invites/${inviteId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ status: 'pending' })
    expect(res.status).toBe(403)
  })

  // ─── Delete an invite (last) ──────────────────────────────────────────────────

  it('denies a stranger deleting the invite (403)', async () => {
    const res = await request(app)
      .delete(`/api/invites/${inviteId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('lets a NON-inviter org leader DELETE the owner\'s invite (the fix — was 403)', async () => {
    const res = await request(app)
      .delete(`/api/invites/${inviteId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
