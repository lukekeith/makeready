import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'
import * as fs from 'fs'
import * as path from 'path'

const prisma = new PrismaClient()

interface BibleMetadata {
  name: string
  shortname: string
  module: string
  year?: string
  copyright: number
  copyright_statement: string
  description?: string
  lang_short: string
}

interface BibleVerse {
  book_name: string
  book: number
  chapter: number
  verse: number
  text: string
}

interface BibleJSON {
  metadata: BibleMetadata
  verses: BibleVerse[]
}

// Testament mapping based on book numbers
function getTestament(bookNumber: number): 'OLD_TESTAMENT' | 'NEW_TESTAMENT' {
  return bookNumber <= 39 ? 'OLD_TESTAMENT' : 'NEW_TESTAMENT'
}

// Book names mapping
const BOOK_NAMES: Record<number, { name: string; abbrev: string; chapters: number }> = {
  1: { name: 'Genesis', abbrev: 'Gen', chapters: 50 },
  2: { name: 'Exodus', abbrev: 'Exod', chapters: 40 },
  3: { name: 'Leviticus', abbrev: 'Lev', chapters: 27 },
  4: { name: 'Numbers', abbrev: 'Num', chapters: 36 },
  5: { name: 'Deuteronomy', abbrev: 'Deut', chapters: 34 },
  6: { name: 'Joshua', abbrev: 'Josh', chapters: 24 },
  7: { name: 'Judges', abbrev: 'Judg', chapters: 21 },
  8: { name: 'Ruth', abbrev: 'Ruth', chapters: 4 },
  9: { name: '1 Samuel', abbrev: '1Sam', chapters: 31 },
  10: { name: '2 Samuel', abbrev: '2Sam', chapters: 24 },
  11: { name: '1 Kings', abbrev: '1Kgs', chapters: 22 },
  12: { name: '2 Kings', abbrev: '2Kgs', chapters: 25 },
  13: { name: '1 Chronicles', abbrev: '1Chr', chapters: 29 },
  14: { name: '2 Chronicles', abbrev: '2Chr', chapters: 36 },
  15: { name: 'Ezra', abbrev: 'Ezra', chapters: 10 },
  16: { name: 'Nehemiah', abbrev: 'Neh', chapters: 13 },
  17: { name: 'Esther', abbrev: 'Esth', chapters: 10 },
  18: { name: 'Job', abbrev: 'Job', chapters: 42 },
  19: { name: 'Psalms', abbrev: 'Ps', chapters: 150 },
  20: { name: 'Proverbs', abbrev: 'Prov', chapters: 31 },
  21: { name: 'Ecclesiastes', abbrev: 'Eccl', chapters: 12 },
  22: { name: 'Song of Solomon', abbrev: 'Song', chapters: 8 },
  23: { name: 'Isaiah', abbrev: 'Isa', chapters: 66 },
  24: { name: 'Jeremiah', abbrev: 'Jer', chapters: 52 },
  25: { name: 'Lamentations', abbrev: 'Lam', chapters: 5 },
  26: { name: 'Ezekiel', abbrev: 'Ezek', chapters: 48 },
  27: { name: 'Daniel', abbrev: 'Dan', chapters: 12 },
  28: { name: 'Hosea', abbrev: 'Hos', chapters: 14 },
  29: { name: 'Joel', abbrev: 'Joel', chapters: 3 },
  30: { name: 'Amos', abbrev: 'Amos', chapters: 9 },
  31: { name: 'Obadiah', abbrev: 'Obad', chapters: 1 },
  32: { name: 'Jonah', abbrev: 'Jonah', chapters: 4 },
  33: { name: 'Micah', abbrev: 'Mic', chapters: 7 },
  34: { name: 'Nahum', abbrev: 'Nah', chapters: 3 },
  35: { name: 'Habakkuk', abbrev: 'Hab', chapters: 3 },
  36: { name: 'Zephaniah', abbrev: 'Zeph', chapters: 3 },
  37: { name: 'Haggai', abbrev: 'Hag', chapters: 2 },
  38: { name: 'Zechariah', abbrev: 'Zech', chapters: 14 },
  39: { name: 'Malachi', abbrev: 'Mal', chapters: 4 },
  40: { name: 'Matthew', abbrev: 'Matt', chapters: 28 },
  41: { name: 'Mark', abbrev: 'Mark', chapters: 16 },
  42: { name: 'Luke', abbrev: 'Luke', chapters: 24 },
  43: { name: 'John', abbrev: 'John', chapters: 21 },
  44: { name: 'Acts', abbrev: 'Acts', chapters: 28 },
  45: { name: 'Romans', abbrev: 'Rom', chapters: 16 },
  46: { name: '1 Corinthians', abbrev: '1Cor', chapters: 16 },
  47: { name: '2 Corinthians', abbrev: '2Cor', chapters: 13 },
  48: { name: 'Galatians', abbrev: 'Gal', chapters: 6 },
  49: { name: 'Ephesians', abbrev: 'Eph', chapters: 6 },
  50: { name: 'Philippians', abbrev: 'Phil', chapters: 4 },
  51: { name: 'Colossians', abbrev: 'Col', chapters: 4 },
  52: { name: '1 Thessalonians', abbrev: '1Thess', chapters: 5 },
  53: { name: '2 Thessalonians', abbrev: '2Thess', chapters: 3 },
  54: { name: '1 Timothy', abbrev: '1Tim', chapters: 6 },
  55: { name: '2 Timothy', abbrev: '2Tim', chapters: 4 },
  56: { name: 'Titus', abbrev: 'Titus', chapters: 3 },
  57: { name: 'Philemon', abbrev: 'Phlm', chapters: 1 },
  58: { name: 'Hebrews', abbrev: 'Heb', chapters: 13 },
  59: { name: 'James', abbrev: 'Jas', chapters: 5 },
  60: { name: '1 Peter', abbrev: '1Pet', chapters: 5 },
  61: { name: '2 Peter', abbrev: '2Pet', chapters: 3 },
  62: { name: '1 John', abbrev: '1John', chapters: 5 },
  63: { name: '2 John', abbrev: '2John', chapters: 1 },
  64: { name: '3 John', abbrev: '3John', chapters: 1 },
  65: { name: 'Jude', abbrev: 'Jude', chapters: 1 },
  66: { name: 'Revelation', abbrev: 'Rev', chapters: 22 },
}

async function importTranslation(filePath: string) {
  try {
    console.log(`\nImporting ${path.basename(filePath)}...`)

    // Read and parse JSON file
    const fileContent = fs.readFileSync(filePath, 'utf-8')
    const data: BibleJSON = JSON.parse(fileContent)

    const { metadata, verses } = data

    // Create or get translation
    console.log(`  Creating translation: ${metadata.name} (${metadata.shortname})`)
    const translation = await prisma.translation.upsert({
      where: { code: metadata.shortname },
      update: {},
      create: {
        code: metadata.shortname,
        name: metadata.name,
        language: metadata.lang_short || 'en',
        description: metadata.description || metadata.name,
        copyright: metadata.copyright_statement,
        license: metadata.copyright === 0 ? 'Public Domain' : metadata.copyright_statement,
      },
    })

    console.log(`  ✅ Translation ready: ${translation.name}`)

    // Group verses by book to create books
    const bookNumbers = Array.from(new Set(verses.map((v) => v.book))).sort((a, b) => a - b)

    console.log(`  Creating ${bookNumbers.length} books...`)
    const bookMap = new Map<number, string>()

    for (const bookNumber of bookNumbers) {
      const bookInfo = BOOK_NAMES[bookNumber]
      if (!bookInfo) {
        console.warn(`  ⚠️  Unknown book number: ${bookNumber}`)
        continue
      }

      const book = await prisma.book.upsert({
        where: {
          translationId_bookNumber: {
            translationId: translation.id,
            bookNumber,
          },
        },
        update: {},
        create: {
          translationId: translation.id,
          bookNumber,
          bookName: bookInfo.name,
          bookAbbrev: bookInfo.abbrev,
          testament: getTestament(bookNumber),
          chapters: bookInfo.chapters,
        },
      })

      bookMap.set(bookNumber, book.id)
    }

    console.log(`  ✅ ${bookNumbers.length} books ready`)

    // Import verses in batches
    console.log(`  Importing ${verses.length} verses...`)
    const batchSize = 1000
    let imported = 0

    for (let i = 0; i < verses.length; i += batchSize) {
      const batch = verses.slice(i, i + batchSize)

      const versesToInsert = batch.map((v) => ({
        translationId: translation.id,
        bookId: bookMap.get(v.book)!,
        bookNumber: v.book,
        chapter: v.chapter,
        verse: v.verse,
        text: v.text,
      }))

      await prisma.verse.createMany({
        data: versesToInsert,
        skipDuplicates: true,
      })

      imported += batch.length
      process.stdout.write(`\r  Progress: ${imported}/${verses.length} verses`)
    }

    console.log(`\n  ✅ Imported ${verses.length} verses`)
    console.log(`  ✅ Translation complete: ${metadata.name}`)

    return {
      code: metadata.shortname,
      name: metadata.name,
      verses: verses.length,
    }
  } catch (error) {
    console.error(`  ❌ Failed to import ${filePath}:`, error)
    throw error
  }
}

async function importAllTranslations() {
  try {
    console.log('Starting Bible translations import...')
    console.log('Source: Bible SuperSearch (https://www.biblesupersearch.com/)\n')

    const translationFiles = [
      '/tmp/EN-English/asv.json',
      '/tmp/EN-English/web.json',
      '/tmp/EN-English/net.json',
    ]

    const results = []

    for (const file of translationFiles) {
      if (fs.existsSync(file)) {
        const result = await importTranslation(file)
        results.push(result)
      } else {
        console.warn(`⚠️  File not found: ${file}`)
      }
    }

    console.log('\n🎉 All translations imported successfully!')
    console.log('\nSummary:')
    for (const result of results) {
      console.log(`  - ${result.name} (${result.code}): ${result.verses} verses`)
    }

  } catch (error) {
    console.error('\n❌ Import failed:', error)
    throw error
  } finally {
    await prisma.$disconnect()
  }
}

// Run the import
importAllTranslations().catch(console.error)
