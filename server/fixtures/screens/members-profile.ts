/**
 * members-profile layer (ui2-members-browse D8, T7): what the member page reads beyond base.
 * Base fills the D13 fields, the groups (members-home adds the second membership) and, with
 * home-dashboard, the activity rail and program progress. This layer links member 7 (Nathan
 * Hughes) to the Group-Leader user of the same name, so his Role reads "Group leader" (D8 —
 * the linked user created a group in the org). Creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS } from '../ids.js'

export const LEADER_MEMBER_INDEX = 7

export async function full(ctx: FixtureContext): Promise<void> {
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX] },
    data: { userId: FIXTURE_LEADER_USER_ID, userLinkedAt: ctx.daysAgo(30) },
  })
}
