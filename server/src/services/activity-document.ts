/**
 * The activity document (activity-viewer 02-content-schema §2–§9): validation, size, media refs,
 * searchable text, content hash and reading-time estimate. Pure functions over a document — no Prisma.
 *
 * Every zod object is `.passthrough()`: an unknown field is kept in the returned document, never stripped
 * (SPEC §Contract "Shapes"; 02 §9).
 */
import { createHash } from 'node:crypto'
import { z } from 'zod'
import { READING_WPM } from '../lib/reading-wpm.js'

export const ACTIVITY_KINDS = ['text', 'bible', 'video', 'youtube', 'write', 'poll'] as const
export const MAX_DOCUMENT_BYTES = 262144

export type ActivityKind = (typeof ACTIVITY_KINDS)[number]
export type ParseResult =
  | { ok: true; document: any }
  | { ok: false; code: 'VALIDATION' | 'TOO_LARGE'; error: string }

const PINNED_ERROR = 'At most one pinned action per page'
const TOO_LARGE_ERROR = 'Activity document exceeds 256 KB'

const hex = z.string().regex(/^#[0-9A-Fa-f]{6}$/)
const unit = z.number().min(0).max(1)
const offset = z.number().int().min(0)
const range = z
  .object({ start: offset, end: offset })
  .passthrough()
  .refine((r) => r.start < r.end, { message: 'start must be below end' })

const textObject = z
  .object({
    id: z.string(),
    role: z.enum(['eyebrow', 'heading', 'body', 'scripture', 'citation', 'prayer']).optional(),
    text: z.string(),
    font: z.enum(['display', 'sans', 'serif', 'mono']),
    weight: z.union([z.literal(400), z.literal(500), z.literal(700)]),
    size: z.number().positive(),
    lineHeight: z.number().optional(),
    tracking: z.number().optional(),
    color: hex,
    alignment: z.enum(['left', 'center', 'right']),
    label: z.enum(['none', 'solidDark', 'solidLight']).optional(),
    listStyle: z.enum(['none', 'bullet', 'numbered', 'bibleVerse']).optional(),
    startNumber: z.number().int().optional(),
    reference: z.unknown().optional(),
    animation: z
      .object({ kind: z.string(), trigger: z.string().optional(), loop: z.boolean().optional() })
      .passthrough()
      .optional(),
    effect: z.enum(['none', 'sparkle', 'neon', 'shimmer', 'pixel']).optional(),
    transform: z
      .object({
        x: z.number(),
        y: z.number(),
        width: z.number().positive(),
        scale: z.number().positive(),
        rotation: z.number(),
      })
      .passthrough(),
    marks: z
      .array(
        z
          .object({ kind: z.enum(['bold', 'italic', 'link']), href: z.string().optional() })
          .passthrough()
          .and(range),
      )
      .optional(),
    highlights: z
      .array(z.object({ id: z.string(), noteMarkdown: z.string().nullish() }).passthrough().and(range))
      .optional(),
  })
  .passthrough()

const canvasContent = z
  .object({
    type: z.literal('canvas'),
    verticalAnchor: z.enum(['center', 'top']),
    objects: z.array(textObject),
  })
  .passthrough()

const bibleContent = canvasContent.extend({
  passages: z
    .array(
      z
        .object({
          bookNumber: z.number().int(),
          chapterStart: z.number().int(),
          verseStart: z.number().int(),
          chapterEnd: z.number().int(),
          verseEnd: z.number().int(),
        })
        .passthrough(),
    )
    .optional(),
})

const CONTENT_BY_KIND: Record<ActivityKind, z.ZodTypeAny> = {
  text: canvasContent,
  bible: bibleContent,
  video: z
    .object({
      type: z.literal('video'),
      videoId: z.string(),
      posterMediaId: z.string().nullish(),
      captionsTrack: z.unknown().optional(),
      presenter: z
        .object({
          name: z.string().nullish(),
          avatarMediaId: z.string().nullish(),
          subtitle: z.string().nullish(),
        })
        .passthrough()
        .nullish(),
    })
    .passthrough(),
  youtube: z
    .object({
      type: z.literal('youtube'),
      youtubeVideoId: z.string(),
      startSeconds: z.number().nullish(),
      endSeconds: z.number().nullish(),
    })
    .passthrough(),
  write: z
    .object({ type: z.literal('write'), prompt: textObject, placeholder: z.string().nullish() })
    .passthrough(),
  poll: z
    .object({
      type: z.literal('poll'),
      prompt: textObject,
      options: z.array(z.object({ id: z.string(), label: z.string() }).passthrough()),
      multiple: z.boolean().optional(),
    })
    .passthrough(),
}

const action = z
  .object({
    id: z.string(),
    kind: z.enum(['addToPrayerList', 'write', 'openUrl', 'nextLesson']),
    label: z.string(),
    placement: z.enum(['inline', 'pinned']),
    payload: z.record(z.unknown()),
  })
  .passthrough()

const envelope = z
  .object({
    schemaVersion: z.literal(1),
    kind: z.enum(ACTIVITY_KINDS),
    background: z
      .object({
        color: hex,
        image: z
          .object({ mediaId: z.string(), focal: z.object({ x: unit, y: unit }).passthrough() })
          .passthrough()
          .optional(),
        wash: z.object({ color: hex, opacity: unit }).passthrough().optional(),
        motion: z
          .object({ mode: z.enum(['scroll', 'fixed', 'parallax']), rate: unit })
          .passthrough()
          .optional(),
      })
      .passthrough(),
    content: z.unknown(),
    actions: z
      .array(action)
      .optional()
      .superRefine((list, ctx) => {
        if ((list ?? []).filter((a) => a.placement === 'pinned').length > 1) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, message: PINNED_ERROR })
        }
      }),
    chrome: z.object({ topAction: z.enum(['share', 'menu', 'none']) }).passthrough(),
    fallback: z.object({ title: z.string(), body: z.string() }).passthrough(),
  })
  .passthrough()

function describeIssue(issue: z.ZodIssue): string {
  if (issue.message === PINNED_ERROR) return PINNED_ERROR
  const path = issue.path.join('.')
  return path ? `${path}: ${issue.message}` : issue.message
}

/** Validates a document for `kind`; returns the input object with unknown fields intact. */
export function parseActivityDocument(input: unknown, kind: string): ParseResult {
  if (Buffer.byteLength(JSON.stringify(input) ?? '') > MAX_DOCUMENT_BYTES) {
    return { ok: false, code: 'TOO_LARGE', error: TOO_LARGE_ERROR }
  }
  const head = envelope.safeParse(input)
  if (!head.success) return { ok: false, code: 'VALIDATION', error: describeIssue(head.error.issues[0]) }
  if (head.data.kind !== kind) {
    return { ok: false, code: 'VALIDATION', error: `Document kind "${head.data.kind}" does not match "${kind}"` }
  }
  const body = CONTENT_BY_KIND[head.data.kind].safeParse(head.data.content)
  if (!body.success) {
    const issue = body.error.issues[0]
    return { ok: false, code: 'VALIDATION', error: describeIssue({ ...issue, path: ['content', ...issue.path] }) }
  }
  return { ok: true, document: head.data }
}

/** Media and video ids a document names, de-duplicated (D34, 05 §4). */
export function documentMediaRefs(doc: any): { mediaIds: string[]; videoIds: string[] } {
  const mediaIds = [doc?.background?.image?.mediaId, doc?.content?.posterMediaId, doc?.content?.presenter?.avatarMediaId]
  const videoIds = [doc?.content?.videoId]
  const ids = (list: unknown[]) => [...new Set(list.filter((v): v is string => typeof v === 'string' && v !== ''))]
  return { mediaIds: ids(mediaIds), videoIds: ids(videoIds) }
}

/** The `content.passages` list of a bible document; empty when absent. */
export function documentPassages(doc: any): any[] {
  return Array.isArray(doc?.content?.passages) ? doc.content.passages : []
}

/** Canvas objects in reading order (y ascending, ties by array index — 02 §3). */
function canvasTexts(doc: any): string[] {
  const objects: any[] = Array.isArray(doc?.content?.objects) ? doc.content.objects : []
  return objects
    .map((o, index) => ({ o, index }))
    .sort((a, b) => (a.o?.transform?.y ?? 0) - (b.o?.transform?.y ?? 0) || a.index - b.index)
    .map(({ o }) => o?.text)
    .filter((t): t is string => typeof t === 'string')
}

/** Canvas text in reading order, or the prompt of a `write`/`poll` page, joined with newlines. */
export function documentText(doc: any): string {
  const prompt = doc?.content?.prompt?.text
  const texts = doc?.content?.type === 'write' || doc?.content?.type === 'poll'
    ? (typeof prompt === 'string' ? [prompt] : [])
    : canvasTexts(doc)
  return texts.join('\n')
}

function stableStringify(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${stableStringify(v)}`).join(',')}}`
  }
  return JSON.stringify(value) ?? 'null'
}

/** sha256 over the lesson title and its activities by position, keys sorted recursively (D20). */
export function hashLessonContent(input: {
  title: string
  activities: { activityKey: string; position: number; kind: string; title: string; document: unknown }[]
}): string {
  const activities = [...input.activities]
    .sort((a, b) => a.position - b.position)
    .map(({ activityKey, position, kind, title, document }) => ({ activityKey, position, kind, title, document }))
  return createHash('sha256').update(stableStringify({ title: input.title, activities })).digest('hex')
}

/** Reading seconds for canvas and `write` pages; `null` for video/youtube (filled from media at save). */
export function estimateDocumentSeconds(doc: any): number | null {
  const type = doc?.content?.type
  if (type !== 'canvas' && type !== 'write') return null
  const words = documentText(doc).split(/\s+/).filter(Boolean).length
  return Math.ceil((words / READING_WPM) * 60)
}
