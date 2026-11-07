/**
 * text-activity Task 18 (D38, SPEC "Export and import"): the export reads old-model rows, the import loads
 * them into the new tables, is idempotent, and keeps a draft edited since the last import.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { randomBytes } from 'node:crypto'
import { mkdtempSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { prisma } from '../src/lib/prisma.js'
import { runExport } from '../scripts/content-export.js'
import { runImport } from '../scripts/content-import.js'

const url = process.env.DATABASE_URL!
const stamp = randomBytes(4).toString('hex')
const IMAGE = `https://images.test/import-${stamp}.jpg`
const created = { userId: '', orgId: '', programIds: [] as string[] }

const EDITED = {
  schemaVersion: 1, kind: 'text', background: { color: '#123456' },
  content: { type: 'canvas', verticalAnchor: 'top', objects: [] },
  actions: [], chrome: { topAction: 'none' }, fallback: { title: 'Edited', body: 'Edited' },
}

/** Old-model rows for one program: a lesson with a styled READ (splits in two), a USER_INPUT and an EXEGESIS. */
async function seedOldModelDump(opts: { unpublishedEdit?: boolean } = {}) {
  const program = await prisma.studyProgram.create({
    data: {
      name: `Old program ${stamp}`, days: 1, creatorId: created.userId, organizationId: created.orgId,
      isPublished: !opts.unpublishedEdit,
    },
  })
  created.programIds.push(program.id)
  const lesson = await prisma.lesson.create({ data: { studyProgramId: program.id, dayNumber: 1, title: 'Day one' } })
  const readContent = opts.unpublishedEdit ? 'Edited after publish' : 'Original text'
  const read = await prisma.lessonActivity.create({
    data: {
      lessonId: lesson.id, activityType: 'READ', orderNumber: 1, title: 'Read',
      readBlocks: {
        create: [
          { orderNumber: 1, content: readContent },
          { orderNumber: 2, content: 'On a picture', backgroundImageUrl: IMAGE },
        ],
      },
    },
  })
  const write = await prisma.lessonActivity.create({
    data: { lessonId: lesson.id, activityType: 'USER_INPUT', orderNumber: 2, title: 'Respond', helpDescription: 'What now?' },
  })
  const exegesis = await prisma.lessonActivity.create({
    data: {
      lessonId: lesson.id, activityType: 'EXEGESIS', orderNumber: 3, title: 'Romans 1',
      readBlocks: {
        create: [{
          orderNumber: 1, isLocked: true, title: 'Romans 1:1', content: '1 Paul, a servant of Christ Jesus.',
          contentHighlights: { create: [{ orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul' }] },
        }],
      },
    },
  })
  if (opts.unpublishedEdit) {
    // The published snapshot still holds the original text; the live rows above hold the edit.
    const snapshotLesson = {
      id: lesson.id, dayNumber: 1, title: 'Day one', contentHash: 'x',
      activityIds: [read.id, write.id, exegesis.id],
      content: {
        title: 'Day one',
        activities: [
          { type: 'READ', orderNumber: 1, title: 'Read', readBlocks: [
            { orderNumber: 1, content: 'Original text', isLocked: false, contentFormat: 'markdown', exegesisHighlights: [] },
            { orderNumber: 2, content: 'On a picture', isLocked: false, contentFormat: 'markdown', backgroundImageUrl: IMAGE, exegesisHighlights: [] },
          ], sourceReferences: [] },
          { type: 'USER_INPUT', orderNumber: 2, title: 'Respond', helpDescription: 'What now?', readBlocks: [], sourceReferences: [] },
          { type: 'EXEGESIS', orderNumber: 3, title: 'Romans 1', sourceReferences: [], readBlocks: [
            { orderNumber: 1, isLocked: true, title: 'Romans 1:1', content: '1 Paul, a servant of Christ Jesus.', contentFormat: 'markdown',
              exegesisHighlights: [{ orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul' }] },
          ] },
        ],
      },
    }
    await prisma.studyProgramVersion.create({
      data: { studyProgramId: program.id, versionNumber: 1, snapshot: { lessons: [snapshotLesson] }, lessonHashes: {} },
    })
  }
  return { programId: program.id, lessonId: lesson.id, url }
}

async function exportFrom(dump: { url: string }) {
  const out = mkdtempSync(join(tmpdir(), 'content-bundle-'))
  const r = await runExport(dump.url, out, {})
  return r.bundlePath
}

const importedKeys = (programId: string) =>
  prisma.contentActivity.count({ where: { lessonVersion: { lesson: { programId } } } })

describe('content export and import', () => {
  beforeAll(async () => {
    const user = await prisma.user.create({ data: { email: `import-${stamp}@content.test`, name: `Import ${stamp}` } })
    const org = await prisma.organization.create({ data: { name: `Import Org ${stamp}`, ownerId: user.id } })
    created.userId = user.id
    created.orgId = org.id
  })

  afterAll(async () => {
    const lessons = await prisma.lesson.findMany({ where: { studyProgramId: { in: created.programIds } }, select: { id: true } })
    const keys = await prisma.contentActivity.findMany({
      where: { lessonVersion: { lessonId: { in: lessons.map((l) => l.id) } } }, select: { activityKey: true },
    })
    await prisma.studyProgram.updateMany({ where: { id: { in: created.programIds } }, data: { currentVersionId: null } })
    await prisma.programVersionLesson.deleteMany({ where: { lessonId: { in: lessons.map((l) => l.id) } } })
    await prisma.studyProgram.deleteMany({ where: { id: { in: created.programIds } } })
    await prisma.mediaUsage.deleteMany({ where: { resourceId: { in: keys.map((k) => k.activityKey) } } })
    await prisma.media.deleteMany({ where: { organizationId: created.orgId } })
    await prisma.organization.deleteMany({ where: { id: created.orgId } })
    await prisma.user.deleteMany({ where: { id: created.userId } })
  })

  it('imports a published program as version 1 with its lessons, activities and media', async () => {
    const dump = await seedOldModelDump()
    const bundle = await exportFrom(dump)
    const r = await runImport(url, bundle, {})
    expect(r.conflicts).toEqual([])
    expect(r.created).toBe(await importedKeys(dump.programId))
    expect(r.created).toBe(4) // read, picture split, write, exegesis

    const lesson = await prisma.lesson.findUniqueOrThrow({ where: { id: dump.lessonId } })
    expect(lesson).toMatchObject({ programId: dump.programId, position: 1 })
    const versions = await prisma.lessonVersion.findMany({ where: { lessonId: dump.lessonId } })
    expect(versions.map((v) => [v.number, v.status])).toEqual([[1, 'PUBLISHED']])
    const program = await prisma.studyProgram.findUniqueOrThrow({
      where: { id: dump.programId }, include: { currentVersion: { include: { lessons: true } } },
    })
    expect(program.currentVersion?.number).toBe(1)
    expect(program.currentVersion?.lessons.map((l) => l.lessonVersionId)).toEqual([versions[0].id])

    const keys = (await prisma.contentActivity.findMany({ where: { lessonVersionId: versions[0].id }, orderBy: { position: 'asc' } }))
      .map((a) => [a.activityKey.replace(/^[0-9a-f-]{36}/, 'OLD'), a.kind])
    expect(keys).toEqual([['OLD', 'text'], ['OLD:1', 'text'], ['OLD', 'write'], ['OLD', 'bible']])

    const media = await prisma.media.findFirstOrThrow({ where: { url: IMAGE } })
    expect(media.organizationId).toBe(created.orgId)
    expect(await prisma.mediaUsage.count({ where: { mediaId: media.id, usageType: 'ACTIVITY' } })).toBe(1)
  })

  it('import is idempotent', async () => {
    const dump = await seedOldModelDump()
    const bundle = await exportFrom(dump)
    const a = await runImport(url, bundle, {}), b = await runImport(url, bundle, {})
    expect(b.created).toBe(0); expect(b.conflicts).toEqual([])
    expect(await importedKeys(dump.programId)).toBe(a.created)
  })

  it('unpublished edits become the draft beside version 1', async () => {
    const dump = await seedOldModelDump({ unpublishedEdit: true })
    await runImport(url, await exportFrom(dump), {})
    const versions = await prisma.lessonVersion.findMany({ where: { lessonId: dump.lessonId }, orderBy: { number: 'asc' } })
    expect(versions.map((v) => [v.number, v.status])).toEqual([[1, 'PUBLISHED'], [2, 'DRAFT']])
    const read = (versionId: string) =>
      prisma.contentActivity.findFirstOrThrow({ where: { lessonVersionId: versionId, position: 1 } })
    expect(JSON.stringify((await read(versions[0].id)).document)).toContain('Original text')
    expect(JSON.stringify((await read(versions[1].id)).document)).toContain('Edited after publish')
  })

  it('a draft edited after import is kept and reported', async () => {
    const dump = await seedOldModelDump({ unpublishedEdit: true })
    const bundle = await exportFrom(dump)
    await runImport(url, bundle, {})
    const draft = await prisma.contentActivity.findFirstOrThrow({
      where: { lessonVersion: { status: 'DRAFT', lesson: { programId: dump.programId } } },
    })
    await prisma.contentActivity.update({ where: { id: draft.id }, data: { document: EDITED } })
    const r = await runImport(url, bundle, {})
    expect(r.conflicts).toContain(draft.activityKey)
    expect((await prisma.contentActivity.findUniqueOrThrow({ where: { id: draft.id } })).document).toEqual(EDITED)
  })

  it('writes a report with counts by old type and new kind', async () => {
    const dump = await seedOldModelDump()
    const out = mkdtempSync(join(tmpdir(), 'content-report-'))
    await runExport(dump.url, out, {})
    const report = readFileSync(join(out, 'report.md'), 'utf8')
    expect(report).toContain(`Old program ${stamp}`)
    expect(report).toMatch(/Old types: EXEGESIS 1, READ 1, USER_INPUT 1/)
    expect(report).toMatch(/New kinds: bible 1, text 2, write 1/)
    expect(report).toMatch(/split into 2 activities/)
  })

  it('a production URL is refused without the flag', async () => {
    await expect(runImport('postgresql://u:p@db.railway.internal:5432/railway', 'b.json', {})).rejects.toThrow(/--confirm-production/)
    await expect(runExport('postgresql://u:p@db.railway.internal:5432/railway', 'out', {})).rejects.toThrow(/--confirm-production/)
  })
})
