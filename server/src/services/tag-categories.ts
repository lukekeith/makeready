/**
 * tag-categories: MakeReady-defined tag categories (D1, D3). Categories and their member spellings are
 * seeded by their migration; a tag belongs to a category when its normalized text equals a member's
 * `tag` (D10). Global and read-only — the same for every organization (D15).
 */
import { prisma } from '../lib/prisma.js'

export type TagCategoryDTO = {
  key: string
  name: string
  position: number
  tags: { tag: string; label: string; position: number }[]
}

/** D10: the Bible parser's own rule — lowercase, all whitespace removed ("1 Samuel" → "1samuel"). */
export function normalizeTag(s: string): string {
  return s.toLowerCase().replace(/\s+/g, '')
}

/** §Contract: categories by position, each one's members by position then spelling. */
export async function listTagCategories(): Promise<TagCategoryDTO[]> {
  const rows = await prisma.tagCategory.findMany({
    orderBy: { position: 'asc' },
    select: {
      key: true,
      name: true,
      position: true,
      tags: {
        select: { tag: true, label: true, position: true },
        orderBy: [{ position: 'asc' }, { tag: 'asc' }],
      },
    },
  })
  return rows.map((c) => ({ key: c.key, name: c.name, position: c.position, tags: c.tags }))
}
