import express from 'express'
import request from 'supertest'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => ({ uploadMemberAvatar: vi.fn(), deleteMemberAvatar: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  // 401/403 stay the middleware's (unchanged); these tests are about the body and the service call.
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member-access.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-access.js')>()),
  canViewMember: vi.fn(),
}))
vi.mock('../../services/member.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member.js')>()),
  updateMember: vi.fn(),
}))

import { updateMember } from '../../services/member.js'
import { canViewMember } from '../../services/member-access.js'
import membersRoutes from '../members.js'

function appAs(who: { userId?: string; memberId?: string }) {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const LEADER = { userId: 'gl' }
const SELF = { memberId: 'm1' }
const DATA = { id: 'm1', firstName: 'James', phoneNumber: '+15550100001' }
const PHONE_MESSAGE = 'Enter a valid phone number'
const BIRTHDAY_MESSAGE = 'Birthday must be between 1900 and today'

const patch = (body: unknown, who: { userId?: string; memberId?: string } = LEADER) =>
  request(appAs(who)).patch('/api/members/m1').send(body as object)
/** The (data, viewerKind) the route handed to updateMember. */
const sent = () => {
  const [memberId, data, viewerKind] = vi.mocked(updateMember).mock.calls[0]
  expect(memberId).toBe('m1')
  return { data, viewerKind }
}
const expect400 = async (body: unknown, message: string) => {
  const res = await patch(body)
  expect(res.status).toBe(400)
  expect(res.body).toEqual({ success: false, error: message })
  expect(updateMember).not.toHaveBeenCalled()
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-10-26T15:00:00Z'))
  vi.mocked(canViewMember).mockResolvedValue(true)
  vi.mocked(updateMember).mockResolvedValue({ success: true, data: DATA as never })
})

afterEach(() => {
  vi.useRealTimers()
})

describe('PATCH /api/members/:memberId — today’s web bodies still save (F3)', () => {
  it('admin profile.ui.ts name edit', async () => {
    const res = await patch({ firstName: 'Ann', lastName: 'Lee' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: DATA })
    expect(sent()).toEqual({ data: { firstName: 'Ann', lastName: 'Lee' }, viewerKind: 'user' })
  })

  it('admin profile.ui.ts consent toggle', async () => {
    const res = await patch({ smsConsent: true })
    expect(res.status).toBe(200)
    expect(sent().data).toEqual({ smsConsent: true, smsConsentAt: expect.any(Date) })
  })

  it('member /profile form (ProfileController.php), from the member’s own session', async () => {
    const res = await patch({ firstName: 'Ann', lastName: 'Lee', gender: null, birthday: '1990-05-01' }, SELF)
    expect(res.status).toBe(200)
    expect(canViewMember).not.toHaveBeenCalled()
    expect(sent()).toEqual({
      data: { firstName: 'Ann', lastName: 'Lee', gender: null, birthday: new Date('1990-05-01T00:00:00.000Z') },
      viewerKind: 'self',
    })
  })
})

describe('.strict() (SC1)', () => {
  it('400s an unknown key and never calls the service', async () => {
    const res = await patch({ firstName: 'Ann', nickname: 'A' })
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(res.body.error).toContain('nickname')
    expect(updateMember).not.toHaveBeenCalled()
  })

  it('400s server-written keys sent by a client', async () => {
    expect((await patch({ phoneVerified: true })).status).toBe(400)
    expect((await patch({ lastVerifiedAt: null })).status).toBe(400)
    expect(updateMember).not.toHaveBeenCalled()
  })
})

describe('phoneNumber (D4, D18)', () => {
  it.each([
    ['5550109999', '+15550109999'],
    ['(555) 010-9999', '+15550109999'],
    ['15550109999', '+15550109999'],
    ['1-555-010-9999', '+15550109999'],
    ['+44 20 7946 0958', '+442079460958'],
    [' +15550109999 ', '+15550109999'],
  ])('%j is sent normalized as %j', async (raw, normalized) => {
    expect((await patch({ phoneNumber: raw })).status).toBe(200)
    expect(sent().data).toEqual({ phoneNumber: normalized })
  })

  it.each([[''], ['   '], ['12345'], ['abc'], ['+0123456789'], ['555-010-9999 x12'], [null], [5550109999]])(
    '%j → 400',
    async (raw) => {
      await expect400({ phoneNumber: raw }, PHONE_MESSAGE)
    }
  )
})

describe('emergencyContactPhone (D7)', () => {
  it.each([['555-1234'], ['(555) 010-2000 ext. 12'], ['+44 20 7946 0958'], ['555 010 2000 x9']])(
    '%j saves as typed',
    async (raw) => {
      expect((await patch({ emergencyContactPhone: raw })).status).toBe(200)
      expect(sent().data).toEqual({ emergencyContactPhone: raw })
    }
  )

  it('trims before storing', async () => {
    await patch({ emergencyContactPhone: '  555-1234  ' })
    expect(sent().data).toEqual({ emergencyContactPhone: '555-1234' })
  })

  it('caps length before the regex runs', async () => {
    await expect400({ emergencyContactPhone: '1'.repeat(41) }, PHONE_MESSAGE)
  })

  it.each([['123456'], ['call mom'], ['555-1234 ext'], ['12345 x67']])('%j → 400', async (raw) => {
    await expect400({ emergencyContactPhone: raw }, PHONE_MESSAGE)
  })
})

describe('birthday (D9, D19) — today is 2026-10-26 UTC', () => {
  it.each([
    ['1900-01-01', '1900-01-01T00:00:00.000Z'],
    ['2026-10-26', '2026-10-26T00:00:00.000Z'], // today
    ['2026-10-27', '2026-10-27T00:00:00.000Z'], // UTC tomorrow (UTC+14)
    ['1990-05-01T23:30:00-05:00', '1990-05-02T00:00:00.000Z'], // its UTC date, at 00:00Z
    ['1990-01-01T00:00:00Z', '1990-01-01T00:00:00.000Z'],
  ])('%j is stored as %s', async (raw, iso) => {
    expect((await patch({ birthday: raw })).status).toBe(200)
    expect((sent().data.birthday as Date).toISOString()).toBe(iso)
  })

  it.each([['1899-12-31'], ['2026-10-28'], ['not a date'], ['2026-02-30'], ['05/01/1990']])('%j → 400', async (raw) => {
    await expect400({ birthday: raw }, BIRTHDAY_MESSAGE)
  })

  it('null clears', async () => {
    expect((await patch({ birthday: null })).status).toBe(200)
    expect(sent().data).toEqual({ birthday: null })
  })
})

describe('email (D11)', () => {
  it('trims before the email check', async () => {
    expect((await patch({ email: ' a@b.com ' })).status).toBe(200)
    expect(sent().data).toEqual({ email: 'a@b.com' })
  })

  it('null clears', async () => {
    expect((await patch({ email: null })).status).toBe(200)
    expect(sent().data).toEqual({ email: null })
  })

  it('an invalid address → 400', async () => {
    await expect400({ email: 'not-an-email' }, 'Enter a valid email')
  })
})

describe('gender (D10)', () => {
  it.each([['male'], ['female'], [null]])('%j saves', async (gender) => {
    expect((await patch({ gender })).status).toBe(200)
    expect(sent().data).toEqual({ gender })
  })

  it('any other value → 400', async () => {
    expect((await patch({ gender: 'other' })).status).toBe(400)
    expect(updateMember).not.toHaveBeenCalled()
  })
})

describe('address and emergencyContactName', () => {
  it('trims and saves', async () => {
    await patch({ address: '  12 Main St\nChicago, IL 60614  ', emergencyContactName: ' Sophia Carter ' })
    expect(sent().data).toEqual({ address: '12 Main St\nChicago, IL 60614', emergencyContactName: 'Sophia Carter' })
  })

  it('null clears', async () => {
    await patch({ address: null, emergencyContactName: null })
    expect(sent().data).toEqual({ address: null, emergencyContactName: null })
  })
})

describe('"" on each clearable key saves null (D8, D11)', () => {
  it.each([['email'], ['birthday'], ['gender'], ['address'], ['emergencyContactName'], ['emergencyContactPhone']])(
    '%s',
    async (key) => {
      expect((await patch({ [key]: '' })).status).toBe(200)
      expect(sent().data).toEqual({ [key]: null })
    }
  )

  it('whitespace-only counts as empty', async () => {
    await patch({ address: '   ', emergencyContactPhone: ' ' })
    expect(sent().data).toEqual({ address: null, emergencyContactPhone: null })
  })
})

describe('viewer kind and result mapping (D5, D12, SC3)', () => {
  it('passes "self" for the member’s own session and "user" for a leader', async () => {
    await patch({ phoneNumber: '+15550109999' }, SELF)
    expect(sent().viewerKind).toBe('self')
    vi.mocked(updateMember).mockClear()
    await patch({ phoneNumber: '+15550109999' }, LEADER)
    expect(sent().viewerKind).toBe('user')
  })

  it('answers 409 with the PHONE_TAKEN code', async () => {
    vi.mocked(updateMember).mockResolvedValue({
      success: false,
      error: 'That number belongs to another member',
      code: 'PHONE_TAKEN',
      status: 409,
    })
    const res = await patch({ phoneNumber: '+15550100002' })
    expect(res.status).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'That number belongs to another member', code: 'PHONE_TAKEN' })
  })

  it('answers 403 for the member-session phone guard', async () => {
    vi.mocked(updateMember).mockResolvedValue({ success: false, error: 'Phone changes go through sign-in', status: 403 })
    const res = await patch({ phoneNumber: '+15550109999' }, SELF)
    expect(res.status).toBe(403)
    expect(res.body).toEqual({ success: false, error: 'Phone changes go through sign-in' })
  })

  it('answers 500 when the service sets no status', async () => {
    vi.mocked(updateMember).mockResolvedValue({ success: false, error: 'Failed to update member' })
    const res = await patch({ firstName: 'Ann' })
    expect(res.status).toBe(500)
    expect(res.body).toEqual({ success: false, error: 'Failed to update member' })
  })

  it('still 404s a leader the member is hidden from, before validating (D7)', async () => {
    vi.mocked(canViewMember).mockResolvedValue(false)
    const res = await patch({ phoneNumber: '+15550109999' }, { userId: 'gl2' })
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
    expect(updateMember).not.toHaveBeenCalled()
  })
})
