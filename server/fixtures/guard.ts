/**
 * Safety guard (SPEC ui2-fixtures D8): the runner deletes rows, so it refuses
 * unless NODE_ENV is development or test AND every database URL it will use
 * (DATABASE_URL, and DIRECT_URL when set — Prisma and the analytics pool
 * prefer it) points at a local host. Pure: the env is passed in.
 *
 * One more way through (staging-fixtures D8, F6): FIXTURES_TARGET=staging with
 * DATABASE_URL and DIRECT_URL both set and each URL's host:port equal to
 * FIXTURES_STAGING_DB_ENDPOINT (which must include a port — Railway proxies
 * share hostnames and differ by port). NODE_ENV is still checked first, and on
 * this path the local host list is not consulted.
 */

export const ALLOWED_NODE_ENVS: readonly string[] = ['development', 'test']
export const ALLOWED_DB_HOSTS: readonly string[] = ['postgres', 'localhost', '127.0.0.1']

export type GuardResult = { ok: true } | { ok: false; reason: string }

export function checkGuard(env: Record<string, string | undefined>): GuardResult {
  const nodeEnv = env.NODE_ENV
  if (!nodeEnv || !ALLOWED_NODE_ENVS.includes(nodeEnv)) {
    return { ok: false, reason: `NODE_ENV is "${nodeEnv ?? ''}" — fixtures run only when NODE_ENV is development or test` }
  }
  if (env.FIXTURES_TARGET === 'staging') {
    // Only the staging rule decides here; the local host list never admits a staging run.
    const endpoint = env.FIXTURES_STAGING_DB_ENDPOINT
    if (!endpoint || !/:\d+$/.test(endpoint)) {
      return { ok: false, reason: 'FIXTURES_STAGING_DB_ENDPOINT must be host:port' }
    }
    for (const name of ['DATABASE_URL', 'DIRECT_URL']) {
      const value = env[name]
      if (!value) return { ok: false, reason: `${name} is not set` }
      let host: string
      try {
        // postgresql: is a non-special scheme, so URL.host keeps the port as typed.
        host = new URL(value).host
      } catch {
        return { ok: false, reason: `${name} is not a valid URL` }
      }
      if (host !== endpoint) return { ok: false, reason: `${name} endpoint "${host}" is not the staging endpoint` }
    }
    return { ok: true }
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
