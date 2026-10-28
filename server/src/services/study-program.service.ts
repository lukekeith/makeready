/**
 * ui2-programs: the study program service — template-less create (D8), the program list's scope and
 * private filter (D13/D14), and the payload mapper every program response goes through (D15).
 * `routes/programs.ts` stays the route layer (house rule: services own the logic).
 */
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { getManageableOrgIds, isSuperAdmin } from './permission.js'

/** D15: the relations every program response selects so it can carry the two names. */
export const PROGRAM_NAME_INCLUDE = {
  creator: { select: { name: true } },
  leader: { select: { name: true } },
} as const

type NamedRelation = { name: string | null } | null | undefined

/** D15: `creator`/`leader` relations → `creatorName`/`leaderName`; the relations themselves are dropped. */
export function toProgramPayload<T extends { creator?: NamedRelation; leader?: NamedRelation }>(
  program: T,
): Omit<T, 'creator' | 'leader'> & { creatorName: string | null; leaderName: string | null } {
  const { creator, leader, ...rest } = program
  return { ...rest, creatorName: creator?.name ?? null, leaderName: leader?.name ?? null }
}

/**
 * D8: a program from a title alone — no template, no lessons, `days` 0, never published (an empty
 * program can't be enrolled), led by its creator.
 */
export async function createBlankProgram(input: {
  name: string
  description?: string | null
  userId: string
  organizationId: string | null
}) {
  return prisma.studyProgram.create({
    data: {
      name: input.name,
      description: input.description ?? null,
      days: 0,
      isPublished: false,
      publishedAt: null,
      creatorId: input.userId,
      leaderId: input.userId,
      updatedById: input.userId,
      organizationId: input.organizationId,
    },
    include: PROGRAM_NAME_INCLUDE,
  })
}

/** D14: every org the caller manages, plus their own org — the orgs whose programs the list returns. */
export async function programListScope(userId: string): Promise<string[]> {
  const [managed, user] = await Promise.all([
    getManageableOrgIds(userId),
    prisma.user.findUnique({ where: { id: userId }, select: { organizationId: true } }),
  ])
  const ids = new Set(managed)
  if (user?.organizationId) ids.add(user.organizationId)
  return [...ids]
}

/**
 * D13: a private program is listed only to its creator, its leader, the owner of its org, an Owner or
 * Admin role-holder there, and super admins. A visibility rule, not mutation auth — so not
 * `canManageOrgContent`, which is true for every role-holder.
 */
export async function privateProgramVisibility(userId: string): Promise<Prisma.StudyProgramWhereInput> {
  if (await isSuperAdmin(userId)) return {}
  const [owned, adminRoles] = await Promise.all([
    prisma.organization.findMany({ where: { ownerId: userId }, select: { id: true } }),
    prisma.userRole.findMany({
      where: { userId, role: { name: { in: ['Owner', 'Admin'] } } },
      select: { organizationId: true },
    }),
  ])
  const orgIds = [...new Set([...owned.map((o) => o.id), ...adminRoles.map((r) => r.organizationId)])]
  return {
    OR: [
      { isPrivate: false },
      { creatorId: userId },
      { leaderId: userId },
      ...(orgIds.length > 0 ? [{ organizationId: { in: orgIds } }] : []),
    ],
  }
}

export interface ProgramListOptions {
  userId: string
  /** D14 scope; `null` = unscoped (super admin). */
  orgIds: string[] | null
  privacy: Prisma.StudyProgramWhereInput
  includeInactive?: boolean
  orgId?: string
  creatorId?: string
  leaders?: string[]
  isPublished?: boolean
  groupId?: string
  tags?: string[]
}

/** D13/D14: the list's `where` — every clause ANDed, so the privacy OR never overwrites the scope OR. */
export function buildProgramListWhere(o: ProgramListOptions): Prisma.StudyProgramWhereInput {
  const and: Prisma.StudyProgramWhereInput[] = []
  if (!o.includeInactive) and.push({ isActive: true })
  if (o.orgIds !== null) {
    and.push(
      o.orgIds.length > 0
        ? { OR: [{ organizationId: { in: o.orgIds } }, { creatorId: o.userId }] }
        : { creatorId: o.userId },
    )
  }
  if (Object.keys(o.privacy).length > 0) and.push(o.privacy)
  if (o.orgId) and.push({ organizationId: o.orgId })
  if (o.creatorId && !o.leaders?.length) and.push({ creatorId: o.creatorId })
  if (o.leaders?.length) {
    and.push({ OR: [{ leaderId: { in: o.leaders } }, { creatorId: { in: o.leaders } }] })
  }
  if (o.isPublished !== undefined) and.push({ isPublished: o.isPublished })
  if (o.groupId) and.push({ enrollments: { some: { groupId: o.groupId } } })
  if (o.tags?.length) and.push({ tags: { some: { tag: { in: o.tags } } } })
  return { AND: and }
}
