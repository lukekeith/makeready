/**
 * Fixture images (home-dashboard-data D22, ui2-members-browse D13, fixture-real-uploads): group
 * covers, program covers, a media library and member avatars seeded as REAL content — the files in
 * the server's R2 bucket under the keys a real upload uses, the rows shaped as that upload writes
 * them. Only the way they got there differs.
 *
 * - Source: the originals committed under `fixtures/images/` with `manifest.json` (the selection and
 *   each image's d2m title, alt and colour). A reset never contacts d2m;
 *   `npm run fixtures:images:refresh` re-pulls the selection from d2m on purpose.
 * - Covers: as `POST /api/groups/:id/cover-image` / `/api/programs/:id/cover-image` leave them —
 *   `groups/group-<id>-<stamp>` (and `programs/program-<id>-<stamp>`) JPEG + WebP ladder, the cover
 *   URL on the row, a Media row "<name> - Cover Image" (source auto_capture) + its usage.
 * - Library photos: as `POST /api/media` leaves them — `library/library-<userId>-<stamp>` ladder,
 *   source direct. Avatars: as `POST /api/members/:id/avatar` — a 512px WebP at
 *   `avatars/members/<id>/<stamp>.webp`, no Media row.
 * - `<stamp>` is a 13-digit number derived from the image's bytes, so keys are stable across resets
 *   (a reset uploads only what the bucket lacks) and change when a refresh changes the image.
 * - Anything that keeps an image from being placed fails the reset; FIXTURE_IMAGES=off skips images
 *   on purpose. Off under vitest unless FIXTURE_IMAGES=on.
 */
import { createHash } from 'node:crypto'
import { existsSync } from 'node:fs'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'
import { extractImageMetadata } from '../src/services/media-metadata.js'
import { getPublicUrl, objectExists, r2BucketName, uploadImageVariants, uploadToR2 } from '../src/services/storage.js'
import { type FixtureContext, FixtureError } from './context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_PROGRAM_IDS, FIXTURE_USER_ID, fixtureId } from './ids.js'

const here = path.dirname(fileURLToPath(import.meta.url))
export const IMAGE_DIR = path.join(here, 'images')
export const MANIFEST_PATH = path.join(IMAGE_DIR, 'manifest.json')
export const LIBRARY_SIZE = 12
export const AVATAR_COUNT = 13
/** The longest side a committed original keeps — the widest size any upload produces. */
export const SOURCE_WIDTH = 1200
/**
 * D13: the members who get an avatar, by base index — the 8 men first, because the d2m set's 13
 * `Use: avatar` faces are all men; the other 11 members fall back to initials.
 */
export const AVATAR_MEMBER_INDICES: readonly number[] = [0, 1, 2, 3, 4, 5, 6, 7, 9, 12, 15, 18, 21]

/** One d2m image, as `GET /api/projects/<project>/images` lists it. */
export interface D2mImage {
  slug: string
  url: string
  title: string
  alt?: string | null
  retired?: boolean
  width: number
  height: number
  mainColor?: string | null
  sha256?: string | null
  terms?: Array<{ taxonomy: string; term: string }>
}

const has = (image: D2mImage, taxonomy: string, term: string) =>
  (image.terms ?? []).some((t) => t.taxonomy === taxonomy && t.term === term)

/** A slot: the preferred d2m slug, then the tag pool it falls back to. */
interface Slot {
  prefer: string
  pool: (image: D2mImage) => boolean
}

/** D22: covers by meaning — group index → slot, program id → slot. */
export const GROUP_COVER_SLOTS: readonly Slot[] = [
  { prefer: 'image-9', pool: (i) => has(i, 'Subject', 'group') }, // Tuesday Men's: men's Bible study around a table
  { prefer: 'image-11', pool: (i) => has(i, 'Subject', 'group') }, // Young Adults: small group around a coffee table
  { prefer: 'image-6', pool: (i) => has(i, 'Subject', 'group') }, // Women's Bible Study: open Bibles and lattes
]
export const PROGRAM_COVER_SLOTS: Readonly<Record<string, Slot>> = {
  [FIXTURE_PROGRAM_IDS.days21]: { prefer: 'genesis-abram-stars', pool: (i) => has(i, 'Book', 'genesis') }, // Foundations of Faith
  [FIXTURE_PROGRAM_IDS.days30]: { prefer: 'john-well-conversation', pool: (i) => has(i, 'Book', 'john') }, // Walking Through John
}

export interface Selection {
  groups: Array<D2mImage | null>
  programs: Record<string, D2mImage | null>
  /** Library-only images (the covers join the library too). */
  library: D2mImage[]
  /** D13: up to AVATAR_COUNT live `Use: avatar` images, by slug — member photos, not library media. */
  avatars: D2mImage[]
}

/**
 * Deterministic picks from a catalog: each slot takes its preferred slug, else the first unused
 * image of its pool (by slug); the library takes LIBRARY_SIZE more `Use: cover` images, one book at
 * a time so it spans the Bible.
 */
export function selectImages(catalog: readonly D2mImage[]): Selection {
  const live = catalog.filter((i) => !i.retired).slice().sort((a, b) => a.slug.localeCompare(b.slug))
  const used = new Set<string>()
  const pick = (slot: Slot): D2mImage | null => {
    const chosen = live.find((i) => i.slug === slot.prefer && !used.has(i.slug)) ?? live.find((i) => slot.pool(i) && !used.has(i.slug))
    if (chosen) used.add(chosen.slug)
    return chosen ?? null
  }
  const groups = GROUP_COVER_SLOTS.map(pick)
  const programs = Object.fromEntries(Object.entries(PROGRAM_COVER_SLOTS).map(([id, slot]) => [id, pick(slot)]))

  const byBook = new Map<string, D2mImage[]>()
  for (const image of live) {
    if (used.has(image.slug) || !has(image, 'Use', 'cover')) continue
    const book = (image.terms ?? []).find((t) => t.taxonomy === 'Book')?.term ?? '~'
    byBook.set(book, [...(byBook.get(book) ?? []), image])
  }
  const books = [...byBook.keys()].sort()
  const library: D2mImage[] = []
  for (let round = 0; library.length < LIBRARY_SIZE && books.some((b) => (byBook.get(b)?.length ?? 0) > round); round++) {
    for (const book of books) {
      const image = byBook.get(book)?.[round]
      if (image && library.length < LIBRARY_SIZE) library.push(image)
    }
  }
  const avatars = live.filter((i) => has(i, 'Use', 'avatar') && !used.has(i.slug)).slice(0, AVATAR_COUNT)
  return { groups, programs, library, avatars }
}

/** What `fixtures/images/` holds: the selection by slug, and each image's d2m metadata. */
export interface ImageManifest {
  groups: Array<string | null>
  programs: Record<string, string | null>
  library: string[]
  avatars: string[]
  images: Record<string, { title: string; alt: string | null; mainColor: string | null }>
}

export function manifestOf(selection: Selection): ImageManifest {
  const all = [...selection.groups, ...Object.values(selection.programs), ...selection.library, ...selection.avatars]
  return {
    groups: selection.groups.map((i) => i?.slug ?? null),
    programs: Object.fromEntries(Object.entries(selection.programs).map(([id, i]) => [id, i?.slug ?? null])),
    library: selection.library.map((i) => i.slug),
    avatars: selection.avatars.map((i) => i.slug),
    images: Object.fromEntries(
      all.filter((i): i is D2mImage => i !== null).map((i) => [i.slug, { title: i.title, alt: i.alt ?? null, mainColor: i.mainColor ?? null }])
    ),
  }
}

export const sourceFile = (slug: string) => path.join(IMAGE_DIR, `${slug}.jpg`)

/** A 13-digit, upload-timestamp-shaped number from the image bytes: stable per image, new per change. */
export function keyStamp(bytes: Buffer): string {
  const n = parseInt(createHash('sha256').update(bytes).digest('hex').slice(0, 8), 16)
  return String(1_700_000_000_000 + n)
}

/** Refuses a bucket that is, or may be, production — fixtures never write there. */
export function assertFixtureBucket(env: NodeJS.ProcessEnv = process.env): void {
  const missing = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET_NAME', 'R2_PUBLIC_URL'].filter((k) => !env[k])
  if (missing.length) {
    throw new FixtureError(`fixture images need R2 — ${missing.join(', ')} not set (FIXTURE_IMAGES=off skips images)`)
  }
  if (env.R2_BUCKET_NAME === 'makeready-media' || /images\.makeready\.org/.test(env.R2_PUBLIC_URL ?? '')) {
    throw new FixtureError(`refusing to seed fixture images into the production bucket (${env.R2_BUCKET_NAME}, ${env.R2_PUBLIC_URL})`)
  }
}

/** The JPEG ladder every cover and library upload writes (groups.ts, programs.ts, media.ts). */
async function ladder(source: Buffer): Promise<[Buffer, Buffer, Buffer]> {
  return Promise.all([
    sharp(source).resize(1200, null, { withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer(),
    sharp(source).resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer(),
    sharp(source).resize(150, null, { withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer(),
  ])
}

interface Placed {
  url: string
  thumbnailUrl: string
  fileSize: number
  meta: Awaited<ReturnType<typeof extractImageMetadata>>
}

/** Uploads `<prefix>/<baseName>` (JPEG + WebP ladder) unless the bucket has it; its public URL. */
async function placeLadder(prefix: string, baseName: string, source: Buffer): Promise<Placed> {
  const [original, medium, thumb] = await ladder(source)
  const key = `${prefix}/${baseName}.jpeg`
  if (!(await objectExists(key))) await uploadImageVariants(prefix, baseName, 'jpeg', original, medium, thumb)
  const url = getPublicUrl(key)
  return { url, thumbnailUrl: url.replace('.jpeg', '-thumb.jpeg'), fileSize: original.length, meta: await extractImageMetadata(source) }
}

async function readSource(slug: string): Promise<Buffer> {
  const file = sourceFile(slug)
  if (!existsSync(file)) throw new FixtureError(`fixture image ${slug} missing at ${file} — run npm run fixtures:images:refresh`)
  return readFile(file)
}

/** Run after the base graph exists: covers on groups and programs, the media library, avatars. */
export async function seedImages(ctx: FixtureContext): Promise<void> {
  const flag = process.env.FIXTURE_IMAGES
  if (flag === 'off' || (process.env.VITEST && flag !== 'on')) return
  assertFixtureBucket()
  if (!existsSync(MANIFEST_PATH)) throw new FixtureError(`no ${MANIFEST_PATH} — run npm run fixtures:images:refresh`)
  const manifest = JSON.parse(await readFile(MANIFEST_PATH, 'utf8')) as ImageManifest
  const { prisma } = ctx
  console.log(`fixtures: placing images in R2 bucket ${r2BucketName()}`)

  let n = 0
  const mediaRow = (p: Placed, title: string, slug: string, source: 'auto_capture' | 'direct') => {
    n += 1
    const info = manifest.images[slug]
    return {
      id: fixtureId('media', n),
      title,
      url: p.url,
      type: 'photo',
      mimeType: 'image/jpeg',
      fileSize: p.fileSize,
      thumbnailUrl: p.thumbnailUrl,
      organizationId: FIXTURE_ORG_ID,
      uploadedBy: FIXTURE_USER_ID,
      visibility: 'members',
      uploadStatus: 'ready',
      source,
      width: p.meta.width,
      height: p.meta.height,
      aspectRatio: p.meta.aspectRatio,
      dominantColor: p.meta.dominantColor ?? info?.mainColor ?? null,
      altText: info?.alt ?? null,
      // media.ts stores the hash on a direct upload; a cover's capture does not.
      fileHash: source === 'direct' ? p.meta.fileHash : null,
      createdAt: ctx.daysAgo(70 - n * 3),
    }
  }

  // Covers: as the cover-image endpoints leave them, captured to the library with their usage.
  const covers: Array<{ kind: 'GROUP_COVER' | 'PROGRAM_COVER'; id: string; name: string; slug: string }> = []
  for (const [i, slug] of manifest.groups.entries()) {
    const id = FIXTURE_GROUP_IDS[i]
    const group = ctx.created.groups.find((g) => g.id === id)
    if (slug && id) covers.push({ kind: 'GROUP_COVER', id, name: group?.name ?? '', slug })
  }
  for (const [id, slug] of Object.entries(manifest.programs)) {
    const program = ctx.created.programs.find((p) => p.id === id)
    if (slug) covers.push({ kind: 'PROGRAM_COVER', id, name: program?.name ?? '', slug })
  }
  const rows = []
  const usages = []
  for (const c of covers) {
    const source = await readSource(c.slug)
    const isGroup = c.kind === 'GROUP_COVER'
    const placed = await placeLadder(isGroup ? 'groups' : 'programs', `${isGroup ? 'group' : 'program'}-${c.id}-${keyStamp(source)}`, source)
    if (isGroup) await prisma.group.update({ where: { id: c.id }, data: { coverImageUrl: placed.url } })
    else await prisma.studyProgram.update({ where: { id: c.id }, data: { coverImageUrl: placed.url } })
    const row = mediaRow(placed, `${c.name} - Cover Image`, c.slug, 'auto_capture')
    rows.push(row)
    usages.push({ id: fixtureId('mediaUsage', usages.length + 1), mediaId: row.id, usageType: c.kind, resourceId: c.id, resourceName: c.name })
  }

  // Library photos: as a direct library upload leaves them.
  for (const slug of manifest.library) {
    const source = await readSource(slug)
    const placed = await placeLadder('library', `library-${FIXTURE_USER_ID}-${keyStamp(source)}`, source)
    rows.push(mediaRow(placed, manifest.images[slug]?.title ?? slug, slug, 'direct'))
  }
  await prisma.media.createMany({ data: rows })
  await prisma.mediaUsage.createMany({ data: usages })

  // D13: avatars as the avatar endpoint leaves them — Member.profilePicture only, never library media.
  for (const [i, slug] of manifest.avatars.entries()) {
    const memberIndex = AVATAR_MEMBER_INDICES[i]
    if (memberIndex === undefined) break
    const memberId = FIXTURE_MEMBER_IDS[memberIndex]
    const source = await readSource(slug)
    const webp = await sharp(source).resize(512, 512, { fit: 'cover', withoutEnlargement: true }).webp({ quality: 85 }).toBuffer()
    const key = `avatars/members/${memberId}/${keyStamp(source)}.webp`
    if (!(await objectExists(key))) await uploadToR2(key, webp, 'image/webp')
    await prisma.member.update({ where: { id: memberId }, data: { profilePicture: getPublicUrl(key) } })
  }
  console.log(`fixtures: ${covers.length} covers, ${manifest.library.length} library photos, ${manifest.avatars.length} avatars in R2`)
}
