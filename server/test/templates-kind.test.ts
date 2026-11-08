/**
 * text-activity Task 10 (SC6, SC9): template activities carry `kind` and a starter `document`, validated
 * like a lesson activity's; the old `type` field is refused.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createMedia, destroyContentWorld, type ContentWorld } from './helpers/content-world.js'

const EXAMPLE_TEXT = {
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D' },
  content: { type: 'canvas', verticalAnchor: 'center', objects: [] },
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body: 'y' },
}

describe('template activities', () => {
  let w: ContentWorld
  let templateId: string
  beforeAll(async () => {
    w = await createContentWorld()
    templateId = (await prisma.lessonTemplate.create({ data: { name: 'T', creatorId: w.leader.userId, organizationId: w.orgId } })).id
  })
  afterAll(async () => {
    await prisma.lessonTemplate.deleteMany({ where: { id: templateId } })
    await destroyContentWorld(w)
  })

  let nextOrder = 1
  /** POST a template activity; `body` is the created activity on success, the error body otherwise. */
  const createTemplateActivity = async (_w: ContentWorld, body: Record<string, unknown>) => {
    const res = await request(app)
      .post(`/api/templates/${templateId}/activities`)
      .set('Authorization', bearer(w.leader.token))
      .send({ orderNumber: nextOrder++, ...body })
    return { status: res.status, body: res.body.activity ?? res.body }
  }

  it('a template activity stores kind and document, and refuses the old type field', async () => {
    const ok = await createTemplateActivity(w, { kind: 'text', title: 'Starter', document: EXAMPLE_TEXT })
    expect(ok.body).toMatchObject({ kind: 'text', document: EXAMPLE_TEXT })
    expect((await createTemplateActivity(w, { type: 'READ', title: 'Old' })).status).toBe(400)
  })

  it('a type field next to a valid kind is refused, not stripped', async () => {
    const r = await createTemplateActivity(w, { kind: 'text', type: 'READ', title: 'Both', document: EXAMPLE_TEXT })
    expect(r.status).toBe(400)
  })

  it('an unknown kind, a malformed document and a foreign media id are 400', async () => {
    const foreign = await createMedia(w.otherOrgId)
    const withForeign = { ...EXAMPLE_TEXT, background: { color: '#0E4A4D', image: { mediaId: foreign.id, focal: { x: 0.5, y: 0.5 } } } }
    const statuses = [
      await createTemplateActivity(w, { kind: 'sticker', title: 'X', document: EXAMPLE_TEXT }),
      await createTemplateActivity(w, { kind: 'text', title: 'X', document: { ...EXAMPLE_TEXT, content: { type: 'nope' } } }),
      await createTemplateActivity(w, { kind: 'text', title: 'X', document: withForeign }),
    ].map((r) => r.status)
    expect(statuses).toEqual([400, 400, 400])
  })

  it('create-with-template and duplicate carry kind and document; update validates the pair', async () => {
    const created = await request(app)
      .post('/api/templates')
      .set('Authorization', bearer(w.leader.token))
      .send({ name: 'Made', activities: [{ kind: 'text', orderNumber: 1, title: 'A', document: EXAMPLE_TEXT }] })
    expect(created.status).toBe(201)
    const dup = await request(app).post(`/api/templates/${created.body.template.id}/duplicate`).set('Authorization', bearer(w.leader.token)).send({})
    expect(dup.body.template.activities[0]).toMatchObject({ kind: 'text', document: EXAMPLE_TEXT })

    const [first] = created.body.template.activities
    const bad = await request(app)
      .patch(`/api/templates/${created.body.template.id}/activities/${first.id}`)
      .set('Authorization', bearer(w.leader.token))
      .send({ document: { ...EXAMPLE_TEXT, kind: 'bible' } })
    expect(bad.status).toBe(400)
    await prisma.lessonTemplate.deleteMany({ where: { id: { in: [created.body.template.id, dup.body.template.id] } } })
  })
})
