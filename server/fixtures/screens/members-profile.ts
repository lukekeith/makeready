/**
 * members-profile layer (ui2-members-browse D8, T7): what the member page reads beyond base.
 * Base fills the D13 fields, the groups (members-home adds the second membership) and, with
 * home-dashboard, the activity rail and program progress. This layer links member 7 (Nathan
 * Hughes) to the Group-Leader user of the same name, so his Role reads "Group leader" (D8 —
 * the linked user created a group in the org). image-framing-editor D4: it also links member 10
 * (Hannah Jenkins, no fixture avatar) to a Google account, so her avatar tap shows the Google-only
 * menu (Change image + View image). The Google picture is member 0's placed avatar URL — a fixture
 * never fetches googleusercontent.com; with images off it is null and she shows initials.
 * Creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS } from '../ids.js'
import { AVATAR_MEMBER_INDICES } from '../images.js'

export const LEADER_MEMBER_INDEX = 7
/** image-framing-editor D4: a member with a Google link and no uploaded avatar. */
export const GOOGLE_ONLY_MEMBER_INDEX = 10
export const GOOGLE_ONLY_GOOGLE_ID = 'fixture-google-member-10'
export const GOOGLE_ONLY_GOOGLE_EMAIL = 'hannah.jenkins@example.org'
/** Whose placed avatar stands in for the Google picture. */
export const GOOGLE_PICTURE_SOURCE_INDEX = AVATAR_MEMBER_INDICES[0]

export async function full(ctx: FixtureContext): Promise<void> {
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX] },
    data: { userId: FIXTURE_LEADER_USER_ID, userLinkedAt: ctx.daysAgo(30) },
  })

  const source = await ctx.prisma.member.findUnique({
    where: { id: FIXTURE_MEMBER_IDS[GOOGLE_PICTURE_SOURCE_INDEX] },
    select: { profilePicture: true },
  })
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[GOOGLE_ONLY_MEMBER_INDEX] },
    data: {
      googleId: GOOGLE_ONLY_GOOGLE_ID,
      googleEmail: GOOGLE_ONLY_GOOGLE_EMAIL,
      googlePicture: source?.profilePicture ?? null,
      googleLinkedAt: ctx.daysAgo(20),
    },
  })
}
