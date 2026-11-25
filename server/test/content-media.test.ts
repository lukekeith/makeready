/**
 * text-activity D34 / SC7: media an activity document names must be the leader's to use, the usage rows
 * are the union over every version holding the key, delete of used media is 409 IN_USE, and the media
 * map carries the contract's fields.
 */
import { randomUUID } from 'node:crypto'
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createMedia, destroyContentWorld, MAKEREADY_ORG_ID, seedActivity, type ContentWorld } from './helpers/content-world.js'
import {
  assertDocumentMediaAllowed,
  buildMediaMap,
  syncActivityMediaUsage,
  videoVersionUseCount,
} from '../src/services/content-media.service.js'

// DELETE /api/videos/:id reaches Stream; nothing may leave the machine (D7, D11).
vi.mock('../src/services/cloudflare.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/cloudflare.js')>()),
  deleteVideo: vi.fn(async () => ({ success: true })),
}))

const EXAMPLE_TEXT = {
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D' },
  content: { type: 'canvas', verticalAnchor: 'center', objects: [] },
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body: 'y' },
}

const withImage = (doc: any, mediaId: string) => ({
  ...doc,
  background: { ...doc.background, image: { mediaId, focal: { x: 0.5, y: 0.4 } } },
})

describe('media in activity documents (D34)', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  it("refuses another org's media and video, allows own and library media", async () => {
    const own = await createMedia(w.orgId), lib = await createMedia(MAKEREADY_ORG_ID)
    const vx = randomUUID() // ids are uuid-typed on CI's db-push database, text on atlas ones
    const foreign = await createMedia(w.otherOrgId), foreignVid = await createMedia(w.otherOrgId, { videoId: vx })
    expect(foreignVid.videoId).toBe(vx)
    await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [own.id, lib.id], videoIds: [] }))).resolves.toBeUndefined()
    await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [foreign.id], videoIds: [] }))).rejects.toMatchObject({ status: 400, code: 'VALIDATION' })
    await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [], videoIds: [vx] }))).rejects.toMatchObject({ code: 'VALIDATION' })
  })

  it('refuses a media or video id with no row', async () => {
    await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [randomUUID()], videoIds: [] }))).rejects.toMatchObject({ status: 400, code: 'VALIDATION' })
    await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [], videoIds: [randomUUID()] }))).rejects.toMatchObject({ status: 400, code: 'VALIDATION' })
  })

  it('usage is the union over every version holding the key', async () => {
    const m1 = await createMedia(w.orgId), m2 = await createMedia(w.orgId)
    await seedActivity(w, { activityKey: 'k1', versionStatus: 'PUBLISHED', mediaId: m1.id })
    await seedActivity(w, { activityKey: 'k1', versionStatus: 'DRAFT', mediaId: m2.id })
    await prisma.$transaction(tx => syncActivityMediaUsage(tx, 'k1'))
    const rows = await prisma.mediaUsage.findMany({ where: { usageType: 'ACTIVITY', resourceId: 'k1' } })
    expect(rows.map(r => r.mediaId).sort()).toEqual([m1.id, m2.id].sort())
  })

  it('media and video delete answer 409 IN_USE while an activity uses them', async () => {
    const v1 = randomUUID()
    const m = await createMedia(w.orgId, { videoId: v1 })
    await prisma.mediaUsage.create({ data: { mediaId: m.id, usageType: 'ACTIVITY', resourceId: 'k9' } })
    const r1 = await request(app).delete(`/api/media/${m.id}`).set('Authorization', bearer(w.leader.token))
    expect(r1.status).toBe(409); expect(r1.body).toMatchObject({ success: false, code: 'IN_USE' })
    const r2 = await request(app).delete(`/api/videos/${v1}`).set('Authorization', bearer(w.leader.token))
    expect(r2.status).toBe(409); expect(r2.body.code).toBe('IN_USE')
    expect(await prisma.media.count({ where: { id: m.id } })).toBe(1)
  })

  it('media delete still works when only other usage types name it', async () => {
    const m = await createMedia(w.orgId)
    await prisma.mediaUsage.create({ data: { mediaId: m.id, usageType: 'PROGRAM_COVER', resourceId: 'p1' } })
    const res = await request(app).delete(`/api/media/${m.id}`).set('Authorization', bearer(w.leader.token))
    expect(res.status).toBe(200)
  })

  it("the media map carries the contract's fields", async () => {
    const m = await createMedia(w.orgId, { width: 1080, height: 1920 })
    const map = await prisma.$transaction(tx => buildMediaMap(tx, [withImage(EXAMPLE_TEXT, m.id)]))
    expect(map[m.id]).toMatchObject({ url: m.url, width: 1080, height: 1920, kind: 'image' })
    expect(map[m.id]).not.toHaveProperty('playbackUrl')
  })

  it('the media map keys a video document by its media id with the playback url', async () => {
    const vMap = randomUUID()
    const m = await createMedia(w.orgId, { videoId: vMap })
    const doc = { ...EXAMPLE_TEXT, kind: 'video', content: { type: 'video', videoId: vMap } }
    const map = await prisma.$transaction(tx => buildMediaMap(tx, [doc]))
    expect(map[m.id]).toMatchObject({ kind: 'video', playbackUrl: `https://stream.test/${vMap}.m3u8` })
    expect(map[m.id].uploaderName).toEqual(expect.any(String))
  })

  it('the media map also keys a video entry by its videoId', async () => {
    const vid = randomUUID()
    const m = await createMedia(w.orgId, { videoId: vid })
    const doc = { ...EXAMPLE_TEXT, kind: 'video', content: { type: 'video', videoId: vid } }
    const map = await prisma.$transaction(tx => buildMediaMap(tx, [doc]))
    expect(map[vid]).toEqual(map[m.id])
    expect(map[vid]).toMatchObject({ kind: 'video', playbackUrl: `https://stream.test/${vid}.m3u8` })
  })

  it('an image entry gets no second key', async () => {
    const m = await createMedia(w.orgId)
    const map = await prisma.$transaction(tx => buildMediaMap(tx, [withImage(EXAMPLE_TEXT, m.id)]))
    expect(Object.keys(map)).toEqual([m.id])
  })

  describe('versionUseCount (D11)', () => {
    const newVideo = async () => {
      const v = randomUUID()
      return { v, m: await createMedia(w.orgId, { videoId: v }) }
    }
    const use = async (key: string, status: 'DRAFT' | 'PUBLISHED', mediaId: string) => {
      const row = await seedActivity(w, { activityKey: key, versionStatus: status, mediaId })
      await prisma.$transaction(tx => syncActivityMediaUsage(tx, key))
      return row
    }
    const counts = async (videoId: string) => {
      const res = await request(app).get(`/api/videos/${videoId}`).set('Authorization', bearer(w.leader.token))
      return [res.body.data.lessonUseCount, res.body.data.versionUseCount]
    }

    it('versionUseCount counts rows in every version that name the video', async () => {
      const { v, m } = await newVideo()
      const draft = await use('vu1', 'DRAFT', m.id)
      expect(await counts(v)).toEqual([1, 1])
      await use('vu1', 'PUBLISHED', m.id)
      expect(await counts(v)).toEqual([1, 2])
      // the draft names it by video id
      await prisma.contentActivity.update({ where: { id: draft.id }, data: { document: { ...EXAMPLE_TEXT, content: { type: 'video', videoId: v } } } })
      expect(await counts(v)).toEqual([1, 2])
    })
    it('a version that names another video is not counted', async () => {
      const a = await newVideo(), b = await newVideo()
      await use('vu2', 'DRAFT', a.m.id)
      await use('vu2', 'PUBLISHED', b.m.id)
      expect(await counts(a.v)).toEqual([1, 1])
    })
    it('counts from the documents alone, without a usage row or a Media row', async () => {
      const { v, m } = await newVideo()
      const draft = await use('vu5', 'DRAFT', m.id)
      const published = await use('vu5', 'PUBLISHED', m.id)
      await prisma.mediaUsage.deleteMany({ where: { mediaId: m.id } })
      expect(await counts(v)).toEqual([0, 2])
      for (const { id } of [draft, published]) {
        await prisma.contentActivity.update({ where: { id }, data: { document: { ...EXAMPLE_TEXT, content: { type: 'video', videoId: v } } } })
      }
      // a mention outside the media fields is not a use
      const other = await createMedia(w.orgId)
      const text = await use('vu6', 'DRAFT', other.id)
      await prisma.contentActivity.update({ where: { id: text.id }, data: { document: { ...EXAMPLE_TEXT, fallback: { title: v, body: v } } } })
      await prisma.media.delete({ where: { id: m.id } })
      expect(await videoVersionUseCount(prisma, v)).toBe(2)
    })
    it('after the draft row goes, DELETE answers as the count predicted', async () => {
      const auth = bearer(w.leader.token)
      for (const [key, published, status] of [['vu3', false, 200], ['vu4', true, 409]] as const) {
        const { v, m } = await newVideo()
        const row = await use(key, 'DRAFT', m.id)
        if (published) await use(key, 'PUBLISHED', m.id)
        await request(app).delete(`/api/content-activities/${row.id}`).set('Authorization', auth)
        expect((await request(app).delete(`/api/videos/${v}`).set('Authorization', auth)).status).toBe(status)
      }
    })
  })
})
