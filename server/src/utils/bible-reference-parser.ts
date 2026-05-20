/**
 * Bible Reference Parser
 *
 * Parses user input to detect direct Bible verse references.
 * Supports various formats:
 * - "Romans 1:1"
 * - "Rom 1:1-5"
 * - "1 John 3"
 * - "Genesis 1:1-3"
 * - "Psalm 23"
 * - "1 Cor 13:4-7"
 */

export interface ParsedReference {
  type: 'direct'
  bookNumber: number
  bookName: string
  chapter: number
  verseStart?: number
  verseEnd?: number
}

// Map of book names and abbreviations to book numbers (1-66)
const BOOK_MAP: Record<string, { number: number; name: string }> = {
  // Genesis
  'genesis': { number: 1, name: 'Genesis' },
  'gen': { number: 1, name: 'Genesis' },
  'ge': { number: 1, name: 'Genesis' },

  // Exodus
  'exodus': { number: 2, name: 'Exodus' },
  'exod': { number: 2, name: 'Exodus' },
  'ex': { number: 2, name: 'Exodus' },

  // Leviticus
  'leviticus': { number: 3, name: 'Leviticus' },
  'lev': { number: 3, name: 'Leviticus' },
  'le': { number: 3, name: 'Leviticus' },

  // Numbers
  'numbers': { number: 4, name: 'Numbers' },
  'num': { number: 4, name: 'Numbers' },
  'nu': { number: 4, name: 'Numbers' },

  // Deuteronomy
  'deuteronomy': { number: 5, name: 'Deuteronomy' },
  'deut': { number: 5, name: 'Deuteronomy' },
  'de': { number: 5, name: 'Deuteronomy' },
  'dt': { number: 5, name: 'Deuteronomy' },

  // Joshua
  'joshua': { number: 6, name: 'Joshua' },
  'josh': { number: 6, name: 'Joshua' },
  'jos': { number: 6, name: 'Joshua' },

  // Judges
  'judges': { number: 7, name: 'Judges' },
  'judg': { number: 7, name: 'Judges' },
  'jdg': { number: 7, name: 'Judges' },

  // Ruth
  'ruth': { number: 8, name: 'Ruth' },
  'ru': { number: 8, name: 'Ruth' },

  // 1 Samuel
  '1samuel': { number: 9, name: '1 Samuel' },
  '1sam': { number: 9, name: '1 Samuel' },
  '1sa': { number: 9, name: '1 Samuel' },

  // 2 Samuel
  '2samuel': { number: 10, name: '2 Samuel' },
  '2sam': { number: 10, name: '2 Samuel' },
  '2sa': { number: 10, name: '2 Samuel' },

  // 1 Kings
  '1kings': { number: 11, name: '1 Kings' },
  '1ki': { number: 11, name: '1 Kings' },
  '1kgs': { number: 11, name: '1 Kings' },

  // 2 Kings
  '2kings': { number: 12, name: '2 Kings' },
  '2ki': { number: 12, name: '2 Kings' },
  '2kgs': { number: 12, name: '2 Kings' },

  // 1 Chronicles
  '1chronicles': { number: 13, name: '1 Chronicles' },
  '1chron': { number: 13, name: '1 Chronicles' },
  '1chr': { number: 13, name: '1 Chronicles' },
  '1ch': { number: 13, name: '1 Chronicles' },

  // 2 Chronicles
  '2chronicles': { number: 14, name: '2 Chronicles' },
  '2chron': { number: 14, name: '2 Chronicles' },
  '2chr': { number: 14, name: '2 Chronicles' },
  '2ch': { number: 14, name: '2 Chronicles' },

  // Ezra
  'ezra': { number: 15, name: 'Ezra' },
  'ezr': { number: 15, name: 'Ezra' },

  // Nehemiah
  'nehemiah': { number: 16, name: 'Nehemiah' },
  'neh': { number: 16, name: 'Nehemiah' },
  'ne': { number: 16, name: 'Nehemiah' },

  // Esther
  'esther': { number: 17, name: 'Esther' },
  'esth': { number: 17, name: 'Esther' },
  'est': { number: 17, name: 'Esther' },

  // Job
  'job': { number: 18, name: 'Job' },
  'jb': { number: 18, name: 'Job' },

  // Psalms
  'psalms': { number: 19, name: 'Psalms' },
  'psalm': { number: 19, name: 'Psalms' },
  'ps': { number: 19, name: 'Psalms' },
  'psa': { number: 19, name: 'Psalms' },

  // Proverbs
  'proverbs': { number: 20, name: 'Proverbs' },
  'prov': { number: 20, name: 'Proverbs' },
  'pro': { number: 20, name: 'Proverbs' },
  'pr': { number: 20, name: 'Proverbs' },

  // Ecclesiastes
  'ecclesiastes': { number: 21, name: 'Ecclesiastes' },
  'eccl': { number: 21, name: 'Ecclesiastes' },
  'ecc': { number: 21, name: 'Ecclesiastes' },
  'ec': { number: 21, name: 'Ecclesiastes' },

  // Song of Solomon
  'songofsolomon': { number: 22, name: 'Song of Solomon' },
  'songofsongs': { number: 22, name: 'Song of Solomon' },
  'song': { number: 22, name: 'Song of Solomon' },
  'sos': { number: 22, name: 'Song of Solomon' },
  'ss': { number: 22, name: 'Song of Solomon' },

  // Isaiah
  'isaiah': { number: 23, name: 'Isaiah' },
  'isa': { number: 23, name: 'Isaiah' },
  'is': { number: 23, name: 'Isaiah' },

  // Jeremiah
  'jeremiah': { number: 24, name: 'Jeremiah' },
  'jer': { number: 24, name: 'Jeremiah' },
  'je': { number: 24, name: 'Jeremiah' },

  // Lamentations
  'lamentations': { number: 25, name: 'Lamentations' },
  'lam': { number: 25, name: 'Lamentations' },
  'la': { number: 25, name: 'Lamentations' },

  // Ezekiel
  'ezekiel': { number: 26, name: 'Ezekiel' },
  'ezek': { number: 26, name: 'Ezekiel' },
  'eze': { number: 26, name: 'Ezekiel' },

  // Daniel
  'daniel': { number: 27, name: 'Daniel' },
  'dan': { number: 27, name: 'Daniel' },
  'da': { number: 27, name: 'Daniel' },

  // Hosea
  'hosea': { number: 28, name: 'Hosea' },
  'hos': { number: 28, name: 'Hosea' },
  'ho': { number: 28, name: 'Hosea' },

  // Joel
  'joel': { number: 29, name: 'Joel' },
  'joe': { number: 29, name: 'Joel' },
  'jl': { number: 29, name: 'Joel' },

  // Amos
  'amos': { number: 30, name: 'Amos' },
  'am': { number: 30, name: 'Amos' },

  // Obadiah
  'obadiah': { number: 31, name: 'Obadiah' },
  'obad': { number: 31, name: 'Obadiah' },
  'ob': { number: 31, name: 'Obadiah' },

  // Jonah
  'jonah': { number: 32, name: 'Jonah' },
  'jon': { number: 32, name: 'Jonah' },

  // Micah
  'micah': { number: 33, name: 'Micah' },
  'mic': { number: 33, name: 'Micah' },

  // Nahum
  'nahum': { number: 34, name: 'Nahum' },
  'nah': { number: 34, name: 'Nahum' },
  'na': { number: 34, name: 'Nahum' },

  // Habakkuk
  'habakkuk': { number: 35, name: 'Habakkuk' },
  'hab': { number: 35, name: 'Habakkuk' },

  // Zephaniah
  'zephaniah': { number: 36, name: 'Zephaniah' },
  'zeph': { number: 36, name: 'Zephaniah' },
  'zep': { number: 36, name: 'Zephaniah' },

  // Haggai
  'haggai': { number: 37, name: 'Haggai' },
  'hag': { number: 37, name: 'Haggai' },

  // Zechariah
  'zechariah': { number: 38, name: 'Zechariah' },
  'zech': { number: 38, name: 'Zechariah' },
  'zec': { number: 38, name: 'Zechariah' },

  // Malachi
  'malachi': { number: 39, name: 'Malachi' },
  'mal': { number: 39, name: 'Malachi' },

  // Matthew
  'matthew': { number: 40, name: 'Matthew' },
  'matt': { number: 40, name: 'Matthew' },
  'mat': { number: 40, name: 'Matthew' },
  'mt': { number: 40, name: 'Matthew' },

  // Mark
  'mark': { number: 41, name: 'Mark' },
  'mk': { number: 41, name: 'Mark' },
  'mr': { number: 41, name: 'Mark' },

  // Luke
  'luke': { number: 42, name: 'Luke' },
  'lk': { number: 42, name: 'Luke' },
  'lu': { number: 42, name: 'Luke' },

  // John
  'john': { number: 43, name: 'John' },
  'jn': { number: 43, name: 'John' },
  'joh': { number: 43, name: 'John' },

  // Acts
  'acts': { number: 44, name: 'Acts' },
  'act': { number: 44, name: 'Acts' },
  'ac': { number: 44, name: 'Acts' },

  // Romans
  'romans': { number: 45, name: 'Romans' },
  'rom': { number: 45, name: 'Romans' },
  'ro': { number: 45, name: 'Romans' },

  // 1 Corinthians
  '1corinthians': { number: 46, name: '1 Corinthians' },
  '1cor': { number: 46, name: '1 Corinthians' },
  '1co': { number: 46, name: '1 Corinthians' },

  // 2 Corinthians
  '2corinthians': { number: 47, name: '2 Corinthians' },
  '2cor': { number: 47, name: '2 Corinthians' },
  '2co': { number: 47, name: '2 Corinthians' },

  // Galatians
  'galatians': { number: 48, name: 'Galatians' },
  'gal': { number: 48, name: 'Galatians' },
  'ga': { number: 48, name: 'Galatians' },

  // Ephesians
  'ephesians': { number: 49, name: 'Ephesians' },
  'eph': { number: 49, name: 'Ephesians' },

  // Philippians
  'philippians': { number: 50, name: 'Philippians' },
  'phil': { number: 50, name: 'Philippians' },
  'php': { number: 50, name: 'Philippians' },

  // Colossians
  'colossians': { number: 51, name: 'Colossians' },
  'col': { number: 51, name: 'Colossians' },

  // 1 Thessalonians
  '1thessalonians': { number: 52, name: '1 Thessalonians' },
  '1thess': { number: 52, name: '1 Thessalonians' },
  '1thes': { number: 52, name: '1 Thessalonians' },
  '1th': { number: 52, name: '1 Thessalonians' },

  // 2 Thessalonians
  '2thessalonians': { number: 53, name: '2 Thessalonians' },
  '2thess': { number: 53, name: '2 Thessalonians' },
  '2thes': { number: 53, name: '2 Thessalonians' },
  '2th': { number: 53, name: '2 Thessalonians' },

  // 1 Timothy
  '1timothy': { number: 54, name: '1 Timothy' },
  '1tim': { number: 54, name: '1 Timothy' },
  '1ti': { number: 54, name: '1 Timothy' },

  // 2 Timothy
  '2timothy': { number: 55, name: '2 Timothy' },
  '2tim': { number: 55, name: '2 Timothy' },
  '2ti': { number: 55, name: '2 Timothy' },

  // Titus
  'titus': { number: 56, name: 'Titus' },
  'tit': { number: 56, name: 'Titus' },

  // Philemon
  'philemon': { number: 57, name: 'Philemon' },
  'phlm': { number: 57, name: 'Philemon' },
  'phm': { number: 57, name: 'Philemon' },

  // Hebrews
  'hebrews': { number: 58, name: 'Hebrews' },
  'heb': { number: 58, name: 'Hebrews' },

  // James
  'james': { number: 59, name: 'James' },
  'jas': { number: 59, name: 'James' },
  'jam': { number: 59, name: 'James' },

  // 1 Peter
  '1peter': { number: 60, name: '1 Peter' },
  '1pet': { number: 60, name: '1 Peter' },
  '1pe': { number: 60, name: '1 Peter' },
  '1pt': { number: 60, name: '1 Peter' },

  // 2 Peter
  '2peter': { number: 61, name: '2 Peter' },
  '2pet': { number: 61, name: '2 Peter' },
  '2pe': { number: 61, name: '2 Peter' },
  '2pt': { number: 61, name: '2 Peter' },

  // 1 John
  '1john': { number: 62, name: '1 John' },
  '1jn': { number: 62, name: '1 John' },
  '1jo': { number: 62, name: '1 John' },

  // 2 John
  '2john': { number: 63, name: '2 John' },
  '2jn': { number: 63, name: '2 John' },
  '2jo': { number: 63, name: '2 John' },

  // 3 John
  '3john': { number: 64, name: '3 John' },
  '3jn': { number: 64, name: '3 John' },
  '3jo': { number: 64, name: '3 John' },

  // Jude
  'jude': { number: 65, name: 'Jude' },
  'jud': { number: 65, name: 'Jude' },

  // Revelation
  'revelation': { number: 66, name: 'Revelation' },
  'rev': { number: 66, name: 'Revelation' },
  're': { number: 66, name: 'Revelation' },
  'apocalypse': { number: 66, name: 'Revelation' },
}

/**
 * Parses a user input string to detect if it's a direct Bible reference.
 *
 * @param input - User search query (e.g., "Romans 1:1", "John 3:16-17")
 * @returns ParsedReference if direct reference detected, null otherwise
 *
 * @example
 * parseReference("Romans 1:1")
 * // => { type: 'direct', bookNumber: 45, bookName: 'Romans', chapter: 1, verseStart: 1 }
 *
 * @example
 * parseReference("John 3:16-17")
 * // => { type: 'direct', bookNumber: 43, bookName: 'John', chapter: 3, verseStart: 16, verseEnd: 17 }
 *
 * @example
 * parseReference("Psalm 23")
 * // => { type: 'direct', bookNumber: 19, bookName: 'Psalms', chapter: 23 }
 *
 * @example
 * parseReference("verses about love")
 * // => null (not a direct reference, use semantic search)
 */
export function parseReference(input: string): ParsedReference | null {
  if (!input || typeof input !== 'string') {
    return null
  }

  const trimmed = input.trim()

  // Pattern explanation:
  // ^(\d?\s*[a-zA-Z]+)  - Book name, optionally starting with number (1 John, 2 Kings)
  // \s*                  - Optional whitespace
  // (\d+)               - Chapter number (required)
  // (?::(\d+))?         - Optional colon and verse start
  // (?:-(\d+))?         - Optional dash and verse end (for ranges)
  // $                   - End of string
  const pattern = /^(\d?\s*[a-zA-Z]+)\s*(\d+)(?::(\d+)(?:-(\d+))?)?$/i

  const match = trimmed.match(pattern)

  if (!match) {
    return null
  }

  const [, bookPart, chapterStr, verseStartStr, verseEndStr] = match

  // Normalize book name: lowercase, remove spaces
  const bookKey = bookPart.toLowerCase().replace(/\s+/g, '')

  const bookInfo = BOOK_MAP[bookKey]

  if (!bookInfo) {
    return null
  }

  const chapter = parseInt(chapterStr, 10)

  if (isNaN(chapter) || chapter < 1) {
    return null
  }

  const result: ParsedReference = {
    type: 'direct',
    bookNumber: bookInfo.number,
    bookName: bookInfo.name,
    chapter,
  }

  // Parse verse start if provided
  if (verseStartStr) {
    const verseStart = parseInt(verseStartStr, 10)
    if (!isNaN(verseStart) && verseStart >= 1) {
      result.verseStart = verseStart
    }
  }

  // Parse verse end if provided (for ranges like John 3:16-17)
  if (verseEndStr) {
    const verseEnd = parseInt(verseEndStr, 10)
    if (!isNaN(verseEnd) && verseEnd >= 1) {
      result.verseEnd = verseEnd
    }
  }

  return result
}

/**
 * Checks if the input appears to be a semantic/natural language query
 * rather than a direct Bible reference.
 *
 * @param input - User search query
 * @returns true if it looks like a semantic query
 */
export function isSemanticQuery(input: string): boolean {
  if (!input) return false

  // Check if it's a direct reference first
  if (parseReference(input) !== null) {
    return false
  }

  // Common patterns indicating semantic search:
  // - "verses about X"
  // - "passages on X"
  // - "what does the bible say about X"
  // - "top passages about X"
  // - Contains question words
  const semanticPatterns = [
    /verses?\s+(about|on|regarding)/i,
    /passages?\s+(about|on|regarding)/i,
    /what\s+does/i,
    /scriptures?\s+(about|on|regarding)/i,
    /top\s+\d*\s*(verses?|passages?)/i,
    /^(who|what|where|when|why|how)\s+/i,
    /the\s+\w+\s+story/i,  // "the creation story"
  ]

  return semanticPatterns.some(pattern => pattern.test(input))
}

/**
 * Determines the search type based on user input.
 *
 * @param input - User search query
 * @returns 'direct' for Bible references, 'semantic' for natural language queries
 */
export function getSearchType(input: string): 'direct' | 'semantic' {
  const ref = parseReference(input)
  return ref ? 'direct' : 'semantic'
}

/**
 * Match input against book names/abbreviations.
 * Returns matching books (e.g. "John" matches John, 1 John, 2 John, 3 John).
 */
export function matchBookNames(input: string): { bookNumber: number; bookName: string }[] {
  if (!input || typeof input !== 'string') return []

  const query = input.trim().toLowerCase().replace(/\s+/g, '')
  if (!query) return []

  // Collect all matching books (deduplicate by bookNumber)
  const matches = new Map<number, string>()

  for (const [key, info] of Object.entries(BOOK_MAP)) {
    if (key === query || key.startsWith(query) || info.name.toLowerCase().replace(/\s+/g, '').startsWith(query)) {
      if (!matches.has(info.number)) {
        matches.set(info.number, info.name)
      }
    }
  }

  return Array.from(matches.entries()).map(([bookNumber, bookName]) => ({ bookNumber, bookName }))
}
