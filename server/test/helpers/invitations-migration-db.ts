import { randomBytes } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

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
  let migrationDir: string | undefined
  try {
    await admin.query(`CREATE DATABASE "${name}"`)
    created = true
    const server = fileURLToPath(new URL('../../', import.meta.url))
    // Materialize the committed prefix: community Atlas has no --to-version flag.
    migrationDir = mkdtempSync(join(tmpdir(), 'invitation-migrations-'))
    const repoPath = 'server/atlas/migrations'
    const entries = execFileSync('git', ['ls-tree', '--name-only', 'HEAD', repoPath + '/'], { cwd: `${server}..`, encoding: 'utf8' }).trim().split('\n')
    const files = entries.filter(path => /\/\d{14}(?:_.+)?\.sql$/.test(path) && path.split('/').pop()!.slice(0, 14) <= LEGACY_INVITATION_REVISION)
    if (!files.some(path => path.split('/').pop()!.startsWith(`${LEGACY_INVITATION_REVISION}_`))) throw new Error('Legacy migration revision missing')
    for (const path of files) writeFileSync(join(migrationDir, path.split('/').pop()!), execFileSync('git', ['show', `HEAD:${path}`], { cwd: `${server}..` }))
    const dir = pathToFileURL(migrationDir).href
    const options = { cwd: `${server}atlas`, stdio: 'pipe' as const, timeout: 120_000 }
    execFileSync(`${server}scripts/atlas.sh`, ['migrate', 'hash', '--dir', dir], options)
    execFileSync(`${server}scripts/atlas.sh`, ['migrate', 'apply', '--url', scratchUrl.href, '--dir', dir], options)
    return await run(scratchUrl.href)
  } finally {
    try {
      if (created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`)
    } finally {
      if (migrationDir) rmSync(migrationDir, { recursive: true, force: true })
      await admin.end()
    }
  }
}
