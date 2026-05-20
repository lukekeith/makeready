import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'

const prisma = new PrismaClient()

// Bible book information
const BOOKS = [
  // Old Testament
  { number: 1, name: 'Genesis', abbrev: 'Gen', testament: 'OLD_TESTAMENT' as const, chapters: 50 },
  { number: 2, name: 'Exodus', abbrev: 'Exod', testament: 'OLD_TESTAMENT' as const, chapters: 40 },
  { number: 3, name: 'Leviticus', abbrev: 'Lev', testament: 'OLD_TESTAMENT' as const, chapters: 27 },
  { number: 4, name: 'Numbers', abbrev: 'Num', testament: 'OLD_TESTAMENT' as const, chapters: 36 },
  { number: 5, name: 'Deuteronomy', abbrev: 'Deut', testament: 'OLD_TESTAMENT' as const, chapters: 34 },
  { number: 6, name: 'Joshua', abbrev: 'Josh', testament: 'OLD_TESTAMENT' as const, chapters: 24 },
  { number: 7, name: 'Judges', abbrev: 'Judg', testament: 'OLD_TESTAMENT' as const, chapters: 21 },
  { number: 8, name: 'Ruth', abbrev: 'Ruth', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  { number: 9, name: '1 Samuel', abbrev: '1Sam', testament: 'OLD_TESTAMENT' as const, chapters: 31 },
  { number: 10, name: '2 Samuel', abbrev: '2Sam', testament: 'OLD_TESTAMENT' as const, chapters: 24 },
  { number: 11, name: '1 Kings', abbrev: '1Kgs', testament: 'OLD_TESTAMENT' as const, chapters: 22 },
  { number: 12, name: '2 Kings', abbrev: '2Kgs', testament: 'OLD_TESTAMENT' as const, chapters: 25 },
  { number: 13, name: '1 Chronicles', abbrev: '1Chr', testament: 'OLD_TESTAMENT' as const, chapters: 29 },
  { number: 14, name: '2 Chronicles', abbrev: '2Chr', testament: 'OLD_TESTAMENT' as const, chapters: 36 },
  { number: 15, name: 'Ezra', abbrev: 'Ezra', testament: 'OLD_TESTAMENT' as const, chapters: 10 },
  { number: 16, name: 'Nehemiah', abbrev: 'Neh', testament: 'OLD_TESTAMENT' as const, chapters: 13 },
  { number: 17, name: 'Esther', abbrev: 'Esth', testament: 'OLD_TESTAMENT' as const, chapters: 10 },
  { number: 18, name: 'Job', abbrev: 'Job', testament: 'OLD_TESTAMENT' as const, chapters: 42 },
  { number: 19, name: 'Psalms', abbrev: 'Ps', testament: 'OLD_TESTAMENT' as const, chapters: 150 },
  { number: 20, name: 'Proverbs', abbrev: 'Prov', testament: 'OLD_TESTAMENT' as const, chapters: 31 },
  { number: 21, name: 'Ecclesiastes', abbrev: 'Eccl', testament: 'OLD_TESTAMENT' as const, chapters: 12 },
  { number: 22, name: 'Song of Solomon', abbrev: 'Song', testament: 'OLD_TESTAMENT' as const, chapters: 8 },
  { number: 23, name: 'Isaiah', abbrev: 'Isa', testament: 'OLD_TESTAMENT' as const, chapters: 66 },
  { number: 24, name: 'Jeremiah', abbrev: 'Jer', testament: 'OLD_TESTAMENT' as const, chapters: 52 },
  { number: 25, name: 'Lamentations', abbrev: 'Lam', testament: 'OLD_TESTAMENT' as const, chapters: 5 },
  { number: 26, name: 'Ezekiel', abbrev: 'Ezek', testament: 'OLD_TESTAMENT' as const, chapters: 48 },
  { number: 27, name: 'Daniel', abbrev: 'Dan', testament: 'OLD_TESTAMENT' as const, chapters: 12 },
  { number: 28, name: 'Hosea', abbrev: 'Hos', testament: 'OLD_TESTAMENT' as const, chapters: 14 },
  { number: 29, name: 'Joel', abbrev: 'Joel', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 30, name: 'Amos', abbrev: 'Amos', testament: 'OLD_TESTAMENT' as const, chapters: 9 },
  { number: 31, name: 'Obadiah', abbrev: 'Obad', testament: 'OLD_TESTAMENT' as const, chapters: 1 },
  { number: 32, name: 'Jonah', abbrev: 'Jonah', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  { number: 33, name: 'Micah', abbrev: 'Mic', testament: 'OLD_TESTAMENT' as const, chapters: 7 },
  { number: 34, name: 'Nahum', abbrev: 'Nah', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 35, name: 'Habakkuk', abbrev: 'Hab', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 36, name: 'Zephaniah', abbrev: 'Zeph', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 37, name: 'Haggai', abbrev: 'Hag', testament: 'OLD_TESTAMENT' as const, chapters: 2 },
  { number: 38, name: 'Zechariah', abbrev: 'Zech', testament: 'OLD_TESTAMENT' as const, chapters: 14 },
  { number: 39, name: 'Malachi', abbrev: 'Mal', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  // New Testament
  { number: 40, name: 'Matthew', abbrev: 'Matt', testament: 'NEW_TESTAMENT' as const, chapters: 28 },
  { number: 41, name: 'Mark', abbrev: 'Mark', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 42, name: 'Luke', abbrev: 'Luke', testament: 'NEW_TESTAMENT' as const, chapters: 24 },
  { number: 43, name: 'John', abbrev: 'John', testament: 'NEW_TESTAMENT' as const, chapters: 21 },
  { number: 44, name: 'Acts', abbrev: 'Acts', testament: 'NEW_TESTAMENT' as const, chapters: 28 },
  { number: 45, name: 'Romans', abbrev: 'Rom', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 46, name: '1 Corinthians', abbrev: '1Cor', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 47, name: '2 Corinthians', abbrev: '2Cor', testament: 'NEW_TESTAMENT' as const, chapters: 13 },
  { number: 48, name: 'Galatians', abbrev: 'Gal', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 49, name: 'Ephesians', abbrev: 'Eph', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 50, name: 'Philippians', abbrev: 'Phil', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 51, name: 'Colossians', abbrev: 'Col', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 52, name: '1 Thessalonians', abbrev: '1Thess', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 53, name: '2 Thessalonians', abbrev: '2Thess', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 54, name: '1 Timothy', abbrev: '1Tim', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 55, name: '2 Timothy', abbrev: '2Tim', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 56, name: 'Titus', abbrev: 'Titus', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 57, name: 'Philemon', abbrev: 'Phlm', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 58, name: 'Hebrews', abbrev: 'Heb', testament: 'NEW_TESTAMENT' as const, chapters: 13 },
  { number: 59, name: 'James', abbrev: 'Jas', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 60, name: '1 Peter', abbrev: '1Pet', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 61, name: '2 Peter', abbrev: '2Pet', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 62, name: '1 John', abbrev: '1John', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 63, name: '2 John', abbrev: '2John', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 64, name: '3 John', abbrev: '3John', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 65, name: 'Jude', abbrev: 'Jude', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 66, name: 'Revelation', abbrev: 'Rev', testament: 'NEW_TESTAMENT' as const, chapters: 22 },
]

interface BibleAPIResponse {
  verses: Array<{
    book_id: string
    book_name: string
    chapter: number
    verse: number
    text: string
  }>
}

async function fetchChapter(book: string, chapter: number): Promise<BibleAPIResponse | null> {
  try {
    const response = await fetch(`https://bible-api.com/${book}+${chapter}?translation=kjv`)
    if (!response.ok) {
      console.error(`Failed to fetch ${book} ${chapter}: ${response.statusText}`)
      return null
    }
    return await response.json() as BibleAPIResponse
  } catch (error) {
    console.error(`Error fetching ${book} ${chapter}:`, error)
    return null
  }
}

async function importBible() {
  try {
    console.log('Starting Bible import...')

    // Create or get KJV translation
    console.log('Creating or fetching KJV translation...')
    const translation = await prisma.translation.upsert({
      where: { code: 'KJV' },
      update: {},
      create: {
        code: 'KJV',
        name: 'King James Version',
        language: 'en',
        description: 'The King James Version (KJV), also known as the Authorized Version, is an English translation of the Christian Bible.',
        copyright: 'Public Domain',
        license: 'Public Domain',
      },
    })

    console.log(`✅ Translation ready: ${translation.name}`)

    // Create or get books
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
      console.log(`  ✅ Ready: ${bookInfo.name}`)
    }

    // Import verses
    console.log('\nImporting verses (this will take a while)...')
    let totalVerses = 0

    for (const bookInfo of BOOKS) {
      console.log(`\nImporting ${bookInfo.name}...`)
      const bookId = bookMap.get(bookInfo.number)!

      for (let chapterNum = 1; chapterNum <= bookInfo.chapters; chapterNum++) {
        // Rate limiting - wait 1 second between requests to avoid 429 errors
        await new Promise((resolve) => setTimeout(resolve, 1000))

        const data = await fetchChapter(bookInfo.abbrev, chapterNum)
        if (!data || !data.verses) {
          console.error(`  ⚠️  Failed to fetch ${bookInfo.name} ${chapterNum}`)
          continue
        }

        // Batch insert verses for this chapter
        const versesToInsert = data.verses.map((v) => ({
          translationId: translation.id,
          bookId,
          bookNumber: bookInfo.number,
          chapter: v.chapter,
          verse: v.verse,
          text: v.text,
        }))

        try {
          await prisma.verse.createMany({
            data: versesToInsert,
            skipDuplicates: true,
          })

          totalVerses += versesToInsert.length
          console.log(`  ✅ Chapter ${chapterNum}: ${versesToInsert.length} verses (Total: ${totalVerses})`)
        } catch (error) {
          console.error(`  ⚠️  Error inserting verses for ${bookInfo.name} ${chapterNum}:`, error)
        }
      }
    }

    console.log('\n🎉 Bible import completed successfully!')
    console.log(`   Total verses imported: ${totalVerses}`)
    console.log(`   Translation: ${translation.name} (${translation.code})`)

  } catch (error) {
    console.error('\n❌ Import failed:', error)
    throw error
  } finally {
    await prisma.$disconnect()
  }
}

// Run the import
importBible().catch(console.error)
