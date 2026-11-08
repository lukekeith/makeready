/**
 * text-activity Task 18 (D38, SPEC "Export and import"): the export reads old-model rows, the import loads
 * them into the new tables, is idempotent, and keeps a draft edited since the last import.
 * Runs on an atlas-migrated scratch database (Task 19): the old tables exist there as raw tables only.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { randomBytes } from 'node:crypto'
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { PrismaClient } from '../src/generated/prisma/index.js'
import { runExport } from '../scripts/content-export.js'
import { runImport } from '../scripts/content-import.js'
import { withMigratedScratchDb } from './helpers/master-search-db.js'
import { seedOldModelDump as seedOld, seedOwner, seedSnapshotScripture as seedSnapshot, type Owner } from './helpers/old-model-dump.js'

const stamp = randomBytes(4).toString('hex')
const IMAGE = `https://images.test/import-${stamp}.jpg`
let url = ''
let prisma: PrismaClient
let pg: import('pg').Client
let owner: Owner
let release: () => void = () => {}
let held: Promise<unknown> = Promise.resolve()

const EDITED = {
  schemaVersion: 1, kind: 'text', background: { color: '#123456' },
  content: { type: 'canvas', verticalAnchor: 'top', objects: [] },
  actions: [], chrome: { topAction: 'none' }, fallback: { title: 'Edited', body: 'Edited' },
}

const seedOldModelDump = async (opts: { unpublishedEdit?: boolean } = {}) => ({ ...(await seedOld(pg, owner, stamp, IMAGE, opts)), url })

async function exportFrom(dump: { url: string }) {
  const out = mkdtempSync(join(tmpdir(), 'content-bundle-'))
  const r = await runExport(dump.url, out, {})
  return r.bundlePath
}

const importedKeys = (programId: string) =>
  prisma.contentActivity.count({ where: { lessonVersion: { lesson: { programId } } } })

describe('content export and import', () => {
  beforeAll(async () => {
    await new Promise<void>((ready, fail) => {
      held = withMigratedScratchDb(async (scratch) => {
        url = scratch
        prisma = new PrismaClient({ datasourceUrl: url })
        const { Client } = await import('pg')
        pg = new Client({ connectionString: url })
        await pg.connect()
        owner = await seedOwner(pg, stamp)
        ready()
        await new Promise<void>((r) => { release = r })
      }).catch(fail)
    })
  }, 240_000)

  afterAll(async () => {
    await prisma?.$disconnect()
    await pg?.end()
    release()
    await held
  }, 60_000)

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
    expect(media.organizationId).toBe(owner.orgId)
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

  const seedSnapshotScripture = async () => ({ ...(await seedSnapshot(pg, owner, stamp)), url })

  it('a snapshot scripture block keeps its passages and does not spawn a spurious draft', async () => {
    const dump = await seedSnapshotScripture()
    const bundle = await exportFrom(dump)
    await runImport(url, bundle, {})
    const versions = await prisma.lessonVersion.findMany({ where: { lessonId: dump.lessonId } })
    expect(versions.map((v) => [v.number, v.status])).toEqual([[1, 'PUBLISHED']])
    const bible = await prisma.contentActivity.findFirstOrThrow({ where: { lessonVersionId: versions[0].id, kind: 'bible' } })
    expect((bible.document as any).content.passages).toEqual([
      { bookNumber: 45, chapterStart: 1, verseStart: 1, chapterEnd: 1, verseEnd: 1 },
    ])
  })

  it('warns when a re-run has no ledger beside the bundle, and not when --ledger points at the first one', async () => {
    const dump = await seedOldModelDump()
    const first = mkdtempSync(join(tmpdir(), 'content-first-'))
    const firstBundle = (await runExport(dump.url, first, {})).bundlePath
    // The test DB holds every other test's programs too; keep only this dump's so the warning counts this run's bundle.
    const narrow = (path: string) => {
      const b = JSON.parse(readFileSync(path, 'utf8'))
      b.programs = b.programs.filter((p: { id: string }) => p.id === dump.programId)
      writeFileSync(path, JSON.stringify(b))
      return path
    }
    narrow(firstBundle)
    const a = await runImport(url, firstBundle, {})
    expect(a.warnings).toEqual([])
    const second = narrow(await exportFrom(dump)) // different directory, so no ledger beside it
    const b = await runImport(url, second, {})
    expect(b.warnings.join(' ')).toMatch(/no ledger/)
    const c = await runImport(url, second, { ledgerPath: join(first, 'import-ledger.json') })
    expect(c.warnings).toEqual([])
  })

  it('lists every lesson of a program missing from the target, in the result and the report', async () => {
    const dump = await seedOldModelDump()
    const bundlePath = await exportFrom(dump)
    const b = JSON.parse(readFileSync(bundlePath, 'utf8'))
    const missing = '00000000-0000-4000-8000-000000000000'
    b.programs = b.programs.filter((p: { id: string }) => p.id === dump.programId).map((p: object) => ({ ...p, id: missing }))
    writeFileSync(bundlePath, JSON.stringify(b))
    const r = await runImport(url, bundlePath, {})
    const line = r.skipped.find((s) => s.startsWith(`lesson ${dump.lessonId}`))
    expect(line).toContain(`program ${missing} is not in the target database`)
    expect(line).toContain('the cutover deletes it')
    const report = readFileSync(join(bundlePath, '..', 'import-report.md'), 'utf8')
    expect(report).toContain(`- lesson ${dump.lessonId}`)
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
