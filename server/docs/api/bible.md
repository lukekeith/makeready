# Bible API

Complete Bible reading, search, and user features API. For detailed documentation with full request/response examples, see [`BIBLE_INTEGRATION_README.md`](../../BIBLE_INTEGRATION_README.md).

---

## Overview

The Bible API provides 17+ endpoints across 6 categories:

| Category | Endpoints | Auth Required |
|----------|-----------|---------------|
| Reading | 5 | No |
| Smart Search | 2 | No |
| Full-text Search & Download | 2 | No |
| Highlights | 4 | Yes |
| Verse Notes | 5 | Yes |
| Bookmarks | 3 | Yes |

---

## Reading Endpoints (Public)

```http
GET /api/bible/translations                           # List all translations
GET /api/bible/translations/:code/books               # Get books for translation
GET /api/bible/:code/:book/:chapter                   # Read full chapter
GET /api/bible/:code/:book/:chapter/:verse            # Read single verse
GET /api/bible/:code/:book/:chapter/verses?start=&end= # Read verse range
```

**Example - Read John 3:16:**
```bash
curl http://localhost:3001/api/bible/KJV/43/3/16
```

---

## Smart Search Endpoints (Public)

The Smart Search API automatically detects query type:
- **Direct references** (e.g., "John 3:16", "Romans 1:1-5") → Exact verse lookup
- **Semantic queries** (e.g., "verses about love") → AI-powered vector search

### Smart Search
```http
POST /api/search/smart
```

**Request Body:**
```json
{
  "query": "John 3:16",
  "translation": "KJV",
  "limit": 10
}
```

**Response Types:**

Direct Reference:
```json
{
  "type": "direct",
  "query": "John 3:16",
  "book": { "bookNumber": 43, "name": "John" },
  "verses": [{ "verse": 16, "text": "For God so loved..." }],
  "total": 1
}
```

Semantic Search:
```json
{
  "type": "semantic",
  "query": "verses about love",
  "results": [
    { "reference": "1 Corinthians 13:4", "text": "...", "similarity": 0.89 }
  ],
  "total": 10
}
```

### Search Suggestions
```http
GET /api/search/suggestions?q=joh&translation=KJV
```

Returns book name autocomplete suggestions.

---

## Download for Offline (Public)

```http
GET /api/bible/translations/:code/download
```

Returns all ~31,000 verses in a flat array for offline caching.

**Response:**
```json
{
  "translation": { "code": "KJV", "name": "King James Version" },
  "books": [...],
  "verses": [
    { "b": 1, "c": 1, "v": 1, "t": "In the beginning..." }
  ],
  "metadata": { "totalVerses": 31102 }
}
```

**Abbreviated Keys:**
| Key | Meaning |
|-----|---------|
| b | bookNumber |
| c | chapter |
| v | verse |
| t | text |

---

## Full-text Search (Public)

```http
GET /api/bible/search?query=love&translation=KJV&limit=10
```

---

## Highlights Endpoints (Auth Required)

```http
GET    /api/bible/highlights                         # Get user's highlights
POST   /api/bible/highlights                         # Create highlight
PATCH  /api/bible/highlights/:id                     # Update highlight color
DELETE /api/bible/highlights/:id                     # Delete highlight
```

**Highlight Colors:** `YELLOW`, `BLUE`, `GREEN`, `ORANGE`, `PURPLE`, `PINK`

**Example - Create highlight:**
```bash
curl -X POST http://localhost:3001/api/bible/highlights \
  -H "Content-Type: application/json" \
  -H "Cookie: connect.sid=s:abc123..." \
  -d '{
    "translationCode": "KJV",
    "bookNumber": 43,
    "chapter": 3,
    "verseStart": 16,
    "verseEnd": null,
    "color": "YELLOW"
  }'
```

---

## Verse Notes Endpoints (Auth Required)

These endpoints manage `VerseNote` records - simple annotations attached to specific Bible verses during personal reading. For study-related notes with polymorphic linking (SOAP notes, journal entries, etc.), see the [Study Notes API](./notes.md).

```http
GET    /api/bible/notes                              # Get user's verse notes
GET    /api/bible/notes/:id                          # Get specific verse note
POST   /api/bible/notes                              # Create verse note
PATCH  /api/bible/notes/:id                          # Update verse note content
DELETE /api/bible/notes/:id                          # Delete verse note
```

**Create Verse Note Request:**
```json
{
  "translationCode": "KJV",
  "bookNumber": 43,
  "chapter": 3,
  "verseStart": 16,
  "verseEnd": null,
  "content": "This verse reminds me of God's love..."
}
```

---

## Bookmarks Endpoints (Auth Required)

```http
GET    /api/bible/bookmarks                          # Get user's bookmarks
POST   /api/bible/bookmarks                          # Create bookmark
DELETE /api/bible/bookmarks/:id                      # Delete bookmark
```

---

## Book Numbers Reference

| Book | Number | | Book | Number |
|------|--------|-|------|--------|
| Genesis | 1 | | Matthew | 40 |
| Exodus | 2 | | Mark | 41 |
| Psalms | 19 | | Luke | 42 |
| Proverbs | 20 | | John | 43 |
| Isaiah | 23 | | Romans | 45 |

Full list: 1-39 (Old Testament), 40-66 (New Testament)

---

## Related APIs

- **[Study Notes API](./notes.md)** - For SOAP study notes, journal entries, and polymorphic note linking during Bible study activities
- **Verse Notes (this page)** - For simple verse annotations during personal Bible reading

## Full Documentation

For complete request/response schemas, database design, and implementation details, see:
- [`BIBLE_INTEGRATION_README.md`](../../BIBLE_INTEGRATION_README.md)
