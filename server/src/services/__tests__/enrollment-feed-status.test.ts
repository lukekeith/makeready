import { describe, it, expect } from 'vitest'
import { feedQuerySchema } from '../enrollment-directory.service'

// owner 2026-10-29: the iPhone status filter is multi-select; no selection asks for `all`.
describe('feedQuerySchema status', () => {
  const statuses = (status?: string) => [...feedQuerySchema.parse(status === undefined ? {} : { status }).status].sort()

  it('defaults to active', () => {
    expect(statuses()).toEqual(['active'])
  })
  it('takes one status', () => {
    expect(statuses('draft')).toEqual(['draft'])
  })
  it('takes a comma list', () => {
    expect(statuses('active,draft')).toEqual(['active', 'draft'])
  })
  it('expands all to every status', () => {
    expect(statuses('all')).toEqual(['active', 'completed', 'draft', 'upcoming'])
  })
  it('refuses an unknown or empty status', () => {
    expect(() => feedQuerySchema.parse({ status: 'archived' })).toThrow()
    expect(() => feedQuerySchema.parse({ status: '' })).toThrow()
  })
})
