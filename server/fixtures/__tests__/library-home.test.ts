import { describe, expect, it } from 'vitest'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { libraryHomeRows } from '../screens/library-home.js'

describe('library-home layer rows (notes D19)', () => {
  it('one note per D3 bucket, newest first, the today note linked to a group', () => {
    const NOW = new Date('2026-11-20T17:00:00.000Z')
    const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
    const { notes, links } = libraryHomeRows(NOW, daysAgo)
    expect(notes).toHaveLength(6)
    expect(notes.every((n) => n.type === 'NOTE' && n.userId === FIXTURE_USER_ID && n.title)).toBe(true)
    const ages = notes.map((n) => Math.round((NOW.getTime() - n.updatedAt.getTime()) / 86_400_000))
    expect(ages).toEqual([0, 1, 4, 15, 45, 400])
    expect(links).toEqual([expect.objectContaining({ noteId: notes[0].id, refType: 'GROUP', refId: FIXTURE_GROUP_IDS[0] })])
    expect(notes[0].id).toBe(fixtureId('studyNote', 1))
  })
})
