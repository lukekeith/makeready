/**
 * memo-detail layer (memo-screens D19): gives the library-home `ready` memo (memo 1) its 3 timestamped
 * transcript segments, its real file size and duration, and uploads the short committed .m4a to the
 * walk bucket under the key a real upload uses, only when the bucket lacks it. Runs after library-home
 * (filename order), so the memo row exists. Creates no rows; never touches ctx.rand.
 */
import { existsSync } from 'node:fs'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { memoKey } from '../../src/services/memos.service.js'
import { objectExists, uploadToR2 } from '../../src/services/storage.js'
import { type FixtureContext, FixtureError } from '../context.js'
import { assertFixtureBucket, r2Unconfigured } from '../images.js'
import { FIXTURE_USER_ID, fixtureId } from '../ids.js'

const AUDIO_FILE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'audio', 'memo-detail.m4a')

/** Their texts, joined with a space, are library-home memo 1's transcript. */
export const MEMO_DETAIL_SEGMENTS: ReadonlyArray<{ text: string; startMs: number; endMs: number }> = [
  { text: 'Grace is a gift, not a wage.', startMs: 0, endMs: 4000 },
  { text: 'Sunday we start Romans eight with the whole group.', startMs: 4000, endMs: 8000 },
  { text: 'Ask Sarah to lead the prayer time.', startMs: 8000, endMs: 12000 },
]

interface StorageDeps {
  objectExists: (key: string) => Promise<boolean>
  uploadToR2: (key: string, bytes: Buffer, contentType: string) => Promise<string>
}

/** Uploads `bytes` under `key` unless the bucket has it; true when it uploaded. */
export async function placeMemoAudio(
  key: string,
  bytes: Buffer,
  deps: StorageDeps = { objectExists, uploadToR2 },
): Promise<boolean> {
  if (await deps.objectExists(key)) return false
  await deps.uploadToR2(key, bytes, 'audio/mp4')
  return true
}

export async function full(ctx: FixtureContext): Promise<void> {
  if (!existsSync(AUDIO_FILE)) throw new FixtureError(`memo-detail audio missing at ${AUDIO_FILE}`)
  const bytes = await readFile(AUDIO_FILE)
  const id = fixtureId('voiceMemo', 1)
  await ctx.prisma.voiceMemo.update({
    where: { id },
    data: {
      transcriptSegments: [...MEMO_DETAIL_SEGMENTS],
      fileSize: bytes.length,
      durationMs: MEMO_DETAIL_SEGMENTS[MEMO_DETAIL_SEGMENTS.length - 1].endMs,
    },
  })

  const flag = process.env.FIXTURE_IMAGES
  if (flag === 'off' || (process.env.VITEST && flag !== 'on')) return
  if (flag !== 'on' && r2Unconfigured()) {
    console.warn('fixtures: ⚠️  no R2 settings — skipping the memo-detail audio; FIXTURE_IMAGES=on makes this an error')
    return
  }
  assertFixtureBucket()
  await placeMemoAudio(memoKey(FIXTURE_USER_ID, id), bytes)
}
