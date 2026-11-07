/**
 * text-activity Task 10 (D43, D3, D34): the program export file is format version 2 on the new model.
 * Export writes each live lesson's draft, else its latest published version; import makes a new program
 * whose lessons each get a DRAFT with new activity keys, and refuses version 1.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import AdmZip from 'adm-zip'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createMedia, destroyContentWorld, seedPublishedLesson, type ContentWorld } from './helpers/content-world.js'

const doc = (body: string, extra: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D' },
  content: { type: 'canvas', verticalAnchor: 'center', objects: [] },
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body },
  ...extra,
})

describe('program export file, version 2', () => {
  let w: ContentWorld
  const importedProgramIds: string[] = []
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => {
    const lessonIds = (await prisma.lesson.findMany({ where: { programId: { in: importedProgramIds } }, select: { id: true } })).map((l) => l.id)
    await prisma.contentActivity.deleteMany({ where: { lessonVersion: { lessonId: { in: lessonIds } } } })
    await prisma.lessonVersion.deleteMany({ where: { lessonId: { in: lessonIds } } })
    await prisma.lesson.deleteMany({ where: { id: { in: lessonIds } } })
    await prisma.studyProgram.deleteMany({ where: { id: { in: importedProgramIds } } })
    await destroyContentWorld(w)
  })

  const exportFile = async (programId = w.programId) => {
    const r = await request(app)
      .post(`/api/programs/${programId}/export`)
      .set('Authorization', bearer(w.leader.token))
      .buffer(true)
      .parse((res, cb) => {
        const chunks: Buffer[] = []
        res.on('data', (c: Buffer) => chunks.push(c))
        res.on('end', () => cb(null, Buffer.concat(chunks)))
      })
    expect(r.status).toBe(200)
    return JSON.parse(new AdmZip(r.body as Buffer).getEntry('manifest.json')!.getData().toString('utf8'))
  }
  const importFile = async (file: unknown, token = w.leader.token) => {
    const zip = new AdmZip()
    zip.addFile('manifest.json', Buffer.from(JSON.stringify(file)))
    const r = await request(app).post('/api/programs/import').set('Authorization', bearer(token)).attach('file', zip.toBuffer(), 'program.zip')
    if (r.body?.program?.id) importedProgramIds.push(r.body.program.id)
    return r
  }

  it('export round-trips as version 2 and version 1 is refused', async () => {
    await seedPublishedLesson(w, [{ activityKey: 'k1' }])
    const file = await exportFile()
    expect(file.version).toBe(2)
    const imported = await importFile(file)
    expect(imported.status).toBe(201)
    const v1 = await importFile({ ...file, version: 1 })
    expect(v1.status).toBe(400); expect(v1.body.code).toBe('VALIDATION')
    expect(v1.body.error).toBe('Unsupported export version')
  })

  it('export writes the draft when one exists, else the latest published version', async () => {
    await seedPublishedLesson(w, [{ activityKey: 'p1' }])
    await prisma.contentActivity.create({
      data: { lessonVersionId: w.draftVersionId, activityKey: 'd1', position: 0, kind: 'text', title: 'Drafted', document: doc('from the draft') },
    })
    const file = await exportFile()
    const drafted = file.lessons.find((l: any) => l.activities.some((a: any) => a.title === 'Drafted'))
    expect(drafted.activities[0]).toEqual({ kind: 'text', title: 'Drafted', document: doc('from the draft') })
    const published = file.lessons.find((l: any) => l.title === 'Published day')
    expect(published.activities).toHaveLength(1)
  })

  it('import makes a new program with a draft per lesson and fresh activity keys', async () => {
    const file = await exportFile()
    const r = await importFile(file)
    expect(r.status).toBe(201)
    const programId = r.body.program.id as string
    expect(programId).not.toBe(w.programId)
    const lessons = await prisma.lesson.findMany({ where: { programId }, orderBy: { position: 'asc' }, include: { versions: { include: { activities: true } } } })
    expect(lessons.map((l) => l.position)).toEqual(file.lessons.map((_: unknown, i: number) => i + 1))
    for (const lesson of lessons) {
      expect(lesson.versions.map((v) => [v.status, v.number, v.enrollmentId])).toEqual([['DRAFT', 1, null]])
    }
    const keys = lessons.flatMap((l) => l.versions[0].activities.map((a) => a.activityKey))
    const oldKeys = (await prisma.contentActivity.findMany({ where: { lessonVersion: { lesson: { programId: w.programId } } }, select: { activityKey: true } })).map((a) => a.activityKey)
    expect(keys.length).toBeGreaterThan(0)
    expect(keys.filter((k) => oldKeys.includes(k))).toEqual([])
    expect((await prisma.studyProgram.findUniqueOrThrow({ where: { id: programId } })).isPublished).toBe(false)
  })

  it('import refuses a document that fails validation and a foreign media id, and creates nothing', async () => {
    const foreign = await createMedia(w.otherOrgId)
    const before = await prisma.studyProgram.count({ where: { creatorId: w.leader.userId } })
    const file = (document: unknown) => ({
      version: 2,
      program: { title: 'Bad import', description: null },
      lessons: [{ position: 1, title: 'L', activities: [{ kind: 'text', title: 'A', document }] }],
    })
    const malformed = await importFile(file(doc('x', { content: { type: 'nope' } })))
    const foreignImage = await importFile(file(doc('x', { background: { color: '#0E4A4D', image: { mediaId: foreign.id, focal: { x: 0.5, y: 0.5 } } } })))
    expect([malformed.status, malformed.body.code]).toEqual([400, 'VALIDATION'])
    expect([foreignImage.status, foreignImage.body.code]).toEqual([400, 'VALIDATION'])
    expect(await prisma.studyProgram.count({ where: { creatorId: w.leader.userId } })).toBe(before)
  })

  it('export of another organization\'s program is 404', async () => {
    const r = await request(app).post(`/api/programs/${w.programId}/export`).set('Authorization', bearer(w.outsider.token))
    expect(r.status).toBe(404)
  })
})
