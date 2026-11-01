/**
 * media-library D6/D15: MakeReady's own media library. Its media are ordinary `Media` rows in one
 * Organization flagged `isMakeReady`, owned by a disabled system user that no person signs in as and
 * that never holds a role. Both have fixed ids — the schema cannot enforce "exactly one", and deleting
 * the owner would cascade the whole library — and are upserted here, never by a migration.
 */
import { prisma } from '../lib/prisma.js'

export const MAKEREADY_ORG_ID = '0a4e5e11-0000-4000-8000-00000000a11b'
export const MAKEREADY_SYSTEM_USER_ID = '0a4e5e11-0000-4000-8000-00000000a11a'
export const MAKEREADY_SYSTEM_USER_EMAIL = 'makeready-library@system.makeready.org'

/** Creates (or repairs) the MakeReady org and its system owner. Idempotent. */
export async function ensureMakeReadyOrg(): Promise<{ orgId: string; userId: string }> {
  await prisma.user.upsert({
    where: { id: MAKEREADY_SYSTEM_USER_ID },
    create: { id: MAKEREADY_SYSTEM_USER_ID, email: MAKEREADY_SYSTEM_USER_EMAIL, name: 'MakeReady', isActive: false },
    update: { isActive: false },
  })
  await prisma.organization.upsert({
    where: { id: MAKEREADY_ORG_ID },
    create: { id: MAKEREADY_ORG_ID, name: 'MakeReady', ownerId: MAKEREADY_SYSTEM_USER_ID, isMakeReady: true },
    update: { isMakeReady: true },
  })
  return { orgId: MAKEREADY_ORG_ID, userId: MAKEREADY_SYSTEM_USER_ID }
}

const makeReadyOrgCache = new Map<string, boolean>()

/** Whether `orgId` is the MakeReady org. Memoized per process: the flag never changes on a live org. */
export async function isMakeReadyOrg(orgId: string | null | undefined): Promise<boolean> {
  if (!orgId) return false
  if (orgId === MAKEREADY_ORG_ID) return true
  const cached = makeReadyOrgCache.get(orgId)
  if (cached !== undefined) return cached
  const org = await prisma.organization.findUnique({ where: { id: orgId }, select: { isMakeReady: true } })
  const flag = org?.isMakeReady ?? false
  makeReadyOrgCache.set(orgId, flag)
  return flag
}

/** Test seam: forget memoized lookups. */
export function resetMakeReadyOrgCache(): void {
  makeReadyOrgCache.clear()
}
