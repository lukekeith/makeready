import { describe, expect, it } from 'vitest'
import { FIXTURE_PROGRAM_IDS } from '../ids.js'
import { type D2mImage, LIBRARY_SIZE, imageBaseUrl, selectImages } from '../images.js'

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

describe('fixture image base URL', () => {
  it('prefers FIXTURE_IMAGE_BASE_URL, else the iPhone Local host on PORT', () => {
    expect(imageBaseUrl({ FIXTURE_IMAGE_BASE_URL: 'http://h:1/' })).toBe('http://h:1')
    expect(imageBaseUrl({ PORT: '3110' })).toMatch(/^http:\/\/[^/:]+:3110$/)
  })
})
