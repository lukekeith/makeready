import { existsSync, readFileSync } from 'node:fs'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { FixtureContext } from '../context.js'
import { FIXTURE_PROGRAM_IDS } from '../ids.js'
import {
  AVATAR_COUNT,
  type D2mImage,
  type ImageManifest,
  LIBRARY_SIZE,
  MANIFEST_PATH,
  assertFixtureBucket,
  keyStamp,
  manifestOf,
  seedImages,
  selectImages,
  sourceFile,
} from '../images.js'

const img = (slug: string, terms: Array<[string, string]>, retired = false): D2mImage => ({
  slug,
  url: `http://d2m/${slug}`,
  title: slug,
  width: 1600,
  height: 900,
  retired,
  terms: terms.map(([taxonomy, term]) => ({ taxonomy, term })),
})

const catalog: D2mImage[] = [
  img('image-9', [['Subject', 'group'], ['Use', 'cover']]),
  img('image-11', [['Subject', 'group'], ['Use', 'cover']]),
  img('image-10', [['Subject', 'group'], ['Use', 'cover']]),
  img('genesis-abram-stars', [['Book', 'genesis'], ['Use', 'cover']]),
  img('john-foot-washing', [['Book', 'john'], ['Use', 'cover']]),
  ...Array.from({ length: 20 }, (_, i) => img(`book${i % 5}-${i}`, [['Book', `b${i % 5}`], ['Use', 'cover']])),
  img('avatar-1', [['Use', 'avatar']]),
  img('retired-cover', [['Use', 'cover']], true),
]

describe('fixture image selection (home-dashboard-data D22)', () => {
  const s = selectImages(catalog)

  it('takes the preferred slug, else the first unused image of the tag pool', () => {
    expect(s.groups.map((g) => g?.slug)).toEqual(['image-9', 'image-11', 'image-10']) // image-6 missing → pool
    expect(s.programs[FIXTURE_PROGRAM_IDS.days21]?.slug).toBe('genesis-abram-stars')
    expect(s.programs[FIXTURE_PROGRAM_IDS.days30]?.slug).toBe('john-foot-washing') // preferred well scene missing → Book john
  })

  it('fills the library with unused, live cover images spread across books', () => {
    expect(s.library).toHaveLength(LIBRARY_SIZE)
    const used = new Set([...s.groups, ...Object.values(s.programs)].map((i) => i?.slug))
    for (const i of s.library) {
      expect(used.has(i.slug)).toBe(false)
      expect(i.slug).not.toBe('retired-cover')
      expect(i.slug).not.toBe('avatar-1')
    }
    expect(new Set(s.library.slice(0, 5).map((i) => i.terms?.find((t) => t.taxonomy === 'Book')?.term)).size).toBe(5)
  })

  it('is deterministic', () => {
    expect(selectImages([...catalog].reverse())).toEqual(s)
  })
})

const r2 = {
  R2_ACCOUNT_ID: 'a',
  R2_ACCESS_KEY_ID: 'k',
  R2_SECRET_ACCESS_KEY: 's',
  R2_BUCKET_NAME: 'makeready',
  R2_PUBLIC_URL: 'https://pub-x.r2.dev',
}

describe('fixture images as real uploads (fixture-real-uploads)', () => {
  afterEach(() => vi.unstubAllEnvs())

  it('stamps keys with a 13-digit number that is stable per image and new per change', () => {
    const a = keyStamp(Buffer.from('one'))
    expect(a).toMatch(/^\d{13}$/)
    expect(keyStamp(Buffer.from('one'))).toBe(a)
    expect(keyStamp(Buffer.from('two'))).not.toBe(a)
  })

  it('needs every R2 setting, and refuses the production bucket', () => {
    expect(() => assertFixtureBucket(r2)).not.toThrow()
    expect(() => assertFixtureBucket({ ...r2, R2_PUBLIC_URL: '' })).toThrow(/R2_PUBLIC_URL not set/)
    expect(() => assertFixtureBucket({ ...r2, R2_BUCKET_NAME: 'makeready-media' })).toThrow(/production bucket/)
    expect(() => assertFixtureBucket({ ...r2, R2_PUBLIC_URL: 'https://images.makeready.org' })).toThrow(/production bucket/)
  })

  it('fails the reset when images are on and R2 is not configured', async () => {
    vi.stubEnv('FIXTURE_IMAGES', 'on')
    vi.stubEnv('R2_BUCKET_NAME', '')
    await expect(seedImages({} as FixtureContext)).rejects.toThrow(/fixture images need R2/)
  })

  it('skips images on purpose with FIXTURE_IMAGES=off', async () => {
    vi.stubEnv('FIXTURE_IMAGES', 'off')
    await expect(seedImages({} as FixtureContext)).resolves.toBeUndefined()
  })

  it('records the selection by slug with each image\'s d2m metadata', () => {
    const m = manifestOf(selectImages(catalog))
    expect(m.groups).toEqual(['image-9', 'image-11', 'image-10'])
    expect(m.library).toHaveLength(LIBRARY_SIZE)
    expect(m.images['image-9']).toEqual({ title: 'image-9', alt: null, mainColor: null })
  })

  it('has every image the committed manifest names in the repo', () => {
    expect(existsSync(MANIFEST_PATH)).toBe(true)
    const m = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8')) as ImageManifest
    expect(m.groups.every(Boolean)).toBe(true)
    expect(m.avatars).toHaveLength(AVATAR_COUNT)
    for (const slug of Object.keys(m.images)) expect(existsSync(sourceFile(slug)), slug).toBe(true)
  })
})

describe('fixture avatars (ui2-members-browse D13)', () => {
  const faces = Array.from({ length: 15 }, (_, i) =>
    img(`face-${String(i).padStart(2, '0')}`, [['Subject', 'person'], ['Use', 'avatar']])
  )
  const s = selectImages([...catalog, ...faces, img('face-retired', [['Use', 'avatar']], true)])

  it('takes the first 13 live `Use: avatar` images by slug', () => {
    expect(s.avatars).toHaveLength(AVATAR_COUNT)
    expect(s.avatars.map((a) => a.slug)).toEqual(['avatar-1', ...faces.slice(0, 12).map((f) => f.slug)])
  })

  it('never takes a cover or library image as an avatar, nor an avatar as a cover', () => {
    const covers = new Set([...s.groups, ...Object.values(s.programs), ...s.library].map((i) => i?.slug))
    for (const a of s.avatars) expect(covers.has(a.slug)).toBe(false)
  })
})
