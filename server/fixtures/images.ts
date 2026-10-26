/**
 * Fixture images (home-dashboard-data D22, owner 2026-10-25): group covers, program covers and a
 * media library, pulled from the d2m `makeready` image set by its tags, resized to JPEG and served
 * by this server's static route from `public/fixture-images/` (gitignored).
 *
 * - Source: `GET <d2m>/api/projects/makeready/images` — d2m listens on 127.0.0.1 and serves only the
 *   full-size originals, so the files are copied here; a later reset reuses them without d2m.
 * - URLs: `<FIXTURE_IMAGE_BASE_URL>/fixture-images/<file>`. The default base is the host the iPhone
 *   uses for Local (`LOCAL_SERVER_URL` in iphone/Debug.xcconfig) on this server's PORT, so the
 *   simulator, a device over Tailscale and the web all load them. No base, or d2m down with no
 *   cached copy → covers stay null and the library empty, with one line saying why.
 * - Off under vitest unless FIXTURE_IMAGES=on; FIXTURE_IMAGES=off turns it off anywhere.
 */
import { createHash } from 'node:crypto'
import { existsSync, readFileSync } from 'node:fs'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'
import { type FixtureContext } from './context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_ORG_ID, FIXTURE_PROGRAM_IDS, FIXTURE_USER_ID, fixtureId } from './ids.js'

const here = path.dirname(fileURLToPath(import.meta.url))
const REPO_ROOT = path.resolve(here, '../..')
export const IMAGE_DIR = path.resolve(here, '../public/fixture-images')
const CATALOG_CACHE = path.join(IMAGE_DIR, 'catalog.json')
export const COVER_WIDTH = 1200
export const THUMB_WIDTH = 400
export const LIBRARY_SIZE = 12

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
  return { groups, programs, library }
}

function d2mApi(): string {
  if (process.env.D2M_API_URL) return process.env.D2M_API_URL.replace(/\/$/, '')
  try {
    const config = JSON.parse(readFileSync(path.join(REPO_ROOT, '.d2m.json'), 'utf8')) as { api?: string }
    if (config.api) return config.api.replace(/\/$/, '')
  } catch {
    // no .d2m.json: fall through to d2m's default port
  }
  return 'http://localhost:5961'
}

/** The base every stored URL starts with; null when nothing names a host devices can reach. */
export function imageBaseUrl(env: NodeJS.ProcessEnv = process.env): string | null {
  if (env.FIXTURE_IMAGE_BASE_URL) return env.FIXTURE_IMAGE_BASE_URL.replace(/\/$/, '')
  const xcconfig = path.join(REPO_ROOT, 'iphone/Debug.xcconfig')
  if (!existsSync(xcconfig)) return null
  const host = /^\s*LOCAL_SERVER_URL\s*=\s*(\S+)/m.exec(readFileSync(xcconfig, 'utf8'))?.[1]
  return host ? `http://${host}:${env.PORT ?? '3010'}` : null
}

async function loadCatalog(): Promise<D2mImage[] | null> {
  const api = d2mApi()
  try {
    const res = await fetch(`${api}/api/projects/makeready/images`, { signal: AbortSignal.timeout(10_000) })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const items = ((await res.json()) as { items: D2mImage[] }).items
    await mkdir(IMAGE_DIR, { recursive: true })
    await writeFile(CATALOG_CACHE, JSON.stringify(items))
    return items
  } catch (error) {
    if (existsSync(CATALOG_CACHE)) {
      console.warn(`fixtures: d2m unreachable at ${api} (${(error as Error).message}) — using the cached image catalog`)
      return JSON.parse(await readFile(CATALOG_CACHE, 'utf8')) as D2mImage[]
    }
    console.warn(`fixtures: d2m unreachable at ${api} (${(error as Error).message}) and no cached images — fixtures carry no images`)
    return null
  }
}

interface Stored {
  image: D2mImage
  file: string
  thumb: string
  width: number
  height: number
  bytes: number
  sha256: string
}

/** The image as a COVER_WIDTH JPEG + a THUMB_WIDTH thumbnail, from the cache or d2m. */
async function store(image: D2mImage): Promise<Stored | null> {
  const key = `${image.slug}-${(image.sha256 ?? 'x').slice(0, 8)}`
  const file = `${key}-${COVER_WIDTH}.jpg`
  const thumb = `${key}-${THUMB_WIDTH}.jpg`
  const filePath = path.join(IMAGE_DIR, file)
  const thumbPath = path.join(IMAGE_DIR, thumb)
  try {
    if (!existsSync(filePath) || !existsSync(thumbPath)) {
      const res = await fetch(image.url, { signal: AbortSignal.timeout(30_000) })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const original = Buffer.from(await res.arrayBuffer())
      await writeFile(filePath, await sharp(original).resize({ width: COVER_WIDTH, withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer())
      await writeFile(thumbPath, await sharp(original).resize({ width: THUMB_WIDTH, withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer())
    }
    const buffer = await readFile(filePath)
    const meta = await sharp(buffer).metadata()
    return {
      image,
      file,
      thumb,
      width: meta.width ?? image.width,
      height: meta.height ?? image.height,
      bytes: buffer.length,
      sha256: createHash('sha256').update(buffer).digest('hex'),
    }
  } catch (error) {
    console.warn(`fixtures: image ${image.slug} skipped (${(error as Error).message})`)
    return null
  }
}

const gcd = (a: number, b: number): number => (b === 0 ? a : gcd(b, a % b))

/** Run after the base graph exists: covers on groups and programs, the media library, its usages. */
export async function seedImages(ctx: FixtureContext): Promise<void> {
  const flag = process.env.FIXTURE_IMAGES
  if (flag === 'off' || (process.env.VITEST && flag !== 'on')) return
  const base = imageBaseUrl()
  if (!base) {
    console.warn('fixtures: no FIXTURE_IMAGE_BASE_URL and no LOCAL_SERVER_URL in iphone/Debug.xcconfig — fixtures carry no images')
    return
  }
  const catalog = await loadCatalog()
  if (!catalog) return
  const selection = selectImages(catalog)
  await mkdir(IMAGE_DIR, { recursive: true })

  const all = [...selection.groups, ...Object.values(selection.programs), ...selection.library].filter((i): i is D2mImage => i !== null)
  const stored = new Map<string, Stored>()
  for (const image of all) {
    const s = await store(image)
    if (s) stored.set(image.slug, s)
  }
  const urlOf = (file: string) => `${base}/fixture-images/${file}`
  const { prisma } = ctx

  // Media rows: every stored image, oldest first, added over the last ~10 weeks.
  const ordered = all.filter((i) => stored.has(i.slug))
  const mediaId = new Map<string, string>()
  await prisma.media.createMany({
    data: ordered.map((image, n) => {
      const s = stored.get(image.slug)!
      const id = fixtureId('media', n + 1)
      mediaId.set(image.slug, id)
      const d = gcd(s.width, s.height) || 1
      return {
        id,
        title: image.title,
        description: null,
        url: urlOf(s.file),
        type: 'photo',
        mimeType: 'image/jpeg',
        fileSize: s.bytes,
        organizationId: FIXTURE_ORG_ID,
        uploadedBy: FIXTURE_USER_ID,
        visibility: 'members',
        thumbnailUrl: urlOf(s.thumb),
        uploadStatus: 'ready',
        source: 'import',
        width: s.width,
        height: s.height,
        aspectRatio: `${s.width / d}:${s.height / d}`,
        dominantColor: image.mainColor ?? null,
        altText: image.alt ?? null,
        fileHash: s.sha256,
        createdAt: ctx.daysAgo(70 - n * 3),
      }
    }),
  })

  const usages: Array<{ mediaId: string; usageType: string; resourceId: string; resourceName: string }> = []
  for (const [i, image] of selection.groups.entries()) {
    const s = image && stored.get(image.slug)
    if (!s) continue
    const group = ctx.created.groups.find((g) => g.id === FIXTURE_GROUP_IDS[i])
    await prisma.group.update({ where: { id: FIXTURE_GROUP_IDS[i] }, data: { coverImageUrl: urlOf(s.file) } })
    usages.push({ mediaId: mediaId.get(image.slug)!, usageType: 'GROUP_COVER', resourceId: FIXTURE_GROUP_IDS[i], resourceName: group?.name ?? '' })
  }
  for (const [programId, image] of Object.entries(selection.programs)) {
    const s = image && stored.get(image.slug)
    if (!s) continue
    const program = ctx.created.programs.find((p) => p.id === programId)
    await prisma.studyProgram.update({ where: { id: programId }, data: { coverImageUrl: urlOf(s.file) } })
    usages.push({ mediaId: mediaId.get(image.slug)!, usageType: 'PROGRAM_COVER', resourceId: programId, resourceName: program?.name ?? '' })
  }
  await prisma.mediaUsage.createMany({ data: usages.map((u, n) => ({ id: fixtureId('mediaUsage', n + 1), ...u })) })
}
