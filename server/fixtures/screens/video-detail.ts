/**
 * video-detail layer (video-recorder): one ready video with an on-device transcript and timestamped segments,
 * for the Video detail screen. Its id (video 2101) is distinct from groups-detail's and library-home's.
 * Creates no org, user or group; never touches ctx.rand; dates only from ctx.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_USER_ID, fixtureId } from '../ids.js'

/** Their texts, joined with a space, are the video's transcript. */
export const VIDEO_DETAIL_SEGMENTS: ReadonlyArray<{ text: string; startMs: number; endMs: number }> = [
  { text: 'Welcome back, everyone.', startMs: 0, endMs: 3000 },
  { text: 'Today we look at how grace changes the way we treat each other.', startMs: 3000, endMs: 9000 },
  { text: 'Read Romans eight before we meet on Sunday.', startMs: 9000, endMs: 14000 },
]

export function videoDetailRow(now: Date) {
  const at = new Date(now.getTime() - 5 * 3_600_000)
  return {
    id: fixtureId('video', 2101),
    userId: FIXTURE_USER_ID,
    title: 'Grace in community',
    cloudflareUid: 'fixture-video-2101',
    playbackUrl: 'https://videodelivery.net/fixture-video-2101/manifest/video.m3u8',
    thumbnailUrl: 'https://picsum.photos/seed/makeready-fixture-video-2101/640/360',
    duration: 14,
    status: 'ready',
    transcript: VIDEO_DETAIL_SEGMENTS.map((s) => s.text).join(' '),
    transcriptSegments: [...VIDEO_DETAIL_SEGMENTS],
    transcriptStatus: 'ready',
    transcriptSource: 'on_device',
    transcriptAttempts: 0,
    isActive: true,
    createdAt: at,
    updatedAt: at,
  }
}

export async function full(ctx: FixtureContext): Promise<void> {
  await ctx.prisma.video.create({ data: videoDetailRow(ctx.now) })
}
