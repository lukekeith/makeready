import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  invitation: { create: vi.fn(), delete: vi.fn(), findUnique: vi.fn(), findFirst: vi.fn() },
  inviteEvent: { create: vi.fn() },
  member: { findUnique: vi.fn() },
  $queryRaw: vi.fn(),
  $transaction: vi.fn(),
  group: { findUnique: vi.fn(), findUniqueOrThrow: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../sms-campaign.js', () => ({ sendCampaignSms: vi.fn() }))

import { sendCampaignSms } from '../sms-campaign.js'
import { sendGroupInvite } from '../invite.js'

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.$transaction.mockImplementation((callback) => callback(prismaMock))
  prismaMock.$queryRaw.mockResolvedValue([])
  prismaMock.member.findUnique.mockResolvedValue(null)
  prismaMock.invitation.findUnique.mockResolvedValue({ id: 'inv1', initiatedBy: 'leader', status: 'pending', groupId: 'g1', recipientPhone: '+15555550123' })
  prismaMock.invitation.create.mockResolvedValue({ id: 'inv1', createdAt: new Date() })
  prismaMock.group.findUniqueOrThrow.mockResolvedValue({ code: 'ABC123', organizationId: 'org1' })
  prismaMock.group.findUnique.mockResolvedValue({ code: 'ABC123', organizationId: 'org1' })
  vi.mocked(sendCampaignSms).mockResolvedValue({ success: true, smsLogId: 's1', messageSid: 'SM1' } as never)
})

describe('sendGroupInvite recipientName (D6, D8)', () => {
  it('writes the name on the invite and leaves the SMS context unchanged', async () => {
    const result = await sendGroupInvite('g1', 'u1', 'Leader', '+15555550123', 'Prayer Team', 'http://app', 'Ada Test')
    expect(result.success).toBe(true)
    expect(prismaMock.invitation.create.mock.calls[0][0].data.recipientName).toBe('Ada Test')
    expect(vi.mocked(sendCampaignSms).mock.calls[0][0].context).toEqual({
      'inviter.name': 'Leader',
      'group.name': 'Prayer Team',
      joinUrl: 'http://app/join/group/ABC123?invite=' + prismaMock.invitation.create.mock.calls[0][0].data.token,
    })
  })

  it('stores null when no name is given', async () => {
    await sendGroupInvite('g1', 'u1', 'Leader', '+15555550123', 'Prayer Team', 'http://app')
    expect(prismaMock.invitation.create.mock.calls[0][0].data.recipientName).toBeNull()
  })
})
