# Study Notes API

The Study Notes API provides a flexible, polymorphic note-taking system for members and users. Notes can be linked to any entity (lessons, activities, groups, enrollments, verses, etc.) through a generic linking system.

---

## Overview

The API supports two authentication contexts:

| Context | Endpoint Prefix | Auth Method | Use Case |
|---------|-----------------|-------------|----------|
| Member | `/api/member/notes` | Phone verification | Mobile app users taking notes during studies |
| User | `/api/notes` | Google OAuth | Web dashboard users |

---

## Architecture

### Note Types (Extensible)

Notes use a string-based `type` field for extensibility:

| Type | Description | SOAP Step |
|------|-------------|-----------|
| `OBSERVATION` | What does this passage say? | O |
| `APPLICATION` | How does this apply to my life? | A |
| `PRAYER` | Prayer response | P |
| `JOURNAL` | Free-form journal entry | - |
| `REFLECTION` | General reflection | - |
| `SCRIPTURE_NOTE` | Note on specific verse(s) | - |
| `QUESTION` | Question about the passage | - |

Custom types can be added without schema changes.

### Link Types (Polymorphic)

Notes can be linked to multiple entities via `NoteLink`:

| Link Type | Description | refId Format |
|-----------|-------------|--------------|
| `LESSON` | Link to a Lesson | UUID |
| `LESSON_ACTIVITY` | Link to a LessonActivity | UUID |
| `LESSON_SCHEDULE` | Link to a LessonSchedule | UUID |
| `ENROLLMENT` | Link to an Enrollment | UUID |
| `GROUP` | Link to a Group | UUID |
| `VERSE` | Link to a Verse (with metadata) | `{bookNumber}-{chapter}-{verse}` |
| `PROGRAM` | Link to a StudyProgram | UUID |

---

## Data Models

### StudyNote

```typescript
{
  id: string                    // UUID
  memberId?: string             // Member owner (phone-auth users)
  userId?: string               // User owner (Google-auth users)
  type: string                  // Note type (OBSERVATION, APPLICATION, etc.)
  content: string               // Note content (text)
  links: NoteLink[]             // Polymorphic entity links
  isActive: boolean             // Soft delete flag
  createdAt: string             // ISO 8601 datetime
  updatedAt: string             // ISO 8601 datetime
}
```

### NoteLink

```typescript
{
  id: string                    // UUID
  noteId: string                // Parent note UUID
  refType: string               // Entity type (LESSON, GROUP, VERSE, etc.)
  refId: string                 // Entity identifier
  metadata?: object             // Optional metadata (e.g., verse reference details)
  createdAt: string             // ISO 8601 datetime
}
```

**Example VERSE Link Metadata:**
```json
{
  "passageReference": "Romans 8:28",
  "bookNumber": 45,
  "bookName": "Romans",
  "chapterStart": 8,
  "verseStart": 28,
  "scriptureText": "And we know that all things work together..."
}
```

---

## Member Notes Endpoints (Phone Auth)

### Create Note
```http
POST /api/member/notes
```

**Authentication:** Member authentication required

**Request Body:**
```json
{
  "type": "OBSERVATION",
  "content": "This passage reminds me that God's love is unconditional.",
  "links": [
    {
      "refType": "LESSON_ACTIVITY",
      "refId": "activity-uuid-here"
    },
    {
      "refType": "GROUP",
      "refId": "group-uuid-here"
    }
  ]
}
```

**Request Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | string | Yes | Note type (OBSERVATION, APPLICATION, etc.) |
| content | string | Yes | Note content |
| links | array | No | Array of entity links |
| links[].refType | string | Yes | Link type (LESSON, GROUP, VERSE, etc.) |
| links[].refId | string | Yes | Entity UUID or identifier |
| links[].metadata | object | No | Additional metadata |

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "note-uuid",
    "memberId": "member-uuid",
    "type": "OBSERVATION",
    "content": "This passage reminds me...",
    "links": [
      {
        "id": "link-uuid",
        "noteId": "note-uuid",
        "refType": "LESSON_ACTIVITY",
        "refId": "activity-uuid",
        "metadata": null,
        "createdAt": "2025-01-18T10:00:00.000Z"
      }
    ],
    "isActive": true,
    "createdAt": "2025-01-18T10:00:00.000Z",
    "updatedAt": "2025-01-18T10:00:00.000Z"
  }
}
```

---

### Get Notes
```http
GET /api/member/notes
```

**Authentication:** Member authentication required

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| type | string | No | - | Filter by note type |
| linkType | string | No | - | Filter by link type (requires linkRefId) |
| linkRefId | string | No | - | Filter by linked entity ID |
| startDate | string | No | - | Filter by created date (ISO 8601) |
| endDate | string | No | - | Filter by created date (ISO 8601) |
| limit | number | No | 50 | Max results |
| offset | number | No | 0 | Pagination offset |

**Example - Get all OBSERVATION notes for an enrollment:**
```bash
curl "http://localhost:3001/api/member/notes?type=OBSERVATION&linkType=ENROLLMENT&linkRefId=enrollment-uuid" \
  -H "Cookie: connect.sid=s:abc123..."
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [...],
  "pagination": {
    "total": 25,
    "limit": 50,
    "offset": 0,
    "hasMore": false
  }
}
```

---

### Get Notes for Entity
```http
GET /api/member/notes/entity/:refType/:refId
```

**Authentication:** Member authentication required

**Purpose:** Get all notes linked to a specific entity (only returns notes owned by the authenticated member).

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| refType | string | Entity type (LESSON, GROUP, ENROLLMENT, etc.) |
| refId | string | Entity UUID |

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| type | string | No | - | Filter by note type |
| limit | number | No | 100 | Max results |

**Example - Get all notes for a lesson:**
```bash
curl "http://localhost:3001/api/member/notes/entity/LESSON/lesson-uuid" \
  -H "Cookie: connect.sid=s:abc123..."
```

---

### Get Single Note
```http
GET /api/member/notes/:noteId
```

**Authentication:** Member authentication required

**Authorization:** Member can only access their own notes.

---

### Update Note
```http
PATCH /api/member/notes/:noteId
```

**Authentication:** Member authentication required

**Authorization:** Member can only update their own notes.

**Request Body:**
```json
{
  "content": "Updated note content here..."
}
```

---

### Delete Note (Soft Delete)
```http
DELETE /api/member/notes/:noteId
```

**Authentication:** Member authentication required

**Authorization:** Member can only delete their own notes.

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Note deleted"
}
```

---

### Get Notes for LLM
```http
GET /api/member/notes/llm
```

**Authentication:** Member authentication required

**Purpose:** Get notes formatted for AI/LLM consumption with scripture context from VERSE link metadata.

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| enrollmentId | string | No | - | Filter by enrollment |
| type | string | No | - | Filter by note type |
| startDate | string | No | - | Filter by created date |
| endDate | string | No | - | Filter by created date |
| limit | number | No | 100 | Max results |

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "type": "OBSERVATION",
      "content": "This passage shows God's faithfulness...",
      "passageReference": "Romans 8:28",
      "scriptureText": "And we know that all things work together for good...",
      "createdAt": "2025-01-18T10:00:00.000Z"
    }
  ]
}
```

---

## User Notes Endpoints (Google Auth)

The User endpoints mirror the Member endpoints but use `/api/notes` prefix and Google OAuth authentication:

```http
POST   /api/notes                    # Create note
GET    /api/notes                    # Get notes (with filtering)
GET    /api/notes/:noteId            # Get single note
PATCH  /api/notes/:noteId            # Update note
DELETE /api/notes/:noteId            # Delete note
```

---

## Constants Endpoint

### Get Available Types
```http
GET /api/notes/types
```

**Authentication:** Public (no auth required)

**Purpose:** Get available note types and link types for API consumers.

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "noteTypes": {
      "OBSERVATION": "OBSERVATION",
      "APPLICATION": "APPLICATION",
      "PRAYER": "PRAYER",
      "JOURNAL": "JOURNAL",
      "REFLECTION": "REFLECTION",
      "SCRIPTURE_NOTE": "SCRIPTURE_NOTE",
      "QUESTION": "QUESTION"
    },
    "linkTypes": {
      "LESSON": "LESSON",
      "LESSON_ACTIVITY": "LESSON_ACTIVITY",
      "LESSON_SCHEDULE": "LESSON_SCHEDULE",
      "ENROLLMENT": "ENROLLMENT",
      "GROUP": "GROUP",
      "VERSE": "VERSE",
      "PROGRAM": "PROGRAM"
    }
  }
}
```

---

## Activity Progress Integration

Notes are automatically created with full context when saving SOAP activity progress:

```http
POST /api/member/activities/:lessonActivityId/progress
```

**Request Body:**
```json
{
  "lessonScheduleId": "schedule-uuid",
  "currentStep": "APPLICATION",
  "notes": [
    {
      "type": "OBSERVATION",
      "content": "I noticed that Paul emphasizes..."
    },
    {
      "type": "APPLICATION",
      "content": "I can apply this by..."
    }
  ]
}
```

**Auto-generated Links:**
When notes are created via activity progress, they automatically receive links to:
- `LESSON_ACTIVITY` - The activity being completed
- `LESSON_SCHEDULE` - The scheduled lesson instance
- `ENROLLMENT` - The group's enrollment in the study program
- `GROUP` - The group
- `LESSON` - The lesson
- `PROGRAM` - The study program
- `VERSE` - The passage (with scripture text in metadata)

---

## Comparison: Study Notes vs Verse Notes

The MakeReady API has two distinct note systems:

| Feature | Study Notes | Verse Notes |
|---------|-------------|-------------|
| Endpoint | `/api/member/notes`, `/api/notes` | `/api/bible/notes` |
| Model | `StudyNote` + `NoteLink` | `VerseNote` |
| Purpose | SOAP study notes with context | Simple verse annotations |
| Linking | Polymorphic (any entity) | Fixed (translation + book + chapter + verse) |
| Auth | Member OR User | User only |
| Use Case | Bible study activities | Personal Bible reading |

---

## Source Files

| File | Purpose |
|------|---------|
| `src/routes/notes.ts` | Route handlers |
| `src/services/notes.service.ts` | Business logic |
| `src/routes/activity-progress.ts` | SOAP progress integration |
| `prisma/schema.prisma` | Database models (StudyNote, NoteLink) |
