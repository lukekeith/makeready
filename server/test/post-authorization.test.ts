/**
 * Group post (feed) authorization (integration).
 *
 * Post routes historically authorized by group `creatorId` (post/list) or by
 * post author / group creator (edit/delete) ONLY — so a non-creator org owner /
 * group leader was locked out of their org's group feed. After the fix these are
 * org-scoped: viewing/posting use `groupManageFilter`; edit/delete allow the
 * author OR anyone who can manage the group's org (`canManageOrgContent`).
 * Strangers still get 404 (list/post) or 403 (edit/delete); unauth gets 401.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Group post authorization (org-scoped management)', () => {
  let owner: TestUserWithToken // group creator + org owner + post author
  let leader: TestUserWithToken // org role-holder, NOT the creator/author/member
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let groupId: string
  let postId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `powner-feed-${stamp}@cl.test`, name: 'Feed Owner' })
    leader = await createUserWithApiKey({ email: `pleader-feed-${stamp}@cl.test`, name: 'Feed Leader' })
    stranger = await createUserWithApiKey({ email: `pstranger-feed-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Feed Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    const role = await prisma.role.create({
      data: { name: `Feed Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    const group = await prisma.group.create({
      data: { name: `Group ${stamp}`, code: `fgrp-${stamp}`, creatorId: owner.userId, organizationId: orgId },
    })
    groupId = group.id

    const post = await prisma.post.create({
      data: { groupId, authorId: owner.userId, type: 'ANNOUNCEMENT', content: 'Hello group' },
    })
    postId = post.id
  })

  afterAll(async () => {
    await prisma.post.deleteMany({ where: { groupId } })
    await prisma.group.deleteMany({ where: { organizationId: orgId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  // ─── View feed ──────────────────────────────────────────────────────────────

  it('lets the group CREATOR view the feed (baseline)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/posts`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-creator org leader VIEW the feed (the fix — was 404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/posts`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger viewing the feed (404)', async () => {
    const res = await request(app)
      .get(`/api/groups/${groupId}/posts`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(404)
  })

  it('rejects unauthenticated feed view (401)', async () => {
    const res = await request(app).get(`/api/groups/${groupId}/posts`)
    expect(res.status).toBe(401)
  })

  // ─── Create post ──────────────────────────────────────────────────────────────

  it('lets a NON-creator org leader POST to the feed (the fix — was 404)', async () => {
    const res = await request(app)
      .post(`/api/groups/${groupId}/posts`)
      .set('Authorization', bearer(leader.token))
      .send({ type: 'ANNOUNCEMENT', content: `Posted by leader ${stamp}` })
    expect([200, 201]).toContain(res.status)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger posting to the feed (404)', async () => {
    const res = await request(app)
      .post(`/api/groups/${groupId}/posts`)
      .set('Authorization', bearer(stranger.token))
      .send({ type: 'ANNOUNCEMENT', content: 'Posted by stranger' })
    expect(res.status).toBe(404)
  })

  // ─── Edit a post authored by someone else ───────────────────────────────────────

  it('lets a NON-author org leader EDIT the owner\'s post (the fix — was 403)', async () => {
    const res = await request(app)
      .patch(`/api/posts/${postId}`)
      .set('Authorization', bearer(leader.token))
      .send({ content: `Edited by leader ${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger editing the post (403)', async () => {
    const res = await request(app)
      .patch(`/api/posts/${postId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ content: 'Edited by stranger' })
    expect(res.status).toBe(403)
  })

  // ─── Delete a post (last) ──────────────────────────────────────────────────────

  it('denies a stranger deleting the post (403)', async () => {
    const res = await request(app)
      .delete(`/api/posts/${postId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('lets a NON-author org leader DELETE the owner\'s post (the fix — was 403)', async () => {
    const res = await request(app)
      .delete(`/api/posts/${postId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
