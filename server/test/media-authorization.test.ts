/**
 * Media authorization (integration).
 *
 * Media routes authorize through the RBAC permission system
 * (`requirePermission` / `requireModifyPermission` → `hasPermission`). The
 * seeded system roles (Owner/Admin/Group Leader) all carry media permissions,
 * so role-holders were fine — but `hasPermission` only consulted UserRole rows,
 * so a non-role-holding ORG OWNER (`organizations.ownerId`) was locked out
 * (403) of media in their own org. After the fix, org owners implicitly hold
 * every permission in their org. Strangers still get 403; unauth gets 401.
 *
 * The media here is uploaded by a SEPARATE user, so the owner's access comes
 * purely from org ownership — not the uploader/creator path.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Media authorization (org-owner recognition)', () => {
  let owner: TestUserWithToken // org owner, holds NO explicit role
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let uploaderId: string
  let mediaId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `mowner-${stamp}@cl.test`, name: 'Media Owner' })
    stranger = await createUserWithApiKey({ email: `mstranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Media Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    // A different user uploaded the media — so the owner's access is via org
    // ownership only, never the creator/uploader path.
    const uploader = await prisma.user.create({
      data: { googleId: `gid-muploader-${stamp}`, email: `muploader-${stamp}@cl.test`, name: 'Uploader' },
    })
    uploaderId = uploader.id

    const media = await prisma.media.create({
      data: {
        title: 'Org Photo',
        url: 'https://images.test/photo.jpg',
        type: 'photo',
        organizationId: orgId,
        uploadedBy: uploader.id,
      },
    })
    mediaId = media.id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, stranger.userId, uploaderId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  it('lets the org OWNER (no explicit role) view media (the fix — was 403)', async () => {
    const res = await request(app)
      .get(`/api/media/${mediaId}`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets the org OWNER list the media library (the fix — was 403)', async () => {
    const res = await request(app)
      .get(`/api/organizations/${orgId}/media/library`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets the org OWNER edit media (the fix — was 403)', async () => {
    const res = await request(app)
      .patch(`/api/media/${mediaId}`)
      .set('Authorization', bearer(owner.token))
      .send({ title: `Edited by owner ${stamp}` })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger viewing media (403)', async () => {
    const res = await request(app)
      .get(`/api/media/${mediaId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('denies a stranger editing media (403)', async () => {
    const res = await request(app)
      .patch(`/api/media/${mediaId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ title: 'Edited by stranger' })
    expect(res.status).toBe(403)
  })

  it('rejects unauthenticated media access (401)', async () => {
    const res = await request(app).get(`/api/media/${mediaId}`)
    expect(res.status).toBe(401)
  })

  it('lets the org OWNER delete media (the fix — was 403)', async () => {
    const res = await request(app)
      .delete(`/api/media/${mediaId}`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
