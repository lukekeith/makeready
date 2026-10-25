/**
 * Safety guard (SPEC ui2-fixtures D8): the runner deletes rows, so it refuses
 * unless NODE_ENV is development or test AND every database URL it will use
 * (DATABASE_URL, and DIRECT_URL when set — Prisma and the analytics pool
 * prefer it) points at a local host. Pure: the env is passed in.
 */

export const ALLOWED_NODE_ENVS: readonly string[] = ['development', 'test']
export const ALLOWED_DB_HOSTS: readonly string[] = ['postgres', 'localhost', '127.0.0.1']

export type GuardResult = { ok: true } | { ok: false; reason: string }

export function checkGuard(env: Record<string, string | undefined>): GuardResult {
  const nodeEnv = env.NODE_ENV
  if (!nodeEnv || !ALLOWED_NODE_ENVS.includes(nodeEnv)) {
    return { ok: false, reason: `NODE_ENV is "${nodeEnv ?? ''}" — fixtures run only when NODE_ENV is development or test` }
  }
  if (!env.DATABASE_URL) {
    return { ok: false, reason: 'DATABASE_URL is not set' }
  }
  for (const name of ['DATABASE_URL', 'DIRECT_URL']) {
    const value = env[name]
    if (!value) continue
    let host: string
    try {
      host = new URL(value).hostname
    } catch {
      return { ok: false, reason: `${name} is not a valid URL` }
    }
    if (!ALLOWED_DB_HOSTS.includes(host)) {
      return { ok: false, reason: `${name} host "${host}" is not local (allowed: ${ALLOWED_DB_HOSTS.join(', ')})` }
    }
  }
  return { ok: true }
}
