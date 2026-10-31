/**
 * media-page SC1 / D4: Media.takenAt ships in ONE Atlas migration that adds the nullable column and
 * backfills it from exifData.dateTaken with a guarded cast, then nulls values out of bounds.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { Prisma } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))
const ADD_COLUMN = 'ALTER TABLE "media" ADD COLUMN "takenAt" timestamp NULL'
const BACKFILL =
  `UPDATE "media" SET "takenAt" = CASE WHEN "exifData"->>'dateTaken' ~ '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}' THEN ("exifData"->>'dateTaken')::timestamptz END WHERE "takenAt" IS NULL AND "exifData" ? 'dateTaken';`
const BOUNDS =
  `UPDATE "media" SET "takenAt" = NULL WHERE "takenAt" < '1990-01-01' OR "takenAt" > now() + interval '24 hours';`

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes(ADD_COLUMN))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 migration (D4)', () => {
  it('adds the nullable takenAt column', () => {
    expect(findMigration().sql).toContain(ADD_COLUMN)
  })

  it('backfills from exifData.dateTaken with a guarded cast, after the column exists', () => {
    const { sql } = findMigration()
    expect(sql).toContain(BACKFILL)
    expect(sql.indexOf(BACKFILL)).toBeGreaterThan(sql.indexOf(ADD_COLUMN))
  })

  it('nulls backfilled values outside 1990-01-01 … now + 24 h, after the backfill', () => {
    const { sql } = findMigration()
    expect(sql).toContain(BOUNDS)
    expect(sql.indexOf(BOUNDS)).toBeGreaterThan(sql.indexOf(BACKFILL))
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma field', () => {
    expect(Object.values(Prisma.MediaScalarFieldEnum)).toContain('takenAt')
  })
})
