/**
 * Video authorization (integration).
 *
 * Videos historically authorized every per-video action by `video.userId`
 * (the uploader) ONLY — so a group leader / org owner who didn't personally
 * upload a video was locked out (403), even though the video belongs to their
 * organization and is used in their programs. After the fix, anyone who can
 * manage the owning org's content (org owner / role-holder / super admin) can
 * view, edit, refresh, and delete it; the org is derived from the video's
 * media-library entry. Strangers still get 403; unauth gets 401.
 *
 * Auth is real end-to-end: each user gets an API key and drives the endpoints
 * via `Authorization: Bearer mr_…` through the live middleware.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Video authorization (org-scoped management)', () => {
  let owner: TestUserWithToken // uploader of the video + org owner
  let leader: TestUserWithToken // org role-holder, NOT the uploader
  let stranger: TestUserWithToken // no relationship to the org
  let orgId: string
  let videoId: string
  let mediaId: string
  const stamp = Date.now()

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `vowner-${stamp}@cl.test`, name: 'Video Owner' })
    leader = await createUserWithApiKey({ email: `vleader-${stamp}@cl.test`, name: 'Video Leader' })
    stranger = await createUserWithApiKey({ email: `vstranger-${stamp}@cl.test`, name: 'Stranger' })

    const org = await prisma.organization.create({
      data: { name: `Video Org ${stamp}`, ownerId: owner.userId },
    })
    orgId = org.id

    // Leader is a role-holder in the org but uploaded nothing.
    const role = await prisma.role.create({
      data: { name: `Video Leader ${stamp}`, organizationId: orgId, isSystem: false },
    })
    await prisma.userRole.create({
      data: { userId: leader.userId, roleId: role.id, organizationId: orgId },
    })

    // Video uploaded by the OWNER, captured into the org's media library.
    const video = await prisma.video.create({
      data: {
        cloudflareUid: `cf-${stamp}`,
        playbackUrl: 'https://example.test/play.m3u8',
        status: 'ready',
        userId: owner.userId,
      },
    })
    videoId = video.id
    const media = await prisma.media.create({
      data: {
        title: 'Org Video',
        url: 'https://example.test/play.m3u8',
        type: 'video',
        organizationId: orgId,
        uploadedBy: owner.userId,
        videoId: video.id,
        source: 'auto_capture',
      },
    })
    mediaId = media.id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { id: mediaId } })
    await prisma.video.deleteMany({ where: { id: videoId } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const userIds = [owner.userId, leader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: userIds } } })
  })

  it('lets the UPLOADER view the video (baseline)', async () => {
    const res = await request(app)
      .get(`/api/videos/${videoId}`)
      .set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('lets a NON-uploader org leader VIEW the video (the fix — was 403)', async () => {
    const res = await request(app)
      .get(`/api/videos/${videoId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })

  it('denies a stranger viewing the video (403)', async () => {
    const res = await request(app)
      .get(`/api/videos/${videoId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('rejects unauthenticated view (401)', async () => {
    const res = await request(app).get(`/api/videos/${videoId}`)
    expect(res.status).toBe(401)
  })

  it('lets a NON-uploader org leader EDIT the video (the fix — was 403)', async () => {
    const res = await request(app)
      .patch(`/api/videos/${videoId}`)
      .set('Authorization', bearer(leader.token))
      .send({ title: 'Edited by leader' })
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    expect(res.body.data.title).toBe('Edited by leader')
  })

  it('denies a stranger editing the video (403)', async () => {
    const res = await request(app)
      .patch(`/api/videos/${videoId}`)
      .set('Authorization', bearer(stranger.token))
      .send({ title: 'Edited by stranger' })
    expect(res.status).toBe(403)
  })

  it('denies a stranger refreshing the video status (403, before any Cloudflare call)', async () => {
    const res = await request(app)
      .post(`/api/videos/${videoId}/refresh`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('denies a stranger deleting the video (403)', async () => {
    const res = await request(app)
      .delete(`/api/videos/${videoId}`)
      .set('Authorization', bearer(stranger.token))
    expect(res.status).toBe(403)
  })

  it('lets a NON-uploader org leader DELETE the video (the fix — was 403)', async () => {
    // Cloudflare deletion may fail in tests; the handler warns and proceeds with
    // the DB delete, so a 200 still confirms the authorization path.
    const res = await request(app)
      .delete(`/api/videos/${videoId}`)
      .set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
  })
})
