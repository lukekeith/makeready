/**
 * ui2-programs D9, on lesson versions (text-activity SC2): the Lessons `+` on a blank program (no template,
 * no lessons) creates position 1 with a draft numbered 1 and no activities, and syncs `days` to the live
 * lesson count.
 */
import request from 'supertest'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, type ContentWorld } from './helpers/content-world.js'

describe('POST /api/programs/:id/lessons on a blank program (D9)', () => {
  let w: ContentWorld
  let programId: string
  beforeAll(async () => {
    w = await createContentWorld()
    const blank = await prisma.studyProgram.create({ data: { name: 'Blank', days: 0, creatorId: w.leader.userId, organizationId: w.orgId } })
    programId = blank.id
  })
  afterAll(async () => {
    await prisma.studyProgram.delete({ where: { id: programId } })
    await destroyContentWorld(w)
  })

  it('creates position 1 with an empty draft and sets days to 1', async () => {
    const res = await request(app).post(`/api/programs/${programId}/lessons`).set('Authorization', bearer(w.leader.token)).send({})
    expect(res.status).toBe(200)
    expect(res.body.lesson).toMatchObject({ position: 1, title: null, activities: [], publishedVersionId: null })
    const draft = await prisma.lessonVersion.findFirst({ where: { lessonId: res.body.lesson.id } })
    expect(draft).toMatchObject({ id: res.body.lesson.draftVersionId, number: 1, status: 'DRAFT', title: null })
    expect(await prisma.contentActivity.count({ where: { lessonVersionId: draft!.id } })).toBe(0)
    expect((await prisma.studyProgram.findUnique({ where: { id: programId } }))!.days).toBe(1)
  })
})
