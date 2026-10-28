/**
 * group-cover-image SC1–SC2: two nullable Group columns in ONE Atlas migration, no backfill
 * (existing groups read null and use D7's fallback).
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
    .filter((m) => m.sql.includes('ALTER TABLE "groups" ADD COLUMN "coverOriginalUrl"'))  // not the programs column (ui2-programs)
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1–SC2 migration', () => {
  it('adds both columns as nullable to groups', () => {
    const { sql } = findMigration()
    expect(sql).toContain('ALTER TABLE "groups"')
    expect(sql).toContain('ADD COLUMN "coverOriginalUrl" text NULL')
    expect(sql).toContain('ADD COLUMN "coverFraming" jsonb NULL')
  })

  it('backfills nothing', () => {
    const { sql } = findMigration()
    expect(sql).not.toMatch(/UPDATE\s+"groups"/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates both Prisma fields', () => {
    const fields = Object.keys(Prisma.GroupScalarFieldEnum)
    expect(fields).toContain('coverOriginalUrl')
    expect(fields).toContain('coverFraming')
  })
})
