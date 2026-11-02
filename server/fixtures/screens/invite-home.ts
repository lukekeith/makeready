/** One linked phone with sent/accepted invitations and a factual six-event timeline. */
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { seedSmsCampaigns } from '../../src/services/sms-campaign-seed.js'

export async function full(ctx: FixtureContext): Promise<void> {
  await seedSmsCampaigns(ctx.prisma)
  const member = await ctx.prisma.member.update({ where: { id: FIXTURE_MEMBER_IDS[0] }, data: { smsConsent: true, smsConsentAt: ctx.at(-7, 10) } })
  const common = { initiatedBy: 'leader', organizationId: FIXTURE_ORG_ID, recipientPhone: member.phoneNumber, recipientName: `${member.firstName} ${member.lastName}` }
  await ctx.prisma.invitation.createMany({ data: [
    { ...common, id: fixtureId('invite', 110), token: 'FIXTURE_DETAIL_SENT', groupId: FIXTURE_GROUP_IDS[1], inviterId: FIXTURE_LEADER_USER_ID, status: 'pending', createdAt: ctx.at(-2, 10), expiresAt: ctx.at(5, 10) },
    { ...common, id: fixtureId('invite', 111), token: 'FIXTURE_DETAIL_ACCEPTED', groupId: FIXTURE_GROUP_IDS[0], inviterId: FIXTURE_USER_ID, memberId: member.id, status: 'accepted', createdAt: ctx.at(-6, 10), acceptedAt: ctx.at(-3, 10) },
  ] })
  await ctx.prisma.inviteEvent.createMany({ data: [
    { id: fixtureId('inviteEvent', 110), invitationId: fixtureId('invite', 111), type: 'sent', at: ctx.at(-6, 10), groupId: FIXTURE_GROUP_IDS[0], actorId: FIXTURE_USER_ID },
    { id: fixtureId('inviteEvent', 111), invitationId: fixtureId('invite', 111), type: 'resent', at: ctx.at(-5, 10), groupId: FIXTURE_GROUP_IDS[0], actorId: FIXTURE_USER_ID },
    { id: fixtureId('inviteEvent', 112), invitationId: fixtureId('invite', 111), type: 'link_clicked', at: ctx.at(-4, 10), groupId: FIXTURE_GROUP_IDS[0] },
    { id: fixtureId('inviteEvent', 113), invitationId: fixtureId('invite', 111), type: 'accepted', at: ctx.at(-3, 10), groupId: FIXTURE_GROUP_IDS[0], actorId: member.id },
    { id: fixtureId('inviteEvent', 114), invitationId: fixtureId('invite', 110), type: 'sent', at: ctx.at(-2, 10), groupId: FIXTURE_GROUP_IDS[1], actorId: FIXTURE_LEADER_USER_ID },
    { id: fixtureId('inviteEvent', 115), invitationId: fixtureId('invite', 110), type: 'link_clicked', at: ctx.at(-1, 10), groupId: FIXTURE_GROUP_IDS[1] },
  ] })
}
