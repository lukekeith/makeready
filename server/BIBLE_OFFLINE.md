# Offline Bible Feature - Product Requirements Document

## Overview

Enable users to read, navigate, and search the Bible without an internet connection on the MakeReady iOS app. Semantic AI-powered search will remain an online-only feature.

---

## Goals

1. **Offline Reading**: Users can read any Bible verse without network connectivity
2. **Fast Navigation**: Instant access to any book, chapter, or verse
3. **Reference Search**: Search by Bible reference (e.g., "John 3:16") works offline
4. **Multiple Translations**: Support KJV and ASV initially, extensible to more
5. **Minimal Storage**: Keep app size reasonable (~10 MB for Bible data)

---

## User Stories

### Core Stories

| ID | As a... | I want to... | So that... |
|----|---------|--------------|------------|
| U1 | User | Read the Bible without internet | I can study Scripture anywhere |
| U2 | User | Navigate by book/chapter/verse | I can quickly find specific passages |
| U3 | User | Type "John 3:16" and see the verse | I can jump directly to references |
| U4 | User | Switch between KJV and ASV | I can compare translations |
| U5 | User | Search "verses about love" when online | I can discover relevant passages |

### Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| E1 | User searches "love" while offline | Show message: "Semantic search requires internet. Try a reference like 'John 3:16'" |
| E2 | User types invalid reference "Hezekiah 1:1" | Show message: "Book not found" with suggestions |
| E3 | User requests verse beyond chapter length | Show message: "Romans 1 has 32 verses" |
| E4 | App launched for first time without internet | Bible data bundled in app, works immediately |

---

## Feature Breakdown

### 1. Offline Bible Reading

**Description**: Display Bible text from local database

**Requirements**:
- Load verses from bundled SQLite database
- Support continuous reading (scroll through chapter)
- Remember last read position
- Adjustable text size

**UI Components**:
- `BibleReaderView` - Main reading interface
- `VerseRow` - Individual verse display
- `ChapterHeader` - Book and chapter title

### 2. Book/Chapter/Verse Navigation

**Description**: Hierarchical navigation through Bible structure

**Requirements**:
- Book picker grouped by Testament (Old/New)
- Chapter grid for selected book
- Verse list with tap-to-navigate
- Breadcrumb showing current location

**UI Components**:
- `BookPickerView` - List of 66 books
- `ChapterGridView` - Grid of chapter numbers
- `NavigationBar` - Current location + back button

### 3. Reference Search (Offline)

**Description**: Parse and navigate to Bible references

**Supported Formats**:
```
Full reference:     "John 3:16"         → John 3:16
Verse range:        "John 3:16-17"      → John 3:16-17
Chapter only:       "Psalm 23"          → Psalm 23:1-6
Abbreviated:        "Gen 1:1"           → Genesis 1:1
Numbered books:     "1 Cor 13"          → 1 Corinthians 13
No space:           "1John 3:16"        → 1 John 3:16
```

**Requirements**:
- Parse reference in < 1ms
- Support common abbreviations (Gen, Ex, Lev, Ps, Matt, etc.)
- Case-insensitive matching
- Fuzzy matching for typos (optional, Phase 2)

### 4. Semantic Search (Online Only)

**Description**: AI-powered search for thematic queries

**Requirements**:
- Detect non-reference queries automatically
- Call `/api/search/smart` endpoint
- Display results with similarity scores
- Show offline message when no network

**Query Classification**:
```
"John 3:16"           → Reference (offline)
"verses about love"   → Semantic (online)
"faith"               → Semantic (online)
"Rom 8:28"            → Reference (offline)
```

### 5. Translation Management

**Description**: Support multiple Bible translations

**Initial Translations**:
- KJV (King James Version) - Public domain
- ASV (American Standard Version) - Public domain

**Requirements**:
- Bundle both translations in app
- Quick translation switcher in reading view
- Parallel view (Phase 2) - show two translations side by side

---

## Technical Architecture

### Data Layer

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS App                                 │
│                                                              │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │  BibleDatabase  │    │  BibleRepository                │ │
│  │  (SQLite)       │◀───│  - getBooks()                   │ │
│  │                 │    │  - getChapters(book)            │ │
│  │  Tables:        │    │  - getVerses(book, chapter)     │ │
│  │  - books        │    │  - searchReference(query)       │ │
│  │  - verses       │    │  - getVerse(book, ch, verse)    │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  ReferenceParser                                        ││
│  │  - parse("John 3:16") → ParsedReference                 ││
│  │  - isReference("verses about love") → false             ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Database Schema

```sql
-- books table
CREATE TABLE books (
    id INTEGER PRIMARY KEY,
    bookNumber INTEGER NOT NULL,      -- 1-66
    bookName TEXT NOT NULL,           -- "Genesis", "Matthew"
    abbreviation TEXT NOT NULL,       -- "Gen", "Matt"
    testament TEXT NOT NULL,          -- "OT" or "NT"
    chapterCount INTEGER NOT NULL     -- Number of chapters
);

-- verses table
CREATE TABLE verses (
    id INTEGER PRIMARY KEY,
    translationCode TEXT NOT NULL,    -- "KJV", "ASV"
    bookNumber INTEGER NOT NULL,      -- 1-66
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    text TEXT NOT NULL,
    FOREIGN KEY (bookNumber) REFERENCES books(bookNumber)
);

-- Indexes for fast queries
CREATE INDEX idx_verses_lookup ON verses(translationCode, bookNumber, chapter, verse);
CREATE INDEX idx_verses_chapter ON verses(translationCode, bookNumber, chapter);
```

### Swift Data Models

```swift
struct Book: Identifiable {
    let id: Int
    let bookNumber: Int
    let bookName: String
    let abbreviation: String
    let testament: Testament
    let chapterCount: Int

    enum Testament: String {
        case old = "OT"
        case new = "NT"
    }
}

struct Verse: Identifiable {
    let id: Int
    let translationCode: String
    let bookNumber: Int
    let chapter: Int
    let verse: Int
    let text: String

    var reference: String {
        "\(bookName) \(chapter):\(verse)"
    }
}

struct ParsedReference {
    let bookNumber: Int
    let bookName: String
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?
}
```

### Reference Parser (Swift)

```swift
class ReferenceParser {
    /// Parse a Bible reference string
    /// - Returns: ParsedReference or nil if not a valid reference
    func parse(_ input: String) -> ParsedReference?

    /// Check if input looks like a reference vs semantic query
    func isReference(_ input: String) -> Bool

    /// Get suggestions for partial input
    func suggest(_ input: String) -> [String]
}
```

### Search Flow

```swift
func search(query: String) async -> SearchResult {
    // 1. Try to parse as reference
    if let reference = ReferenceParser.parse(query) {
        // Offline lookup
        let verses = BibleRepository.getVerses(reference)
        return .reference(verses)
    }

    // 2. Not a reference - try semantic search
    guard NetworkMonitor.isConnected else {
        return .offlineError("Semantic search requires internet")
    }

    // 3. Call API for semantic search
    let results = try await APIClient.semanticSearch(query)
    return .semantic(results)
}
```

---

## Implementation Phases

### Phase 1: Data Export & Bundle (Server)
**Effort**: 1 day

- [ ] Create `export-bible-sqlite.ts` script
- [ ] Export books table with metadata
- [ ] Export verses table (KJV + ASV, no embeddings)
- [ ] Generate `bible.sqlite` file (~8 MB)
- [ ] Add to iOS app bundle

**Deliverable**: `bible.sqlite` file ready for iOS bundle

### Phase 2: iOS Database Layer
**Effort**: 2 days

- [ ] Add SQLite.swift package or use GRDB
- [ ] Create `BibleDatabase.swift` wrapper
- [ ] Create `BibleRepository.swift` with query methods
- [ ] Create `Book` and `Verse` models
- [ ] Write unit tests for data layer

**Deliverable**: Working data layer with tests

### Phase 3: Reference Parser (Swift)
**Effort**: 1 day

- [ ] Port TypeScript parser to Swift
- [ ] Support all abbreviation patterns
- [ ] Support verse ranges
- [ ] Handle edge cases (numbered books, no space)
- [ ] Write unit tests for parser

**Deliverable**: `ReferenceParser.swift` with full test coverage

### Phase 4: Navigation UI
**Effort**: 2 days

- [ ] Create `BookPickerView`
- [ ] Create `ChapterGridView`
- [ ] Create `BibleReaderView`
- [ ] Implement navigation stack
- [ ] Add translation switcher

**Deliverable**: Complete navigation flow

### Phase 5: Search Integration
**Effort**: 1 day

- [ ] Create unified `SearchView`
- [ ] Implement search bar with instant results
- [ ] Route references to offline lookup
- [ ] Route semantic queries to API
- [ ] Handle offline state gracefully

**Deliverable**: Unified search experience

### Phase 6: Polish & Testing
**Effort**: 1 day

- [ ] Performance optimization
- [ ] Memory usage audit
- [ ] Offline mode testing
- [ ] Accessibility review
- [ ] UI polish

**Deliverable**: Production-ready feature

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Reference lookup time | < 50ms |
| Chapter load time | < 100ms |
| App size increase | < 15 MB |
| Offline reliability | 100% for references |
| Parser accuracy | 100% for valid references |

---

## Dependencies

### Server-Side
- Railway Postgres database with Bible data (complete)
- Export script to generate SQLite

### iOS-Side
- SQLite library (SQLite.swift or GRDB)
- Network monitoring (NWPathMonitor)

### Existing Assets
- Bible data in Railway Postgres (KJV + ASV)
- Reference parser logic (TypeScript - needs porting)
- Semantic search API endpoint (complete)

---

## Out of Scope (Future Phases)

- Offline semantic search (requires on-device ML model)
- Highlighting and notes
- Bookmarks and reading plans
- Audio Bible
- Cross-references
- Additional translations beyond KJV/ASV
- Parallel translation view

---

## Open Questions

1. **Download vs Bundle**: Should Bible data be bundled or downloaded on first launch?
   - Recommendation: Bundle for immediate offline access

2. **Update Strategy**: How to handle corrections to Bible text?
   - Recommendation: App update, Bible text rarely changes

3. **Translation Licensing**: Are there other public domain translations to add?
   - Consider: WEB (World English Bible), YLT (Young's Literal)

---

## Appendix

### Book Abbreviation Reference

```
Genesis     Gen, Ge, Gn
Exodus      Ex, Exod, Exo
Leviticus   Lev, Le, Lv
Numbers     Num, Nu, Nm
Deuteronomy Deut, De, Dt
...
Matthew     Matt, Mt
Mark        Mark, Mk, Mr
Luke        Luke, Lk, Lu
John        John, Jn, Jhn
Acts        Acts, Ac
Romans      Rom, Ro, Rm
...
Revelation  Rev, Re, Rv
```

### Example API Response (Semantic Search)

```json
{
  "type": "semantic",
  "query": "verses about love",
  "results": [
    {
      "reference": "1 Corinthians 13:4",
      "text": "Charity suffereth long, and is kind...",
      "similarity": 0.89
    },
    {
      "reference": "John 3:16",
      "text": "For God so loved the world...",
      "similarity": 0.87
    }
  ]
}
```

### Example Offline Reference Response

```json
{
  "type": "reference",
  "query": "John 3:16",
  "verses": [
    {
      "reference": "John 3:16",
      "bookNumber": 43,
      "chapter": 3,
      "verse": 16,
      "text": "For God so loved the world, that he gave his only begotten Son..."
    }
  ]
}
```
