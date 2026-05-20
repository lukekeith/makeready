import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'

const prisma = new PrismaClient()

// Bible book information with GitHub filenames
const BOOKS = [
  // Old Testament
  { number: 1, name: 'Genesis', file: 'Genesis', testament: 'OLD_TESTAMENT' as const, chapters: 50 },
  { number: 2, name: 'Exodus', file: 'Exodus', testament: 'OLD_TESTAMENT' as const, chapters: 40 },
  { number: 3, name: 'Leviticus', file: 'Leviticus', testament: 'OLD_TESTAMENT' as const, chapters: 27 },
  { number: 4, name: 'Numbers', file: 'Numbers', testament: 'OLD_TESTAMENT' as const, chapters: 36 },
  { number: 5, name: 'Deuteronomy', file: 'Deuteronomy', testament: 'OLD_TESTAMENT' as const, chapters: 34 },
  { number: 6, name: 'Joshua', file: 'Joshua', testament: 'OLD_TESTAMENT' as const, chapters: 24 },
  { number: 7, name: 'Judges', file: 'Judges', testament: 'OLD_TESTAMENT' as const, chapters: 21 },
  { number: 8, name: 'Ruth', file: 'Ruth', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  { number: 9, name: '1 Samuel', file: '1Samuel', testament: 'OLD_TESTAMENT' as const, chapters: 31 },
  { number: 10, name: '2 Samuel', file: '2Samuel', testament: 'OLD_TESTAMENT' as const, chapters: 24 },
  { number: 11, name: '1 Kings', file: '1Kings', testament: 'OLD_TESTAMENT' as const, chapters: 22 },
  { number: 12, name: '2 Kings', file: '2Kings', testament: 'OLD_TESTAMENT' as const, chapters: 25 },
  { number: 13, name: '1 Chronicles', file: '1Chronicles', testament: 'OLD_TESTAMENT' as const, chapters: 29 },
  { number: 14, name: '2 Chronicles', file: '2Chronicles', testament: 'OLD_TESTAMENT' as const, chapters: 36 },
  { number: 15, name: 'Ezra', file: 'Ezra', testament: 'OLD_TESTAMENT' as const, chapters: 10 },
  { number: 16, name: 'Nehemiah', file: 'Nehemiah', testament: 'OLD_TESTAMENT' as const, chapters: 13 },
  { number: 17, name: 'Esther', file: 'Esther', testament: 'OLD_TESTAMENT' as const, chapters: 10 },
  { number: 18, name: 'Job', file: 'Job', testament: 'OLD_TESTAMENT' as const, chapters: 42 },
  { number: 19, name: 'Psalms', file: 'Psalms', testament: 'OLD_TESTAMENT' as const, chapters: 150 },
  { number: 20, name: 'Proverbs', file: 'Proverbs', testament: 'OLD_TESTAMENT' as const, chapters: 31 },
  { number: 21, name: 'Ecclesiastes', file: 'Ecclesiastes', testament: 'OLD_TESTAMENT' as const, chapters: 12 },
  { number: 22, name: 'Song of Solomon', file: 'SongofSolomon', testament: 'OLD_TESTAMENT' as const, chapters: 8 },
  { number: 23, name: 'Isaiah', file: 'Isaiah', testament: 'OLD_TESTAMENT' as const, chapters: 66 },
  { number: 24, name: 'Jeremiah', file: 'Jeremiah', testament: 'OLD_TESTAMENT' as const, chapters: 52 },
  { number: 25, name: 'Lamentations', file: 'Lamentations', testament: 'OLD_TESTAMENT' as const, chapters: 5 },
  { number: 26, name: 'Ezekiel', file: 'Ezekiel', testament: 'OLD_TESTAMENT' as const, chapters: 48 },
  { number: 27, name: 'Daniel', file: 'Daniel', testament: 'OLD_TESTAMENT' as const, chapters: 12 },
  { number: 28, name: 'Hosea', file: 'Hosea', testament: 'OLD_TESTAMENT' as const, chapters: 14 },
  { number: 29, name: 'Joel', file: 'Joel', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 30, name: 'Amos', file: 'Amos', testament: 'OLD_TESTAMENT' as const, chapters: 9 },
  { number: 31, name: 'Obadiah', file: 'Obadiah', testament: 'OLD_TESTAMENT' as const, chapters: 1 },
  { number: 32, name: 'Jonah', file: 'Jonah', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  { number: 33, name: 'Micah', file: 'Micah', testament: 'OLD_TESTAMENT' as const, chapters: 7 },
  { number: 34, name: 'Nahum', file: 'Nahum', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 35, name: 'Habakkuk', file: 'Habakkuk', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 36, name: 'Zephaniah', file: 'Zephaniah', testament: 'OLD_TESTAMENT' as const, chapters: 3 },
  { number: 37, name: 'Haggai', file: 'Haggai', testament: 'OLD_TESTAMENT' as const, chapters: 2 },
  { number: 38, name: 'Zechariah', file: 'Zechariah', testament: 'OLD_TESTAMENT' as const, chapters: 14 },
  { number: 39, name: 'Malachi', file: 'Malachi', testament: 'OLD_TESTAMENT' as const, chapters: 4 },
  // New Testament
  { number: 40, name: 'Matthew', file: 'Matthew', testament: 'NEW_TESTAMENT' as const, chapters: 28 },
  { number: 41, name: 'Mark', file: 'Mark', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 42, name: 'Luke', file: 'Luke', testament: 'NEW_TESTAMENT' as const, chapters: 24 },
  { number: 43, name: 'John', file: 'John', testament: 'NEW_TESTAMENT' as const, chapters: 21 },
  { number: 44, name: 'Acts', file: 'Acts', testament: 'NEW_TESTAMENT' as const, chapters: 28 },
  { number: 45, name: 'Romans', file: 'Romans', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 46, name: '1 Corinthians', file: '1Corinthians', testament: 'NEW_TESTAMENT' as const, chapters: 16 },
  { number: 47, name: '2 Corinthians', file: '2Corinthians', testament: 'NEW_TESTAMENT' as const, chapters: 13 },
  { number: 48, name: 'Galatians', file: 'Galatians', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 49, name: 'Ephesians', file: 'Ephesians', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 50, name: 'Philippians', file: 'Philippians', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 51, name: 'Colossians', file: 'Colossians', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 52, name: '1 Thessalonians', file: '1Thessalonians', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 53, name: '2 Thessalonians', file: '2Thessalonians', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 54, name: '1 Timothy', file: '1Timothy', testament: 'NEW_TESTAMENT' as const, chapters: 6 },
  { number: 55, name: '2 Timothy', file: '2Timothy', testament: 'NEW_TESTAMENT' as const, chapters: 4 },
  { number: 56, name: 'Titus', file: 'Titus', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 57, name: 'Philemon', file: 'Philemon', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 58, name: 'Hebrews', file: 'Hebrews', testament: 'NEW_TESTAMENT' as const, chapters: 13 },
  { number: 59, name: 'James', file: 'James', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 60, name: '1 Peter', file: '1Peter', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 61, name: '2 Peter', file: '2Peter', testament: 'NEW_TESTAMENT' as const, chapters: 3 },
  { number: 62, name: '1 John', file: '1John', testament: 'NEW_TESTAMENT' as const, chapters: 5 },
  { number: 63, name: '2 John', file: '2John', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 64, name: '3 John', file: '3John', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 65, name: 'Jude', file: 'Jude', testament: 'NEW_TESTAMENT' as const, chapters: 1 },
  { number: 66, name: 'Revelation', file: 'Revelation', testament: 'NEW_TESTAMENT' as const, chapters: 22 },
]

interface BibleJSON {
  book: string
  chapters: Array<{
    chapter: string
    verses: Array<{
      verse: string
      text: string
    }>
  }>
}

async function fetchBookJSON(filename: string): Promise<BibleJSON | null> {
  try {
    const url = `https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/${encodeURIComponent(filename)}.json`
    const response = await fetch(url)
    if (!response.ok) {
      console.error(`Failed to fetch ${filename}: ${response.statusText}`)
      return null
    }
    return await response.json() as BibleJSON
  } catch (error) {
    console.error(`Error fetching ${filename}:`, error)
    return null
  }
}

async function importBibleBulk() {
  try {
    console.log('Starting bulk Bible import from GitHub...')
    console.log('Source: https://github.com/aruljohn/Bible-kjv\n')

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

    console.log(`✅ Translation ready: ${translation.name}\n`)

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
          bookAbbrev: bookInfo.file,
          testament: bookInfo.testament,
          chapters: bookInfo.chapters,
        },
      })
      bookMap.set(bookInfo.number, book.id)
      console.log(`  ✅ Ready: ${bookInfo.name}`)
    }

    // Import verses from JSON files
    console.log('\nImporting verses from GitHub JSON files...')
    let totalVerses = 0
    let totalBooks = 0

    for (const bookInfo of BOOKS) {
      console.log(`\nDownloading ${bookInfo.name}...`)
      const data = await fetchBookJSON(bookInfo.file)

      if (!data || !data.chapters) {
        console.error(`  ⚠️  Failed to fetch ${bookInfo.name}`)
        continue
      }

      const bookId = bookMap.get(bookInfo.number)!
      const versesToInsert = []

      // Parse all chapters and verses
      for (const chapter of data.chapters) {
        const chapterNum = parseInt(chapter.chapter)
        for (const verse of chapter.verses) {
          versesToInsert.push({
            translationId: translation.id,
            bookId,
            bookNumber: bookInfo.number,
            chapter: chapterNum,
            verse: parseInt(verse.verse),
            text: verse.text,
          })
        }
      }

      // Batch insert all verses for this book
      try {
        await prisma.verse.createMany({
          data: versesToInsert,
          skipDuplicates: true,
        })

        totalVerses += versesToInsert.length
        totalBooks++
        console.log(`  ✅ Imported ${versesToInsert.length} verses (Total: ${totalVerses})`)
      } catch (error) {
        console.error(`  ⚠️  Error inserting verses for ${bookInfo.name}:`, error)
      }
    }

    console.log('\n🎉 Bible import completed successfully!')
    console.log(`   Total books imported: ${totalBooks}/66`)
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
importBibleBulk().catch(console.error)
