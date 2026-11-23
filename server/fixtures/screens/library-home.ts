/**
 * library-home layer (notes D19): the Fixtures leader's notes, one in each D3 bucket — today,
 * yesterday, Previous 7 Days, Previous 30 Days, an earlier month, an earlier year — newest first,
 * the today note linked to base group 1 for the context line. Also (memo-screens D19) 5 voice memos,
 * one per Library preview state: ready (1 h), pending (1 d), failed (4 d), none (15 d), ready (45 d).
 * Also (video-recorder) 4 videos, ids 2001-2004: ready with a transcript (3 h), pending (2 d), failed transcript (6 d)
 * and ready used in a lesson activity (20 d, with its org Media row and ACTIVITY MediaUsage).
 * `empty` is base only (this layer
 * exports none). Creates no org, user or group; never touches ctx.rand; dates only from ctx.
 */
import type { FixtureContext } from '../context.js'
import { deriveTitlePreview } from '../../src/services/note-title.js'
import { memoKey } from '../../src/services/memos.service.js'
import { TRANSCRIPT_MAX_ATTEMPTS } from '../../src/services/transcription.service.js'
import { FIXTURE_GROUP_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

const NOTES: ReadonlyArray<{ age: number | 'hour'; content: string }> = [
  { age: 'hour', content: '# Sunday sermon\nGrace is a gift, not a wage.' },
  { age: 1, content: '# Prayer list\nFamily, the group, and the week ahead.' },
  { age: 4, content: '# Romans 8 reflections\nNo condemnation for those in Christ.' },
  { age: 15, content: '# Group study ideas\nTry a five-day plan on forgiveness.' },
  { age: 45, content: '# Retreat planning\nBook the lodge and confirm the speaker.' },
  { age: 400, content: '# Last year goals\nRead through the Gospels slowly.' },
]

export function libraryHomeRows(now: Date, daysAgo: (n: number) => Date) {
  const notes = NOTES.map((spec, i) => {
    const at = spec.age === 'hour' ? new Date(now.getTime() - 3_600_000) : daysAgo(spec.age)
    return {
      id: fixtureId('studyNote', i + 1),
      userId: FIXTURE_USER_ID,
      type: 'NOTE',
      content: spec.content,
      ...deriveTitlePreview(spec.content),
      createdAt: at,
      updatedAt: at,
    }
  })
  const links = [
    { id: fixtureId('studyNote', 1001), noteId: notes[0].id, refType: 'GROUP', refId: FIXTURE_GROUP_IDS[0], createdAt: notes[0].createdAt },
  ]
  return { notes, links }
}

type MemoSpec = {
  recordedAt: (now: Date, daysAgo: (n: number) => Date) => Date
  title: string
  durationMs: number
  transcriptStatus: 'ready' | 'pending' | 'failed' | 'none'
  transcriptAttempts: number
  transcript: string | null
}

// pending/failed carry TRANSCRIPT_MAX_ATTEMPTS so memoIdsDueForTranscriptRetry never claims them.
const MEMOS: ReadonlyArray<MemoSpec> = [
  {
    recordedAt: (now) => new Date(now.getTime() - 3_600_000),
    title: 'Sermon follow-up',
    durationMs: 12_000,
    transcriptStatus: 'ready',
    transcriptAttempts: 1,
    transcript: 'Grace is a gift, not a wage. Sunday we start Romans eight with the whole group. Ask Sarah to lead the prayer time.',
  },
  { recordedAt: (_, d) => d(1), title: 'Prayer requests', durationMs: 95_000, transcriptStatus: 'pending', transcriptAttempts: TRANSCRIPT_MAX_ATTEMPTS, transcript: null },
  { recordedAt: (_, d) => d(4), title: 'Leader huddle notes', durationMs: 184_000, transcriptStatus: 'failed', transcriptAttempts: TRANSCRIPT_MAX_ATTEMPTS, transcript: null },
  { recordedAt: (_, d) => d(15), title: 'Memo 4', durationMs: 31_000, transcriptStatus: 'none', transcriptAttempts: 0, transcript: null },
  {
    recordedAt: (_, d) => d(45),
    title: 'Retreat ideas',
    durationMs: 3_725_000,
    transcriptStatus: 'ready',
    transcriptAttempts: 1,
    transcript: 'Book the lodge early and ask the worship team about Saturday night.',
  },
]

export function libraryHomeMemos(now: Date, daysAgo: (n: number) => Date) {
  return MEMOS.map((spec, i) => {
    const id = fixtureId('voiceMemo', i + 1)
    const at = spec.recordedAt(now, daysAgo)
    return {
      id,
      userId: FIXTURE_USER_ID,
      key: memoKey(FIXTURE_USER_ID, id),
      title: spec.title,
      durationMs: spec.durationMs,
      fileSize: null,
      transcript: spec.transcript,
      transcriptStatus: spec.transcriptStatus,
      transcriptSource: spec.transcriptStatus === 'ready' ? 'server' : null,
      transcriptAttempts: spec.transcriptAttempts,
      uploadStatus: 'ready',
      isActive: true,
      recordedAt: at,
      createdAt: at,
      updatedAt: at,
    }
  })
}

type VideoSpec = {
  at: (now: Date, daysAgo: (n: number) => Date) => Date
  title: string
  status: 'ready' | 'pending'
  duration: number | null
  transcriptStatus: 'ready' | 'pending' | 'failed'
  transcript: string | null
}

// pending/failed carry TRANSCRIPT_MAX_ATTEMPTS so the fallback runner never claims them.
const VIDEOS: ReadonlyArray<VideoSpec> = [
  {
    at: (now) => new Date(now.getTime() - 3 * 3_600_000),
    title: 'Welcome to the group',
    status: 'ready',
    duration: 45,
    transcriptStatus: 'ready',
    transcript: 'Welcome everyone. This week we begin a study of Romans together, so bring your Bible and a friend.',
  },
  { at: (_, d) => d(2), title: 'Video 2', status: 'pending', duration: null, transcriptStatus: 'pending', transcript: null },
  { at: (_, d) => d(6), title: 'Week three recap', status: 'ready', duration: 72, transcriptStatus: 'failed', transcript: null },
  {
    at: (_, d) => d(20),
    title: 'Opening prayer',
    status: 'ready',
    duration: 30,
    transcriptStatus: 'ready',
    transcript: 'Father, thank you for this time together. Open our hearts to your word.',
  },
]

/** The Library's videos, one per state, plus the Media row and ACTIVITY usage that put the last one in a lesson. */
export function libraryHomeVideos(now: Date, daysAgo: (n: number) => Date) {
  const videos = VIDEOS.map((spec, i) => {
    const n = 2001 + i
    const at = spec.at(now, daysAgo)
    const pending = spec.status === 'pending'
    return {
      id: fixtureId('video', n),
      userId: FIXTURE_USER_ID,
      title: spec.title,
      cloudflareUid: `fixture-video-${n}`,
      playbackUrl: pending ? '' : `https://videodelivery.net/fixture-video-${n}/manifest/video.m3u8`,
      thumbnailUrl: pending ? null : `https://picsum.photos/seed/makeready-fixture-video-${n}/640/360`,
      duration: spec.duration,
      status: spec.status,
      transcript: spec.transcript,
      transcriptStatus: spec.transcriptStatus,
      transcriptSource: spec.transcriptStatus === 'ready' ? 'on_device' : null,
      transcriptAttempts: spec.transcriptStatus === 'ready' ? 0 : TRANSCRIPT_MAX_ATTEMPTS,
      isActive: true,
      createdAt: at,
      updatedAt: at,
    }
  })
  const used = videos[3]
  const media = [
    {
      id: fixtureId('media', 2201),
      title: used.title,
      url: used.playbackUrl,
      type: 'video',
      organizationId: FIXTURE_ORG_ID,
      uploadedBy: FIXTURE_USER_ID,
      videoId: used.id,
      thumbnailUrl: used.thumbnailUrl,
      duration: used.duration,
      source: 'auto_capture',
      createdAt: used.createdAt,
      updatedAt: used.createdAt,
    },
  ]
  const usages = [
    {
      id: fixtureId('mediaUsage', 2201),
      mediaId: media[0].id,
      usageType: 'ACTIVITY',
      resourceId: fixtureId('contentActivity', 2201),
      resourceName: 'Opening prayer',
      createdAt: used.createdAt,
    },
  ]
  return { videos, media, usages }
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { notes, links } = libraryHomeRows(ctx.now, (n) => ctx.daysAgo(n))
  await ctx.prisma.studyNote.createMany({ data: notes })
  await ctx.prisma.noteLink.createMany({ data: links })
  await ctx.prisma.voiceMemo.createMany({ data: libraryHomeMemos(ctx.now, (n) => ctx.daysAgo(n)) })
  const { videos, media, usages } = libraryHomeVideos(ctx.now, (n) => ctx.daysAgo(n))
  await ctx.prisma.video.createMany({ data: videos })
  await ctx.prisma.media.createMany({ data: media })
  await ctx.prisma.mediaUsage.createMany({ data: usages })
}
