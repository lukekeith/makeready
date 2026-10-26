import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn(), update: vi.fn() },
}))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import { updateMember } from '../member.js'

const STORED_PHONE = '+15550100001'
const UPDATED = { id: 'm1', firstName: 'James', phoneNumber: STORED_PHONE }
const p2002 = () =>
  Object.assign(new Error('Unique constraint failed on the fields: (`phone_number`)'), {
    code: 'P2002',
    meta: { target: ['phone_number'] },
  })

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.member.findUnique.mockResolvedValue({ phoneNumber: STORED_PHONE })
  prismaMock.member.update.mockResolvedValue(UPDATED)
})

const written = () => prismaMock.member.update.mock.calls[0][0]

describe('updateMember without a phone (unchanged behaviour)', () => {
  it('writes the keys as given and never reads the stored phone', async () => {
    const res = await updateMember('m1', { firstName: 'X', address: null, emergencyContactName: null })
    expect(res).toEqual({ success: true, data: UPDATED })
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(written()).toEqual({
      where: { id: 'm1' },
      data: { firstName: 'X', address: null, emergencyContactName: null, updatedAt: expect.any(Date) },
    })
  })

  it('returns the generic failure (no status) on any non-P2002 error', async () => {
    prismaMock.member.update.mockRejectedValue(new Error('connection lost'))
    expect(await updateMember('m1', { firstName: 'X' })).toEqual({ success: false, error: 'Failed to update member' })
  })
})

describe('updateMember with a changed phone (D5, D17)', () => {
  it('writes the normalized number and resets verification and consent', async () => {
    const res = await updateMember('m1', { phoneNumber: '(555) 010-9999' })
    expect(res.success).toBe(true)
    expect(prismaMock.member.findUnique).toHaveBeenCalledWith({ where: { id: 'm1' }, select: { phoneNumber: true } })
    expect(written()).toEqual({
      where: { id: 'm1' },
      data: {
        phoneNumber: '+15550109999',
        phoneVerified: false,
        lastVerifiedAt: null,
        smsConsent: false,
        smsConsentAt: expect.any(Date),
        updatedAt: expect.any(Date),
      },
    })
  })

  it('overrides an smsConsent:true sent in the same request (D17)', async () => {
    await updateMember('m1', { phoneNumber: '+15550109999', smsConsent: true, smsConsentAt: null })
    expect(written().data).toMatchObject({ smsConsent: false, smsConsentAt: expect.any(Date) })
  })

  it('lets a user viewer (the default) change it', async () => {
    expect((await updateMember('m1', { phoneNumber: '+15550109999' }, 'user')).success).toBe(true)
    expect(prismaMock.member.update).toHaveBeenCalledTimes(1)
  })

  it('maps a P2002 to 409 PHONE_TAKEN', async () => {
    prismaMock.member.update.mockRejectedValue(p2002())
    expect(await updateMember('m1', { phoneNumber: '+15550100002' })).toEqual({
      success: false,
      error: 'That number belongs to another member',
      code: 'PHONE_TAKEN',
      status: 409,
    })
  })

  it('maps a P2002 without meta.target to 409 too (Prisma-version independent)', async () => {
    prismaMock.member.update.mockRejectedValue(Object.assign(new Error('unique'), { code: 'P2002' }))
    expect((await updateMember('m1', { phoneNumber: '+15550100002' })).status).toBe(409)
  })
})

describe('updateMember with the same phone in another format (D5, D23)', () => {
  it.each([['+15550100001'], ['(555) 010-0001'], ['1-555-010-0001'], ['5550100001']])(
    '%j drops the key and changes nothing about verification',
    async (raw) => {
      const res = await updateMember('m1', { phoneNumber: raw, firstName: 'X' }, 'self')
      expect(res.success).toBe(true)
      expect(written().data).toEqual({ firstName: 'X', updatedAt: expect.any(Date) })
    }
  )
})

describe('updateMember member-session phone guard (D12, D23)', () => {
  it('403s a member session changing its own number and writes nothing', async () => {
    expect(await updateMember('m1', { phoneNumber: '+15550109999' }, 'self')).toEqual({
      success: false,
      error: 'Phone changes go through sign-in',
      status: 403,
    })
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('lets a member session save its unchanged number', async () => {
    expect((await updateMember('m1', { phoneNumber: STORED_PHONE }, 'self')).success).toBe(true)
  })
})

describe('updateMember phone edge cases', () => {
  it('400s an unnormalizable number without a read or a write', async () => {
    expect(await updateMember('m1', { phoneNumber: '12345' })).toEqual({
      success: false,
      error: 'Enter a valid phone number',
      status: 400,
    })
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('404s when the member row is gone', async () => {
    prismaMock.member.findUnique.mockResolvedValue(null)
    expect(await updateMember('m1', { phoneNumber: '+15550109999' })).toEqual({
      success: false,
      error: 'Member not found',
      status: 404,
    })
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
