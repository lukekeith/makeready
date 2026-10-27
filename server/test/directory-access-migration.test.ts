/**
 * ui2-groups-browse SC1 / D11: the DirectoryAccess enum + Group.memberDirectoryAccess column ship
 * in ONE Atlas migration that backfills NOT_ALLOWED from the Boolean memberDirectoryEnabled.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { DirectoryAccess } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))
const ADD_COLUMN = 'ADD COLUMN "memberDirectoryAccess" "DirectoryAccess" NOT NULL DEFAULT \'ALLOWED\''
const BACKFILL = 'UPDATE "groups" SET "memberDirectoryAccess" = \'NOT_ALLOWED\' WHERE "memberDirectoryEnabled" = false;'

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes('"memberDirectoryAccess"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 migration (D11)', () => {
  it('creates the enum and the NOT NULL column with default ALLOWED', () => {
    const { sql } = findMigration()
    expect(sql).toContain('CREATE TYPE "DirectoryAccess" AS ENUM (\'ALLOWED\', \'NAMES_ONLY\', \'NOT_ALLOWED\')')
    expect(sql).toContain(ADD_COLUMN)
  })

  it('backfills NOT_ALLOWED where the Boolean is off, after the column exists', () => {
    const { sql } = findMigration()
    expect(sql).toContain(BACKFILL)
    expect(sql.indexOf(BACKFILL)).toBeGreaterThan(sql.indexOf(ADD_COLUMN))
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma enum with the three values', () => {
    expect(Object.values(DirectoryAccess)).toEqual(['ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED'])
  })
})
