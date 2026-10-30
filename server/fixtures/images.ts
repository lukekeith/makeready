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
 *   on purpose. Off under vitest unless FIXTURE_IMAGES=on. With NO R2 setting at all (the agent walk
 *   env, which never sees server/.env) images are skipped with a warning; a partial R2 config, or
 *   FIXTURE_IMAGES=on without R2, still fails.
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
  // Owner 2026-10-30: ≥ 80% of the fixture programs carry a cover. These programs are made by later
  // layers (groups-enroll-program's n 5, home-dashboard's history n 100…), which place their own
  // covers with placeProgramCovers once their rows exist.
  [fixtureId('program', 5)]: { prefer: 'romans-new-life-baptism', pool: (i) => has(i, 'Book', 'romans') }, // Romans in 12 Days
  [fixtureId('program', 100)]: { prefer: 'matthew-mountain-teaching', pool: (i) => has(i, 'Book', 'matthew') }, // The Sermon on the Mount
  [fixtureId('program', 101)]: { prefer: 'psalms-shepherd-valley', pool: (i) => has(i, 'Book', 'psalms') }, // Psalms of Ascent
  [fixtureId('program', 102)]: { prefer: 'acts-pentecost-gathering', pool: (i) => has(i, 'Book', 'acts') }, // Acts: The Early Church
  [fixtureId('program', 103)]: { prefer: 'daniel-prayer-window', pool: (i) => has(i, 'Book', 'daniel') }, // Prayer That Changes Things
  [fixtureId('program', 104)]: { prefer: 'luke-prodigal-embrace', pool: (i) => has(i, 'Book', 'luke') }, // Parables of Jesus
  [fixtureId('program', 105)]: { prefer: 'genesis-creation-animals', pool: (i) => has(i, 'Book', 'genesis') }, // Genesis: Beginnings
  [fixtureId('program', 106)]: { prefer: 'james-faith-feeds', pool: (i) => has(i, 'Book', 'james') }, // James: Faith at Work
  [fixtureId('program', 107)]: { prefer: 'philippians-joy-confinement', pool: (i) => has(i, 'Book', 'philippians') }, // Philippians: Joy
  [fixtureId('program', 108)]: { prefer: 'ruth-road-with-naomi', pool: (i) => has(i, 'Book', 'ruth') }, // Ruth and Esther
  [fixtureId('program', 109)]: { prefer: '1-samuel-hannah-prayer', pool: (i) => has(i, 'Book', '1 samuel') }, // The Lord’s Prayer
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

const R2_KEYS = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET_NAME', 'R2_PUBLIC_URL']

/** True when not one R2 setting is present — an env with no storage, not a misconfigured one. */
export function r2Unconfigured(env: NodeJS.ProcessEnv = process.env): boolean {
  return R2_KEYS.every((k) => !env[k])
}

/** Refuses a bucket that is, or may be, production — fixtures never write there. */
export function assertFixtureBucket(env: NodeJS.ProcessEnv = process.env): void {
  const missing = R2_KEYS.filter((k) => !env[k])
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
  if (flag !== 'on' && r2Unconfigured()) {
    console.warn('fixtures: ⚠️  no R2 settings — skipping fixture images (covers, library, avatars); FIXTURE_IMAGES=on makes this an error')
    return
  }
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
    // A program a later layer makes gets its cover there (placeProgramCovers).
    const program = ctx.created.programs.find((p) => p.id === id)
    if (slug && program) covers.push({ kind: 'PROGRAM_COVER', id, name: program.name, slug })
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

/** Clear of base's media (n ≤ ~30) and study-program-home's usage (101). */
const LAYER_COVER_ID_BASE = 500

/**
 * A later layer's programs (owner 2026-10-30): each manifest program cover among `programIds` placed
 * exactly as seedImages places base's — the R2 ladder, the cover URL, a "<name> - Cover Image" Media
 * row and its PROGRAM_COVER usage. Skipped when images are (the same switches as seedImages).
 */
export async function placeProgramCovers(ctx: FixtureContext, programIds: readonly string[]): Promise<void> {
  const flag = process.env.FIXTURE_IMAGES
  if (flag === 'off' || (process.env.VITEST && flag !== 'on')) return
  if (flag !== 'on' && r2Unconfigured()) return
  assertFixtureBucket()
  if (!existsSync(MANIFEST_PATH)) throw new FixtureError(`no ${MANIFEST_PATH} — run npm run fixtures:images:refresh`)
  const manifest = JSON.parse(await readFile(MANIFEST_PATH, 'utf8')) as ImageManifest
  const { prisma } = ctx
  const programs = await prisma.studyProgram.findMany({ where: { id: { in: [...programIds] } }, select: { id: true, name: true } })
  for (const program of programs) {
    const slug = manifest.programs[program.id]
    if (!slug) continue
    const source = await readSource(slug)
    const placed = await placeLadder('programs', `program-${program.id}-${keyStamp(source)}`, source)
    await prisma.studyProgram.update({ where: { id: program.id }, data: { coverImageUrl: placed.url } })
    const n = LAYER_COVER_ID_BASE + Object.keys(manifest.programs).indexOf(program.id)
    const info = manifest.images[slug]
    const media = await prisma.media.create({
      data: {
        id: fixtureId('media', n),
        title: `${program.name} - Cover Image`,
        url: placed.url,
        type: 'photo',
        mimeType: 'image/jpeg',
        fileSize: placed.fileSize,
        thumbnailUrl: placed.thumbnailUrl,
        organizationId: FIXTURE_ORG_ID,
        uploadedBy: FIXTURE_USER_ID,
        visibility: 'members',
        uploadStatus: 'ready',
        source: 'auto_capture',
        width: placed.meta.width,
        height: placed.meta.height,
        aspectRatio: placed.meta.aspectRatio,
        dominantColor: placed.meta.dominantColor ?? info?.mainColor ?? null,
        altText: info?.alt ?? null,
        createdAt: ctx.daysAgo(60),
      },
    })
    await prisma.mediaUsage.create({
      data: { id: fixtureId('mediaUsage', n), mediaId: media.id, usageType: 'PROGRAM_COVER', resourceId: program.id, resourceName: program.name },
    })
  }
}
