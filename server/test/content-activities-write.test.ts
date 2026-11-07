/**
 * text-activity D3/D32/D34/D35: the four draft writes (create, replace, delete, reorder) run under one
 * lock on the version row, refuse a published version, validate the document, and keep media usage current.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createMedia, destroyContentWorld, seedPublishedLesson, type ContentWorld } from './helpers/content-world.js'

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

function padToBytes(doc: any, bytes: number) {
  const copy = JSON.parse(JSON.stringify(doc))
  copy.fallback.body = ''
  const base = Buffer.byteLength(JSON.stringify(copy))
  copy.fallback.body = 'a'.repeat(bytes - base)
  return copy
}

type Actor = Pick<ContentWorld, 'leader'>
const auth = (a: Actor) => bearer(a.leader.token)
const post = (a: Actor, versionId: string, body: unknown) =>
  request(app).post(`/api/lesson-versions/${versionId}/activities`).set('Authorization', auth(a)).send(body as object)
const put = (a: Actor, id: string, body: unknown) =>
  request(app).put(`/api/content-activities/${id}`).set('Authorization', auth(a)).send(body as object)
const del = (a: Actor, id: string) => request(app).delete(`/api/content-activities/${id}`).set('Authorization', auth(a))
const order = (a: Actor, versionId: string, activityIds: string[]) =>
  request(app).patch(`/api/lesson-versions/${versionId}/activities/order`).set('Authorization', auth(a)).send({ activityIds })

const rows = (versionId: string) =>
  prisma.contentActivity.findMany({ where: { lessonVersionId: versionId }, orderBy: { position: 'asc' } })
const activityIds = async (versionId: string) => (await rows(versionId)).map(r => r.id)
const positions = async (versionId: string) => (await rows(versionId)).map(r => r.position)
const usageIds = async (key: string) =>
  (await prisma.mediaUsage.findMany({ where: { usageType: 'ACTIVITY', resourceId: key } })).map(r => r.mediaId)

describe('writing a draft', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  it('create appends with a new key; replace keeps it', async () => {
    const c = await post(w, w.draftVersionId, { kind: 'text', title: 'Text', document: EXAMPLE_TEXT })
    expect(c.status).toBe(201); expect(c.body.activity).toMatchObject({ position: 0, kind: 'text', title: 'Text' })
    const p = await put(w, c.body.activity.id, { document: { ...EXAMPLE_TEXT, extra: 1 } })
    expect(p.body.activity.activityKey).toBe(c.body.activity.activityKey)
    expect(p.body.activity.document.extra).toBe(1)
  })

  it('256 KB + 1 byte is 413 on POST and PUT', async () => {
    const big = padToBytes(EXAMPLE_TEXT, 262145)
    expect((await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: big })).status).toBe(413)
    const c = await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: EXAMPLE_TEXT })
    const r = await put(w, c.body.activity.id, { document: big })
    expect(r.status).toBe(413); expect(r.body.code).toBe('TOO_LARGE')
  })

  it('a published version refuses every write with 409 NOT_DRAFT', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
    const [actId] = await activityIds(pub.versionId)
    const codes = [
      await post(w, pub.versionId, { kind: 'text', title: 'T', document: EXAMPLE_TEXT }),
      await put(w, actId, { document: EXAMPLE_TEXT }),
      await del(w, actId),
      await order(w, pub.versionId, [actId]),
    ].map(r => [r.status, r.body.code])
    expect(codes).toEqual(Array(4).fill([409, 'NOT_DRAFT']))
  })

  it('a foreign media id is refused and usage follows saves', async () => {
    const foreign = await createMedia(w.otherOrgId), own = await createMedia(w.orgId)
    expect((await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: withImage(EXAMPLE_TEXT, foreign.id) })).status).toBe(400)
    const c = await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: withImage(EXAMPLE_TEXT, own.id) })
    expect(await usageIds(c.body.activity.activityKey)).toEqual([own.id])
    await del(w, c.body.activity.id)
    expect(await usageIds(c.body.activity.activityKey)).toEqual([])
  })

  it('delete closes up positions; reorder needs the exact set; double POST gives no 500', async () => {
    const body = { kind: 'text', title: 'T', document: EXAMPLE_TEXT }
    const [a, b] = await Promise.all([post(w, w.draftVersionId, body), post(w, w.draftVersionId, body)])
    expect([a.status, b.status].every(s => s === 201 || s === 409)).toBe(true)
    await post(w, w.draftVersionId, body)
    const ids = await activityIds(w.draftVersionId)
    expect((await order(w, w.draftVersionId, ids.slice(1))).status).toBe(400)
    expect((await order(w, w.draftVersionId, [...ids].reverse())).body.activities.map((x: any) => x.id)).toEqual([...ids].reverse())
    await del(w, ids[0])
    expect((await positions(w.draftVersionId))).toEqual([...Array(ids.length - 1).keys()])
  })

  it("order with another version's ids is 400, and another org gets 404 on every write", async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'kx' }])
    expect((await order(w, w.draftVersionId, await activityIds(pub.versionId))).status).toBe(400)
    const o = { ...w, leader: w.outsider }
    const [actId] = await activityIds(w.draftVersionId)
    const codes = [
      await post(o, w.draftVersionId, { kind: 'text', title: 'T', document: EXAMPLE_TEXT }),
      await put(o, actId, { document: EXAMPLE_TEXT }),
      await del(o, actId),
      await order(o, w.draftVersionId, [actId]),
    ].map(r => r.status)
    expect(codes).toEqual([404, 404, 404, 404])
  })
})
