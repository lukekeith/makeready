import { describe, expect, it } from 'vitest'
import { fixtureId } from '../ids.js'
import { videoDetailRow } from '../screens/video-detail.js'

describe('video-detail layer', () => {
  it('video-detail seeds one ready video with segments', () => {
    const now = new Date('2026-11-20T17:00:00.000Z')
    const v = videoDetailRow(now)
    expect(v).toMatchObject({ id: fixtureId('video', 2101), status: 'ready', transcriptStatus: 'ready', transcriptSource: 'on_device' })
    expect((v.transcriptSegments as unknown[]).length).toBeGreaterThan(1)
  })
})
