import { randomBytes } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

/** Only a live Builder lease, never its template, administration DB or human DB. */
export function assertInvitationTestDatabase(value: string | undefined): string {
  if (!value) throw new Error('Invitation tests require a leased TEST_DATABASE_URL')
  const url = new URL(value)
  if (!['postgres:', 'postgresql:'].includes(url.protocol) ||
      !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) ||
      url.port !== '5434' || !/^\/postgres_vt_\d+_\d+$/.test(url.pathname) ||
      url.search || url.hash) {
    throw new Error('Invitation tests refuse a non-loopback or non-verifier lease URL')
  }
  return value
}

// Freeze the predecessor revision: later migrations must never enter the old-schema seed DB.
export const LEGACY_INVITATION_REVISION = '20261102040206'

/** Creates and drops exactly one owned DB. No cleanup ever targets the parent lease. */
export async function withInvitationMigrationDb<T>(run: (url: string) => Promise<T>): Promise<T> {
  const parent = assertInvitationTestDatabase(process.env.TEST_DATABASE_URL)
  const name = `postgres_vt_invites_${process.pid}_${randomBytes(6).toString('hex')}`
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
    const server = fileURLToPath(new URL('../../', import.meta.url))
    execFileSync(`${server}scripts/atlas.sh`, ['migrate', 'apply', '--url', scratchUrl.href,
      '--dir', `file://${server}atlas/migrations`, '--to-version', LEGACY_INVITATION_REVISION],
    { cwd: `${server}atlas`, stdio: 'pipe', timeout: 120_000 })
    return await run(scratchUrl.href)
  } finally {
    try {
      if (created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`)
    } finally { await admin.end() }
  }
}
