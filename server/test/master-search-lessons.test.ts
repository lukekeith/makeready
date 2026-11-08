/**
 * text-activity SC12 (search half), §server "Search and AI summaries": lesson search reads the latest published
 * version of each live lesson (else its draft) - its title and the text inside its activities' documents.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import request from 'supertest'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { LESSON_SEARCH_TEXT_SQL, SEARCH_TEXT } from '../src/services/master-search-text.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, destroyContentWorld, seedPublishedLesson, textObject, type ContentWorld } from './helpers/content-world.js'

const migrations = fileURLToPath(new URL('../atlas/migrations/', import.meta.url))
const findMigration = (fragment: string) => {
  const files = readdirSync(migrations).filter(name => name.includes(fragment))
  expect(files).toHaveLength(1)
  return readFileSync(migrations + files[0], 'utf8')
}
const normalizeSql = (sql: string) => sql.replace(/\s+/g, ' ').trim()

describe('the lesson search expressions', () => {
  it('the index expression matches the query expression', () => {
    const sql = findMigration('text_activity_search')
    expect(sql).toContain(normalizeSql(LESSON_SEARCH_TEXT_SQL))
    expect(sql).toContain(normalizeSql(SEARCH_TEXT.lesson))
  })
})

describe.skipIf(!process.env.TEST_DATABASE_URL)('lesson search over versions and documents', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  async function search(q: string) {
    const res = await request(app).get('/api/search').query({ q, types: 'LESSON' }).set('Authorization', bearer(w.leader.token))
    expect(res.status, JSON.stringify(res.body)).toBe(200)
    return res.body
  }
  const foundIds = async (q: string): Promise<string[]> => (await search(q)).results.lessons.map((l: { id: string }) => l.id)

  it('finds a lesson by its draft title and by text inside a document', async () => {
    await prisma.lessonVersion.update({ where: { id: w.draftVersionId }, data: { title: 'Zephyrword Day' } })
    expect(await foundIds('zephyrword')).toEqual([w.lessonId])

    const pub = await seedPublishedLesson(w, [{ activityKey: 'k1', text: 'Finally, brothers and sisters, quillwort' }])
    const r = await search('quillwort')
    expect(r.results.lessons.some((x: any) => x.id === pub.lessonId)).toBe(true)
    expect(r.results.lessons.find((x: any) => x.id === pub.lessonId)).toMatchObject({ studyProgramId: w.programId })
  })

  it('finds a write page by its prompt text', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'p1' }])
    await prisma.contentActivity.updateMany({
      where: { lessonVersionId: pub.versionId },
      data: { kind: 'write', document: { schemaVersion: 1, kind: 'write', content: { type: 'write', prompt: textObject('Describe your marjoramword') }, actions: [] } },
    })
    expect(await foundIds('marjoramword')).toEqual([pub.lessonId])
  })

  it('reads the latest published version, not an older one or a newer draft', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'a1', text: 'oldversionword' }])
    const v2 = await prisma.lessonVersion.create({
      data: { lessonId: pub.lessonId, number: 2, status: 'PUBLISHED', title: 'Second', publishedAt: new Date() },
    })
    await prisma.contentActivity.create({
      data: { lessonVersionId: v2.id, activityKey: 'a1', position: 1, kind: 'text', title: 'Text', document: { content: { type: 'canvas', objects: [textObject('newversionword')] } } },
    })
    const draft = await prisma.lessonVersion.create({ data: { lessonId: pub.lessonId, number: 3, status: 'DRAFT', title: 'Third' } })
    await prisma.contentActivity.create({
      data: { lessonVersionId: draft.id, activityKey: 'a1', position: 1, kind: 'text', title: 'Text', document: { content: { type: 'canvas', objects: [textObject('draftonlyword')] } } },
    })
    expect(await foundIds('newversionword')).toEqual([pub.lessonId])
    expect(await foundIds('oldversionword')).toEqual([])
    expect(await foundIds('draftonlyword')).toEqual([])
  })

  it('leaves out a deleted lesson', async () => {
    const pub = await seedPublishedLesson(w, [{ activityKey: 'd1', text: 'goneword' }])
    expect(await foundIds('goneword')).toEqual([pub.lessonId])
    await prisma.lesson.update({ where: { id: pub.lessonId }, data: { deletedAt: new Date() } })
    expect(await foundIds('goneword')).toEqual([])
  })
})
