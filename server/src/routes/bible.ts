import { Router } from 'express'
import { prisma } from '../lib/prisma.js'
import * as apiBible from '../services/api-bible.js'
import * as bibleMetadata from '../services/bible-metadata.js'
import * as bibleCache from '../services/bible-cache.js'
import * as preferencesService from '../services/preferences.js'
import {
  getBookByNumber,
  getBookByApiBibleId,
  buildChapterId,
  buildVerseId,
  parseVerseId,
} from '../utils/bible-id-map.js'
import { parseChapterContent } from '../utils/bible-content-parser.js'

const router = Router()

// ============================================
// Helper: resolve translation code to API.Bible bibleId
// ============================================

async function resolveTranslation(
  translationCode: string | undefined,
  req: any
): Promise<{ bibleId: string; code: string } | null> {
  let code = translationCode?.toUpperCase()

  // If no code provided, use the user's preference
  if (!code) {
    const identity = req.user?.id
      ? { userId: req.user.id }
      : req.session?.memberId
      ? { memberId: req.session.memberId }
      : null
    if (identity) {
      code = (await preferencesService.getPreferenceOrDefault(identity, 'bible_translation')).toUpperCase()
    } else {
      code = 'NASB'
    }
  }

  const bibleId = await bibleMetadata.resolveBibleId(code)
  if (!bibleId) return null
  return { bibleId, code }
}

// ============================================
// LIST TRANSLATIONS (API.Bible)
// ============================================

/**
 * @openapi
 * /api/bible/translations:
 *   get:
 *     tags: [Bible]
 *     summary: List available translations
 *     description: |
 *       Returns all available Bible translations from API.Bible.
 *       Currently returns ~37 English translations including NASB, KJV, NIV, and many others.
 *       Results are cached for 24 hours.
 *     responses:
 *       200:
 *         description: List of translations
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 translations:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         description: API.Bible bibleId
 *                         example: a761ca71e0b3ddcf-01
 *                       code:
 *                         type: string
 *                         description: Translation abbreviation used in other endpoints
 *                         example: NASB
 *                       name:
 *                         type: string
 *                         example: New American Standard Bible 2020
 *                       language:
 *                         type: string
 *                         example: eng
 *                       description:
 *                         type: string
 *                       copyright:
 *                         type: string
 */
router.get('/translations', async (_req, res) => {
  try {
    const versions = await bibleMetadata.getAvailableBibles('eng')

    res.json({
      translations: versions.map((v) => ({
        id: v.apiBibleId,
        code: v.abbreviation,
        name: v.name,
        language: v.language,
        description: v.description || '',
        copyright: v.copyright || '',
        popularity: v.popularity,
      })),
    })
  } catch (error) {
    console.error('Error fetching translations:', error)
    res.status(500).json({ error: 'Failed to fetch translations' })
  }
})

// ============================================
// GET BOOKS FOR TRANSLATION (API.Bible)
// ============================================

/**
 * @openapi
 * /api/bible/translations/{translationCode}/books:
 *   get:
 *     tags: [Bible]
 *     summary: Get books for a translation
 *     description: |
 *       Returns all 66 canonical books for a Bible translation, ordered by book number.
 *       Includes chapter counts per book. Data sourced from API.Bible.
 *     parameters:
 *       - in: path
 *         name: translationCode
 *         required: true
 *         schema:
 *           type: string
 *           example: NASB
 *         description: Translation code from the /translations endpoint (e.g., NASB, engKJV, NIV11)
 *     responses:
 *       200:
 *         description: List of books in the translation
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 translation:
 *                   type: string
 *                   example: NASB
 *                 books:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       bookNumber:
 *                         type: integer
 *                         description: Canonical book number (1-66)
 *                         example: 1
 *                       bookName:
 *                         type: string
 *                         example: Genesis
 *                       bookAbbrev:
 *                         type: string
 *                         example: Gen
 *                       testament:
 *                         type: string
 *                         enum: [OT, NT]
 *                         example: OT
 *                       chapters:
 *                         type: integer
 *                         description: Total chapters in the book
 *                         example: 50
 *       404:
 *         description: Translation not found
 */
router.get('/translations/:translationCode/books', async (req, res) => {
  try {
    const resolved = await resolveTranslation(req.params.translationCode, req)
    if (!resolved) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const books = await bibleMetadata.getBooksForBible(resolved.bibleId)

    res.json({
      translation: resolved.code,
      books,
    })
  } catch (error) {
    console.error('Error fetching books:', error)
    res.status(500).json({ error: 'Failed to fetch books' })
  }
})

// ============================================
// DOWNLOAD TRANSLATION — REMOVED
// ============================================
// Endpoint removed for API.Bible licensing compliance.
// API.Bible terms prohibit caching more than 500 consecutive verses
// and require cache refresh every 14 days.
// See: https://docs.api.bible/common-questions#can-i-cache-data

// ============================================
// GET CHAPTER (API.Bible with cache)
// ============================================

// ============================================
// Shared: Chapter-first caching strategy
// ============================================
// Any request for a verse, verse range, or chapter fetches and caches the
// entire chapter in a single API call. Subsequent requests for any verse
// in that chapter are served from cache with zero API calls.
//
// API.Bible rules:
//   - Max 500 consecutive verses per request (a chapter is always < 200)
//   - Cache must be refreshed every 14 days
//   - FUMS token must be reported for every *view* (even cache hits)
// ============================================

interface ChapterCacheResult {
  verses: { verse: number; text: string }[]
  copyright: string | null
  fumsToken: string | null
}

/**
 * Get all verses for a chapter, using cache-first strategy.
 * On cache miss: fetches the full chapter from API.Bible (1 API call),
 * caches it for 14 days, and returns parsed verses.
 * On cache hit: returns cached verses and fetches a fresh fumsToken.
 */
async function getChapterVerses(
  bibleId: string,
  bookId: string,
  chapter: number,
  options?: { skipCache?: boolean }
): Promise<ChapterCacheResult> {
  const chapterId = buildChapterId(bookId, chapter)
  const cacheKey = `chapter:${bibleId}:${chapterId}`

  if (!options?.skipCache) {
    const cached = await bibleCache.getCached(cacheKey)
    if (cached) {
      // Cache hit — still need a fresh fumsToken for FUMS compliance
      let fumsToken: string | null = null
      try {
        const verseId = buildVerseId(bookId, chapter, 1)
        const fumsResponse = await apiBible.getVerse(bibleId, verseId)
        fumsToken = apiBible.extractFumsToken(fumsResponse.meta)
      } catch {
        // fumsToken fetch failed — content still valid
      }

      return {
        verses: JSON.parse(cached.responseJson),
        copyright: cached.copyright,
        fumsToken,
      }
    }
  } else {
    // skipCache: clear existing entry so fresh data replaces it
    await bibleCache.clearCacheEntry(cacheKey)
  }

  // Cache miss or refresh — fetch full chapter (1 API call covers all verses)
  const response = await apiBible.getChapter(bibleId, chapterId)
  const verses = parseChapterContent(response.data.content)
  const copyright = response.data.copyright
  const fumsToken = apiBible.extractFumsToken(response.meta)

  // Cache for 14 days
  if (verses.length > 0) {
    await bibleCache.setCache(cacheKey, bibleId, 'chapter', verses, copyright, verses.length)
  }

  return { verses, copyright, fumsToken }
}

// ============================================
// GET CHAPTER
// ============================================

/**
 * @openapi
 * /api/bible/{translationCode}/{bookNumber}/{chapter}:
 *   get:
 *     tags: [Bible]
 *     summary: Get chapter verses
 *     description: |
 *       Returns all verses in a chapter with navigation links, copyright, and FUMS token.
 *       Content is cached for 14 days (API.Bible compliance). If the user is authenticated,
 *       highlights and notes are overlaid on matching verses.
 *       If translationCode is omitted or the user has a preferred translation set via
 *       the preferences API, that translation is used. Default is NASB.
 *     parameters:
 *       - in: path
 *         name: translationCode
 *         required: true
 *         schema:
 *           type: string
 *           example: NASB
 *       - in: path
 *         name: bookNumber
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 66
 *         description: Canonical book number (1=Genesis, 43=John, 66=Revelation)
 *       - in: path
 *         name: chapter
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *     responses:
 *       200:
 *         description: Chapter with verses, navigation, and FUMS metadata
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 translation:
 *                   type: string
 *                 book:
 *                   type: object
 *                   properties:
 *                     bookNumber:
 *                       type: integer
 *                     name:
 *                       type: string
 *                     abbrev:
 *                       type: string
 *                     testament:
 *                       type: string
 *                       enum: [OT, NT]
 *                 chapter:
 *                   type: integer
 *                 verses:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       verse:
 *                         type: integer
 *                       text:
 *                         type: string
 *                       reference:
 *                         type: string
 *                         example: John 3:16
 *                       highlight:
 *                         type: object
 *                         nullable: true
 *                       notes:
 *                         type: array
 *                         items:
 *                           type: object
 *                 navigation:
 *                   type: object
 *                   properties:
 *                     previousChapter:
 *                       type: object
 *                       nullable: true
 *                       properties:
 *                         bookNumber:
 *                           type: integer
 *                         chapter:
 *                           type: integer
 *                     nextChapter:
 *                       type: object
 *                       nullable: true
 *                       properties:
 *                         bookNumber:
 *                           type: integer
 *                         chapter:
 *                           type: integer
 *                 fumsToken:
 *                   type: string
 *                   nullable: true
 *                   description: FUMS token for API.Bible fair use reporting. Must be reported by the client.
 *                 copyright:
 *                   type: string
 *                   nullable: true
 *                   description: Copyright notice — must be displayed alongside scripture content.
 *       404:
 *         description: Translation, book, or chapter not found
 */
router.get('/:translationCode/:bookNumber/:chapter', async (req, res) => {
  try {
    const { translationCode, bookNumber: bookNum, chapter: chapterNum } = req.params
    const bookNumber = parseInt(bookNum)
    const chapter = parseInt(chapterNum)

    if (isNaN(bookNumber) || isNaN(chapter) || bookNumber < 1 || bookNumber > 66 || chapter < 1) {
      return res.status(400).json({ error: 'Invalid book number or chapter' })
    }

    const resolved = await resolveTranslation(translationCode, req)
    if (!resolved) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const bookEntry = getBookByNumber(bookNumber)
    const refresh = req.query.refresh === 'true'
    const { verses, copyright, fumsToken } = await getChapterVerses(
      resolved.bibleId, bookEntry.apiBibleId, chapter, { skipCache: refresh }
    )

    if (verses.length === 0) {
      return res.status(404).json({ error: 'Chapter not found or has no verses' })
    }

    // Get user highlights/notes if authenticated
    const isAuthenticated = req.isAuthenticated && req.isAuthenticated() && req.user
    const userId = isAuthenticated ? (req.user as any).id : null

    let highlights: any[] = []
    let notes: any[] = []

    if (userId) {
      const version = await prisma.apiBibleVersion.findUnique({
        where: { apiBibleId: resolved.bibleId },
      })
      const translationId = version?.id

      if (translationId) {
        ;[highlights, notes] = await Promise.all([
          prisma.highlight.findMany({
            where: { userId, translationId, bookNumber, chapter },
          }),
          prisma.verseNote.findMany({
            where: { userId, translationId, bookNumber, chapter },
          }),
        ])
      }
    }

    // Navigation
    const previousChapter =
      chapter > 1
        ? { bookNumber, chapter: chapter - 1 }
        : bookNumber > 1
        ? { bookNumber: bookNumber - 1, chapter: 1 }
        : null

    const nextChapter =
      bookNumber <= 66
        ? { bookNumber, chapter: chapter + 1 }
        : null

    res.json({
      translation: resolved.code,
      book: {
        bookNumber,
        name: bookEntry.name,
        abbrev: bookEntry.abbrev,
        testament: bookEntry.testament,
      },
      chapter,
      verses: verses.map((v) => ({
        verse: v.verse,
        text: v.text,
        reference: `${bookEntry.name} ${chapter}:${v.verse}`,
        highlight: highlights.find(
          (h: any) =>
            h.verseStart <= v.verse && (h.verseEnd === null || h.verseEnd >= v.verse)
        ) || null,
        notes: notes.filter(
          (n: any) =>
            n.verseStart <= v.verse && (n.verseEnd === null || n.verseEnd >= v.verse)
        ),
      })),
      navigation: {
        previousChapter: previousChapter && previousChapter.bookNumber >= 1 ? previousChapter : null,
        nextChapter: nextChapter && nextChapter.bookNumber <= 66 ? nextChapter : null,
      },
      fumsToken,
      copyright,
    })
  } catch (error) {
    console.error('Error fetching chapter:', error)
    res.status(500).json({ error: 'Failed to fetch chapter' })
  }
})

// ============================================
// GET VERSE RANGE (API.Bible with cache)
// Must be registered BEFORE /:chapter/:verse to avoid "verses" matching as a verse number
// ============================================

/**
 * @openapi
 * /api/bible/{translationCode}/{bookNumber}/{chapter}/verses:
 *   get:
 *     tags: [Bible]
 *     summary: Get a range of verses
 *     description: |
 *       Returns a range of verses within a chapter. Uses chapter-first caching —
 *       the entire chapter is fetched and cached on first access, then subsequent
 *       requests for any verse or range in that chapter are served from cache.
 *       Maximum 500 consecutive verses per API.Bible rules.
 *     parameters:
 *       - in: path
 *         name: translationCode
 *         required: true
 *         schema:
 *           type: string
 *           example: NASB
 *       - in: path
 *         name: bookNumber
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 66
 *       - in: path
 *         name: chapter
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *       - in: query
 *         name: start
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: Starting verse number
 *       - in: query
 *         name: end
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *         description: Ending verse number
 *     responses:
 *       200:
 *         description: The requested verse range with FUMS metadata
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 translation:
 *                   type: string
 *                 book:
 *                   type: object
 *                   properties:
 *                     bookNumber:
 *                       type: integer
 *                     name:
 *                       type: string
 *                     abbrev:
 *                       type: string
 *                 chapter:
 *                   type: integer
 *                 verseRange:
 *                   type: string
 *                   example: "16-18"
 *                 verses:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       verse:
 *                         type: integer
 *                       text:
 *                         type: string
 *                       reference:
 *                         type: string
 *                 fumsToken:
 *                   type: string
 *                   nullable: true
 *                 copyright:
 *                   type: string
 *                   nullable: true
 *       400:
 *         description: Invalid parameters or exceeds 500 verse limit
 *       404:
 *         description: Translation or verses not found
 */
router.get('/:translationCode/:bookNumber/:chapter/verses', async (req, res) => {
  try {
    const { translationCode, bookNumber: bookNum, chapter: chapterNum } = req.params
    const { start, end } = req.query
    const bookNumber = parseInt(bookNum)
    const chapter = parseInt(chapterNum)
    const startVerse = parseInt(start as string)
    const endVerse = parseInt(end as string)

    if (isNaN(bookNumber) || isNaN(chapter) || isNaN(startVerse) || isNaN(endVerse)) {
      return res.status(400).json({ error: 'Invalid parameters' })
    }

    if (endVerse - startVerse >= 500) {
      return res.status(400).json({ error: 'Maximum 500 consecutive verses allowed' })
    }

    const resolved = await resolveTranslation(translationCode, req)
    if (!resolved) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const bookEntry = getBookByNumber(bookNumber)

    // Use chapter-first caching — fetches and caches full chapter, then slices
    const { verses: allVerses, copyright, fumsToken } = await getChapterVerses(
      resolved.bibleId, bookEntry.apiBibleId, chapter
    )

    // Slice the requested range from the cached chapter
    const verses = allVerses.filter((v) => v.verse >= startVerse && v.verse <= endVerse)

    if (verses.length === 0) {
      return res.status(404).json({ error: 'Verses not found' })
    }

    res.json({
      translation: resolved.code,
      book: {
        bookNumber,
        name: bookEntry.name,
        abbrev: bookEntry.abbrev,
      },
      chapter,
      verseRange: `${startVerse}-${endVerse}`,
      verses: verses.map((v) => ({
        verse: v.verse,
        text: v.text,
        reference: `${bookEntry.name} ${chapter}:${v.verse}`,
      })),
      fumsToken,
      copyright,
    })
  } catch (error) {
    console.error('Error fetching verse range:', error)
    res.status(500).json({ error: 'Failed to fetch verses' })
  }
})

// ============================================
// GET SINGLE VERSE (API.Bible with cache)
// ============================================

/**
 * @openapi
 * /api/bible/{translationCode}/{bookNumber}/{chapter}/{verse}:
 *   get:
 *     tags: [Bible]
 *     summary: Get a single verse
 *     description: |
 *       Returns a specific verse by translation, book, chapter, and verse number.
 *       Uses chapter-first caching — the entire chapter is fetched and cached on
 *       first access, so subsequent verse requests in the same chapter are instant.
 *     parameters:
 *       - in: path
 *         name: translationCode
 *         required: true
 *         schema:
 *           type: string
 *           example: NASB
 *       - in: path
 *         name: bookNumber
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 66
 *       - in: path
 *         name: chapter
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *       - in: path
 *         name: verse
 *         required: true
 *         schema:
 *           type: integer
 *           minimum: 1
 *     responses:
 *       200:
 *         description: The requested verse with FUMS metadata
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 translation:
 *                   type: string
 *                   example: NASB
 *                 book:
 *                   type: object
 *                   properties:
 *                     bookNumber:
 *                       type: integer
 *                     name:
 *                       type: string
 *                     abbrev:
 *                       type: string
 *                 chapter:
 *                   type: integer
 *                 verse:
 *                   type: integer
 *                 text:
 *                   type: string
 *                   example: '"For God so loved the world, that He gave His only Son...'
 *                 reference:
 *                   type: string
 *                   example: John 3:16
 *                 fumsToken:
 *                   type: string
 *                   nullable: true
 *                   description: FUMS token for API.Bible fair use reporting
 *                 copyright:
 *                   type: string
 *                   nullable: true
 *                   description: Copyright notice — must be displayed alongside scripture
 *       400:
 *         description: Invalid parameters
 *       404:
 *         description: Translation, book, or verse not found
 */
router.get('/:translationCode/:bookNumber/:chapter/:verse', async (req, res) => {
  try {
    const {
      translationCode,
      bookNumber: bookNum,
      chapter: chapterNum,
      verse: verseNum,
    } = req.params
    const bookNumber = parseInt(bookNum)
    const chapter = parseInt(chapterNum)
    const verse = parseInt(verseNum)

    if (isNaN(bookNumber) || isNaN(chapter) || isNaN(verse)) {
      return res.status(400).json({ error: 'Invalid parameters' })
    }

    const resolved = await resolveTranslation(translationCode, req)
    if (!resolved) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const bookEntry = getBookByNumber(bookNumber)

    // Use chapter-first caching — fetches and caches full chapter, then picks the verse
    const { verses, copyright, fumsToken } = await getChapterVerses(
      resolved.bibleId, bookEntry.apiBibleId, chapter
    )

    const match = verses.find((v) => v.verse === verse)
    if (!match) {
      return res.status(404).json({ error: 'Verse not found' })
    }

    res.json({
      translation: resolved.code,
      book: {
        bookNumber,
        name: bookEntry.name,
        abbrev: bookEntry.abbrev,
      },
      chapter,
      verse,
      text: match.text,
      reference: `${bookEntry.name} ${chapter}:${verse}`,
      fumsToken,
      copyright,
    })
  } catch (error) {
    console.error('Error fetching verse:', error)
    res.status(500).json({ error: 'Failed to fetch verse' })
  }
})

// ============================================
// SEARCH BIBLE (API.Bible proxy)
// ============================================

/**
 * @openapi
 * /api/bible/search:
 *   get:
 *     tags: [Bible]
 *     summary: Search Bible text
 *     description: |
 *       Search for verses by keyword via API.Bible. All keywords must appear in a verse (AND logic).
 *       Supports wildcards (* for multi-char, ? for single-char), fuzziness for misspellings,
 *       and range filtering to limit search to specific books. If the query looks like a Bible
 *       reference (e.g., "John 3:16"), returns passage results instead of keyword matches.
 *       Default translation is NASB, or the user's preferred translation if authenticated.
 *     parameters:
 *       - in: query
 *         name: query
 *         required: true
 *         schema:
 *           type: string
 *         description: Search keywords or passage reference. Supports * and ? wildcards.
 *         example: love
 *       - in: query
 *         name: translation
 *         schema:
 *           type: string
 *           default: NASB
 *         description: Translation code (e.g., NASB, engKJV, NIV11)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 25
 *           maximum: 100
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [relevance, canonical, reverse-canonical]
 *           default: relevance
 *       - in: query
 *         name: fuzziness
 *         schema:
 *           type: string
 *           enum: [AUTO, "0", "1", "2"]
 *           default: AUTO
 *         description: Misspelling tolerance (AUTO varies by word length)
 *       - in: query
 *         name: range
 *         schema:
 *           type: string
 *         description: Limit search to books/chapters (e.g., "gen.1,gen.5" or "gen-num" or "gen.1.1-gen.3.5")
 *     responses:
 *       200:
 *         description: Search results with pagination and FUMS token
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 query:
 *                   type: string
 *                 translation:
 *                   type: string
 *                 total:
 *                   type: integer
 *                 limit:
 *                   type: integer
 *                 offset:
 *                   type: integer
 *                 results:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       book:
 *                         type: object
 *                         properties:
 *                           bookNumber:
 *                             type: integer
 *                           name:
 *                             type: string
 *                           abbrev:
 *                             type: string
 *                       chapter:
 *                         type: integer
 *                       verse:
 *                         type: integer
 *                       text:
 *                         type: string
 *                       reference:
 *                         type: string
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     currentPage:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 *                     hasMore:
 *                       type: boolean
 *                 fumsToken:
 *                   type: string
 *                   nullable: true
 *       400:
 *         description: Query parameter required
 *       404:
 *         description: Translation not found
 */
router.get('/search', async (req, res) => {
  try {
    const {
      query,
      translation = 'NASB',
      limit = '25',
      offset = '0',
      sort,
      fuzziness,
      range,
    } = req.query

    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'Query parameter required' })
    }

    const resolved = await resolveTranslation(translation as string, req)
    if (!resolved) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const limitNum = Math.min(parseInt(limit as string) || 25, 100)
    const offsetNum = parseInt(offset as string) || 0

    const response = await apiBible.searchBible(resolved.bibleId, {
      query,
      limit: limitNum,
      offset: offsetNum,
      sort: sort as any,
      fuzziness: fuzziness as any,
      range: range as string,
    })

    const searchData = response.data
    const fumsToken = apiBible.extractFumsToken(response.meta)

    // Map results to our response shape
    const results = (searchData.verses || []).map((v) => {
      let bookNumber: number
      let bookName: string
      let bookAbbrev: string
      try {
        const bookEntry = getBookByApiBibleId(v.bookId)
        bookNumber = bookEntry.bookNumber
        bookName = bookEntry.name
        bookAbbrev = bookEntry.abbrev
      } catch {
        bookNumber = 0
        bookName = v.bookId
        bookAbbrev = v.bookId
      }

      const parsed = parseVerseId(v.id)

      return {
        book: {
          bookNumber,
          name: bookName,
          abbrev: bookAbbrev,
        },
        chapter: parsed.chapter,
        verse: parsed.verse,
        text: v.text,
        reference: v.reference,
      }
    })

    res.json({
      query,
      translation: resolved.code,
      total: searchData.total,
      limit: limitNum,
      offset: offsetNum,
      results,
      pagination: {
        currentPage: Math.floor(offsetNum / limitNum) + 1,
        totalPages: Math.ceil(searchData.total / limitNum),
        hasMore: offsetNum + limitNum < searchData.total,
      },
      fumsToken,
    })
  } catch (error) {
    console.error('Error searching Bible:', error)
    res.status(500).json({ error: 'Search failed' })
  }
})

// ============================================
// USER FEATURES - HIGHLIGHTS
// ============================================

/**
 * @openapi
 * /api/bible/highlights:
 *   get:
 *     tags: [Bible]
 *     summary: Get user's highlights
 *     description: Returns all highlights created by the authenticated user. Can optionally filter by translation.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: translation
 *         schema:
 *           type: string
 *           example: KJV
 *         description: Filter highlights by translation code
 *     responses:
 *       200:
 *         description: List of user's highlights
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 highlights:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       userId:
 *                         type: string
 *                       translationId:
 *                         type: string
 *                       bookNumber:
 *                         type: integer
 *                       chapter:
 *                         type: integer
 *                       verseStart:
 *                         type: integer
 *                       verseEnd:
 *                         type: integer
 *                         nullable: true
 *                       color:
 *                         type: string
 *                         example: yellow
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       translation:
 *                         type: object
 *                         properties:
 *                           code:
 *                             type: string
 *                           name:
 *                             type: string
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to fetch highlights
 */
router.get('/highlights', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { translation } = req.query

    const where: any = { userId }
    if (translation) {
      const translationRecord = await prisma.translation.findUnique({
        where: { code: (translation as string).toUpperCase() },
      })
      if (translationRecord) {
        where.translationId = translationRecord.id
      }
    }

    const highlights = await prisma.highlight.findMany({
      where,
      include: {
        translation: {
          select: { code: true, name: true },
        },
      },
      orderBy: [{ bookNumber: 'asc' }, { chapter: 'asc' }, { verseStart: 'asc' }],
    })

    res.json({ highlights })
  } catch (error) {
    console.error('Error fetching highlights:', error)
    res.status(500).json({ error: 'Failed to fetch highlights' })
  }
})

/**
 * @openapi
 * /api/bible/highlights:
 *   post:
 *     tags: [Bible]
 *     summary: Create a highlight
 *     description: Creates a new highlight on one or more verses for the authenticated user.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - translationCode
 *               - bookNumber
 *               - chapter
 *               - verseStart
 *               - color
 *             properties:
 *               translationCode:
 *                 type: string
 *                 example: KJV
 *               bookNumber:
 *                 type: integer
 *                 example: 1
 *               chapter:
 *                 type: integer
 *                 example: 1
 *               verseStart:
 *                 type: integer
 *                 example: 1
 *               verseEnd:
 *                 type: integer
 *                 nullable: true
 *                 example: 3
 *                 description: End verse for highlighting a range (optional)
 *               color:
 *                 type: string
 *                 example: yellow
 *                 description: Highlight color
 *     responses:
 *       200:
 *         description: Highlight created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 highlight:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     userId:
 *                       type: string
 *                     translationId:
 *                       type: string
 *                     bookNumber:
 *                       type: integer
 *                     chapter:
 *                       type: integer
 *                     verseStart:
 *                       type: integer
 *                     verseEnd:
 *                       type: integer
 *                       nullable: true
 *                     color:
 *                       type: string
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Missing required fields
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Missing required fields
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       404:
 *         description: Translation not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Translation not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to create highlight
 */
router.post('/highlights', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { translationCode, bookNumber, chapter, verseStart, verseEnd, color } = req.body

    if (!translationCode || !bookNumber || !chapter || !verseStart || !color) {
      return res.status(400).json({ error: 'Missing required fields' })
    }

    const translation = await prisma.translation.findUnique({
      where: { code: translationCode.toUpperCase() },
    })

    if (!translation) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const highlight = await prisma.highlight.create({
      data: {
        userId,
        translationId: translation.id,
        bookNumber: parseInt(bookNumber),
        chapter: parseInt(chapter),
        verseStart: parseInt(verseStart),
        verseEnd: verseEnd ? parseInt(verseEnd) : null,
        color,
      },
    })

    res.json({ highlight })
  } catch (error) {
    console.error('Error creating highlight:', error)
    res.status(500).json({ error: 'Failed to create highlight' })
  }
})

/**
 * @openapi
 * /api/bible/highlights/{id}:
 *   patch:
 *     tags: [Bible]
 *     summary: Update highlight color
 *     description: Updates the color of an existing highlight. User must own the highlight.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The highlight ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - color
 *             properties:
 *               color:
 *                 type: string
 *                 example: green
 *                 description: New highlight color
 *     responses:
 *       200:
 *         description: Highlight updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 highlight:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     color:
 *                       type: string
 *       400:
 *         description: Color is required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Color is required
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       403:
 *         description: Not authorized to update this highlight
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Not authorized to update this highlight
 *       404:
 *         description: Highlight not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Highlight not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to update highlight
 */
router.patch('/highlights/:id', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { id } = req.params
    const { color } = req.body

    if (!color) {
      return res.status(400).json({ error: 'Color is required' })
    }

    // Verify ownership
    const existingHighlight = await prisma.highlight.findUnique({
      where: { id },
    })

    if (!existingHighlight) {
      return res.status(404).json({ error: 'Highlight not found' })
    }

    if (existingHighlight.userId !== userId) {
      return res.status(403).json({ error: 'Not authorized to update this highlight' })
    }

    const highlight = await prisma.highlight.update({
      where: { id },
      data: { color },
    })

    res.json({ highlight })
  } catch (error) {
    console.error('Error updating highlight:', error)
    res.status(500).json({ error: 'Failed to update highlight' })
  }
})

/**
 * @openapi
 * /api/bible/highlights/{id}:
 *   delete:
 *     tags: [Bible]
 *     summary: Delete a highlight
 *     description: Deletes an existing highlight. User must own the highlight.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The highlight ID
 *     responses:
 *       200:
 *         description: Highlight deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Highlight deleted successfully
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       403:
 *         description: Not authorized to delete this highlight
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Not authorized to delete this highlight
 *       404:
 *         description: Highlight not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Highlight not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to delete highlight
 */
router.delete('/highlights/:id', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { id } = req.params

    // Verify ownership
    const existingHighlight = await prisma.highlight.findUnique({
      where: { id },
    })

    if (!existingHighlight) {
      return res.status(404).json({ error: 'Highlight not found' })
    }

    if (existingHighlight.userId !== userId) {
      return res.status(403).json({ error: 'Not authorized to delete this highlight' })
    }

    await prisma.highlight.delete({
      where: { id },
    })

    res.json({ message: 'Highlight deleted successfully' })
  } catch (error) {
    console.error('Error deleting highlight:', error)
    res.status(500).json({ error: 'Failed to delete highlight' })
  }
})

// ============================================
// USER FEATURES - NOTES
// ============================================

/**
 * @openapi
 * /api/bible/notes:
 *   get:
 *     tags: [Bible]
 *     summary: Get user's notes
 *     description: Returns all verse notes created by the authenticated user. Can optionally filter by translation.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: translation
 *         schema:
 *           type: string
 *           example: KJV
 *         description: Filter notes by translation code
 *     responses:
 *       200:
 *         description: List of user's notes
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 notes:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       userId:
 *                         type: string
 *                       translationId:
 *                         type: string
 *                       bookNumber:
 *                         type: integer
 *                       chapter:
 *                         type: integer
 *                       verseStart:
 *                         type: integer
 *                       verseEnd:
 *                         type: integer
 *                         nullable: true
 *                       content:
 *                         type: string
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       updatedAt:
 *                         type: string
 *                         format: date-time
 *                       translation:
 *                         type: object
 *                         properties:
 *                           code:
 *                             type: string
 *                           name:
 *                             type: string
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to fetch notes
 */
router.get('/notes', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { translation } = req.query

    const where: any = { userId }
    if (translation) {
      const translationRecord = await prisma.translation.findUnique({
        where: { code: (translation as string).toUpperCase() },
      })
      if (translationRecord) {
        where.translationId = translationRecord.id
      }
    }

    const notes = await prisma.verseNote.findMany({
      where,
      include: {
        translation: {
          select: { code: true, name: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    res.json({ notes })
  } catch (error) {
    console.error('Error fetching notes:', error)
    res.status(500).json({ error: 'Failed to fetch notes' })
  }
})

/**
 * @openapi
 * /api/bible/notes/{id}:
 *   get:
 *     tags: [Bible]
 *     summary: Get a specific note
 *     description: Returns a specific note by ID. User must own the note.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The note ID
 *     responses:
 *       200:
 *         description: The requested note
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 note:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     userId:
 *                       type: string
 *                     translationId:
 *                       type: string
 *                     bookNumber:
 *                       type: integer
 *                     chapter:
 *                       type: integer
 *                     verseStart:
 *                       type: integer
 *                     verseEnd:
 *                       type: integer
 *                       nullable: true
 *                     content:
 *                       type: string
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
 *                     translation:
 *                       type: object
 *                       properties:
 *                         code:
 *                           type: string
 *                         name:
 *                           type: string
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       403:
 *         description: Not authorized to view this note
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Not authorized to view this note
 *       404:
 *         description: Note not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Note not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to fetch note
 */
router.get('/notes/:id', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { id } = req.params

    const note = await prisma.verseNote.findUnique({
      where: { id },
      include: {
        translation: {
          select: { code: true, name: true },
        },
      },
    })

    if (!note) {
      return res.status(404).json({ error: 'Note not found' })
    }

    if (note.userId !== userId) {
      return res.status(403).json({ error: 'Not authorized to view this note' })
    }

    res.json({ note })
  } catch (error) {
    console.error('Error fetching note:', error)
    res.status(500).json({ error: 'Failed to fetch note' })
  }
})

/**
 * @openapi
 * /api/bible/notes:
 *   post:
 *     tags: [Bible]
 *     summary: Create a note
 *     description: Creates a new note on one or more verses for the authenticated user.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - translationCode
 *               - bookNumber
 *               - chapter
 *               - verseStart
 *               - content
 *             properties:
 *               translationCode:
 *                 type: string
 *                 example: KJV
 *               bookNumber:
 *                 type: integer
 *                 example: 1
 *               chapter:
 *                 type: integer
 *                 example: 1
 *               verseStart:
 *                 type: integer
 *                 example: 1
 *               verseEnd:
 *                 type: integer
 *                 nullable: true
 *                 example: 3
 *                 description: End verse for noting a range (optional)
 *               content:
 *                 type: string
 *                 example: This verse reminds me of God's creative power.
 *                 description: The note content
 *     responses:
 *       200:
 *         description: Note created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 note:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     userId:
 *                       type: string
 *                     translationId:
 *                       type: string
 *                     bookNumber:
 *                       type: integer
 *                     chapter:
 *                       type: integer
 *                     verseStart:
 *                       type: integer
 *                     verseEnd:
 *                       type: integer
 *                       nullable: true
 *                     content:
 *                       type: string
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Missing required fields
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Missing required fields
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       404:
 *         description: Translation not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Translation not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to create note
 */
router.post('/notes', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { translationCode, bookNumber, chapter, verseStart, verseEnd, content } = req.body

    if (!translationCode || !bookNumber || !chapter || !verseStart || !content) {
      return res.status(400).json({ error: 'Missing required fields' })
    }

    const translation = await prisma.translation.findUnique({
      where: { code: translationCode.toUpperCase() },
    })

    if (!translation) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const note = await prisma.verseNote.create({
      data: {
        userId,
        translationId: translation.id,
        bookNumber: parseInt(bookNumber),
        chapter: parseInt(chapter),
        verseStart: parseInt(verseStart),
        verseEnd: verseEnd ? parseInt(verseEnd) : null,
        content,
      },
    })

    res.json({ note })
  } catch (error) {
    console.error('Error creating note:', error)
    res.status(500).json({ error: 'Failed to create note' })
  }
})

/**
 * @openapi
 * /api/bible/notes/{id}:
 *   patch:
 *     tags: [Bible]
 *     summary: Update a note
 *     description: Updates the content of an existing note. User must own the note.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The note ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - content
 *             properties:
 *               content:
 *                 type: string
 *                 example: Updated note content with new insights.
 *                 description: New note content
 *     responses:
 *       200:
 *         description: Note updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 note:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     content:
 *                       type: string
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Content is required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Content is required
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       403:
 *         description: Not authorized to update this note
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Not authorized to update this note
 *       404:
 *         description: Note not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Note not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to update note
 */
router.patch('/notes/:id', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { id } = req.params
    const { content } = req.body

    if (!content) {
      return res.status(400).json({ error: 'Content is required' })
    }

    // Verify ownership
    const existingNote = await prisma.verseNote.findUnique({
      where: { id },
    })

    if (!existingNote) {
      return res.status(404).json({ error: 'Note not found' })
    }

    if (existingNote.userId !== userId) {
      return res.status(403).json({ error: 'Not authorized to update this note' })
    }

    const note = await prisma.verseNote.update({
      where: { id },
      data: { content },
    })

    res.json({ note })
  } catch (error) {
    console.error('Error updating note:', error)
    res.status(500).json({ error: 'Failed to update note' })
  }
})

/**
 * @openapi
 * /api/bible/notes/{id}:
 *   delete:
 *     tags: [Bible]
 *     summary: Delete a note
 *     description: Deletes an existing note. User must own the note.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The note ID
 *     responses:
 *       200:
 *         description: Note deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Note deleted successfully
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       403:
 *         description: Not authorized to delete this note
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Not authorized to delete this note
 *       404:
 *         description: Note not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Note not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to delete note
 */
router.delete('/notes/:id', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { id } = req.params

    // Verify ownership
    const existingNote = await prisma.verseNote.findUnique({
      where: { id },
    })

    if (!existingNote) {
      return res.status(404).json({ error: 'Note not found' })
    }

    if (existingNote.userId !== userId) {
      return res.status(403).json({ error: 'Not authorized to delete this note' })
    }

    await prisma.verseNote.delete({
      where: { id },
    })

    res.json({ message: 'Note deleted successfully' })
  } catch (error) {
    console.error('Error deleting note:', error)
    res.status(500).json({ error: 'Failed to delete note' })
  }
})

// ============================================
// USER FEATURES - BOOKMARKS
// ============================================

/**
 * @openapi
 * /api/bible/bookmarks:
 *   get:
 *     tags: [Bible]
 *     summary: Get user's bookmarks
 *     description: Returns all bookmarks created by the authenticated user, ordered by creation date (newest first).
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of user's bookmarks
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 bookmarks:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       userId:
 *                         type: string
 *                       translationId:
 *                         type: string
 *                       bookNumber:
 *                         type: integer
 *                       chapter:
 *                         type: integer
 *                       verseStart:
 *                         type: integer
 *                       verseEnd:
 *                         type: integer
 *                         nullable: true
 *                       label:
 *                         type: string
 *                         nullable: true
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to fetch bookmarks
 */
router.get('/bookmarks', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id

    const bookmarks = await prisma.bookmark.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    })

    res.json({ bookmarks })
  } catch (error) {
    console.error('Error fetching bookmarks:', error)
    res.status(500).json({ error: 'Failed to fetch bookmarks' })
  }
})

/**
 * @openapi
 * /api/bible/bookmarks:
 *   post:
 *     tags: [Bible]
 *     summary: Create a bookmark
 *     description: Creates a new bookmark on one or more verses for the authenticated user.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - translationCode
 *               - bookNumber
 *               - chapter
 *               - verseStart
 *             properties:
 *               translationCode:
 *                 type: string
 *                 example: KJV
 *               bookNumber:
 *                 type: integer
 *                 example: 43
 *               chapter:
 *                 type: integer
 *                 example: 3
 *               verseStart:
 *                 type: integer
 *                 example: 16
 *               verseEnd:
 *                 type: integer
 *                 nullable: true
 *                 example: 17
 *                 description: End verse for bookmarking a range (optional)
 *               label:
 *                 type: string
 *                 nullable: true
 *                 example: God's love
 *                 description: Optional label for the bookmark
 *     responses:
 *       200:
 *         description: Bookmark created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 bookmark:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     userId:
 *                       type: string
 *                     translationId:
 *                       type: string
 *                     bookNumber:
 *                       type: integer
 *                     chapter:
 *                       type: integer
 *                     verseStart:
 *                       type: integer
 *                     verseEnd:
 *                       type: integer
 *                       nullable: true
 *                     label:
 *                       type: string
 *                       nullable: true
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Missing required fields
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Missing required fields
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       404:
 *         description: Translation not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Translation not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to create bookmark
 */
router.post('/bookmarks', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { translationCode, bookNumber, chapter, verseStart, verseEnd, label } = req.body

    if (!translationCode || !bookNumber || !chapter || !verseStart) {
      return res.status(400).json({ error: 'Missing required fields' })
    }

    const translation = await prisma.translation.findUnique({
      where: { code: translationCode.toUpperCase() },
    })

    if (!translation) {
      return res.status(404).json({ error: 'Translation not found' })
    }

    const bookmark = await prisma.bookmark.create({
      data: {
        userId,
        translationId: translation.id,
        bookNumber: parseInt(bookNumber),
        chapter: parseInt(chapter),
        verseStart: parseInt(verseStart),
        verseEnd: verseEnd ? parseInt(verseEnd) : null,
        label: label || null,
      },
    })

    res.json({ bookmark })
  } catch (error) {
    console.error('Error creating bookmark:', error)
    res.status(500).json({ error: 'Failed to create bookmark' })
  }
})

/**
 * @openapi
 * /api/bible/bookmarks/{id}:
 *   delete:
 *     tags: [Bible]
 *     summary: Delete a bookmark
 *     description: Deletes an existing bookmark. User must own the bookmark.
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The bookmark ID
 *     responses:
 *       200:
 *         description: Bookmark deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Bookmark deleted successfully
 *       401:
 *         description: Authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 *       403:
 *         description: Not authorized to delete this bookmark
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Not authorized to delete this bookmark
 *       404:
 *         description: Bookmark not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Bookmark not found
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Failed to delete bookmark
 */
router.delete('/bookmarks/:id', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const userId = (req.user as any).id
    const { id } = req.params

    // Verify ownership
    const existingBookmark = await prisma.bookmark.findUnique({
      where: { id },
    })

    if (!existingBookmark) {
      return res.status(404).json({ error: 'Bookmark not found' })
    }

    if (existingBookmark.userId !== userId) {
      return res.status(403).json({ error: 'Not authorized to delete this bookmark' })
    }

    await prisma.bookmark.delete({
      where: { id },
    })

    res.json({ message: 'Bookmark deleted successfully' })
  } catch (error) {
    console.error('Error deleting bookmark:', error)
    res.status(500).json({ error: 'Failed to delete bookmark' })
  }
})

// ============================================
// ADMIN: CACHE INVALIDATION
// ============================================

/**
 * @openapi
 * /api/bible/cache/clear:
 *   post:
 *     tags: [Bible]
 *     summary: Clear Bible content cache
 *     description: |
 *       Clears cached Bible content. Useful when cached data is stale or incomplete.
 *       If translationCode, bookNumber, and chapter are provided, clears that specific chapter.
 *       If only translationCode is provided, clears all chapters for that translation.
 *       If no parameters, clears all Bible content cache.
 *       Requires authentication.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               translationCode:
 *                 type: string
 *                 example: NASB
 *               bookNumber:
 *                 type: integer
 *                 example: 40
 *               chapter:
 *                 type: integer
 *                 example: 5
 *     responses:
 *       200:
 *         description: Cache cleared
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 cleared:
 *                   type: integer
 *       401:
 *         description: Authentication required
 */
router.post('/cache/clear', async (req, res) => {
  try {
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ error: 'Authentication required' })
    }

    const { translationCode, bookNumber, chapter } = req.body

    if (translationCode && bookNumber && chapter) {
      // Clear specific chapter
      const resolved = await resolveTranslation(translationCode, req)
      if (!resolved) {
        return res.status(404).json({ error: 'Translation not found' })
      }
      const bookEntry = getBookByNumber(parseInt(bookNumber))
      const chapterId = buildChapterId(bookEntry.apiBibleId, parseInt(chapter))
      const cacheKey = `chapter:${resolved.bibleId}:${chapterId}`
      const cleared = await bibleCache.clearCacheEntry(cacheKey)
      return res.json({
        message: cleared ? 'Chapter cache cleared' : 'No cache entry found',
        cleared: cleared ? 1 : 0,
      })
    }

    if (translationCode) {
      // Clear all chapters for a translation
      const resolved = await resolveTranslation(translationCode, req)
      if (!resolved) {
        return res.status(404).json({ error: 'Translation not found' })
      }
      const cleared = await bibleCache.clearCacheByPrefix(`chapter:${resolved.bibleId}:`)
      return res.json({ message: `Cleared ${cleared} cache entries for ${resolved.code}`, cleared })
    }

    // Clear all
    const cleared = await bibleCache.clearCacheByPrefix('chapter:')
    res.json({ message: `Cleared ${cleared} cache entries`, cleared })
  } catch (error) {
    console.error('Error clearing cache:', error)
    res.status(500).json({ error: 'Failed to clear cache' })
  }
})

export default router
