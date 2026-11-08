/**
 * text-activity Task 19 (D27, D30, D42): the table drop exists only under atlas/cutover/, and it applies cleanly to a
 * database that has every committed migration plus an import run.
 */
import { randomBytes } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { cpSync, mkdtempSync, readdirSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { PrismaClient } from '../src/generated/prisma/index.js'
import { runExport } from '../scripts/content-export.js'
import { runImport } from '../scripts/content-import.js'
import { withMigratedScratchDb } from './helpers/master-search-db.js'
import { seedOldModelDump, seedOwner } from './helpers/old-model-dump.js'

const SERVER = fileURLToPath(new URL('../', import.meta.url))
const MIGRATIONS = join(SERVER, 'atlas/migrations')
const CUTOVER = join(SERVER, 'atlas/cutover')

const readAllMigrations = () =>
  readdirSync(MIGRATIONS).filter((f) => f.endsWith('.sql')).map((f) => readFileSync(join(MIGRATIONS, f), 'utf8')).join('\n')
const readCutover = () =>
  readdirSync(CUTOVER).filter((f) => f.endsWith('.sql')).map((f) => readFileSync(join(CUTOVER, f), 'utf8')).join('\n')

/**
 * Applies the cutover exactly as CUTOVER.md steps 7-8 do: the file moved into the migrations directory, `migrate hash`,
 * then `migrate apply` (atlas runs each file in its own transaction). A copy of the directory, so the repo stays as is.
 */
function applyCutoverWithAtlas(url: string): void {
  const dir = mkdtempSync(join(tmpdir(), 'cutover-migrations-'))
  cpSync(MIGRATIONS, dir, { recursive: true })
  for (const f of readdirSync(CUTOVER).filter((f) => f.endsWith('.sql'))) cpSync(join(CUTOVER, f), join(dir, f))
  const atlas = (args: string[]) =>
    execFileSync(join(SERVER, 'scripts/atlas.sh'), args, { cwd: join(SERVER, 'atlas'), stdio: 'pipe', timeout: 180_000 })
  atlas(['migrate', 'hash', '--dir', `file://${dir}`])
  atlas(['migrate', 'apply', '--url', `${url}?sslmode=disable`, '--dir', `file://${dir}`])
}

describe('cutover drop (static)', () => {
  it('the drop lives only under cutover/', () => {
    const live = readAllMigrations()
    expect(live).not.toMatch(/DROP TABLE[^;]*"(lesson_activities|lesson_schedules|text_themes|enrollment_sync_runs)"/)
    expect(readCutover()).toMatch(/DROP TABLE[^;]*"lesson_activities"/)
  })

  it('drops every removed model, one statement per table, and the old columns and enum', () => {
    const sql = readCutover()
    for (const t of [
      'lesson_activities', 'scheduled_lesson_activities', 'activity_read_blocks', 'content_highlights', 'activity_source_references',
      'text_themes', 'lesson_schedules', 'lesson_schedule_versions', 'member_activity_progress', 'member_video_progress',
      'member_lesson_progress', 'study_program_versions', 'enrollment_sync_runs',
    ]) expect(sql).toMatch(new RegExp(`DROP TABLE "${t}" CASCADE;`))
    expect(sql).toContain('DROP TYPE IF EXISTS "TemplateActivityType";')
  })

  it('leaves the transaction to atlas: no BEGIN or COMMIT of its own', () => {
    const sql = readCutover()
    expect(sql).not.toMatch(/^\s*(BEGIN|COMMIT|ROLLBACK)\b/im)
  })
})

describe('cutover drop (live)', () => {
  it('the cutover applies through atlas migrate apply to a migrated and imported database', async () => {
    await withMigratedScratchDb(async (url) => {
      const stamp = randomBytes(4).toString('hex')
      const { Client } = await import('pg')
      const pg = new Client({ connectionString: url })
      await pg.connect()
      const c = new PrismaClient({ datasourceUrl: url })
      try {
        const owner = await seedOwner(pg, stamp)
        const dump = await seedOldModelDump(pg, owner, stamp, `https://images.test/cutover-${stamp}.jpg`)
        // A lesson that was never imported (no program) and rows D42 deletes.
        await pg.query(`INSERT INTO "lessons" ("updatedAt") VALUES (now())`)
        await pg.query(`INSERT INTO "client_events" ("id", "eventType", "occurredAt", "lessonScheduleId") VALUES (gen_random_uuid(), 'LESSON_OPENED', now(), $1)`, [dump.lessonId])

        const out = mkdtempSync(join(tmpdir(), 'cutover-bundle-'))
        const bundle = (await runExport(url, out, {})).bundlePath
        await runImport(url, bundle, {})

        // An enrollment with an enrollment-owned version and a schedule on it (RESTRICT against the enrollment cascade).
        const group = await c.group.create({ data: { name: `G ${stamp}`, code: `g-${stamp}`, creatorId: owner.userId, organizationId: owner.orgId } })
        const enrollment = await c.enrollment.create({
          data: { groupId: group.id, studyProgramId: dump.programId, startDate: new Date(), endDate: new Date(), enabledDays: '[]' },
        })
        const enrolledVersion = await c.lessonVersion.create({
          data: { lessonId: dump.lessonId, enrollmentId: enrollment.id, number: 1, status: 'PUBLISHED', title: 'Customized' },
        })
        await c.scheduledLesson.create({
          data: { enrollmentId: enrollment.id, lessonId: dump.lessonId, currentVersionId: enrolledVersion.id, scheduledDate: new Date() },
        })

        applyCutoverWithAtlas(url)
        const revision = await pg.query(`SELECT version FROM atlas_schema_revisions.atlas_schema_revisions WHERE version = '20261107233000'`)
        expect(revision.rows).toHaveLength(1)
        expect(await c.enrollment.count()).toBe(0)
        expect(await c.scheduledLesson.count()).toBe(0)
        expect(await c.lessonVersion.count({ where: { enrollmentId: { not: null } } })).toBe(0)

        expect(await c.contentActivity.count()).toBeGreaterThan(0)
        expect(await c.lesson.count()).toBe(1)
        expect(await c.lesson.count({ where: { id: dump.lessonId, programId: dump.programId, position: 1 } })).toBe(1)
        expect(await c.clientEvent.count()).toBe(0)
        const program = await c.studyProgram.findUniqueOrThrow({ where: { id: dump.programId }, include: { currentVersion: true } })
        expect(program.currentVersion?.number).toBe(1)

        const gone = await pg.query(
          `SELECT table_name FROM information_schema.tables WHERE table_name = ANY($1)`,
          [['lesson_activities', 'lesson_schedules', 'text_themes', 'enrollment_sync_runs', 'study_program_versions']],
        )
        expect(gone.rows).toEqual([])
        const columns = await pg.query(`SELECT column_name FROM information_schema.columns WHERE table_name = 'lessons'`)
        expect(columns.rows.map((r) => r.column_name)).not.toContain('studyProgramId')
        const nullable = await pg.query(
          `SELECT is_nullable FROM information_schema.columns WHERE table_name = 'lessons' AND column_name = 'programId'`,
        )
        expect(nullable.rows[0].is_nullable).toBe('NO')
      } finally {
        await c.$disconnect()
        await pg.end()
      }
    })
  }, 240_000)
})
