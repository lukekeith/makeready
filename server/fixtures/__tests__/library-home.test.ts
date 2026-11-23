import { describe, expect, it } from 'vitest'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { libraryHomeMemos, libraryHomeRows, libraryHomeVideos } from '../screens/library-home.js'
import { memoKey } from '../../src/services/memos.service.js'
import { TRANSCRIPT_MAX_ATTEMPTS } from '../../src/services/transcription.service.js'

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

  it('the 5 memos cover each D5 preview state at the D19 ages', () => {
    const NOW = new Date('2026-11-20T17:00:00.000Z')
    const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
    const memos = libraryHomeMemos(NOW, daysAgo)
    expect(memos.map((m) => m.id)).toEqual([1, 2, 3, 4, 5].map((n) => fixtureId('voiceMemo', n)))
    expect(memos.map((m) => m.transcriptStatus)).toEqual(['ready', 'pending', 'failed', 'none', 'ready'])
    expect(memos.map((m) => (NOW.getTime() - m.recordedAt.getTime()) / 3_600_000)).toEqual([1, 24, 96, 360, 1080])
    expect(memos[1].transcriptAttempts).toBe(TRANSCRIPT_MAX_ATTEMPTS)
    expect(memos[2].transcriptAttempts).toBe(TRANSCRIPT_MAX_ATTEMPTS)
    expect(memos.every((m) => m.userId === FIXTURE_USER_ID && m.key === memoKey(FIXTURE_USER_ID, m.id) && m.uploadStatus === 'ready')).toBe(true)
  })

  it('library-home seeds one video per state', () => {
    const NOW = new Date('2026-11-20T17:00:00.000Z')
    const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
    const { videos, media, usages } = libraryHomeVideos(NOW, daysAgo)
    expect(videos.map((v) => [v.status, v.transcriptStatus])).toEqual([['ready', 'ready'], ['pending', 'pending'], ['ready', 'failed'], ['ready', 'ready']])
    expect(new Set(videos.map((v) => v.id)).size).toBe(4)
    expect(videos.map((v) => v.id)).toEqual([2001, 2002, 2003, 2004].map((n) => fixtureId('video', n)))
    expect(media).toHaveLength(1)
    expect(media[0].videoId).toBe(videos[3].id)
    expect(usages[0]).toMatchObject({ usageType: 'ACTIVITY', mediaId: media[0].id })
  })
})
