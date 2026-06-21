/**
 * Group authorization (integration).
 *
 * Group-level routes historically authorized by `creatorId` ONLY, so a
 * non-creator org owner / group leader was locked out (404/403) of groups in
 * their own organization: viewing, editing, deleting, reviewing join requests,
 * and managing members. After the fix these are org-scoped via
 * `canManageOrgContent` / `groupManageFilter` (creator / org owner / role-holder
 * / super admin). Strangers still fall through to 404 (or 403 on the
 * member-management middleware); unauth gets 401.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Group authorization (org-scoped management)', () => {
  let owner: TestUserWithToken // creator of the group + org owner
  let leader: TestUserWithToken // org role-holder, NOT the creator
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let groupId: string
  let memberId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `gowner-${stamp}@cl.test`, name: 'Group Owner' })
    leader = await createUserWithApiKey({ email: `gleader-${stamp}@cl.test`, name: 'Group Leader' })
    stranger = await createUserWithApiKey({ email: `gstranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Group Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    // Leader holds a role in the org but created nothing.
    const role = await prisma.role.create({
      data: { name: `Group Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    // Group created by the OWNER, scoped to the org.
    const group = await prisma.group.create({
      data: {
        name: `Group ${stamp}`,
        code: `grp-${stamp}`,
        creatorId: owner.userId,
        organizationId: orgId,
      },
    })
    groupId = group.id

    // A verified member with an active membership in the group (for the
    // member-removal authorization test).
    const member = await prisma.member.create({
      data: { phoneNumber: `+1999${stamp.toString().slice(-7)}`, phoneVerified: true },
    })
    memberId = member.id
    await prisma.groupMember.create({
      data: { groupId, memberId, isActive: true },
    })
  })

  afterAll(async () => {
    await prisma.groupMember.deleteMany({ where: { groupId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.group.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  // ─── View ──────────────────────────────────────────────────────────────────

  it('lets the CREATOR view the group (baseline)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader VIEW the group (the fix — was 404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger viewing the group (404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  it('rejects unauthenticated view (401)', async () => {
    const res = await request(app).get(`/api/groups/${groupId}`)
    expect(res.status).toBe(401)
  })

  // ─── Edit ──────────────────────────────────────────────────────────────────

  it('lets a NON-creator org leader RENAME the group (the fix — was 404)', async () => {
    const res = await request(app)
      .patch(`/api/groups/${groupId}`)
      .set('Authorization', bearer(leader.token))
      .send({ name: `Renamed by leader ${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger renaming the group (404)', async () => {
    const res = await request(app)
      .patch(`/api/groups/${groupId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ name: 'Renamed by stranger' })
    expect(res.status).toBe(404)
  })

  // ─── Join requests ───────────────────────────────────────────────────────────

  it('lets a NON-creator org leader LIST join requests (the fix — was 404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/join-requests`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger listing join requests (404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/join-requests`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  // ─── Member management (requireGroupManage middleware) ──────────────────────

  it('denies a stranger removing a member (403 from requireGroupManage)', async () => {
    const res = await request(app)
      .delete(`/api/groups/${groupId}/members/${memberId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('lets a NON-creator org leader REMOVE a member (the fix — was 403)', async () => {
    const res = await request(app)
      .delete(`/api/groups/${groupId}/members/${memberId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)

    const gm = await prisma.groupMember.findFirst({ where: { groupId, memberId } })
    expect(gm?.isActive).toBe(false)
  })

  // ─── Delete (last — soft-deletes the group) ─────────────────────────────────

  it('lets a NON-creator org leader DELETE the group (the fix — was 404)', async () => {
    const res = await request(app)
      .delete(`/api/groups/${groupId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
