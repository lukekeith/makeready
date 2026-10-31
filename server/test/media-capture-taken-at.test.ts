import { beforeEach, describe, expect, it, vi } from 'vitest'

const mockFindFirst = vi.fn()
const mockCreate = vi.fn()

vi.mock('../src/lib/prisma.js', () => ({
  prisma: {
    media: {
      findFirst: (...args: unknown[]) => mockFindFirst(...args),
      create: (...args: unknown[]) => mockCreate(...args),
    },
  },
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn() }))

const { captureToLibrary } = await import('../src/services/media-library.js')

const base = {
  title: 'Prayer Team - Cover Image',
  url: 'https://images.test/groups/g1.jpeg',
  type: 'photo',
  organizationId: 'org-1',
  uploadedBy: 'user-1',
  uploadStatus: 'pending', // skips the fire-and-forget AI enrichment
}

describe('captureToLibrary stores takenAt (media-page D4)', () => {
  beforeEach(() => {
    mockFindFirst.mockReset().mockResolvedValue(null)
    mockCreate.mockReset().mockImplementation(async ({ data }: { data: object }) => ({ id: 'm1', ...data }))
  })

  it('stores a valid takenAt from the caller', async () => {
    captureToLibrary({ ...base, takenAt: '2025-06-14T09:30:00-05:00' })
    await vi.waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate.mock.calls[0][0].data.takenAt?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
  })

  it('falls back to exifData.dateTaken', async () => {
    captureToLibrary({ ...base, exifData: { dateTaken: new Date('2024-03-02T10:11:12Z') } })
    await vi.waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate.mock.calls[0][0].data.takenAt?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
  })

  it('stores null with neither, and ignores an invalid takenAt', async () => {
    captureToLibrary({ ...base, takenAt: '2025-06-14' })
    await vi.waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate.mock.calls[0][0].data.takenAt).toBeNull()
  })
})
