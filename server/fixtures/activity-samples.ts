/**
 * The sample lesson both activities screens write (SPEC §iphone "Fixtures"): one activity of each kind —
 * text, bible, video, youtube, write — plus an unknown kind (`quiz`, D11's fallback), a text page long enough to
 * scroll on a 956 pt viewport, a background image, an inline action and a pinned action.
 */
import {
  bibleDocument,
  inlineAction,
  pinnedAction,
  textDocument,
  textObject,
  videoDocument,
  writeDocument,
  youtubeDocument,
} from './activity-documents.js'
import type { FixtureContext } from './context.js'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from './ids.js'
import { type ActivitySeed, seedImageMedia } from './lesson-content.js'

export const SAMPLE_BACKGROUND_URL = 'https://picsum.photos/seed/makeready-fixture-activities/880/1912'
export const SAMPLE_POSTER_URL = 'https://picsum.photos/seed/makeready-fixture-poster/640/360'
export const SAMPLE_VIDEO_PLAYBACK_URL = 'https://videodelivery.net/fixture-video-samples/manifest/video.m3u8'
export const SAMPLE_KINDS = ['text', 'bible', 'video', 'youtube', 'write', 'quiz'] as const

export interface SampleMedia {
  backgroundId: string
  posterId: string
  videoId: string
}

/** Two photos, a Video and its Media row, under ids from `n` upward. */
export async function seedSampleMedia(ctx: FixtureContext, n: number): Promise<SampleMedia> {
  const backgroundId = await seedImageMedia(ctx, n + 1, 'Sample background', SAMPLE_BACKGROUND_URL)
  const posterId = await seedImageMedia(ctx, n + 2, 'Sample poster', SAMPLE_POSTER_URL)
  const videoId = fixtureId('video', n)
  await ctx.prisma.video.create({
    data: {
      id: videoId,
      title: 'A welcome from your leader',
      cloudflareUid: `fixture-video-samples-${n}`,
      playbackUrl: SAMPLE_VIDEO_PLAYBACK_URL,
      thumbnailUrl: SAMPLE_POSTER_URL,
      duration: 180,
      status: 'ready',
      userId: FIXTURE_USER_ID,
      createdAt: ctx.daysAgo(30),
    },
  })
  await ctx.prisma.media.create({
    data: {
      id: fixtureId('media', n + 3),
      title: 'A welcome from your leader',
      url: SAMPLE_VIDEO_PLAYBACK_URL,
      thumbnailUrl: SAMPLE_POSTER_URL,
      type: 'video',
      mimeType: 'video/mp4',
      videoId,
      organizationId: FIXTURE_ORG_ID,
      uploadedBy: FIXTURE_USER_ID,
    },
  })
  return { backgroundId, posterId, videoId }
}

const LONG_PARAGRAPH =
  'Grace is not a reward for the finished and the faithful. It meets us in the middle of the story, before we have ' +
  'earned anything, and it keeps meeting us after we have failed again. Read this slowly and let each line settle. '

/** The samples in rail order; `suffix` marks a draft's text so the two reads differ. */
export function sampleActivities(m: SampleMedia, idBase: number, keyPrefix: string, suffix = ''): ActivitySeed[] {
  const key = (k: number) => `${keyPrefix}-${k}`
  const id = (k: number) => fixtureId('contentActivity', idBase + k)
  return [
    {
      id: id(1),
      activityKey: key(1),
      kind: 'text',
      title: 'Text',
      document: textDocument(
        [
          textObject({ id: 'o1', role: 'eyebrow', text: 'PRAYER', size: 11, weight: 700, y: 182 }),
          textObject({ id: 'o2', role: 'prayer', text: `God, sometimes it's hard to focus my mind on good things.${suffix}`, size: 28, weight: 700, y: 470 }),
        ],
        { imageMediaId: m.backgroundId, actions: [inlineAction('a1', 'Add to Prayer List')] }
      ),
    },
    {
      id: id(2),
      activityKey: key(2),
      kind: 'text',
      title: 'Long text',
      document: textDocument(
        [textObject({ id: 'o1', role: 'body', text: LONG_PARAGRAPH.repeat(24), size: 20, font: 'serif', y: 1250 })],
        { anchor: 'top', actions: [pinnedAction('a1', 'Next lesson')] }
      ),
    },
    {
      id: id(3),
      activityKey: key(3),
      kind: 'bible',
      title: 'Bible',
      document: bibleDocument(
        [
          textObject({ id: 'o1', role: 'scripture', text: '16 For God so loved the world, that he gave his only Son.', font: 'serif', size: 26, y: 440 }),
          textObject({ id: 'o2', role: 'citation', text: 'John 3:16', size: 14, weight: 700, y: 560 }),
        ],
        [{ bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16 }]
      ),
    },
    {
      id: id(4),
      activityKey: key(4),
      kind: 'video',
      title: 'Video',
      document: videoDocument(m.videoId, { posterMediaId: m.posterId, presenterName: 'Fixture Leader' }),
      estimatedSeconds: 180,
    },
    { id: id(5), activityKey: key(5), kind: 'youtube', title: 'YouTube', document: youtubeDocument('G-2e9mMf7E8') },
    { id: id(6), activityKey: key(6), kind: 'write', title: 'Write', document: writeDocument('What stood out to you today?') },
    {
      // An unknown kind, written directly: it fails parseActivityDocument on purpose (D11's fallback).
      id: id(7),
      activityKey: key(7),
      kind: 'quiz',
      title: 'Quiz',
      document: {
        schemaVersion: 1,
        kind: 'quiz',
        background: { color: '#0E4A4D' },
        content: { type: 'quiz' },
        chrome: { topAction: 'none' },
        fallback: { title: 'A new activity', body: 'Update the app to see this.' },
      },
    },
  ]
}
