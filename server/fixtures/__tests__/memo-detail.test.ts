import { describe, expect, it } from 'vitest'
import { FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { libraryHomeMemos } from '../screens/library-home.js'
import { MEMO_DETAIL_SEGMENTS, placeMemoAudio } from '../screens/memo-detail.js'
import { memoKey } from '../../src/services/memos.service.js'

describe('memo-detail layer (memo-screens D19)', () => {
  it('segments are timestamped and spell memo 1\'s transcript', () => {
    expect(MEMO_DETAIL_SEGMENTS.map((s) => s.startMs)).toEqual([0, 4000, 8000])
    const memo1 = libraryHomeMemos(new Date(), (n) => new Date(Date.now() - n * 86_400_000))[0]
    expect(MEMO_DETAIL_SEGMENTS.map((s) => s.text).join(' ')).toBe(memo1.transcript)
  })

  it('the audio uploads once, under the real memo key', async () => {
    const uploads: string[] = []
    const stored = new Set<string>()
    const deps = {
      objectExists: async (k: string) => stored.has(k),
      uploadToR2: async (k: string, _b: Buffer, type: string) => { expect(type).toBe('audio/mp4'); uploads.push(k); stored.add(k); return k },
    }
    const key = memoKey(FIXTURE_USER_ID, fixtureId('voiceMemo', 1))
    expect(await placeMemoAudio(key, Buffer.from('x'), deps)).toBe(true)
    expect(await placeMemoAudio(key, Buffer.from('x'), deps)).toBe(false)
    expect(uploads).toEqual([key])
  })
})
