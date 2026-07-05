// Static Bible metadata — web port of iphone/MakeReady/Pages/Bible/
// BibleData.swift (all 66 books: names, grid abbreviations, chapter counts,
// category colors) and BibleVersionMenu.swift (known translations + the
// popular-first sort order for the version dropdown).

export type BibleTestament = 'old' | 'new'

export type BibleBookCategory =
  | 'pentateuch'
  | 'historical'
  | 'wisdom'
  | 'majorProphets'
  | 'minorProphets'
  | 'gospelsAndActs'
  | 'paulineEpistles'
  | 'generalEpistles'
  | 'apocalyptic'

export interface BibleBookInfo {
  id: number // book number 1–66
  name: string
  abbreviation: string
  chapters: number
  category: BibleBookCategory
  testament: BibleTestament
}

/** BookCategory.color hex values (BibleData.swift). */
export const BIBLE_CATEGORY_COLORS: Record<BibleBookCategory, string> = {
  pentateuch: '#424216',
  historical: '#143F45',
  wisdom: '#254422',
  majorProphets: '#143F45',
  minorProphets: '#563B2D',
  gospelsAndActs: '#563139',
  paulineEpistles: '#424216',
  generalEpistles: '#563B2D',
  apocalyptic: '#563139',
}

const B = (
  id: number,
  name: string,
  abbreviation: string,
  chapters: number,
  category: BibleBookCategory,
  testament: BibleTestament,
): BibleBookInfo => ({ id, name, abbreviation, chapters, category, testament })

export const bibleBooks: BibleBookInfo[] = [
  // Old Testament — Pentateuch (1–5)
  B(1, 'Genesis', 'Gen', 50, 'pentateuch', 'old'),
  B(2, 'Exodus', 'Exod', 40, 'pentateuch', 'old'),
  B(3, 'Leviticus', 'Lev', 27, 'pentateuch', 'old'),
  B(4, 'Numbers', 'Num', 36, 'pentateuch', 'old'),
  B(5, 'Deuteronomy', 'Deut', 34, 'pentateuch', 'old'),
  // Historical (6–17)
  B(6, 'Joshua', 'Josh', 24, 'historical', 'old'),
  B(7, 'Judges', 'Judg', 21, 'historical', 'old'),
  B(8, 'Ruth', 'Ruth', 4, 'historical', 'old'),
  B(9, '1 Samuel', '1 Sam', 31, 'historical', 'old'),
  B(10, '2 Samuel', '2 Sam', 24, 'historical', 'old'),
  B(11, '1 Kings', '1 King', 22, 'historical', 'old'),
  B(12, '2 Kings', '2 King', 25, 'historical', 'old'),
  B(13, '1 Chronicles', '1 Chron', 29, 'historical', 'old'),
  B(14, '2 Chronicles', '2 Chron', 36, 'historical', 'old'),
  B(15, 'Ezra', 'Ezra', 10, 'historical', 'old'),
  B(16, 'Nehemiah', 'Neh', 13, 'historical', 'old'),
  B(17, 'Esther', 'Esther', 10, 'historical', 'old'),
  // Wisdom & Poetry (18–22)
  B(18, 'Job', 'Job', 42, 'wisdom', 'old'),
  B(19, 'Psalms', 'Ps', 150, 'wisdom', 'old'),
  B(20, 'Proverbs', 'Prov', 31, 'wisdom', 'old'),
  B(21, 'Ecclesiastes', 'Eccles', 12, 'wisdom', 'old'),
  B(22, 'Song of Solomon', 'Song', 8, 'wisdom', 'old'),
  // Major Prophets (23–27)
  B(23, 'Isaiah', 'Isa', 66, 'majorProphets', 'old'),
  B(24, 'Jeremiah', 'Jer', 52, 'majorProphets', 'old'),
  B(25, 'Lamentations', 'Lam', 5, 'majorProphets', 'old'),
  B(26, 'Ezekiel', 'Ezek', 48, 'majorProphets', 'old'),
  B(27, 'Daniel', 'Dan', 12, 'majorProphets', 'old'),
  // Minor Prophets (28–39)
  B(28, 'Hosea', 'Hos', 14, 'minorProphets', 'old'),
  B(29, 'Joel', 'Joel', 3, 'minorProphets', 'old'),
  B(30, 'Amos', 'Amos', 9, 'minorProphets', 'old'),
  B(31, 'Obadiah', 'Obad', 1, 'minorProphets', 'old'),
  B(32, 'Jonah', 'Jonah', 4, 'minorProphets', 'old'),
  B(33, 'Micah', 'Micah', 7, 'minorProphets', 'old'),
  B(34, 'Nahum', 'Nah', 3, 'minorProphets', 'old'),
  B(35, 'Habakkuk', 'Hab', 3, 'minorProphets', 'old'),
  B(36, 'Zephaniah', 'Zeph', 3, 'minorProphets', 'old'),
  B(37, 'Haggai', 'Haggai', 2, 'minorProphets', 'old'),
  B(38, 'Zechariah', 'Zech', 14, 'minorProphets', 'old'),
  B(39, 'Malachi', 'Mal', 4, 'minorProphets', 'old'),
  // New Testament — Gospels & Acts (40–44)
  B(40, 'Matthew', 'Matt', 28, 'gospelsAndActs', 'new'),
  B(41, 'Mark', 'Mark', 16, 'gospelsAndActs', 'new'),
  B(42, 'Luke', 'Luke', 24, 'gospelsAndActs', 'new'),
  B(43, 'John', 'John', 21, 'gospelsAndActs', 'new'),
  B(44, 'Acts', 'Acts', 28, 'gospelsAndActs', 'new'),
  // Pauline Epistles (45–57)
  B(45, 'Romans', 'Rom', 16, 'paulineEpistles', 'new'),
  B(46, '1 Corinthians', '1 Cor', 16, 'paulineEpistles', 'new'),
  B(47, '2 Corinthians', '2 Cor', 13, 'paulineEpistles', 'new'),
  B(48, 'Galatians', 'Gal', 6, 'paulineEpistles', 'new'),
  B(49, 'Ephesians', 'Eph', 6, 'paulineEpistles', 'new'),
  B(50, 'Philippians', 'Phil', 4, 'paulineEpistles', 'new'),
  B(51, 'Colossians', 'Col', 4, 'paulineEpistles', 'new'),
  B(52, '1 Thessalonians', '1 Thess', 5, 'paulineEpistles', 'new'),
  B(53, '2 Thessalonians', '2 Thess', 3, 'paulineEpistles', 'new'),
  B(54, '1 Timothy', '1 Tim', 6, 'paulineEpistles', 'new'),
  B(55, '2 Timothy', '2 Tim', 4, 'paulineEpistles', 'new'),
  B(56, 'Titus', 'Titus', 3, 'paulineEpistles', 'new'),
  B(57, 'Philemon', 'Phil', 1, 'paulineEpistles', 'new'),
  // General Epistles (58–65)
  B(58, 'Hebrews', 'Heb', 13, 'generalEpistles', 'new'),
  B(59, 'James', 'James', 5, 'generalEpistles', 'new'),
  B(60, '1 Peter', '1 Pet', 5, 'generalEpistles', 'new'),
  B(61, '2 Peter', '2 Pet', 3, 'generalEpistles', 'new'),
  B(62, '1 John', '1 John', 5, 'generalEpistles', 'new'),
  B(63, '2 John', '2 John', 1, 'generalEpistles', 'new'),
  B(64, '3 John', '3 John', 1, 'generalEpistles', 'new'),
  B(65, 'Jude', 'Jude', 1, 'generalEpistles', 'new'),
  // Apocalyptic (66)
  B(66, 'Revelation', 'Rev', 22, 'apocalyptic', 'new'),
]

export const oldTestamentBooks = bibleBooks.filter((b) => b.testament === 'old')
export const newTestamentBooks = bibleBooks.filter((b) => b.testament === 'new')

export function bibleBookByNumber(bookNumber: number): BibleBookInfo | undefined {
  return bibleBooks.find((b) => b.id === bookNumber)
}

export interface BibleVersionInfo {
  id: string // API.Bible id
  code: string // abbreviation shown in the version badge
  name: string
}

/** Cached fallback translations (BibleVersionMenu.swift knownBibleVersions). */
export const knownBibleVersions: BibleVersionInfo[] = [
  { id: 'de4e12af7f28f599-02', code: 'KJV', name: 'King James (Authorised) Version' },
  { id: '01b29f4b342acc35-01', code: 'ASV', name: 'American Standard Version' },
  { id: '9879dbb7cfe39e4d-04', code: 'FBV', name: 'Free Bible Version' },
  { id: '65eec8e0b60e656b-01', code: 'GNV', name: 'Geneva Bible' },
  { id: '55212e3cf4d04c49-01', code: 'GNTD', name: 'Good News Translation (US Version)' },
  { id: 'b32b9d1b64b4ef29-01', code: 'LSV', name: 'Literal Standard Version' },
  { id: 'c315fa9f71d4af3a-01', code: 'WEB', name: 'World English Bible' },
  { id: 'f72b840c855f362c-04', code: 'WEBBE', name: 'World English Bible, British Edition' },
  { id: '7142879509583d59-04', code: 'T4T', name: 'Translation for Translators' },
  { id: 'bba9f40f2062d3ca-01', code: 'BSB', name: 'Berean Standard Bible' },
]

/** Version-dropdown sort: popular codes first, then by name (iOS versionTapped). */
export const POPULAR_TRANSLATION_CODES = ['KJV', 'NIV', 'ESV', 'NASB', 'NLT', 'NKJV', 'CSB', 'BSB', 'WEB', 'ASV']

export function sortVersionsPopularFirst<T extends { code: string; name: string }>(versions: T[]): T[] {
  return [...versions].sort((a, b) => {
    const ai = POPULAR_TRANSLATION_CODES.indexOf(a.code.toUpperCase())
    const bi = POPULAR_TRANSLATION_CODES.indexOf(b.code.toUpperCase())
    const av = ai === -1 ? Number.MAX_SAFE_INTEGER : ai
    const bv = bi === -1 ? Number.MAX_SAFE_INTEGER : bi
    if (av !== bv) return av - bv
    return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
  })
}

/** PassageData.reference (StudyModels.swift) — "Romans 1:1" / "Romans 1:1-5" / "Romans 1:28 - 2:4". */
export function passageReference(p: {
  bookName: string
  chapterStart: number
  chapterEnd?: number | null
  verseStart: number
  verseEnd: number
}): string {
  if (p.chapterEnd != null && p.chapterEnd !== p.chapterStart) {
    return `${p.bookName} ${p.chapterStart}:${p.verseStart} - ${p.chapterEnd}:${p.verseEnd}`
  }
  if (p.verseStart === p.verseEnd) return `${p.bookName} ${p.chapterStart}:${p.verseStart}`
  return `${p.bookName} ${p.chapterStart}:${p.verseStart}-${p.verseEnd}`
}
