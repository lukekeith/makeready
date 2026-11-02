import { describe, expect, it } from 'vitest'
import { toLegacyInvite, toLegacyJoinRequest } from '../src/services/invitation.js'

const createdAt = new Date('2025-01-02T03:04:05Z')
const updatedAt = new Date('2025-03-01T00:00:00Z')
const respondedAt = new Date('2025-02-02T00:00:00Z')
const row = {
  id: 'row', initiatedBy: 'member', groupId: 'group', memberId: 'member',
  organizationId: 'org', token: null, inviterId: null, recipientPhone: '+12025550100',
  recipientName: null, message: 'Please', status: 'accepted', respondedById: 'reviewer',
  respondedAt, acceptedAt: null, expiresAt: null, createdAt, updatedAt,
}

describe('invitation legacy serializers', () => {
  it('preserves complete request scalars with original approved and reviewer vocabulary', () => {
    expect(toLegacyJoinRequest(row)).toEqual({
      id: 'row', groupId: 'group', memberId: 'member', status: 'approved', message: 'Please',
      reviewedById: 'reviewer', reviewedAt: respondedAt, createdAt, updatedAt,
    })
  })
  it('preserves nullable generic invite fields without new storage fields', () => {
    expect(toLegacyInvite({ ...row, initiatedBy: 'leader', token: 'TOKEN', inviterId: 'leader', groupId: null, recipientPhone: null })).toEqual({
      id: 'row', token: 'TOKEN', inviterId: 'leader', groupId: null, recipientPhone: null,
      recipientName: null, status: 'accepted', expiresAt: null, createdAt, acceptedAt: null,
    })
  })
  it('refuses to serialize the opposite relationship kind as a legacy object', () => {
    expect(() => toLegacyInvite(row)).toThrow()
    expect(() => toLegacyJoinRequest({ ...row, initiatedBy: 'leader' })).toThrow()
  })
})
