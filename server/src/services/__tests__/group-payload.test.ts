import { describe, expect, it } from 'vitest'
import { toGroupPayload } from '../group-payload.js'
import { coverFramingSchema, parseStoredFraming } from '../group-cover.js'

const row = (over: Record<string, unknown> = {}) => ({
  id: 'g1', organizationId: 'org1', code: 'ABC123', name: 'Prayer Team', description: null,
  coverImageUrl: 'https://img.test/c.jpeg', coverOriginalUrl: 'https://img.test/o.jpeg',
  coverFraming: { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 },
  isPrivate: false, allowInvites: true, memberDirectoryEnabled: true, memberDirectoryAccess: 'ALLOWED',
  welcomeMessage: null, ageRangeMin: null, ageRangeMax: null, maxMembers: null, creatorId: 'u1',
  createdAt: new Date('2026-10-01T00:00:00Z'), updatedAt: new Date('2026-10-02T00:00:00Z'),
  _count: { members: 3 }, creator: { name: 'Tony Stark' },
  ...over,
})

describe('toGroupPayload (D17)', () => {
  it('returns both cover fields', () => {
    const p = toGroupPayload(row() as any)
    expect(p.coverOriginalUrl).toBe('https://img.test/o.jpeg')
    expect(p.coverFraming).toEqual({ scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 })
  })

  it('returns null for absent cover fields', () => {
    const p = toGroupPayload(row({ coverOriginalUrl: null, coverFraming: null }) as any)
    expect(p.coverOriginalUrl).toBeNull()
    expect(p.coverFraming).toBeNull()
  })

  it('returns null for a stored framing that fails D11', () => {
    expect(toGroupPayload(row({ coverFraming: { scale: 99 } }) as any).coverFraming).toBeNull()
  })

  it('keeps the existing mapping', () => {
    const p = toGroupPayload(row({ ageRangeMin: 18, memberDirectoryEnabled: false }) as any)
    expect(p).toMatchObject({ memberDirectory: false, ageRange: { min: 18, max: null }, memberCount: 3, creatorName: 'Tony Stark' })
    expect(p).not.toHaveProperty('memberDirectoryEnabled')
  })

  it('adds organizationName only when asked', () => {
    expect(toGroupPayload(row() as any)).not.toHaveProperty('organizationName')
    expect(toGroupPayload(row() as any, { organizationName: 'Grace' }).organizationName).toBe('Grace')
    expect(toGroupPayload(row() as any, { organizationName: null })).toHaveProperty('organizationName', null)
  })
})

describe('coverFramingSchema (D11)', () => {
  const ok = { scale: 1, rotation: 0, offsetX: 0, offsetY: 0 }
  it('accepts the bounds', () => {
    expect(coverFramingSchema.parse({ scale: 8, rotation: -180, offsetX: 1, offsetY: -1 })).toBeTruthy()
  })
  it.each([
    ['scale below 1', { ...ok, scale: 0.5 }],
    ['scale above 8', { ...ok, scale: 8.1 }],
    ['rotation above 180', { ...ok, rotation: 181 }],
    ['offsetX beyond 1', { ...ok, offsetX: 1.5 }],
    ['an unknown key', { ...ok, flip: true }],
    ['a missing key', { scale: 1, rotation: 0, offsetX: 0 }],
    ['a non-finite value', { ...ok, scale: Number.POSITIVE_INFINITY }],
  ])('rejects %s', (_label, value) => {
    expect(coverFramingSchema.safeParse(value).success).toBe(false)
  })
  it('parseStoredFraming returns null for junk', () => {
    expect(parseStoredFraming('x')).toBeNull()
    expect(parseStoredFraming(null)).toBeNull()
    expect(parseStoredFraming(ok)).toEqual(ok)
  })
})
