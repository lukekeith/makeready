/**
 * members-home layer (ui2-members-browse D6, D7, D15, T7): what the Members list reads.
 *  - groupCount and the Group-Leader view: members 0, 8 and 16 (one per base group) also join
 *    base's Prayer Team, the Group-Leader user's one group → three rows read groupCount 2, and a
 *    Group-Leader session lists exactly those three.
 *  - D6 "Joined" labels: six members' MemberOrganization.joinedAt move to Today, Yesterday,
 *    4 days ago, 1 week ago, 2 weeks ago and 40 days ago (a dated label), so the list leads with
 *    every label form; the other 18 keep base's −62 … −51.
 * Creates no org, user or group, and no membership events (home-dashboard counts base's 24).
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, fixtureId } from '../ids.js'

export const MULTI_GROUP_MEMBER_INDICES: readonly number[] = [0, 8, 16]
/** [member index, day offset from today], newest first. */
export const JOINED_OFFSETS: ReadonlyArray<readonly [memberIndex: number, dayOffset: number]> = [
  [23, 0],
  [22, -1],
  [21, -4],
  [20, -9],
  [19, -16],
  [18, -40],
]
/** Today's join lands this long before ctx.now, so it is never in the future. */
export const RECENT_JOIN_LEAD_MS = 5 * 60_000

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.groupMember.createMany({
    data: MULTI_GROUP_MEMBER_INDICES.map((memberIndex, n) => ({
      id: fixtureId('groupMember', FIXTURE_MEMBER_IDS.length + 1 + n), // 25 … 27, after base's 1 … 24
      groupId: FIXTURE_LEADER_GROUP_ID,
      memberId: FIXTURE_MEMBER_IDS[memberIndex],
      joinedAt: ctx.at(-45 + n, 10),
    })),
  })
  for (const [memberIndex, offset] of JOINED_OFFSETS) {
    const joinedAt = offset === 0 ? new Date(ctx.now.getTime() - RECENT_JOIN_LEAD_MS) : ctx.at(offset, 10)
    await prisma.memberOrganization.update({
      where: { memberId_organizationId: { memberId: FIXTURE_MEMBER_IDS[memberIndex], organizationId: FIXTURE_ORG_ID } },
      data: { joinedAt },
    })
  }
}
