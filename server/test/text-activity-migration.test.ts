/**
 * text-activity SC1 + SC13 (D27, D30, D31): the new model's tables are created with ids typed as
 * "users"."id" is, no migration drops an old table, and the hand-managed partial unique index admits
 * exactly one DRAFT per (lessonId, enrollmentId) with NULL colliding with NULL.
 */
import { randomUUID } from 'node:crypto'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { assertSearchLease } from './helpers/master-search-db.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))

function allMigrations(): { file: string; sql: string }[] {
  return readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
}

function findMigration(needle: string): string {
  const hits = allMigrations().filter((m) => m.sql.includes(needle))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0].sql
}

function readAllMigrations(): string {
  return allMigrations().map((m) => m.sql).join('\n')
}

describe('SC1 text-activity tables (static)', () => {
  it('wraps every new table in the id_type DO-block', () => {
    const sql = findMigration('CREATE TABLE "lesson_versions"')
    for (const t of ['lesson_versions', 'content_activities', 'program_versions', 'program_version_lessons', 'scheduled_lessons', 'lesson_progress', 'activity_progress'])
      expect(sql).toContain(`CREATE TABLE "${t}"`)
    expect(sql).toMatch(/format_type\(atttypid, atttypmod\) INTO id_type/)
    expect(sql).not.toMatch(/"(lessonId|lessonVersionId|enrollmentId|programId|scheduledLessonId|currentVersionId)" uuid/)
  })

  it('no migration drops an old table', () => {
    const all = readAllMigrations()
    expect(all).not.toMatch(/DROP TABLE[^;]*"(lesson_activities|lesson_schedules|text_themes|study_program_versions)"/)
  })
})

// The index lives only in the atlas-migrated lease (CI's `prisma db push` lacks it — F13), so these
// run through a dedicated client. FK triggers are switched off for the seed rows: the unique indexes
// under test are not triggers, and a real enrollment would drag in orgs, groups and programs.
describe('SC13 one-draft index (live)', () => {
  type Pg = import('pg').Client
  let client: Pg
  const lessonIds: string[] = []

  beforeAll(async () => {
    const { Client } = await import('pg')
    client = new Client({ connectionString: assertSearchLease() })
    await client.connect()
    await client.query("SET session_replication_role = 'replica'")
  })

  afterAll(async () => {
    if (!client) return
    if (lessonIds.length) {
      await client.query('DELETE FROM "lesson_versions" WHERE "lessonId" = ANY($1)', [lessonIds])
      await client.query('DELETE FROM "lessons" WHERE "id" = ANY($1)', [lessonIds])
    }
    await client.end()
  })

  async function seedLesson() {
    const lessonId = randomUUID()
    await client.query('INSERT INTO "lessons" ("id", "updatedAt") VALUES ($1, now())', [lessonId])
    lessonIds.push(lessonId)
    return { lessonId }
  }

  async function seedLessonWithEnrollment() {
    return { ...(await seedLesson()), enrollmentId: randomUUID() }
  }

  async function insertVersion(v: { lessonId: string; enrollmentId: string | null; number: number; status: 'DRAFT' | 'PUBLISHED' }) {
    return client.query(
      'INSERT INTO "lesson_versions" ("id", "lessonId", "enrollmentId", "number", "status", "updatedAt") VALUES ($1, $2, $3, $4, $5, now())',
      [randomUUID(), v.lessonId, v.enrollmentId, v.number, v.status],
    )
  }

  it('refuses a second program draft for one lesson', async () => {
    const { lessonId } = await seedLesson()
    await insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'DRAFT' })
    await expect(insertVersion({ lessonId, enrollmentId: null, number: 2, status: 'DRAFT' })).rejects.toMatchObject({ code: '23505' })
  })

  it('allows a program draft beside a group draft, and a draft beside published versions', async () => {
    const { lessonId, enrollmentId } = await seedLessonWithEnrollment()
    await insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'PUBLISHED' })
    await insertVersion({ lessonId, enrollmentId: null, number: 2, status: 'DRAFT' })
    await expect(insertVersion({ lessonId, enrollmentId, number: 1, status: 'DRAFT' })).resolves.toBeDefined()
  })

  it('refuses a duplicate version number with a NULL enrollment', async () => {
    const { lessonId } = await seedLesson()
    await insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'PUBLISHED' })
    await expect(insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'PUBLISHED' })).rejects.toMatchObject({ code: '23505' })
  })
})
