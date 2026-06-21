/**
 * API-key authentication helpers for integration tests.
 *
 * The app authenticates `Authorization: Bearer mr_…` tokens globally via
 * `authenticateApiKey` (src/index.ts), looking the key up in the `api_keys`
 * table and setting `req.user`. So to drive an endpoint AS a specific user
 * through the real auth + permission middleware, we insert an api_keys row for
 * that user and send its token. This is real end-to-end auth — not a mock.
 */

import { prisma } from '../../src/lib/prisma.js'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../src/lib/api-key.js'

export interface TestUserWithToken {
  userId: string
  token: string // full `mr_…` bearer token
  apiKeyId: string
}

/**
 * Create a user and an active API key for them. Returns the bearer token to use
 * in `.set('Authorization', `Bearer ${token}`)`.
 */
export async function createUserWithApiKey(opts: {
  email: string
  name: string
  isSuperAdmin?: boolean
}): Promise<TestUserWithToken> {
  const user = await prisma.user.create({
    data: {
      googleId: `gid-${opts.email}`,
      email: opts.email,
      name: opts.name,
      isSuperAdmin: opts.isSuperAdmin ?? false,
    },
  })
  return createApiKeyForUser(user.id, opts.name)
}

/** Issue an API key for an existing user id. */
export async function createApiKeyForUser(
  userId: string,
  label = 'test'
): Promise<TestUserWithToken> {
  const token = generateApiKey()
  const apiKey = await prisma.apiKey.create({
    data: {
      keyHash: hashApiKey(token),
      keyPrefix: getKeyPrefix(token),
      name: `${label} test key`,
      userId,
    },
    select: { id: true },
  })
  return { userId, token, apiKeyId: apiKey.id }
}

/** Authorization header value for a token. */
export function bearer(token: string): string {
  return `Bearer ${token}`
}
