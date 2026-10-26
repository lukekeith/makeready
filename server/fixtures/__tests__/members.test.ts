import { describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_NAME, MALE_MEMBER_COUNT, MEMBERS_PER_GROUP, memberNominalAge, memberProfile } from '../base.js'
import { FIXTURE_MEMBER_IDS } from '../ids.js'
import { AVATAR_COUNT, AVATAR_MEMBER_INDICES } from '../images.js'
import { JOINED_OFFSETS, MULTI_GROUP_MEMBER_INDICES } from '../screens/members-home.js'
import { LEADER_MEMBER_INDEX } from '../screens/members-profile.js'

const indices = Array.from({ length: FIXTURE_MEMBER_IDS.length }, (_, i) => i)
/** Whole years between a birthday and a YYYY-MM-DD day. */
function ageOn(birthday: Date, today: string): number {
  const [y, m, d] = today.split('-').map(Number)
  const notYet = m - 1 < birthday.getUTCMonth() || (m - 1 === birthday.getUTCMonth() && d < birthday.getUTCDate())
  return y - birthday.getUTCFullYear() - (notYet ? 1 : 0)
}

describe('D13 member fields (base.ts)', () => {
  it('gives every member a unique first.last@example.org', () => {
    const emails = indices.map((i) => memberProfile(i, '2026-10-25').email)
    for (const e of emails) expect(e).toMatch(/^[a-z]+\.[a-z]+@example\.org$/)
    expect(new Set(emails).size).toBe(24)
    expect(emails[0]).toBe('james.carter@example.org')
  })

  it.each(['2026-01-01', '2026-10-25', '2026-12-31'])('keeps every age within 19–67 on %s', (today) => {
    for (const i of indices) {
      const age = ageOn(memberProfile(i, today).birthday, today)
      expect(age).toBeGreaterThanOrEqual(19)
      expect(age).toBeLessThanOrEqual(67)
    }
  })

  it('spreads the ages across the range', () => {
    expect(new Set(indices.map(memberNominalAge)).size).toBeGreaterThanOrEqual(20)
  })

  it('fills gender, a two-line city address and an emergency name and phone', () => {
    for (const i of indices) {
      const p = memberProfile(i, '2026-10-25')
      expect(p.gender).toBe(i < MALE_MEMBER_COUNT ? 'male' : 'female')
      expect(p.address).toMatch(/^\d+ [A-Za-z ]+\n[A-Za-z ]+, IL \d{5}$/)
      expect(p.emergencyContactName).toMatch(/^[A-Z][a-z]+ [A-Z][a-z]+$/)
      expect(p.emergencyContactPhone).toMatch(/^\+1555020\d{4}$/)
    }
  })
})

describe('D13 avatars (images.ts)', () => {
  it('names 13 distinct members of the 24; the other 11 fall back to initials', () => {
    expect(AVATAR_COUNT).toBe(13)
    expect(AVATAR_MEMBER_INDICES).toHaveLength(AVATAR_COUNT)
    expect(new Set(AVATAR_MEMBER_INDICES).size).toBe(AVATAR_COUNT)
    for (const i of AVATAR_MEMBER_INDICES) {
      expect(i).toBeGreaterThanOrEqual(0)
      expect(i).toBeLessThan(FIXTURE_MEMBER_IDS.length)
    }
  })
})

describe('members-home layer', () => {
  it('puts one member of each base group in the Prayer Team (groupCount 2)', () => {
    expect(MULTI_GROUP_MEMBER_INDICES.map((i) => Math.floor(i / MEMBERS_PER_GROUP))).toEqual([0, 1, 2])
  })

  it('re-dates joins so every D6 label bucket appears: 0, 1, 2–6, 7–13, 14–29, ≥ 30 days', () => {
    const ages = JOINED_OFFSETS.map(([, offset]) => -offset)
    expect(ages).toContain(0)
    expect(ages).toContain(1)
    expect(ages.some((d) => d >= 2 && d <= 6)).toBe(true)
    expect(ages.some((d) => d >= 7 && d <= 13)).toBe(true)
    expect(ages.some((d) => d >= 14 && d <= 29)).toBe(true)
    expect(ages.some((d) => d >= 30 && d < 51)).toBe(true) // still newer than every base join (−62 … −51)
    const members = JOINED_OFFSETS.map(([i]) => i)
    expect(new Set(members).size).toBe(members.length)
    for (const i of members) expect(MULTI_GROUP_MEMBER_INDICES).not.toContain(i)
    expect([...ages].sort((a, b) => a - b)).toEqual(ages) // listed newest first
  })
})

describe('members-profile layer', () => {
  it('links the Group-Leader user to the member of the same name (D8 Role)', () => {
    expect(memberProfile(LEADER_MEMBER_INDEX, '2026-10-25').email).toBe(
      `${FIXTURE_LEADER_NAME.toLowerCase().replace(' ', '.')}@example.org`
    )
  })
})
