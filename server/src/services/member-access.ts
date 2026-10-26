/**
 * Which members a leader may SEE in an organization (ui2-members-browse D7).
 *
 *  - all: a super admin, the org's owner (Organization.ownerId), or a holder of
 *    the SYSTEM Owner or Admin role in that org;
 *  - otherwise (Group Leader, Contributor, any custom role): members with an
 *    active GroupMember row in an active group of that org the caller created.
 *
 * Recorded exception (SPEC D7, F6 — settled at audit 2026-10-25): this is a
 * VISIBILITY rule under the existing gates (requirePermission('member.read'),
 * requireMemberOrOrgOwner), not an authorization gate, so it narrows by
 * Group.creatorId ON PURPOSE. Its all-members test is deliberately not
 * canManageOrgContent / getManageableOrgIds, which admit every role-holder.
 * Used by the members list, GET /api/members/:id, /:id/groups,
 * /:id/engagement and /api/home/days?memberId.
 */
import { prisma } from '../lib/prisma.js'
import { isSuperAdmin } from './permission.js'

export type MemberAccessScope = { all: true } | { all: false; groupIds: string[] }

/** Who reads a member: the member's own session (unscoped) or a user (D7-scoped). */
export type MemberViewer = { kind: 'self' } | { kind: 'user'; userId: string }

export const ALL_MEMBERS_SYSTEM_ROLES = ['Owner', 'Admin'] as const

export async function memberAccessScope(userId: string, orgId: string): Promise<MemberAccessScope> {
  if (await isSuperAdmin(userId)) return { all: true }
  const org = await prisma.organization.findUnique({ where: { id: orgId }, select: { ownerId: true } })
  if (org?.ownerId === userId) return { all: true }
  const adminRole = await prisma.userRole.findFirst({
    where: {
      userId,
      organizationId: orgId,
      role: { isSystem: true, name: { in: [...ALL_MEMBERS_SYSTEM_ROLES] } },
    },
    select: { id: true },
  })
  if (adminRole) return { all: true }
  const groups = await prisma.group.findMany({
    where: { creatorId: userId, organizationId: orgId, isActive: true },
    select: { id: true },
    orderBy: { id: 'asc' },
  })
  return { all: false, groupIds: groups.map((g) => g.id) }
}

export async function canAccessMember(scope: MemberAccessScope, memberId: string, orgId: string): Promise<boolean> {
  if (scope.all) {
    return (await prisma.memberOrganization.count({ where: { memberId, organizationId: orgId } })) > 0
  }
  if (scope.groupIds.length === 0) return false
  const memberships = await prisma.groupMember.count({
    where: {
      memberId,
      isActive: true,
      groupId: { in: scope.groupIds },
      group: { isActive: true, organizationId: orgId },
    },
  })
  return memberships > 0
}

export async function visibleMemberOrgIds(viewer: MemberViewer, memberId: string): Promise<string[]> {
  const rows = await prisma.memberOrganization.findMany({
    where: { memberId },
    select: { organizationId: true },
    orderBy: { organizationId: 'asc' },
  })
  const orgIds = rows.map((r) => r.organizationId)
  if (viewer.kind === 'self') return orgIds
  const visible: string[] = []
  for (const orgId of orgIds) {
    const scope = await memberAccessScope(viewer.userId, orgId)
    if (await canAccessMember(scope, memberId, orgId)) visible.push(orgId)
  }
  return visible
}

export async function canViewMember(userId: string, memberId: string, organizationId?: string): Promise<boolean> {
  const visible = await visibleMemberOrgIds({ kind: 'user', userId }, memberId)
  return organizationId ? visible.includes(organizationId) : visible.length > 0
}
