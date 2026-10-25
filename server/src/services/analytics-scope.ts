/**
 * The caller's entitled analytics scope — shared by POST /api/analytics/query
 * and /api/home/* (home-dashboard-data D9). Moved verbatim from
 * routes/analytics.ts deriveScope: API keys and super admins see all; everyone
 * else sees orgs they own/hold a role in (getManageableOrgIds) plus groups they
 * personally created. `organizationId` can only NARROW it; an org wholly
 * outside the caller's scope yields an empty scope, which callers read as 404.
 */
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'
import { getManageableOrgIds, isSuperAdmin } from './permission.js'

export interface AnalyticsCaller {
  userId?: string
  apiKeyId?: string
}

export function isEmptyScope(scope: AnalyticsScope): boolean {
  return !scope.all && scope.orgIds.length === 0 && scope.groupIds.length === 0
}

async function entitledScope(caller: AnalyticsCaller): Promise<AnalyticsScope | null> {
  if (caller.apiKeyId) return { all: true }
  if (!caller.userId) return null
  if (await isSuperAdmin(caller.userId)) return { all: true }
  const [orgIds, ownGroups] = await Promise.all([
    getManageableOrgIds(caller.userId),
    prisma.group.findMany({ where: { creatorId: caller.userId, isActive: true }, select: { id: true } }),
  ])
  return { all: false, orgIds, groupIds: ownGroups.map((g) => g.id) }
}

async function narrowToOrganization(scope: AnalyticsScope, organizationId: string): Promise<AnalyticsScope> {
  if (scope.all || scope.orgIds.includes(organizationId)) {
    return { all: false, orgIds: [organizationId], groupIds: [] }
  }
  if (scope.groupIds.length === 0) return { all: false, orgIds: [], groupIds: [] }
  const groups = await prisma.group.findMany({
    where: { id: { in: scope.groupIds }, organizationId },
    select: { id: true },
  })
  return { all: false, orgIds: [], groupIds: groups.map((g) => g.id) }
}

export async function deriveAnalyticsScope(
  caller: AnalyticsCaller,
  opts: { organizationId?: string } = {}
): Promise<AnalyticsScope | null> {
  const scope = await entitledScope(caller)
  if (!scope || !opts.organizationId) return scope
  return narrowToOrganization(scope, opts.organizationId)
}
