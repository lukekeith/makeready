/**
 * shared-edit-field layer (ui2-members-edit T5, D8, D9, D10): the edit pages' "stored null" states.
 * Exports `sparse` only — `full` keeps all 24 members fully populated (members.db.test.ts). The
 * runner runs just the layers that export the chosen scenario, so `sparse` first replays the two
 * Members layers' `full` (the Prayer Team memberships the Group-Leader user sees, and member 7's
 * user link), then nulls gender, birthday, address and both emergency fields on one Prayer Team
 * member: the Birthday page opens on "Not set", Gender pre-selects "Not set", Address and both
 * Emergency pages open empty. Email and phone stay set. Creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_MEMBER_IDS } from '../ids.js'
import { full as membersHome } from './members-home.js'
import { full as membersProfile } from './members-profile.js'

/** One of MULTI_GROUP_MEMBER_INDICES (Prayer Team); not member 0, whom members.db.test.ts searches. */
export const SPARSE_MEMBER_INDEX = 16

export const SPARSE_NULL_FIELDS = [
  'gender',
  'birthday',
  'address',
  'emergencyContactName',
  'emergencyContactPhone',
] as const

export async function sparse(ctx: FixtureContext): Promise<void> {
  await membersHome(ctx)
  await membersProfile(ctx)
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[SPARSE_MEMBER_INDEX] },
    data: { gender: null, birthday: null, address: null, emergencyContactName: null, emergencyContactPhone: null },
  })
}
