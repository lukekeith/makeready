/**
 * Bible ID Mapping Utility
 *
 * Bidirectional mapping between our numeric book numbers (1-66)
 * and API.Bible string book IDs (GEN, EXO, ... REV).
 *
 * Also provides helpers for building API.Bible chapter/verse/passage IDs.
 */

// ============================================
// Static mapping: bookNumber ↔ API.Bible bookId
// ============================================

interface BookEntry {
  bookNumber: number
  apiBibleId: string
  name: string
  abbrev: string
  testament: 'OT' | 'NT'
}

const BOOKS: BookEntry[] = [
  // Old Testament
  { bookNumber: 1, apiBibleId: 'GEN', name: 'Genesis', abbrev: 'Gen', testament: 'OT' },
  { bookNumber: 2, apiBibleId: 'EXO', name: 'Exodus', abbrev: 'Exod', testament: 'OT' },
  { bookNumber: 3, apiBibleId: 'LEV', name: 'Leviticus', abbrev: 'Lev', testament: 'OT' },
  { bookNumber: 4, apiBibleId: 'NUM', name: 'Numbers', abbrev: 'Num', testament: 'OT' },
  { bookNumber: 5, apiBibleId: 'DEU', name: 'Deuteronomy', abbrev: 'Deut', testament: 'OT' },
  { bookNumber: 6, apiBibleId: 'JOS', name: 'Joshua', abbrev: 'Josh', testament: 'OT' },
  { bookNumber: 7, apiBibleId: 'JDG', name: 'Judges', abbrev: 'Judg', testament: 'OT' },
  { bookNumber: 8, apiBibleId: 'RUT', name: 'Ruth', abbrev: 'Ruth', testament: 'OT' },
  { bookNumber: 9, apiBibleId: '1SA', name: '1 Samuel', abbrev: '1Sam', testament: 'OT' },
  { bookNumber: 10, apiBibleId: '2SA', name: '2 Samuel', abbrev: '2Sam', testament: 'OT' },
  { bookNumber: 11, apiBibleId: '1KI', name: '1 Kings', abbrev: '1Kgs', testament: 'OT' },
  { bookNumber: 12, apiBibleId: '2KI', name: '2 Kings', abbrev: '2Kgs', testament: 'OT' },
  { bookNumber: 13, apiBibleId: '1CH', name: '1 Chronicles', abbrev: '1Chr', testament: 'OT' },
  { bookNumber: 14, apiBibleId: '2CH', name: '2 Chronicles', abbrev: '2Chr', testament: 'OT' },
  { bookNumber: 15, apiBibleId: 'EZR', name: 'Ezra', abbrev: 'Ezra', testament: 'OT' },
  { bookNumber: 16, apiBibleId: 'NEH', name: 'Nehemiah', abbrev: 'Neh', testament: 'OT' },
  { bookNumber: 17, apiBibleId: 'EST', name: 'Esther', abbrev: 'Esth', testament: 'OT' },
  { bookNumber: 18, apiBibleId: 'JOB', name: 'Job', abbrev: 'Job', testament: 'OT' },
  { bookNumber: 19, apiBibleId: 'PSA', name: 'Psalms', abbrev: 'Ps', testament: 'OT' },
  { bookNumber: 20, apiBibleId: 'PRO', name: 'Proverbs', abbrev: 'Prov', testament: 'OT' },
  { bookNumber: 21, apiBibleId: 'ECC', name: 'Ecclesiastes', abbrev: 'Eccl', testament: 'OT' },
  { bookNumber: 22, apiBibleId: 'SNG', name: 'Song of Solomon', abbrev: 'Song', testament: 'OT' },
  { bookNumber: 23, apiBibleId: 'ISA', name: 'Isaiah', abbrev: 'Isa', testament: 'OT' },
  { bookNumber: 24, apiBibleId: 'JER', name: 'Jeremiah', abbrev: 'Jer', testament: 'OT' },
  { bookNumber: 25, apiBibleId: 'LAM', name: 'Lamentations', abbrev: 'Lam', testament: 'OT' },
  { bookNumber: 26, apiBibleId: 'EZK', name: 'Ezekiel', abbrev: 'Ezek', testament: 'OT' },
  { bookNumber: 27, apiBibleId: 'DAN', name: 'Daniel', abbrev: 'Dan', testament: 'OT' },
  { bookNumber: 28, apiBibleId: 'HOS', name: 'Hosea', abbrev: 'Hos', testament: 'OT' },
  { bookNumber: 29, apiBibleId: 'JOL', name: 'Joel', abbrev: 'Joel', testament: 'OT' },
  { bookNumber: 30, apiBibleId: 'AMO', name: 'Amos', abbrev: 'Amos', testament: 'OT' },
  { bookNumber: 31, apiBibleId: 'OBA', name: 'Obadiah', abbrev: 'Obad', testament: 'OT' },
  { bookNumber: 32, apiBibleId: 'JON', name: 'Jonah', abbrev: 'Jonah', testament: 'OT' },
  { bookNumber: 33, apiBibleId: 'MIC', name: 'Micah', abbrev: 'Mic', testament: 'OT' },
  { bookNumber: 34, apiBibleId: 'NAM', name: 'Nahum', abbrev: 'Nah', testament: 'OT' },
  { bookNumber: 35, apiBibleId: 'HAB', name: 'Habakkuk', abbrev: 'Hab', testament: 'OT' },
  { bookNumber: 36, apiBibleId: 'ZEP', name: 'Zephaniah', abbrev: 'Zeph', testament: 'OT' },
  { bookNumber: 37, apiBibleId: 'HAG', name: 'Haggai', abbrev: 'Hag', testament: 'OT' },
  { bookNumber: 38, apiBibleId: 'ZEC', name: 'Zechariah', abbrev: 'Zech', testament: 'OT' },
  { bookNumber: 39, apiBibleId: 'MAL', name: 'Malachi', abbrev: 'Mal', testament: 'OT' },
  // New Testament
  { bookNumber: 40, apiBibleId: 'MAT', name: 'Matthew', abbrev: 'Matt', testament: 'NT' },
  { bookNumber: 41, apiBibleId: 'MRK', name: 'Mark', abbrev: 'Mark', testament: 'NT' },
  { bookNumber: 42, apiBibleId: 'LUK', name: 'Luke', abbrev: 'Luke', testament: 'NT' },
  { bookNumber: 43, apiBibleId: 'JHN', name: 'John', abbrev: 'John', testament: 'NT' },
  { bookNumber: 44, apiBibleId: 'ACT', name: 'Acts', abbrev: 'Acts', testament: 'NT' },
  { bookNumber: 45, apiBibleId: 'ROM', name: 'Romans', abbrev: 'Rom', testament: 'NT' },
  { bookNumber: 46, apiBibleId: '1CO', name: '1 Corinthians', abbrev: '1Cor', testament: 'NT' },
  { bookNumber: 47, apiBibleId: '2CO', name: '2 Corinthians', abbrev: '2Cor', testament: 'NT' },
  { bookNumber: 48, apiBibleId: 'GAL', name: 'Galatians', abbrev: 'Gal', testament: 'NT' },
  { bookNumber: 49, apiBibleId: 'EPH', name: 'Ephesians', abbrev: 'Eph', testament: 'NT' },
  { bookNumber: 50, apiBibleId: 'PHP', name: 'Philippians', abbrev: 'Phil', testament: 'NT' },
  { bookNumber: 51, apiBibleId: 'COL', name: 'Colossians', abbrev: 'Col', testament: 'NT' },
  { bookNumber: 52, apiBibleId: '1TH', name: '1 Thessalonians', abbrev: '1Thess', testament: 'NT' },
  { bookNumber: 53, apiBibleId: '2TH', name: '2 Thessalonians', abbrev: '2Thess', testament: 'NT' },
  { bookNumber: 54, apiBibleId: '1TI', name: '1 Timothy', abbrev: '1Tim', testament: 'NT' },
  { bookNumber: 55, apiBibleId: '2TI', name: '2 Timothy', abbrev: '2Tim', testament: 'NT' },
  { bookNumber: 56, apiBibleId: 'TIT', name: 'Titus', abbrev: 'Tit', testament: 'NT' },
  { bookNumber: 57, apiBibleId: 'PHM', name: 'Philemon', abbrev: 'Phlm', testament: 'NT' },
  { bookNumber: 58, apiBibleId: 'HEB', name: 'Hebrews', abbrev: 'Heb', testament: 'NT' },
  { bookNumber: 59, apiBibleId: 'JAS', name: 'James', abbrev: 'Jas', testament: 'NT' },
  { bookNumber: 60, apiBibleId: '1PE', name: '1 Peter', abbrev: '1Pet', testament: 'NT' },
  { bookNumber: 61, apiBibleId: '2PE', name: '2 Peter', abbrev: '2Pet', testament: 'NT' },
  { bookNumber: 62, apiBibleId: '1JN', name: '1 John', abbrev: '1Jn', testament: 'NT' },
  { bookNumber: 63, apiBibleId: '2JN', name: '2 John', abbrev: '2Jn', testament: 'NT' },
  { bookNumber: 64, apiBibleId: '3JN', name: '3 John', abbrev: '3Jn', testament: 'NT' },
  { bookNumber: 65, apiBibleId: 'JUD', name: 'Jude', abbrev: 'Jude', testament: 'NT' },
  { bookNumber: 66, apiBibleId: 'REV', name: 'Revelation', abbrev: 'Rev', testament: 'NT' },
]

// Pre-built lookup maps
const byBookNumber = new Map<number, BookEntry>(BOOKS.map((b) => [b.bookNumber, b]))
const byApiBibleId = new Map<string, BookEntry>(BOOKS.map((b) => [b.apiBibleId, b]))

// ============================================
// Lookup functions
// ============================================

/** Get API.Bible book ID from our numeric book number */
export function bookNumberToApiBibleId(bookNumber: number): string {
  const entry = byBookNumber.get(bookNumber)
  if (!entry) throw new Error(`[bible-id-map] Invalid bookNumber: ${bookNumber}`)
  return entry.apiBibleId
}

/** Get our numeric book number from API.Bible book ID */
export function apiBibleIdToBookNumber(bookId: string): number {
  const entry = byApiBibleId.get(bookId)
  if (!entry) throw new Error(`[bible-id-map] Unknown API.Bible bookId: ${bookId}`)
  return entry.bookNumber
}

/** Get full book entry from book number */
export function getBookByNumber(bookNumber: number): BookEntry {
  const entry = byBookNumber.get(bookNumber)
  if (!entry) throw new Error(`[bible-id-map] Invalid bookNumber: ${bookNumber}`)
  return entry
}

/** Get full book entry from API.Bible book ID */
export function getBookByApiBibleId(bookId: string): BookEntry {
  const entry = byApiBibleId.get(bookId)
  if (!entry) throw new Error(`[bible-id-map] Unknown API.Bible bookId: ${bookId}`)
  return entry
}

/** Get all 66 book entries */
export function getAllBooks(): BookEntry[] {
  return BOOKS
}

// ============================================
// ID builders
// ============================================

/** Build API.Bible chapter ID: "JHN.3" */
export function buildChapterId(bookId: string, chapter: number): string {
  return `${bookId}.${chapter}`
}

/** Build API.Bible verse ID: "JHN.3.16" */
export function buildVerseId(bookId: string, chapter: number, verse: number): string {
  return `${bookId}.${chapter}.${verse}`
}

/** Build API.Bible passage ID: "JHN.3.16-JHN.3.18" */
export function buildPassageId(
  bookId: string,
  chapter: number,
  startVerse: number,
  endVerse: number
): string {
  return `${bookId}.${chapter}.${startVerse}-${bookId}.${chapter}.${endVerse}`
}

// ============================================
// Parsers
// ============================================

/** Parse API.Bible verse ID "JHN.3.16" → { bookId, chapter, verse } */
export function parseVerseId(verseId: string): { bookId: string; chapter: number; verse: number } {
  const parts = verseId.split('.')
  if (parts.length !== 3) throw new Error(`[bible-id-map] Invalid verseId format: ${verseId}`)
  return {
    bookId: parts[0],
    chapter: parseInt(parts[1], 10),
    verse: parseInt(parts[2], 10),
  }
}

/** Parse API.Bible chapter ID "JHN.3" → { bookId, chapter } */
export function parseChapterId(chapterId: string): { bookId: string; chapter: number } {
  const parts = chapterId.split('.')
  if (parts.length !== 2) throw new Error(`[bible-id-map] Invalid chapterId format: ${chapterId}`)
  return {
    bookId: parts[0],
    chapter: parseInt(parts[1], 10),
  }
}

export type { BookEntry }
