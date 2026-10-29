/**
 * ui2-enrollment-create SC1 (D4): Enrollment.lessonAccess — a NOT NULL enum column whose DEFAULT
 * 'ALL_AT_ONCE' fills every existing enrollment in the same statement (existing ones stay open).
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { LessonAccess, Prisma } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes('ADD COLUMN "lessonAccess"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 migration', () => {
  it('creates the LessonAccess enum', () => {
    expect(findMigration().sql).toContain(`CREATE TYPE "LessonAccess" AS ENUM ('ONE_AT_A_TIME', 'ALL_AT_ONCE')`)
  })

  it('adds the column NOT NULL with the ALL_AT_ONCE default (the backfill)', () => {
    expect(findMigration().sql).toMatch(
      /ALTER TABLE "enrollments" ADD COLUMN "lessonAccess" "LessonAccess" NOT NULL DEFAULT 'ALL_AT_ONCE'/,
    )
  })

  it('runs no separate UPDATE', () => {
    expect(findMigration().sql).not.toMatch(/UPDATE\s+"enrollments"/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma field and enum', () => {
    expect(Object.keys(Prisma.EnrollmentScalarFieldEnum)).toContain('lessonAccess')
    expect(Object.values(LessonAccess)).toEqual(['ONE_AT_A_TIME', 'ALL_AT_ONCE'])
  })
})
