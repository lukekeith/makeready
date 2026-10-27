/**
 * invite-member layer (invite-member D15, D18): the invite flow's walkable world.
 *  - D18: seeds the SMS campaigns first, so `POST /api/invites/send` finds `group-invite-v1` in a
 *    freshly reset database (no migration or seed creates SMS templates).
 *  - D15: one pending invite with `recipientName` on the first base group, sent by the Fixtures
 *    user, so `GET /api/invites` returns a named row. Base's 3+ groups make the group picker show.
 * Creates no org, user or group; the invite is removed with its group by wipe.ts (cascade).
 */
import { seedSmsCampaigns } from '../../src/services/sms-campaign-seed.js'
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const INVITE_FIXTURE_RECIPIENT_NAME = 'Tony Stark'
/** 555-01xx is reserved for fiction; never a real handset. */
export const INVITE_FIXTURE_PHONE = '+15555550199'

export async function full(ctx: FixtureContext): Promise<void> {
  await seedSmsCampaigns(ctx.prisma)
  await ctx.prisma.invite.create({
    data: {
      id: fixtureId('invite', 1),
      token: 'FIXTUREINV1',
      groupId: FIXTURE_GROUP_IDS[0],
      inviterId: FIXTURE_USER_ID,
      recipientPhone: INVITE_FIXTURE_PHONE,
      recipientName: INVITE_FIXTURE_RECIPIENT_NAME,
      status: 'pending',
      createdAt: ctx.at(-1, 10),
      expiresAt: ctx.at(6, 10),
    },
  })
}
