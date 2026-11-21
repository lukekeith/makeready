/**
 * library-home layer (notes D19): the Fixtures leader's notes, one in each D3 bucket — today,
 * yesterday, Previous 7 Days, Previous 30 Days, an earlier month, an earlier year — newest first,
 * the today note linked to base group 1 for the context line. Also (memo-screens D19) 5 voice memos,
 * one per Library preview state: ready (1 h), pending (1 d), failed (4 d), none (15 d), ready (45 d).
 * `empty` is base only (this layer
 * exports none). Creates no org, user or group; never touches ctx.rand; dates only from ctx.
 */
import type { FixtureContext } from '../context.js'
import { deriveTitlePreview } from '../../src/services/note-title.js'
import { memoKey } from '../../src/services/memos.service.js'
import { TRANSCRIPT_MAX_ATTEMPTS } from '../../src/services/transcription.service.js'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'

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

export async function full(ctx: FixtureContext): Promise<void> {
  const { notes, links } = libraryHomeRows(ctx.now, (n) => ctx.daysAgo(n))
  await ctx.prisma.studyNote.createMany({ data: notes })
  await ctx.prisma.noteLink.createMany({ data: links })
  await ctx.prisma.voiceMemo.createMany({ data: libraryHomeMemos(ctx.now, (n) => ctx.daysAgo(n)) })
}
