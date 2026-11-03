import { randomBytes } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { assertInvitationTestDatabase } from './invitations-migration-db.js'

/** Only a live Builder lease: returns TEST_DATABASE_URL once the invitation guard accepts it. */
export function assertSearchLease(): string {
  return assertInvitationTestDatabase(process.env.TEST_DATABASE_URL)
}

async function withScratchDatabase<T>(label: string, setup: (url: string) => void, run: (url: string) => Promise<T>): Promise<T> {
  const parent = assertSearchLease()
  const name = `postgres_vt_${label}_${process.pid}_${randomBytes(6).toString('hex')}`
  const adminUrl = new URL(parent)
  adminUrl.pathname = '/postgres'
  const scratchUrl = new URL(parent)
  scratchUrl.pathname = `/${name}`
  const { Client } = await import('pg')
  const admin = new Client({ connectionString: adminUrl.href })
  await admin.connect()
  let created = false
  try {
    await admin.query(`CREATE DATABASE "${name}"`)
    created = true
    setup(scratchUrl.href)
    return await run(scratchUrl.href)
  } finally {
    try {
      if (created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`)
    } finally {
      await admin.end()
    }
  }
}

/** A scratch database whose ids are text, built by `prisma db push` (User.id is a plain String). */
export function withTextIdSearchDb<T>(run: (url: string) => Promise<T>): Promise<T> {
  return withScratchDatabase('search', url => {
    const server = fileURLToPath(new URL('../../', import.meta.url))
    const env = { ...process.env, DATABASE_URL: url, DIRECT_URL: url }
    execFileSync('psql', [url, '-c', 'CREATE EXTENSION IF NOT EXISTS vector'], { cwd: server, env, stdio: 'pipe', timeout: 60_000 })
    execFileSync('npx', ['--no-install', 'prisma', 'db', 'push', '--skip-generate'], { cwd: server, env, stdio: 'pipe', timeout: 120_000 })
  }, run)
}

/** An empty scratch database, for tests that build their own tables. */
export function withEmptySearchDb<T>(run: (url: string) => Promise<T>): Promise<T> {
  return withScratchDatabase('searchempty', () => {}, run)
}
