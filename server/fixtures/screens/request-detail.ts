/** A reviewed historical request followed by a fresh pending request; no invented event type. */
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export async function full(ctx: FixtureContext): Promise<void> {
  const member = await ctx.prisma.member.findUniqueOrThrow({ where: { id: FIXTURE_MEMBER_IDS[2] } })
  const common = { initiatedBy: 'member', organizationId: FIXTURE_ORG_ID, groupId: FIXTURE_GROUP_IDS[2], memberId: member.id,
    recipientPhone: member.phoneNumber, recipientName: `${member.firstName} ${member.lastName}` }
  await ctx.prisma.invitation.createMany({ data: [
    { ...common, id: fixtureId('joinRequest', 110), status: 'rejected', message: 'Could I join this group?', createdAt: ctx.at(-6, 10), respondedAt: ctx.at(-5, 10), respondedById: FIXTURE_USER_ID },
    { ...common, id: fixtureId('joinRequest', 111), status: 'pending', message: 'My schedule has changed. I would love to join.', createdAt: ctx.at(-1, 9) },
  ] })
  await ctx.prisma.inviteEvent.createMany({ data: [
    { id: fixtureId('inviteEvent', 120), invitationId: fixtureId('joinRequest', 110), type: 'requested', at: ctx.at(-6, 10), groupId: common.groupId, actorId: member.id },
    { id: fixtureId('inviteEvent', 121), invitationId: fixtureId('joinRequest', 110), type: 'rejected', at: ctx.at(-5, 10), groupId: common.groupId, actorId: FIXTURE_USER_ID },
    { id: fixtureId('inviteEvent', 122), invitationId: fixtureId('joinRequest', 111), type: 'requested', at: ctx.at(-1, 9), groupId: common.groupId, actorId: member.id },
  ] })
}
