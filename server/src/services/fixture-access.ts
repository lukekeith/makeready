/**
 * Fixture access: the gate for the staging fixture routes (C1 login, C2 reset),
 * the fixture-to-email map, and the GitHub workflow dispatch behind C2.
 *
 * Must not import from server/fixtures/ - the API image has no fixtures/ directory.
 */
import { createHash, timingSafeEqual } from 'node:crypto'
import { z } from 'zod'

type Env = Record<string, string | undefined>

const sha256 = (value: string) => createHash('sha256').update(value).digest()

/** True only with the flag on, a non-empty server key, and a matching header (constant time over digests). */
export function fixtureGateOpen(header: string | undefined, env: Env): boolean {
  if (env.FIXTURE_LOGIN_ENABLED !== 'true') return false
  const serverKey = env.FIXTURE_ACCESS_KEY
  if (!serverKey || !header) return false
  return timingSafeEqual(sha256(header), sha256(serverKey))
}

export const fixtureBodySchema = z.object({
  fixture: z.enum(['full', 'new-group']),
})

export type Fixture = z.infer<typeof fixtureBodySchema>['fixture']

export const FIXTURE_LOGIN_EMAILS = {
  full: 'fixtures@makeready.local',
  'new-group': 'fixtures-new@makeready.local',
} as const

const DISPATCH_URL =
  'https://api.github.com/repos/lukekeith/makeready/actions/workflows/reset-staging-fixtures.yml/dispatches'

/** Starts the reset workflow for a fixture. True only on GitHub's 204; never throws, never logs the token. */
export async function dispatchFixtureReset(fixture: Fixture, env: Env): Promise<boolean> {
  const token = env.FIXTURE_RESET_GITHUB_TOKEN
  if (!token) return false
  try {
    const res = await fetch(DISPATCH_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ref: 'main', inputs: { fixture } }),
      signal: AbortSignal.timeout(10_000),
    })
    if (res.status === 204) return true
    console.error(`fixture reset dispatch refused: GitHub status ${res.status}`)
    return false
  } catch (err) {
    console.error(`fixture reset dispatch failed: ${err instanceof Error ? err.name : 'unknown error'}`)
    return false
  }
}
