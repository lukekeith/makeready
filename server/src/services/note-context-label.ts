/**
 * contextLabel for leader note responses (notes D22).
 *
 * One link per note is chosen (refType priority MEMO > GROUP > PROGRAM, then createdAt, then id) and
 * resolves to its entity's name only when the user may see that entity: its organization is one the
 * user owns or holds a role in. A chosen link that does not resolve gives null; the next link is not tried.
 * Every list costs at most one query per entity kind, plus one for the user's visible orgs.
 *
 * MEMO resolves to the VoiceMemo's title when the user owns it and it is active (F9); otherwise null.
 */
import { prisma } from '../lib/prisma.js'

interface LabelLink {
  id: string
  refType: string
  refId: string
  createdAt: Date
}

const REF_TYPE_PRIORITY: Record<string, number> = { MEMO: 0, GROUP: 1, PROGRAM: 2 }

function chooseLink(links: LabelLink[]): LabelLink | null {
  const candidates = links.filter((l) => l.refType in REF_TYPE_PRIORITY)
  if (candidates.length === 0) return null
  candidates.sort(
    (a, b) =>
      REF_TYPE_PRIORITY[a.refType] - REF_TYPE_PRIORITY[b.refType] ||
      a.createdAt.getTime() - b.createdAt.getTime() ||
      (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  )
  return candidates[0]
}

async function visibleOrganizationIds(userId: string): Promise<Set<string>> {
  const [owned, roles] = await Promise.all([
    prisma.organization.findMany({ where: { ownerId: userId }, select: { id: true } }),
    prisma.userRole.findMany({ where: { userId }, select: { organizationId: true } }),
  ])
  return new Set([...owned.map((o) => o.id), ...roles.map((r) => r.organizationId)])
}

export async function attachContextLabels<N extends { links: LabelLink[] }>(
  notes: N[],
  userId: string,
): Promise<Array<N & { contextLabel: string | null }>> {
  const chosen = notes.map((note) => chooseLink(note.links))
  const groupIds = [...new Set(chosen.filter((l) => l?.refType === 'GROUP').map((l) => l!.refId))]
  const programIds = [...new Set(chosen.filter((l) => l?.refType === 'PROGRAM').map((l) => l!.refId))]
  const memoIds = [...new Set(chosen.filter((l) => l?.refType === 'MEMO').map((l) => l!.refId))]

  const [orgIds, groups, programs, memos] = await Promise.all([
    groupIds.length + programIds.length > 0 ? visibleOrganizationIds(userId) : new Set<string>(),
    groupIds.length > 0
      ? prisma.group.findMany({ where: { id: { in: groupIds } }, select: { id: true, name: true, organizationId: true } })
      : [],
    programIds.length > 0
      ? prisma.studyProgram.findMany({ where: { id: { in: programIds } }, select: { id: true, name: true, organizationId: true } })
      : [],
    memoIds.length > 0
      ? prisma.voiceMemo.findMany({ where: { id: { in: memoIds }, userId, isActive: true }, select: { id: true, title: true } })
      : [],
  ])

  const groupById = new Map(groups.map((g) => [g.id, g]))
  const programById = new Map(programs.map((p) => [p.id, p]))
  const memoTitleById = new Map(memos.map((m) => [m.id, m.title]))
  const visibleName = (entity: { name: string; organizationId: string | null } | undefined): string | null =>
    entity && entity.organizationId && orgIds.has(entity.organizationId) ? entity.name : null

  return notes.map((note, i) => {
    const link = chosen[i]
    let contextLabel: string | null = null
    if (link?.refType === 'MEMO') contextLabel = memoTitleById.get(link.refId) ?? null
    else if (link?.refType === 'GROUP') contextLabel = visibleName(groupById.get(link.refId))
    else if (link?.refType === 'PROGRAM') contextLabel = visibleName(programById.get(link.refId))
    return { ...note, contextLabel }
  })
}

export async function attachContextLabel<N extends { links: LabelLink[] }>(
  note: N,
  userId: string,
): Promise<N & { contextLabel: string | null }> {
  return (await attachContextLabels([note], userId))[0]
}
