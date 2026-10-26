import { beforeEach, describe, expect, it, vi } from 'vitest'
import { LAYER_SCENARIOS, createContext } from '../context.js'
import { FIXTURE_MEMBER_IDS } from '../ids.js'
import { availableScenarios } from '../runner.js'
import { MULTI_GROUP_MEMBER_INDICES } from '../screens/members-home.js'
import { LEADER_MEMBER_INDEX } from '../screens/members-profile.js'
import * as layer from '../screens/shared-edit-field.js'

const prisma = {
  groupMember: { createMany: vi.fn() },
  memberOrganization: { update: vi.fn() },
  member: { update: vi.fn() },
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('shared-edit-field layer (ui2-members-edit T5)', () => {
  it('exports sparse only, so full keeps every member populated', () => {
    expect(Object.keys(layer).filter((k) => (LAYER_SCENARIOS as readonly string[]).includes(k))).toEqual(['sparse'])
    expect(availableScenarios([{ name: 'shared-edit-field', module: { sparse: layer.sparse } }])).toEqual(['sparse', 'empty'])
  })

  it('picks a Prayer Team member the Group-Leader user sees, never the leader’s own member or James Carter', () => {
    expect(MULTI_GROUP_MEMBER_INDICES).toContain(layer.SPARSE_MEMBER_INDEX)
    expect(layer.SPARSE_MEMBER_INDEX).not.toBe(LEADER_MEMBER_INDEX)
    expect(layer.SPARSE_MEMBER_INDEX).not.toBe(0)
  })

  it('replays the Members layers, then nulls the five optional fields on that one member', async () => {
    await layer.sparse(createContext(prisma as never, new Date('2026-10-26T15:00:00Z')))
    // members-home: the three Prayer Team memberships; members-profile: the member-7 user link.
    expect(prisma.groupMember.createMany).toHaveBeenCalledTimes(1)
    expect(prisma.groupMember.createMany.mock.calls[0][0].data).toHaveLength(3)
    expect(prisma.member.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX] } })
    )
    expect(prisma.member.update).toHaveBeenLastCalledWith({
      where: { id: FIXTURE_MEMBER_IDS[layer.SPARSE_MEMBER_INDEX] },
      data: { gender: null, birthday: null, address: null, emergencyContactName: null, emergencyContactPhone: null },
    })
    expect(layer.SPARSE_NULL_FIELDS).toEqual(['gender', 'birthday', 'address', 'emergencyContactName', 'emergencyContactPhone'])
  })
})
