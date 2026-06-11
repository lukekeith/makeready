import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'

/**
 * Import the World English Bible (WEB) — modern-English, public domain.
 *
 * The WEB translation is the embedding source for Bible concept search
 * (see embed-bible.ts): modern phrasing matches modern user queries far
 * better than KJV's archaic English. Search results map back to the user's
 * preferred display translation by book/chapter/verse reference.
 *
 * Source: getbible.net v2 API — the entire translation in one JSON document.
 * Idempotent: translation/books are upserted, verses use skipDuplicates.
 *
 * Usage: npm run bible:import:web   (optionally with DATABASE_URL override)
 */

const prisma = new PrismaClient()

const SOURCE_URL = 'https://api.getbible.net/v2/web.json'

// Canonical 66-book metadata, keyed by book number (matches import-bible-bulk.ts)
const BOOKS = [
  // Old Testament
  { number: 1, name: 'Genesis', abbrev: 'Genesis', testament: 'OLD_TESTAMENT' as const, chapters: 50 },
  { number: 2, name: 'Exodus', abbrev: 'Exodus', testament: 'OLD_TESTAMENT' as const, chapters: 40 },
  { number: 3, name: 'Leviticus', abbrev: 'Leviticus', testament: 'OLD_TESTAMENT' as const, chapters: 27 },
  { number: 4, name: 'Numbers', abbrev: 'Numbers', testament: 'OLD_TESTAMENT' as const, chapters: 36 },
  { number: 5, name: 'Deuteronomy', abbrev: 'Deuteronomy', testament: 'OLD_TESTAMENT' as const, chapters: 34 },
  { number: 6, name: 'Joshua', abbrev: 'Joshua', testament: 'OLD_TESTAMENT' as const, chapters: 24 },
  { number: 7, name: 'Judges', abbrev: 'Judges', testament: 'OLD_TESTAMENT' as const, chapters: 21 },
  { number: 8, name: 'Ruth', abbrev: 'Ruth', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  { number: 9, name: '1 Samuel', abbrev: '1Samuel', testament: 'OLD_TESTAMENT' as const, chapters: 31 },
  { number: 10, name: '2 Samuel', abbrev: '2Samuel', testament: 'OLD_TESTAMENT' as const, chapters: 24 },
  { number: 11, name: '1 Kings', abbrev: '1Kings', testament: 'OLD_TESTAMENT' as const, chapters: 22 },
  { number: 12, name: '2 Kings', abbrev: '2Kings', testament: 'OLD_TESTAMENT' as const, chapters: 25 },
  { number: 13, name: '1 Chronicles', abbrev: '1Chronicles', testament: 'OLD_TESTAMENT' as const, chapters: 29 },
  { number: 14, name: '2 Chronicles', abbrev: '2Chronicles', testament: 'OLD_TESTAMENT' as const, chapters: 36 },
  { number: 15, name: 'Ezra', abbrev: 'Ezra', testament: 'OLD_TESTAMENT' as const, chapters: 10 },
  { number: 16, name: 'Nehemiah', abbrev: 'Nehemiah', testament: 'OLD_TESTAMENT' as const, chapters: 13 },
  { number: 17, name: 'Esther', abbrev: 'Esther', testament: 'OLD_TESTAMENT' as const, chapters: 10 },
  { number: 18, name: 'Job', abbrev: 'Job', testament: 'OLD_TESTAMENT' as const, chapters: 42 },
  { number: 19, name: 'Psalms', abbrev: 'Psalms', testament: 'OLD_TESTAMENT' as const, chapters: 150 },
  { number: 20, name: 'Proverbs', abbrev: 'Proverbs', testament: 'OLD_TESTAMENT' as const, chapters: 31 },
  { number: 21, name: 'Ecclesiastes', abbrev: 'Ecclesiastes', testament: 'OLD_TESTAMENT' as const, chapters: 12 },
  { number: 22, name: 'Song of Solomon', abbrev: 'SongofSolomon', testament: 'OLD_TESTAMENT' as const, chapters: 8 },
  { number: 23, name: 'Isaiah', abbrev: 'Isaiah', testament: 'OLD_TESTAMENT' as const, chapters: 66 },
  { number: 24, name: 'Jeremiah', abbrev: 'Jeremiah', testament: 'OLD_TESTAMENT' as const, chapters: 52 },
  { number: 25, name: 'Lamentations', abbrev: 'Lamentations', testament: 'OLD_TESTAMENT' as const, chapters: 5 },
  { number: 26, name: 'Ezekiel', abbrev: 'Ezekiel', testament: 'OLD_TESTAMENT' as const, chapters: 48 },
  { number: 27, name: 'Daniel', abbrev: 'Daniel', testament: 'OLD_TESTAMENT' as const, chapters: 12 },
  { number: 28, name: 'Hosea', abbrev: 'Hosea', testament: 'OLD_TESTAMENT' as const, chapters: 14 },
  { number: 29, name: 'Joel', abbrev: 'Joel', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 30, name: 'Amos', abbrev: 'Amos', testament: 'OLD_TESTAMENT' as const, chapters: 9 },
  { number: 31, name: 'Obadiah', abbrev: 'Obadiah', testament: 'OLD_TESTAMENT' as const, chapters: 1 },
  { number: 32, name: 'Jonah', abbrev: 'Jonah', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  { number: 33, name: 'Micah', abbrev: 'Micah', testament: 'OLD_TESTAMENT' as const, chapters: 7 },
  { number: 34, name: 'Nahum', abbrev: 'Nahum', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 35, name: 'Habakkuk', abbrev: 'Habakkuk', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 36, name: 'Zephaniah', abbrev: 'Zephaniah', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 37, name: 'Haggai', abbrev: 'Haggai', testament: 'OLD_TESTAMENT' as const, chapters: 2 },
  { number: 38, name: 'Zechariah', abbrev: 'Zechariah', testament: 'OLD_TESTAMENT' as const, chapters: 14 },
  { number: 39, name: 'Malachi', abbrev: 'Malachi', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  // New Testament
  { number: 40, name: 'Matthew', abbrev: 'Matthew', testament: 'NEW_TESTAMENT' as const, chapters: 28 },
  { number: 41, name: 'Mark', abbrev: 'Mark', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 42, name: 'Luke', abbrev: 'Luke', testament: 'NEW_TESTAMENT' as const, chapters: 24 },
  { number: 43, name: 'John', abbrev: 'John', testament: 'NEW_TESTAMENT' as const, chapters: 21 },
  { number: 44, name: 'Acts', abbrev: 'Acts', testament: 'NEW_TESTAMENT' as const, chapters: 28 },
  { number: 45, name: 'Romans', abbrev: 'Romans', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 46, name: '1 Corinthians', abbrev: '1Corinthians', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 47, name: '2 Corinthians', abbrev: '2Corinthians', testament: 'NEW_TESTAMENT' as const, chapters: 13 },
  { number: 48, name: 'Galatians', abbrev: 'Galatians', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 49, name: 'Ephesians', abbrev: 'Ephesians', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 50, name: 'Philippians', abbrev: 'Philippians', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 51, name: 'Colossians', abbrev: 'Colossians', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 52, name: '1 Thessalonians', abbrev: '1Thessalonians', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 53, name: '2 Thessalonians', abbrev: '2Thessalonians', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 54, name: '1 Timothy', abbrev: '1Timothy', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 55, name: '2 Timothy', abbrev: '2Timothy', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 56, name: 'Titus', abbrev: 'Titus', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 57, name: 'Philemon', abbrev: 'Philemon', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 58, name: 'Hebrews', abbrev: 'Hebrews', testament: 'NEW_TESTAMENT' as const, chapters: 13 },
  { number: 59, name: 'James', abbrev: 'James', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 60, name: '1 Peter', abbrev: '1Peter', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 61, name: '2 Peter', abbrev: '2Peter', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 62, name: '1 John', abbrev: '1John', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 63, name: '2 John', abbrev: '2John', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 64, name: '3 John', abbrev: '3John', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 65, name: 'Jude', abbrev: 'Jude', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 66, name: 'Revelation', abbrev: 'Revelation', testament: 'NEW_TESTAMENT' as const, chapters: 22 },
]

interface GetBibleJSON {
  translation: string
  abbreviation: string
  distribution_license: string
  books: Array<{
    nr: number
    name: string
    chapters: Array<{
      chapter: number
      verses: Array<{
        chapter: number
        verse: number
        text: string
      }>
    }>
  }>
}

/** Strip inline footnotes ("/f + ... /f*") and normalize whitespace. */
function cleanVerseText(text: string): string {
  return text.replace(/\/f\s*\+.*?\/f\*/g, '').replace(/\s+/g, ' ').trim()
}

async function importWebBible() {
  try {
    console.log('Starting World English Bible import...')
    console.log(`Source: ${SOURCE_URL}\n`)

    const response = await fetch(SOURCE_URL)
    if (!response.ok) {
      throw new Error(`Failed to fetch WEB Bible: ${response.status} ${response.statusText}`)
    }
    const data = await response.json() as GetBibleJSON
    console.log(`Downloaded: ${data.translation} (license: ${data.distribution_license}, ${data.books.length} books)\n`)

    const translation = await prisma.translation.upsert({
      where: { code: 'WEB' },
      update: {},
      create: {
        code: 'WEB',
        name: 'World English Bible',
        language: 'en',
        description: 'The World English Bible (WEB) is a modern-English update of the American Standard Version, dedicated to the public domain.',
        copyright: 'Public Domain',
        license: 'Public Domain',
      },
    })
    console.log(`✅ Translation ready: ${translation.name}\n`)

    console.log('Creating or fetching books...')
    const bookMap = new Map<number, string>()
    for (const bookInfo of BOOKS) {
      const book = await prisma.book.upsert({
        where: {
          translationId_bookNumber: {
            translationId: translation.id,
            bookNumber: bookInfo.number,
          },
        },
        update: {},
        create: {
          translationId: translation.id,
          bookNumber: bookInfo.number,
          bookName: bookInfo.name,
          bookAbbrev: bookInfo.abbrev,
          testament: bookInfo.testament,
          chapters: bookInfo.chapters,
        },
      })
      bookMap.set(bookInfo.number, book.id)
    }
    console.log(`✅ ${bookMap.size} books ready\n`)

    console.log('Importing verses...')
    let totalVerses = 0
    let totalBooks = 0

    for (const sourceBook of data.books) {
      const bookId = bookMap.get(sourceBook.nr)
      if (!bookId) {
        console.error(`  ⚠️  Unknown book number ${sourceBook.nr} (${sourceBook.name}), skipping`)
        continue
      }

      const versesToInsert = []
      for (const chapter of sourceBook.chapters) {
        for (const verse of chapter.verses) {
          const text = cleanVerseText(verse.text)
          if (!text) continue
          versesToInsert.push({
            translationId: translation.id,
            bookId,
            bookNumber: sourceBook.nr,
            chapter: chapter.chapter,
            verse: verse.verse,
            text,
          })
        }
      }

      await prisma.verse.createMany({
        data: versesToInsert,
        skipDuplicates: true,
      })
      totalVerses += versesToInsert.length
      totalBooks++
      console.log(`  ✅ ${sourceBook.name}: ${versesToInsert.length} verses (total: ${totalVerses})`)
    }

    const dbCount = await prisma.verse.count({ where: { translationId: translation.id } })
    console.log('\n🎉 WEB import completed!')
    console.log(`   Books imported: ${totalBooks}/66`)
    console.log(`   Verses processed: ${totalVerses}`)
    console.log(`   Verses in database: ${dbCount}`)
  } catch (error) {
    console.error('\n❌ Import failed:', error)
    process.exitCode = 1
  } finally {
    await prisma.$disconnect()
  }
}

importWebBible()
