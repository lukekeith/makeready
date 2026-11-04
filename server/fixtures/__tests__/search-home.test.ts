import { describe, expect, it } from 'vitest'
import { fixtureId } from '../ids.js'
import { SEARCH_HOME_WORD, searchHomeRows } from '../screens/search-home.js'

const NOW = new Date('2026-10-31T17:00:00.000Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)

describe('search-home layer rows (master-search D25)', () => {
  it('covers every D5 type with the shared word', () => {
    const rows = searchHomeRows(NOW, daysAgo)
    const titled = [rows.program, rows.lesson, rows.exactPost, rows.orgTemplate, rows.event, rows.photo, rows.video].map((r: any) => r.title ?? r.name)
    for (const t of titled) expect(t).toContain(SEARCH_HOME_WORD)
    expect(rows.exactPost.title).toBe('Grace')
    expect(rows.untitledPost.title).toBeNull()
    expect(rows.photo.uploadStatus).toBe('ready')
    expect(rows.video.type).toBe('video')
    expect(new Set(rows.series.map((e) => e.recurrenceGroupId)).size).toBe(1)
    expect(rows.lessonEvent.type).toBe('LESSON')
  })

  it('recents are newest-first with fixed ids', () => {
    const { recents } = searchHomeRows(NOW, daysAgo)
    expect(recents.map((r) => r.resourceType)).toEqual(['PROGRAM', 'LESSON', 'GROUP', 'PHOTO', 'POST', 'MEMBER'])
    const times = recents.map((r) => r.openedAt.getTime())
    expect(times).toEqual([...times].sort((a, b) => b - a))
    expect(new Set(times).size).toBe(times.length)
    expect(recents[0].id).toBe(fixtureId('recent', 1))
  })
})
