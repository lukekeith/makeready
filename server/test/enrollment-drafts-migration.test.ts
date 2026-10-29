/**
 * ui2-enrollments-browse SC1 (D2, D6, D19): enrollment_drafts — group + program required (CASCADE),
 * every checklist field nullable, creator/updater SET NULL, one draft per (group, program).
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { Prisma } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes('CREATE TABLE "enrollment_drafts"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 enrollment_drafts migration', () => {
  // The id columns take "users"."id"'s real type (text on the Prisma-era dev/prod schema, uuid on a
  // migrations-only database) — the 20261028080040 precedent; a literal uuid failed on dev with 42804.
  it('creates the table with the two required keys typed as "users"."id" is', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/format_type\(atttypid, atttypmod\) INTO id_type/)
    expect(sql).toMatch(/"groupId" %1\$s NOT NULL/)
    expect(sql).toMatch(/"studyProgramId" %1\$s NOT NULL/)
    expect(sql).not.toMatch(/"(groupId|studyProgramId|createdById|updatedById)" uuid/)
  })

  it('makes every checklist field nullable with the SC1 types', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/"startDate" character varying NULL/)
    expect(sql).toMatch(/"enabledDays" jsonb NULL/)
    expect(sql).toMatch(/"overriddenDates" jsonb NULL/)
    expect(sql).toMatch(/"scheduleDates" jsonb NULL/)
    expect(sql).toMatch(/"smsTime" character varying NULL/)
    expect(sql).toMatch(/"timezone" character varying NULL/)
    expect(sql).toMatch(/"syncMode" "EnrollmentSyncMode" NULL/)
    expect(sql).toMatch(/"lessonAccess" "LessonAccess" NULL/)
  })

  it('cascades from group and program and nulls the creator/updater on user delete', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/FOREIGN KEY \("groupId"\) REFERENCES (?:"public"\.)?"groups" \("id"\) ON UPDATE NO ACTION ON DELETE CASCADE/)
    expect(sql).toMatch(/FOREIGN KEY \("studyProgramId"\) REFERENCES (?:"public"\.)?"study_programs" \("id"\) ON UPDATE NO ACTION ON DELETE CASCADE/)
    expect(sql).toMatch(/FOREIGN KEY \("createdById"\) REFERENCES (?:"public"\.)?"users" \("id"\) ON UPDATE NO ACTION ON DELETE SET NULL/)
    expect(sql).toMatch(/FOREIGN KEY \("updatedById"\) REFERENCES (?:"public"\.)?"users" \("id"\) ON UPDATE NO ACTION ON DELETE SET NULL/)
  })

  it('holds one draft per (group, program) and adds no separate groupId index', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/UNIQUE \("groupId", "studyProgramId"\)/)
    expect(sql).not.toMatch(/CREATE INDEX "[^"]*" ON (?:"public"\.)?"enrollment_drafts" \("groupId"\)/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma model', () => {
    expect(Object.keys(Prisma.EnrollmentDraftScalarFieldEnum)).toEqual([
      'id', 'groupId', 'studyProgramId', 'startDate', 'enabledDays', 'overriddenDates', 'scheduleDates',
      'smsTime', 'timezone', 'syncMode', 'lessonAccess', 'createdById', 'updatedById', 'createdAt', 'updatedAt',
    ])
  })
})
