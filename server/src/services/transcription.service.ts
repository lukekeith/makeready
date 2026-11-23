import { spawn } from 'node:child_process'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { prisma } from '../lib/prisma.js'
import { createDownload, deleteDownload, getDownload, type StreamDownload } from './cloudflare.js'
import { downloadObject } from './storage.js'

export const TRANSCRIPT_MAX_ATTEMPTS = 3
export const CLAIM_STALE_MS = 600_000

const GROQ_URL = 'https://api.groq.com/openai/v1/audio/transcriptions'
const GROQ_MODEL = 'whisper-large-v3-turbo'
const DEFAULT_MAX_UPLOAD_BYTES = 26_214_400

export type TranscriptSegment = { text: string; startMs: number; endMs: number }
export interface GroqResult { text: string; segments: TranscriptSegment[] }
export interface GroqClient { transcribe(audio: Buffer, filename: string): Promise<GroqResult> }
export type SplitAudio = (audio: Buffer, maxBytes: number) => Promise<{ audio: Buffer; offsetMs: number }[]>
export type TranscribeOutcome = 'ready' | 'failed' | 'no-key' | 'not-claimed'
export type VideoTranscribeOutcome = TranscribeOutcome | 'in-progress'

export function createGroqClient(apiKey: string): GroqClient {
  return {
    async transcribe(audio, filename) {
      const form = new FormData()
      form.append('file', new Blob([new Uint8Array(audio)], { type: 'audio/mp4' }), filename)
      form.append('model', GROQ_MODEL)
      form.append('response_format', 'verbose_json')
      const res = await fetch(GROQ_URL, { method: 'POST', headers: { Authorization: `Bearer ${apiKey}` }, body: form })
      if (!res.ok) throw new Error(`Groq transcription failed: ${res.status}`)
      const body = (await res.json()) as { text?: string; segments?: { text: string; start: number; end: number }[] }
      return {
        text: body.text ?? '',
        segments: (body.segments ?? []).map((s) => ({ text: s.text, startMs: Math.round(s.start * 1000), endMs: Math.round(s.end * 1000) })),
      }
    },
  }
}

function run(cmd: string, args: string[]): Promise<{ stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args)
    let stderr = ''
    child.stderr.on('data', (d) => { stderr += d })
    child.on('error', reject)
    child.on('close', (code) => (code === 0 ? resolve({ stderr }) : reject(new Error(`${cmd} exited ${code}: ${stderr.slice(-500)}`))))
  })
}

/** Total duration in ms from ffmpeg's `Duration: hh:mm:ss.xx` line. */
function parseDurationMs(stderr: string): number {
  const m = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(stderr)
  if (!m) throw new Error('ffmpeg reported no duration')
  return Math.round((Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3])) * 1000)
}

/**
 * Splits audio into chunks of at most ~0.9 x maxBytes, cutting at silence
 * boundaries (hard cut when no silence qualifies). Offsets are the cut starts.
 */
export const ffmpegSplitAudio: SplitAudio = async (audio, maxBytes) => {
  const dir = await mkdtemp(path.join(tmpdir(), 'memo-split-'))
  try {
    const input = path.join(dir, 'in.m4a')
    await writeFile(input, audio)
    const { stderr } = await run('ffmpeg', ['-i', input, '-af', 'silencedetect=noise=-30dB:d=0.4', '-f', 'null', '-'])
    const totalMs = parseDurationMs(stderr)
    const silenceEnds = [...stderr.matchAll(/silence_end:\s*([\d.]+)/g)].map((m) => Math.round(Number(m[1]) * 1000))
    const budgetMs = (0.9 * maxBytes * totalMs) / audio.length // the longest span whose estimated size stays <= 0.9 x maxBytes

    const cuts: number[] = [0]
    while (totalMs - cuts[cuts.length - 1] > budgetMs) {
      const start = cuts[cuts.length - 1]
      const fit = silenceEnds.filter((t) => t > start && t - start <= budgetMs)
      cuts.push(fit.length ? fit[fit.length - 1] : Math.floor(start + budgetMs))
    }
    cuts.push(totalMs)

    const chunks: { audio: Buffer; offsetMs: number }[] = []
    for (let i = 0; i < cuts.length - 1; i++) {
      const out = path.join(dir, `chunk-${i}.m4a`)
      await run('ffmpeg', ['-ss', String(cuts[i] / 1000), '-to', String(cuts[i + 1] / 1000), '-i', input, '-c', 'copy', '-f', 'mp4', out])
      chunks.push({ audio: await readFile(out), offsetMs: cuts[i] })
    }
    return chunks
  } finally {
    await rm(dir, { recursive: true, force: true })
  }
}

export interface StreamDownloads {
  createDownload(uid: string): Promise<StreamDownload>
  getDownload(uid: string): Promise<StreamDownload | null>
  deleteDownload(uid: string): Promise<void>
}

interface TranscribeDeps {
  groq?: GroqClient
  splitAudio?: SplitAudio
  env?: NodeJS.ProcessEnv
  download?: (url: string) => Promise<Buffer>
  extractAudio?: (mp4: Buffer) => Promise<Buffer>
  stream?: StreamDownloads
}

/** The row-agnostic core: chunks audio under Groq's upload cap, transcribes each chunk and offsets its segments. */
export async function transcribeAudio(audio: Buffer, deps: TranscribeDeps = {}): Promise<GroqResult> {
  const env = deps.env ?? process.env
  const groq = deps.groq ?? createGroqClient(env.GROQ_API_KEY ?? '')
  const maxBytes = Number(env.GROQ_MAX_UPLOAD_BYTES) || DEFAULT_MAX_UPLOAD_BYTES
  const chunks = audio.length <= maxBytes ? [{ audio, offsetMs: 0 }] : await (deps.splitAudio ?? ffmpegSplitAudio)(audio, maxBytes)

  const texts: string[] = []
  const segments: TranscriptSegment[] = []
  for (const [i, chunk] of chunks.entries()) {
    const result = await groq.transcribe(chunk.audio, `audio-${i}.m4a`)
    texts.push(result.text.trim())
    for (const s of result.segments) segments.push({ text: s.text, startMs: s.startMs + chunk.offsetMs, endMs: s.endMs + chunk.offsetMs })
  }
  return { text: texts.join(' '), segments }
}

/** Transcribes one memo through Groq; claims the row first (D32) and never throws (D33). */
export async function transcribeMemo(memoId: string, deps: TranscribeDeps = {}): Promise<TranscribeOutcome> {
  const env = deps.env ?? process.env
  const apiKey = env.GROQ_API_KEY

  if (!apiKey) {
    const flipped = await prisma.voiceMemo.updateMany({ where: { id: memoId, transcriptStatus: 'pending' }, data: { transcriptStatus: 'failed' } })
    if (flipped.count > 0) console.warn(`[transcription] GROQ_API_KEY is not set; memo ${memoId} left failed without a retry count`)
    return 'no-key'
  }

  const claim = await prisma.voiceMemo.updateMany({
    where: {
      id: memoId, isActive: true, uploadStatus: 'ready', transcriptStatus: { in: ['pending', 'failed'] },
      transcriptAttempts: { lt: TRANSCRIPT_MAX_ATTEMPTS },
      OR: [{ transcriptClaimedAt: null }, { transcriptClaimedAt: { lt: new Date(Date.now() - CLAIM_STALE_MS) } }],
    },
    data: { transcriptClaimedAt: new Date() },
  })
  if (claim.count === 0) return 'not-claimed'

  try {
    const memo = await prisma.voiceMemo.findUniqueOrThrow({ where: { id: memoId }, select: { key: true } })
    const { text, segments } = await transcribeAudio(await downloadObject(memo.key), { ...deps, groq: deps.groq ?? createGroqClient(apiKey) })

    await prisma.voiceMemo.update({
      where: { id: memoId },
      data: { transcript: text, transcriptSegments: segments, transcriptStatus: 'ready', transcriptSource: 'server', transcriptClaimedAt: null },
    })
    return 'ready'
  } catch (err) {
    console.error(`[transcription] memo ${memoId} failed:`, err)
    try {
      await prisma.voiceMemo.update({
        where: { id: memoId },
        data: { transcriptAttempts: { increment: 1 }, transcriptStatus: 'failed', transcriptClaimedAt: null },
      })
    } catch (writeErr) {
      console.error(`[transcription] memo ${memoId}: could not record the failure:`, writeErr)
    }
    return 'failed'
  }
}

async function fetchMp4(url: string): Promise<Buffer> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`Stream download fetch failed: ${res.status}`)
  return Buffer.from(await res.arrayBuffer())
}

/** Copies the audio track out of an MP4 into an `.m4a` (`-vn -c:a copy`). */
async function ffmpegExtractAudio(mp4: Buffer): Promise<Buffer> {
  const dir = await mkdtemp(path.join(tmpdir(), 'video-audio-'))
  try {
    const input = path.join(dir, 'in.mp4')
    const output = path.join(dir, 'out.m4a')
    await writeFile(input, mp4)
    await run('ffmpeg', ['-i', input, '-vn', '-c:a', 'copy', output])
    return await readFile(output)
  } finally {
    await rm(dir, { recursive: true, force: true })
  }
}

/**
 * Transcribes one ready video from its Stream MP4 download (D11); claims the row like a memo's and never throws.
 * A download still being built releases the claim without spending an attempt.
 */
export async function transcribeVideo(videoId: string, deps: TranscribeDeps = {}): Promise<VideoTranscribeOutcome> {
  const env = deps.env ?? process.env
  const apiKey = env.GROQ_API_KEY
  if (!apiKey) return 'no-key'

  const claim = await prisma.video.updateMany({
    where: {
      id: videoId, isActive: true, status: 'ready', transcriptStatus: { in: ['pending', 'failed'] },
      transcriptAttempts: { lt: TRANSCRIPT_MAX_ATTEMPTS },
      OR: [{ transcriptClaimedAt: null }, { transcriptClaimedAt: { lt: new Date(Date.now() - CLAIM_STALE_MS) } }],
    },
    data: { transcriptClaimedAt: new Date() },
  })
  if (claim.count === 0) return 'not-claimed'

  try {
    const { cloudflareUid } = await prisma.video.findUniqueOrThrow({ where: { id: videoId }, select: { cloudflareUid: true } })
    const stream = deps.stream ?? { createDownload, getDownload, deleteDownload }
    const existing = await stream.getDownload(cloudflareUid)
    const download = existing ?? (await stream.createDownload(cloudflareUid))

    if (download.status === 'inprogress') {
      await prisma.video.update({ where: { id: videoId }, data: { transcriptClaimedAt: null } })
      return 'in-progress'
    }

    try {
      if (download.status !== 'ready' || !download.url) throw new Error(`Stream download is ${download.status}`)
      const mp4 = await (deps.download ?? fetchMp4)(download.url)
      const m4a = await (deps.extractAudio ?? ffmpegExtractAudio)(mp4)
      const { text, segments } = await transcribeAudio(m4a, { ...deps, groq: deps.groq ?? createGroqClient(apiKey) })
      await prisma.video.update({
        where: { id: videoId },
        data: { transcript: text, transcriptSegments: segments, transcriptStatus: 'ready', transcriptSource: 'server', transcriptClaimedAt: null },
      })
      return 'ready'
    } finally {
      try {
        await stream.deleteDownload(cloudflareUid)
      } catch (deleteErr) {
        console.error(`[transcription] video ${videoId}: could not delete the Stream download:`, deleteErr)
      }
    }
  } catch (err) {
    console.error(`[transcription] video ${videoId} failed:`, err)
    try {
      await prisma.video.update({
        where: { id: videoId },
        data: { transcriptAttempts: { increment: 1 }, transcriptStatus: 'failed', transcriptClaimedAt: null },
      })
    } catch (writeErr) {
      console.error(`[transcription] video ${videoId}: could not record the failure:`, writeErr)
    }
    return 'failed'
  }
}
