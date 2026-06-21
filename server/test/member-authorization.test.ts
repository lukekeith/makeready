/**
 * Member access authorization (integration).
 *
 * Member routes historically authorized by group `creatorId` (profile) or by
 * the `requireMemberOrOrgOwner` middleware, which recognized the member-self or
 * an org OWNER only — so a non-owner org role-holder (group leader / admin) was
 * locked out (403) of members in their own org. After the fix:
 *   - `requireMemberOrOrgOwner` allows super admin / org owner / any org
 *     role-holder (via getManageableOrgIds), and
 *   - `GET /:memberId/profile` authorizes anyone who can manage a group the
 *     member belongs to (groupManageFilter).
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

describe('Member access authorization (org-scoped management)', () => {
  let owner: TestUserWithToken // org owner (holds no explicit role)
  let leader: TestUserWithToken // org role-holder, NOT the owner/creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let groupId: string
  let memberId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `mbowner-${stamp}@cl.test`, name: 'Member Owner' })
    leader = await createUserWithApiKey({ email: `mbleader-${stamp}@cl.test`, name: 'Member Leader' })
    stranger = await createUserWithApiKey({ email: `mbstranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Member Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    const role = await prisma.role.create({
      data: { name: `Member Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    const group = await prisma.group.create({
      data: { name: `Group ${stamp}`, code: `mgrp-${stamp}`, creatorId: owner.userId, organizationId: orgId },
    })
    groupId = group.id

    // A member who belongs to the org AND the group.
    const member = await prisma.member.create({
      data: {
        phoneNumber: `+1888${stamp.toString().slice(-7)}`,
        phoneVerified: true,
        firstName: 'Pat',
        lastName: 'Member',
      },
    })
    memberId = member.id
    await prisma.memberOrganization.create({
      data: { memberId, organizationId: orgId },
    })
    await prisma.groupMember.create({
      data: { groupId, memberId, isActive: true },
    })
  })

  afterAll(async () => {
    await prisma.groupMember.deleteMany({ where: { groupId } })
    await prisma.memberOrganization.deleteMany({ where: { organizationId: orgId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.group.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  // ─── Member profile (inline group-manage authorization) ─────────────────────────

  it('lets the org OWNER view the member profile (baseline)', async () => {
    const res = await request(app)
      .get(`/api/members/${memberId}/profile`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader view the member profile (the fix — was 403)', async () => {
    const res = await request(app)
      .get(`/api/members/${memberId}/profile`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger viewing the member profile (403)', async () => {
    const res = await request(app)
      .get(`/api/members/${memberId}/profile`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('rejects unauthenticated profile access (401)', async () => {
    const res = await request(app).get(`/api/members/${memberId}/profile`)
    expect(res.status).toBe(401)
  })

  // ─── Member CRUD (requireMemberOrOrgOwner middleware) ───────────────────────────

  it('lets a NON-owner org leader GET the member (the fix — was 403)', async () => {
    const res = await request(app)
      .get(`/api/members/${memberId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-owner org leader EDIT the member (the fix — was 403)', async () => {
    const res = await request(app)
      .patch(`/api/members/${memberId}`)
      .set('Authorization', bearer(leader.token))
      .send({ firstName: `Edited${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-owner org leader list the member groups (the fix — was 403)', async () => {
    const res = await request(app)
      .get(`/api/members/${memberId}/groups`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger getting the member (403)', async () => {
    const res = await request(app)
      .get(`/api/members/${memberId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })
})
