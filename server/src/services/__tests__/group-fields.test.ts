import { describe, expect, it } from 'vitest'
import { directoryWrite, isAgeRangeInverted } from '../group-fields.js'

describe('directoryWrite (D7, D12)', () => {
  it('writes nothing when neither key is sent', () => {
    expect(directoryWrite({}, 'NAMES_ONLY')).toBeNull()
  })

  it.each([
    ['ALLOWED', true],
    ['NAMES_ONLY', false],
    ['NOT_ALLOWED', false],
  ] as const)('memberDirectoryAccess %s → enum + Boolean %s (D7)', (access, enabled) => {
    expect(directoryWrite({ memberDirectoryAccess: access }, 'ALLOWED')).toEqual({
      memberDirectoryAccess: access,
      memberDirectoryEnabled: enabled,
    })
  })

  it('accepts both keys when they agree', () => {
    expect(directoryWrite({ memberDirectory: true, memberDirectoryAccess: 'ALLOWED' }, 'NOT_ALLOWED')).toEqual({
      memberDirectoryAccess: 'ALLOWED',
      memberDirectoryEnabled: true,
    })
    expect(directoryWrite({ memberDirectory: false, memberDirectoryAccess: 'NAMES_ONLY' }, 'ALLOWED')).toEqual({
      memberDirectoryAccess: 'NAMES_ONLY',
      memberDirectoryEnabled: false,
    })
  })

  it('flags a conflict when the two keys disagree (D7)', () => {
    expect(directoryWrite({ memberDirectory: true, memberDirectoryAccess: 'NAMES_ONLY' }, 'ALLOWED')).toBe('conflict')
    expect(directoryWrite({ memberDirectory: true, memberDirectoryAccess: 'NOT_ALLOWED' }, 'ALLOWED')).toBe('conflict')
    expect(directoryWrite({ memberDirectory: false, memberDirectoryAccess: 'ALLOWED' }, 'ALLOWED')).toBe('conflict')
  })

  it('Boolean-only true → ALLOWED (D12)', () => {
    expect(directoryWrite({ memberDirectory: true }, 'NAMES_ONLY')).toEqual({
      memberDirectoryAccess: 'ALLOWED',
      memberDirectoryEnabled: true,
    })
  })

  it('Boolean-only false keeps a stored NAMES_ONLY or NOT_ALLOWED, turns ALLOWED into NOT_ALLOWED (D12)', () => {
    expect(directoryWrite({ memberDirectory: false }, 'NAMES_ONLY')).toEqual({
      memberDirectoryAccess: 'NAMES_ONLY',
      memberDirectoryEnabled: false,
    })
    expect(directoryWrite({ memberDirectory: false }, 'NOT_ALLOWED')).toEqual({
      memberDirectoryAccess: 'NOT_ALLOWED',
      memberDirectoryEnabled: false,
    })
    expect(directoryWrite({ memberDirectory: false }, 'ALLOWED')).toEqual({
      memberDirectoryAccess: 'NOT_ALLOWED',
      memberDirectoryEnabled: false,
    })
  })
})

describe('isAgeRangeInverted (D8)', () => {
  it.each([
    [undefined, false],
    [null, false],
    [{ min: 30, max: 20 }, true],
    [{ min: 20, max: 20 }, false],
    [{ min: 20, max: 30 }, false],
    [{ min: 30, max: null }, false],
    [{ min: null, max: 20 }, false],
    [{ min: 30 }, false],
  ])('%j → %s', (range, inverted) => {
    expect(isAgeRangeInverted(range)).toBe(inverted)
  })
})
