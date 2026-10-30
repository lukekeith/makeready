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

describe('feed org / group / leader filters (owner 2026-10-30: multi-select)', () => {
  const a = '11111111-1111-4111-8111-111111111111'
  const b = '22222222-2222-4222-8222-222222222222'
  it('reads one id or a comma list, and nothing as no filter', () => {
    expect(feedQuerySchema.parse({ groupId: a }).groupId).toEqual([a])
    expect(feedQuerySchema.parse({ leaderId: `${a},${b}` }).leaderId).toEqual([a, b])
    expect(feedQuerySchema.parse({ orgId: '' }).orgId).toBeUndefined()
    expect(feedQuerySchema.parse({}).orgId).toBeUndefined()
  })
  it('refuses a non-uuid in the list', () => {
    expect(() => feedQuerySchema.parse({ groupId: `${a},nope` })).toThrow()
  })
})
