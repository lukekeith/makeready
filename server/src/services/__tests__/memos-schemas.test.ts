import { describe, expect, it } from 'vitest'
import { createMemoBody } from '../memos.service.js'

const base = { title: 'Memo 1', durationMs: 1000, fileSize: 10, recordedAt: '2026-11-20T10:00:00.000Z', waveformPeaks: Array(10).fill(0.5) }

describe('createMemoBody', () => {
  it.each([
    [{ title: '   ' }], [{ title: 'x'.repeat(121) }], [{ fileSize: 104_857_601 }], [{ durationMs: 10_800_001 }],
    [{ durationMs: 0 }], [{ waveformPeaks: Array(13).fill(0.5) }], [{ waveformPeaks: [...Array(9).fill(0.5), 1.5] }],
    [{ transcriptSegments: [{ text: 'a', startMs: 0, endMs: 1001 }] }], [{ transcriptSegments: [{ text: 'a', startMs: 600, endMs: 500 }] }],
    [{ extra: true }], [{ recordedAt: 'yesterday' }],
  ])('createMemoBody refuses %j', (patch) => {
    expect(createMemoBody.safeParse({ ...base, ...patch }).success).toBe(false)
  })

  it.each([9, 10, 11])('createMemoBody accepts %i peaks for 1000 ms', (n) => {
    expect(createMemoBody.safeParse({ ...base, waveformPeaks: Array(n).fill(0) }).success).toBe(true)
  })

  it('createMemoBody trims the title', () => {
    expect(createMemoBody.parse({ ...base, title: '  Memo 7  ' }).title).toBe('Memo 7')
  })
})
