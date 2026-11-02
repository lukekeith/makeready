/** Full feed: all five display states across existing groups and leaders. No transport/log writes. */
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { seedSmsCampaigns } from '../../src/services/sms-campaign-seed.js'

export async function full(ctx: FixtureContext): Promise<void> {
  await seedSmsCampaigns(ctx.prisma)
  const members = await ctx.prisma.member.findMany({ where: { id: { in: [FIXTURE_MEMBER_IDS[3], FIXTURE_MEMBER_IDS[4], FIXTURE_MEMBER_IDS[8]] } } })
  const member = (index: number) => members.find(row => row.id === FIXTURE_MEMBER_IDS[index])!
  const common = { organizationId: FIXTURE_ORG_ID, createdAt: ctx.at(-4, 10) }
  await ctx.prisma.invitation.createMany({ data: [
    { ...common, id: fixtureId('invite', 100), initiatedBy: 'leader', token: 'FIXTURE_FEED_SENT', groupId: FIXTURE_GROUP_IDS[0], inviterId: FIXTURE_USER_ID, recipientPhone: '+15555550191', recipientName: 'Alex Rivera', status: 'pending', expiresAt: ctx.at(5, 10) },
    { ...common, id: fixtureId('invite', 101), initiatedBy: 'leader', token: 'FIXTURE_FEED_ACCEPTED', groupId: FIXTURE_GROUP_IDS[1], inviterId: FIXTURE_LEADER_USER_ID, recipientPhone: member(8).phoneNumber, recipientName: `${member(8).firstName} ${member(8).lastName}`, memberId: member(8).id, status: 'accepted', acceptedAt: ctx.at(-2, 10) },
    { ...common, id: fixtureId('invite', 102), initiatedBy: 'leader', token: 'FIXTURE_FEED_EXPIRED', groupId: FIXTURE_GROUP_IDS[1], inviterId: FIXTURE_LEADER_USER_ID, recipientPhone: '+15555550192', recipientName: 'Jordan Lee', status: 'pending', expiresAt: ctx.at(-1, 10) },
    { ...common, id: fixtureId('joinRequest', 100), initiatedBy: 'member', groupId: FIXTURE_GROUP_IDS[1], memberId: member(3).id, recipientPhone: member(3).phoneNumber, recipientName: `${member(3).firstName} ${member(3).lastName}`, status: 'pending', message: 'I would like to join.' },
    { ...common, id: fixtureId('joinRequest', 101), initiatedBy: 'member', groupId: FIXTURE_GROUP_IDS[1], memberId: member(4).id, recipientPhone: member(4).phoneNumber, recipientName: `${member(4).firstName} ${member(4).lastName}`, status: 'rejected', respondedById: FIXTURE_USER_ID, respondedAt: ctx.at(-2, 10) },
  ] })
  await ctx.prisma.inviteEvent.createMany({ data: [
    { id: fixtureId('inviteEvent', 100), invitationId: fixtureId('invite', 100), type: 'sent', at: common.createdAt, groupId: FIXTURE_GROUP_IDS[0], actorId: FIXTURE_USER_ID },
    { id: fixtureId('inviteEvent', 101), invitationId: fixtureId('invite', 101), type: 'accepted', at: ctx.at(-2, 10), groupId: FIXTURE_GROUP_IDS[1], actorId: member(8).id },
    { id: fixtureId('inviteEvent', 102), invitationId: fixtureId('joinRequest', 100), type: 'requested', at: common.createdAt, groupId: FIXTURE_GROUP_IDS[1], actorId: member(3).id },
    { id: fixtureId('inviteEvent', 103), invitationId: fixtureId('joinRequest', 101), type: 'rejected', at: ctx.at(-2, 10), groupId: FIXTURE_GROUP_IDS[1], actorId: FIXTURE_USER_ID },
  ] })
}
