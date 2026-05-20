/**
 * API.Bible TypeScript Interfaces
 *
 * Type definitions for all API.Bible v1 response shapes.
 * Reference: https://rest.api.bible/v1/swagger.json
 */

// ============================================
// Core response wrapper
// ============================================

export interface ApiBibleResponse<T> {
  data: T
  meta?: ApiBibleMeta
}

export interface ApiBibleMeta {
  fums: string
  fumsId: string
  fumsJsInclude: string
  fumsJs: string
  fumsNoScript: string
  fumsToken?: string
}

// ============================================
// Bible / Translation
// ============================================

export interface ApiBibleLanguage {
  id: string // ISO 639-3, e.g., "eng"
  name: string
  nameLocal: string
  script: string
  scriptDirection: string
}

export interface ApiBibleCountry {
  id: string
  name: string
  nameLocal: string
}

export interface ApiBibleSummary {
  id: string // e.g., "a761ca71e0b3ddcf-01"
  dblId: string
  abbreviation: string // e.g., "NASB"
  abbreviationLocal: string
  name: string
  nameLocal: string
  description: string | null
  descriptionLocal: string | null
  language: ApiBibleLanguage
  countries: ApiBibleCountry[]
  type: string // "text"
  updatedAt: string
  relatedDbl: string | null
  audioBibles: ApiBibleAudioSummary[]
}

export interface ApiBible extends ApiBibleSummary {
  copyright: string
  info: string
}

export interface ApiBibleAudioSummary {
  id: string
  name: string
  nameLocal: string
  description: string
  descriptionLocal: string
}

// ============================================
// Book
// ============================================

export interface ApiBibleBook {
  id: string // e.g., "GEN", "JHN"
  bibleId: string
  abbreviation: string
  name: string // e.g., "Genesis"
  nameLong: string // e.g., "The First Book of Moses, called Genesis"
  chapters?: ApiBibleChapterSummary[]
}

// ============================================
// Chapter
// ============================================

export interface ApiBibleChapterSummary {
  id: string // e.g., "GEN.1"
  bibleId: string
  number: string
  bookId: string
  reference: string
}

export interface ApiBibleChapter {
  id: string
  bibleId: string
  number: string
  bookId: string
  content: string // Full chapter text or HTML
  reference: string
  verseCount: number
  copyright: string
  next: { id: string; number: string; bookId: string } | null
  previous: { id: string; number: string; bookId: string } | null
}

// ============================================
// Verse
// ============================================

export interface ApiBibleVerseSummary {
  id: string // e.g., "JHN.3.16"
  orgId: string
  bibleId: string
  bookId: string
  chapterId: string
  reference: string
}

export interface ApiBibleVerse {
  id: string
  orgId: string
  bibleId: string
  bookId: string
  chapterId: string
  content: string
  reference: string
  verseCount: number
  copyright: string
  next: { id: string; number: string } | null
  previous: { id: string; number: string } | null
}

// ============================================
// Passage
// ============================================

export interface ApiBiblePassage {
  id: string // e.g., "JHN.3.16-JHN.3.18"
  orgId: string
  bibleId: string
  bookId: string
  chapterIds: string[]
  content: string
  reference: string
  verseCount: number
  copyright: string
}

// ============================================
// Search
// ============================================

export interface ApiBibleSearchOptions {
  query: string
  limit?: number
  offset?: number
  sort?: 'relevance' | 'canonical' | 'reverse-canonical'
  range?: string // e.g., "gen.1,gen.5" or "gen-num"
  fuzziness?: 'AUTO' | '0' | '1' | '2'
}

export interface ApiBibleSearchVerse {
  id: string
  orgId: string
  bibleId: string
  bookId: string
  chapterId: string
  text: string
  reference: string
}

export interface ApiBibleSearchResponse {
  query: string
  limit: number
  offset: number
  total: number
  verseCount: number
  verses: ApiBibleSearchVerse[] | null
  passages: ApiBiblePassage[] | null
}
