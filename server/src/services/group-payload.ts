/**
 * group-cover-image D17: the one group payload every groups route returns (POST, GET list,
 * GET /:id, PATCH) — the four inline mappers it replaced were identical but for the org keys.
 */
import type { Group } from '../generated/prisma/index.js'
import { parseStoredFraming, type CoverFraming } from './group-cover.js'

export type GroupPayloadRow = Pick<
  Group,
  | 'id' | 'organizationId' | 'code' | 'name' | 'description' | 'coverImageUrl' | 'coverOriginalUrl'
  | 'coverFraming' | 'isPrivate' | 'allowInvites' | 'memberDirectoryEnabled' | 'memberDirectoryAccess'
  | 'welcomeMessage' | 'ageRangeMin' | 'ageRangeMax' | 'maxMembers' | 'creatorId' | 'createdAt' | 'updatedAt'
> & {
  _count: { members: number }
  creator?: { name: string | null } | null
}

export interface GroupPayload {
  id: string
  organizationId: string
  code: string | null
  name: string
  description: string | null
  coverImageUrl: string | null
  coverOriginalUrl: string | null
  coverFraming: CoverFraming | null
  isPrivate: boolean
  allowInvites: boolean
  memberDirectory: boolean
  memberDirectoryAccess: Group['memberDirectoryAccess']
  welcomeMessage: string | null
  ageRange: { min: number | null; max: number | null } | null
  maxMembers: number | null
  memberCount: number
  creatorId: string
  creatorName: string | null
  organizationName?: string | null
  createdAt: Date
  updatedAt: Date
}

/** Transform a group row to match the iOS model. `organizationName` is added only when passed. */
export function toGroupPayload(group: GroupPayloadRow, opts: { organizationName?: string | null } = {}): GroupPayload {
  const payload: GroupPayload = {
    id: group.id,
    organizationId: group.organizationId,
    code: group.code,
    name: group.name,
    description: group.description,
    coverImageUrl: group.coverImageUrl,
    coverOriginalUrl: group.coverOriginalUrl ?? null,
    coverFraming: parseStoredFraming(group.coverFraming),
    isPrivate: group.isPrivate,
    allowInvites: group.allowInvites,
    memberDirectory: group.memberDirectoryEnabled,
    memberDirectoryAccess: group.memberDirectoryAccess,
    welcomeMessage: group.welcomeMessage,
    ageRange:
      group.ageRangeMin !== null || group.ageRangeMax !== null
        ? { min: group.ageRangeMin, max: group.ageRangeMax }
        : null,
    maxMembers: group.maxMembers,
    memberCount: group._count.members,
    creatorId: group.creatorId,
    creatorName: group.creator?.name ?? null,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt,
  }
  if ('organizationName' in opts) payload.organizationName = opts.organizationName ?? null
  return payload
}
