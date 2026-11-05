import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest'
import { assertSearchLease, withEmptySearchDb, withTextIdSearchDb } from './helpers/master-search-db.js'

const migrations = fileURLToPath(new URL('../atlas/migrations/', import.meta.url))
function readMigration(suffix: string) {
  const files = readdirSync(migrations).filter(name => name.endsWith(suffix))
  expect(files).toHaveLength(1)
  return readFileSync(migrations + files[0], 'utf8')
}
const searchId = (n: number) => `a3300000-0000-4000-8000-${String(n).padStart(12, '0')}`

async function withScratchUsersTable(idType: 'text' | 'uuid', run: (client: import('pg').Client) => Promise<void>) {
  await withEmptySearchDb(async url => {
    const { Client } = await import('pg')
    const client = new Client({ connectionString: url })
    await client.connect()
    try {
      await client.query(`CREATE TABLE "users" ("id" ${idType} PRIMARY KEY)`)
      await run(client)
    } finally { await client.end() }
  })
}

describe.skipIf(!process.env.TEST_DATABASE_URL)('master-search recents table', () => {
  let prisma: any
  let owner: { id: string }

  beforeAll(async () => {
    assertSearchLease()
    prisma = (await import('../src/lib/prisma.js')).prisma
  })
  beforeEach(async () => {
    await prisma.searchRecentResult.deleteMany({ where: { userId: { in: [searchId(900), searchId(901)] } } })
    await prisma.user.deleteMany({ where: { id: { in: [searchId(900), searchId(901)] } } })
    owner = await prisma.user.create({ data: { id: searchId(900), name: 'Owner', email: 'ms-owner@example.invalid' } })
  })
  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: [searchId(900), searchId(901)] } } })
  })

  it('the migration takes uuid on a migrations-only database', async () => {
    const [row] = await prisma.$queryRaw<{ user: string; recent: string }[]>`
      SELECT format_type(u.atttypid, u.atttypmod) AS user, format_type(r.atttypid, r.atttypmod) AS recent
      FROM pg_attribute u, pg_attribute r
      WHERE u.attrelid = '"users"'::regclass AND u.attname = 'id'
        AND r.attrelid = '"search_recent_results"'::regclass AND r.attname = 'userId'`
    expect(row.recent).toBe(row.user)
  })

  it('the migration takes text where users.id is text', async () => {
    await withScratchUsersTable('text', async (client) => {
      await client.query(readMigration('_master_search_recents.sql'))
      const r = await client.query(`SELECT format_type(atttypid, atttypmod) t FROM pg_attribute WHERE attrelid = '"search_recent_results"'::regclass AND attname = 'userId'`)
      expect(r.rows[0].t).toBe('text')
    })
  }, 60000)

  it('the text-id scratch database has a text users.id', async () => {
    await withTextIdSearchDb(async url => {
      const { Client } = await import('pg')
      const client = new Client({ connectionString: url })
      await client.connect()
      try {
        const r = await client.query(`SELECT format_type(atttypid, atttypmod) t FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id'`)
        expect(r.rows[0].t).toBe('text')
      } finally { await client.end() }
    })
  }, 180000)

  it('deleting a user cascades to their recents', async () => {
    const user = await prisma.user.create({ data: { id: searchId(901), name: 'Gone', email: 'gone@example.invalid' } })
    await prisma.searchRecentResult.create({ data: { userId: user.id, resourceType: 'GROUP', resourceId: 'g1' } })
    await prisma.user.delete({ where: { id: user.id } })
    expect(await prisma.searchRecentResult.count({ where: { userId: user.id } })).toBe(0)
  })

  it('a second row for one resource is refused', async () => {
    const data = { userId: owner.id, resourceType: 'GROUP', resourceId: 'g1' }
    await prisma.searchRecentResult.create({ data })
    await expect(prisma.searchRecentResult.create({ data })).rejects.toMatchObject({ code: 'P2002' })
  })
})
