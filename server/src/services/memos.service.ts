import { randomUUID } from 'node:crypto'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import type { VoiceMemo as VoiceMemoRow } from '../generated/prisma/index.js'
import { headObject, presignPut } from './storage.js'
import { transcribeMemo } from './transcription.service.js'

const MEMO_MIME_TYPE = 'audio/mp4'
const UPLOAD_TTL_SECONDS = 900

const segment = z.object({ text: z.string(), startMs: z.number().int().min(0), endMs: z.number().int().min(0) }).strict()

/** Body of POST /api/memos (D11, D12, D44). */
export const createMemoBody = z.object({
  title: z.string().trim().min(1).max(120),
  durationMs: z.number().int().min(1).max(10_800_000),
  fileSize: z.number().int().min(1).max(104_857_600),
  recordedAt: z.string().datetime({ offset: true }),
  waveformPeaks: z.array(z.number().finite().min(0).max(1)).max(108_001),
  transcript: z.string().max(1_000_000).optional(),
  transcriptSegments: z.array(segment).max(50_000).optional(),
}).strict().superRefine((b, ctx) => {
  if (Math.abs(b.waveformPeaks.length - Math.ceil(b.durationMs / 100)) > 1)
    ctx.addIssue({ code: 'custom', path: ['waveformPeaks'], message: 'waveformPeaks must have one value per 100 ms' })
  b.transcriptSegments?.forEach((s, i) => { if (s.startMs > s.endMs || s.endMs > b.durationMs)
    ctx.addIssue({ code: 'custom', path: ['transcriptSegments', i], message: 'segment out of range' }) })
})

export type CreateMemoInput = z.infer<typeof createMemoBody>

export class MemoServiceError extends Error {
  constructor(public status: 400 | 404 | 409, message: string) {
    super(message)
    this.name = 'MemoServiceError'
  }
}

export interface UploadTicket {
  url: string
  method: 'PUT'
  headers: { 'Content-Type': string; 'Content-Length': string }
  expiresAt: string
}

/** The §Contract VoiceMemo JSON; `url` is non-null only on the detail read (D31). */
export function toVoiceMemo(row: VoiceMemoRow, url?: { url: string; expiresAt: Date }) {
  return {
    id: row.id,
    title: row.title,
    url: url?.url ?? null,
    urlExpiresAt: url?.expiresAt.toISOString() ?? null,
    mimeType: row.mimeType,
    fileSize: row.fileSize,
    durationMs: row.durationMs,
    waveformPeaks: row.waveformPeaks as number[] | null,
    transcript: row.transcript,
    transcriptSegments: row.transcriptSegments as { text: string; startMs: number; endMs: number }[] | null,
    transcriptStatus: row.transcriptStatus,
    transcriptSource: row.transcriptSource,
    uploadStatus: row.uploadStatus,
    recordedAt: row.recordedAt.toISOString(),
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  }
}

/** The list shape (D24): no url, transcript, segments or peaks; a 280-char transcript preview. */
export function toVoiceMemoSummary(row: VoiceMemoRow & { transcriptPreview?: string | null }) {
  const { url: _url, urlExpiresAt: _expires, transcript: _t, transcriptSegments: _s, waveformPeaks: _w, ...rest } = toVoiceMemo(row)
  return { ...rest, transcriptPreview: row.transcriptPreview ?? row.transcript?.slice(0, 280) ?? null }
}

export const memoKey = (userId: string, memoId: string) => `memos/${userId}/${memoId}.m4a`

type TranscriptionRunner = (memoId: string) => void

const defaultRunner: TranscriptionRunner = (memoId) => {
  if (process.env.NODE_ENV === 'test') return
  void transcribeMemo(memoId)
}

let runTranscription: TranscriptionRunner = defaultRunner

/** Swaps the fire-and-forget transcription starter (D33); returns the previous one. */
export function setTranscriptionRunner(fn: TranscriptionRunner): TranscriptionRunner {
  const previous = runTranscription
  runTranscription = fn
  return previous
}

async function findOwnedMemo(userId: string, memoId: string): Promise<VoiceMemoRow> {
  const memo = await prisma.voiceMemo.findFirst({ where: { id: memoId, userId, isActive: true } })
  if (!memo) throw new MemoServiceError(404, 'Memo not found')
  return memo
}

async function mintUpload(key: string, fileSize: number): Promise<UploadTicket> {
  const url = await presignPut(key, MEMO_MIME_TYPE, fileSize, UPLOAD_TTL_SECONDS)
  return {
    url,
    method: 'PUT',
    headers: { 'Content-Type': MEMO_MIME_TYPE, 'Content-Length': String(fileSize) },
    expiresAt: new Date(Date.now() + UPLOAD_TTL_SECONDS * 1000).toISOString(),
  }
}

export async function createMemo(userId: string, input: CreateMemoInput) {
  const id = randomUUID()
  const key = memoKey(userId, id)
  const hasTranscript = !!input.transcript
  const row = await prisma.voiceMemo.create({
    data: {
      id,
      userId,
      key,
      title: input.title,
      mimeType: MEMO_MIME_TYPE,
      fileSize: input.fileSize,
      durationMs: input.durationMs,
      recordedAt: new Date(input.recordedAt),
      waveformPeaks: input.waveformPeaks,
      uploadStatus: 'pending',
      ...(hasTranscript ? {
        transcript: input.transcript,
        transcriptSegments: input.transcriptSegments ?? [],
        transcriptSource: 'on_device',
      } : {}),
    },
  })
  return { memo: toVoiceMemo(row), upload: await mintUpload(key, input.fileSize) }
}

export async function remintUpload(userId: string, memoId: string): Promise<UploadTicket> {
  const memo = await findOwnedMemo(userId, memoId)
  if (memo.uploadStatus === 'ready') throw new MemoServiceError(409, 'Memo already uploaded')
  return mintUpload(memo.key, memo.fileSize ?? 0)
}

export async function completeMemo(userId: string, memoId: string) {
  const memo = await findOwnedMemo(userId, memoId)
  if (memo.uploadStatus === 'ready') return toVoiceMemo(memo)

  const head = await headObject(memo.key)
  if (!head) throw new MemoServiceError(409, 'Uploaded file not found')
  if (head.contentLength !== memo.fileSize) throw new MemoServiceError(409, 'Uploaded file size does not match')

  const hasTranscript = !!memo.transcript
  const updated = await prisma.voiceMemo.update({
    where: { id: memo.id },
    data: { uploadStatus: 'ready', transcriptStatus: hasTranscript ? 'ready' : 'pending' },
  })
  if (!hasTranscript) runTranscription(memo.id)
  return toVoiceMemo(updated)
}
