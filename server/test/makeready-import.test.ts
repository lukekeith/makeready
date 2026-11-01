/** media-library D5/D15: importFromCatalog is idempotent and repairs a row whose R2 object is gone. */
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import sharp from 'sharp'

process.env.R2_PUBLIC_URL = 'https://images.test'
const present = new Set<string>()
vi.mock('../src/services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/storage.js')>()),
  uploadImageVariants: vi.fn(async (prefix: string, baseName: string) => {
    present.add(`${prefix}/${baseName}.jpeg`)
    return { url: `https://images.test/${prefix}/${baseName}.jpeg` }
  }),
  objectExists: vi.fn(async (key: string) => present.has(key)),
}))

const { prisma } = await import('../src/lib/prisma.js')
const { importFromCatalog, catalogCovers } = await import('../src/services/makeready-media.js')
const { MAKEREADY_ORG_ID } = await import('../src/services/makeready-library.js')

describe('importFromCatalog (media-library D15)', () => {
  const stamp = Date.now()
  let file: Buffer
  const items = () => [
    { slug: `imp-a-${stamp}`, title: `Imp A ${stamp}`, alt: 'Alt A', tags: ['john', 'lesson'], file },
    { slug: `imp-b-${stamp}`, title: `Imp B ${stamp}`, alt: 'Alt B', tags: ['psalms'], file },
  ]

  beforeAll(async () => {
    file = await sharp({ create: { width: 20, height: 10, channels: 3, background: '#445566' } }).jpeg().toBuffer()
  })
  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: MAKEREADY_ORG_ID, title: { endsWith: ` ${stamp}` } } })
  })

  it('creates, then skips, then repairs a row whose object vanished', async () => {
    expect(await importFromCatalog(items())).toEqual({ created: 2, skipped: 0, repaired: 0 })
    expect(await importFromCatalog(items())).toEqual({ created: 0, skipped: 2, repaired: 0 })
    const row = await prisma.media.findFirstOrThrow({ where: { title: `Imp A ${stamp}` }, include: { tags: true } })
    expect(row).toMatchObject({ description: 'Alt A', altText: 'Alt A', organizationId: MAKEREADY_ORG_ID })
    expect(row.tags.map((t) => t.tag).sort()).toEqual(['john', 'lesson'])
    present.delete(row.url.replace('https://images.test/', ''))
    expect(await importFromCatalog(items())).toEqual({ created: 0, skipped: 1, repaired: 1 })
  })

  it('catalogCovers keeps live Use=cover images with Subject + Book tags', () => {
    const covers = catalogCovers([
      { slug: 'b', url: 'u', title: 'B', terms: [{ taxonomy: 'Use', term: 'cover' }, { taxonomy: 'Subject', term: 'Lesson' }, { taxonomy: 'Book', term: 'John' }] },
      { slug: 'a', url: 'u', title: 'A', terms: [{ taxonomy: 'Use', term: 'avatar' }] },
      { slug: 'c', url: 'u', title: 'C', retired: true, terms: [{ taxonomy: 'Use', term: 'cover' }] },
    ])
    expect(covers.map((c) => [c.slug, c.tags])).toEqual([['b', ['lesson', 'john']]])
  })
})
