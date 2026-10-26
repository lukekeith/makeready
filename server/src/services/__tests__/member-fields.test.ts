import { describe, expect, it } from 'vitest'
import { E164, birthdayInRange, isValidContactPhone, normalizePhone, parseBirthday } from '../member-fields.js'

describe('E164 (shared with routes/verification.ts)', () => {
  it('is the sign-in regex', () => {
    expect(E164.source).toBe('^\\+[1-9]\\d{1,14}$')
    expect(E164.test('+15550100001')).toBe(true)
    expect(E164.test('+05550100001')).toBe(false)
    expect(E164.test('15550100001')).toBe(false)
  })
})

describe('normalizePhone (D4, D18)', () => {
  it.each([
    ['5550109999', '+15550109999'], // 10 digits → +1
    ['(555) 010-9999', '+15550109999'], // punctuation stripped
    ['555.010.9999', '+15550109999'],
    [' 555 010 9999 ', '+15550109999'],
    ['15550109999', '+15550109999'], // D18: 11 digits starting 1 → +
    ['1-555-010-9999', '+15550109999'],
    ['+1 (555) 010-9999', '+15550109999'], // leading + kept
    ['+44 20 7946 0958', '+442079460958'],
    ['+15550100001', '+15550100001'], // already normalized
    ['0123456789', '+10123456789'], // NANP-invalid but E.164-valid: accepted (D18)
  ])('%j → %j', (raw, expected) => {
    expect(normalizePhone(raw)).toBe(expected)
  })

  it.each([
    [''],
    ['   '],
    ['12345'], // too short, no +
    ['25550109999'], // 11 digits not starting 1
    ['abc'],
    ['555-010-9999 x12'], // extensions are emergency-phone only (D7)
    ['+0123456789'], // E.164 first digit must be 1-9
    ['+1234567890123456'], // 16 digits
    ['+'],
  ])('%j → null', (raw) => {
    expect(normalizePhone(raw)).toBeNull()
  })
})

describe('isValidContactPhone (D7)', () => {
  it.each([
    ['555-1234'], // exactly 7 digits
    ['(555) 010-2000'],
    ['+1 555 010 2000'],
    ['+44 20 7946 0958'],
    ['555-010-2000 ext. 12'],
    ['555-010-2000 ext 12'],
    ['555 010 2000 x9'],
    ['5550102000X9'],
    ['  555-1234  '], // trimmed before the check
  ])('%j is valid', (raw) => {
    expect(isValidContactPhone(raw)).toBe(true)
  })

  it.each([
    [''],
    ['123456'], // 6 digits
    ['12345 x67'], // 5 digits before the extension
    ['call mom'],
    ['555-1234 ext'], // extension word without digits
    ['555-1234 ext. 12 ext. 3'],
    ['555#1234'],
  ])('%j is invalid', (raw) => {
    expect(isValidContactPhone(raw)).toBe(false)
  })
})

describe('parseBirthday (D9, D19)', () => {
  it.each([
    ['1990-05-01', '1990-05-01T00:00:00.000Z'],
    [' 1990-05-01 ', '1990-05-01T00:00:00.000Z'],
    ['1990-05-01T00:00:00Z', '1990-05-01T00:00:00.000Z'],
    ['1990-05-01T00:00:00.000Z', '1990-05-01T00:00:00.000Z'],
    ['1990-05-01T15:45:00Z', '1990-05-01T00:00:00.000Z'], // time dropped
    ['1990-05-01T23:30:00-05:00', '1990-05-02T00:00:00.000Z'], // its UTC calendar date
    ['1990-05-01T01:00:00+05:00', '1990-04-30T00:00:00.000Z'],
    ['1990-05-01T12:00:00', '1990-05-01T00:00:00.000Z'], // no offset = UTC (never server-local)
    ['2000-02-29', '2000-02-29T00:00:00.000Z'],
  ])('%j → %s', (raw, iso) => {
    expect(parseBirthday(raw)?.toISOString()).toBe(iso)
  })

  it.each([[''], ['not a date'], ['1990-13-01'], ['2026-02-30'], ['2001-02-29'], ['05/01/1990'], ['1990-5-1'], ['1990']])(
    '%j → null',
    (raw) => {
      expect(parseBirthday(raw)).toBeNull()
    }
  )
})

describe('birthdayInRange (D9)', () => {
  const now = new Date('2026-10-26T15:00:00Z')
  const at = (ymd: string) => new Date(`${ymd}T00:00:00Z`)

  it.each<[string, boolean]>([
    ['1899-12-31', false],
    ['1900-01-01', true],
    ['1990-05-01', true],
    ['2026-10-26', true], // UTC today
    ['2026-10-27', true], // UTC tomorrow (UTC+14 devices)
    ['2026-10-28', false],
  ])('%s → %s', (ymd, expected) => {
    expect(birthdayInRange(at(ymd), now)).toBe(expected)
  })

  it('uses the UTC day of now, not its time', () => {
    expect(birthdayInRange(at('2026-10-27'), new Date('2026-10-26T00:00:01Z'))).toBe(true)
    expect(birthdayInRange(at('2026-10-28'), new Date('2026-10-26T23:59:59Z'))).toBe(false)
  })
})
