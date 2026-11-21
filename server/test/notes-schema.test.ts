/**
 * notes SC1, SC2, SC9: StudyNote.title / preview (nullable, no default) and the [userId, updatedAt] index.
 */
import { describe, expect, it } from 'vitest'
import { prisma } from '../src/lib/prisma.js'

describe('StudyNote schema', () => {
  it('a new note row has null title and preview', async () => {
    const user = await prisma.user.create({ data: { email: `ns-${Date.now()}@t.test`, name: 'ns' } })
    const note = await prisma.studyNote.create({ data: { userId: user.id, type: 'NOTE', content: 'x' } })
    expect(note).toMatchObject({ title: null, preview: null })
    await prisma.user.delete({ where: { id: user.id } })
  })

  it('the user/updatedAt index exists', async () => {
    const rows = await prisma.$queryRaw<{ indexdef: string }[]>`SELECT indexdef FROM pg_indexes WHERE tablename = 'study_notes'`
    expect(rows.some((r) => /\("userId", "updatedAt"\)/.test(r.indexdef))).toBe(true)
  })
})
