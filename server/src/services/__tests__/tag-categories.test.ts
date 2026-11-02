import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ tagCategory: { findMany: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { listTagCategories, normalizeTag } from '../tag-categories.js'

describe('tag-categories service', () => {
  beforeEach(() => prismaMock.tagCategory.findMany.mockReset())

  it('normalizes like the Bible parser: lowercase, all whitespace removed (D10)', () => {
    expect(normalizeTag('1 Samuel')).toBe('1samuel')
    expect(normalizeTag('  PSALMS ')).toBe('psalms')
    expect(normalizeTag('song of\tsongs')).toBe('songofsongs')
  })

  it('asks for categories and members in position order, and returns the contract shape', async () => {
    prismaMock.tagCategory.findMany.mockResolvedValue([
      {
        key: 'bible-books',
        name: 'Books of the Bible',
        position: 1,
        tags: [
          { tag: 'genesis', label: 'Genesis', position: 1 },
          { tag: 'psalm', label: 'Psalms', position: 19 },
        ],
      },
    ])
    expect(await listTagCategories()).toEqual([
      {
        key: 'bible-books',
        name: 'Books of the Bible',
        position: 1,
        tags: [
          { tag: 'genesis', label: 'Genesis', position: 1 },
          { tag: 'psalm', label: 'Psalms', position: 19 },
        ],
      },
    ])
    const args = prismaMock.tagCategory.findMany.mock.calls[0][0]
    expect(args.orderBy).toEqual({ position: 'asc' })
    expect(args.select.tags.orderBy).toEqual([{ position: 'asc' }, { tag: 'asc' }])
  })
})
