/**
 * image-framing-editor SC1–SC2: two nullable Member columns in ONE Atlas migration, no backfill
 * (every member reads null and uses D5's fallback).
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
    .filter((m) => m.sql.includes('"profilePictureOriginalUrl"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1–SC2 migration', () => {
  it('adds both columns as nullable to members', () => {
    const { sql } = findMigration()
    expect(sql).toContain('ALTER TABLE "members"')
    expect(sql).toContain('ADD COLUMN "profilePictureOriginalUrl" text NULL')
    expect(sql).toContain('ADD COLUMN "profilePictureFraming" jsonb NULL')
  })

  it('touches nothing else and backfills nothing', () => {
    const { sql } = findMigration()
    expect(sql).not.toMatch(/UPDATE\s+"members"/)
    expect(sql).not.toMatch(/DROP|ALTER COLUMN/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates both Prisma fields', () => {
    const fields = Object.keys(Prisma.MemberScalarFieldEnum)
    expect(fields).toContain('profilePictureOriginalUrl')
    expect(fields).toContain('profilePictureFraming')
  })
})
