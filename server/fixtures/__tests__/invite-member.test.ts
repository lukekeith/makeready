import { describe, expect, it, vi } from 'vitest'

vi.mock('../../src/services/sms-campaign-seed.js', () => ({ seedSmsCampaigns: vi.fn().mockResolvedValue(undefined) }))

import { seedSmsCampaigns } from '../../src/services/sms-campaign-seed.js'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { INVITE_FIXTURE_RECIPIENT_NAME, full } from '../screens/invite-member.js'

describe('invite-member fixtures layer (D15, D18)', () => {
  it('seeds the campaigns first, then one named pending invite on the first base group', async () => {
    const order: string[] = []
    vi.mocked(seedSmsCampaigns).mockImplementation(async () => { order.push('seed') })
    const create = vi.fn(async () => { order.push('invite') })
    const now = new Date('2026-10-26T15:00:00Z')
    await full({ prisma: { invite: { create } }, now, at: (d: number, h: number) => new Date(now.getTime() + d * 86_400_000 + h) } as never)
    expect(order).toEqual(['seed', 'invite'])
    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        id: fixtureId('invite', 1),
        groupId: FIXTURE_GROUP_IDS[0],
        inviterId: FIXTURE_USER_ID,
        recipientName: INVITE_FIXTURE_RECIPIENT_NAME,
        status: 'pending',
      }),
    })
    expect(INVITE_FIXTURE_RECIPIENT_NAME).toBe('Tony Stark')
  })
})
