/** notes Task 4: isStomped compares the stored updatedAt to the echoed base (D23). */
import { describe, expect, it, vi } from 'vitest'

vi.mock('../../lib/prisma.js', () => ({ prisma: {}, Prisma: {} }))

import { isStomped } from '../notes.service.js'

describe('isStomped', () => {
  it('isStomped compares at ms with a fraction, at seconds without', () => {
    const stored = new Date('2026-11-20T10:00:00.700Z')
    expect(isStomped(stored, '2026-11-20T10:00:00.700Z')).toBe(false)
    expect(isStomped(stored, '2026-11-20T10:00:00.699Z')).toBe(true)
    expect(isStomped(stored, '2026-11-20T10:00:00Z')).toBe(false)
    expect(isStomped(stored, '2026-11-20T09:59:59Z')).toBe(true)
    expect(isStomped(stored, '2026-11-20T04:00:00.700-06:00')).toBe(false)
  })
})
