# Study Programs API

Study programs are structured Bible study curricula with lessons organized by day. Each lesson can have multiple activities of different types.

---

## Data Models

### Study Program
```typescript
{
  id: string                    // UUID
  name: string                  // Program name (max 200 chars)
  description?: string          // Optional description (max 2000 chars)
  defaultActivity: ActivityType // Default activity type for new lessons
  days: number                  // Total number of days (1-360)
  coverImageUrl?: string        // Cover image URL (responsive variants)
  creatorId: string             // User UUID (owner)
  isActive: boolean             // Soft delete flag
  createdAt: string             // ISO 8601 datetime
  updatedAt: string             // ISO 8601 datetime
  lessons: Lesson[]             // Nested lessons with activities
}
```

### Lesson
```typescript
{
  id: string                    // UUID
  studyProgramId: string        // Parent program UUID
  dayNumber: number             // 1-based day number
  createdAt: string             // ISO 8601 datetime
  updatedAt: string             // ISO 8601 datetime
  activities: LessonActivity[]  // Activities for this day
}
```

### Lesson Activity
```typescript
{
  id: string                    // UUID
  lessonId: string              // Parent lesson UUID
  type: ActivityType            // SOAP | OIA | DBS | HEAR | VIDEO
  status: ActivityStatus        // PENDING | COMPLETE
  highlightMode: HighlightMode  // HIGHLIGHT | CHAPTER | VERSE
  orderNumber: number           // Order within lesson (1-based)

  // Passage Reference (for study activities)
  passageReference?: string     // Human-readable: "Romans 1:1-5"
  bookNumber?: number           // 1-66
  bookName?: string             // "Romans"
  chapterStart?: number
  chapterEnd?: number
  verseStart?: number
  verseEnd?: number

  // Highlight Range (word-level for HIGHLIGHT mode)
  startElementId?: string       // "45-1-1" (bookNum-chapter-verse)
  startOffset?: number          // Character offset within start verse
  endElementId?: string
  endOffset?: number

  // Selected Verses (for VERSE mode)
  selectedVerses?: string[]     // ["45-1-1", "45-1-3", "45-1-5"]

  // VIDEO activity reference
  videoId?: string              // Video UUID (for VIDEO type only)
  videoUrl?: string             // Cloudflare Stream playback URL
  video?: Video                 // Populated video details

  createdAt: string
  updatedAt: string
}
```

### Activity Type Configuration
```typescript
{
  id: string                    // UUID
  type: ActivityType            // Activity type enum value
  maxPerLesson?: number         // Max of this type per lesson (null = unlimited)
  category?: string             // Category for mutual exclusivity
  categoryMax?: number          // Max total of category per lesson
  displayName: string           // Human-readable name
  description?: string          // Activity description
}
```

---

## Activity Types

| Type | Display Name | Category | Limit | Description |
|------|--------------|----------|-------|-------------|
| `SOAP` | SOAP Method | STUDY | 1 total* | Scripture, Observation, Application, Prayer |
| `OIA` | OIA Method | STUDY | 1 total* | Observation, Interpretation, Application |
| `DBS` | Discovery Bible Study | STUDY | 1 total* | Group-based discovery method |
| `HEAR` | HEAR Method | STUDY | 1 total* | Highlight, Explain, Apply, Respond |
| `VIDEO` | Video | - | Unlimited | Video content activity |

**\* Study activities are mutually exclusive** - only ONE study activity (SOAP, OIA, DBS, or HEAR) can exist per lesson. VIDEO activities have no limit.

---

## Endpoints

### Program CRUD

#### Create Program
```http
POST /api/programs
```

**Authentication:** Required

**Request Body:**
```json
{
  "name": "30 Days of Romans",
  "description": "A journey through the book of Romans",
  "defaultActivity": "SOAP",
  "days": 30,
  "coverImageUrl": "https://example.com/cover.jpg"
}
```

**Request Schema:**
| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| name | string | Yes | - | Program name (1-200 chars) |
| description | string | No | - | Description (max 2000 chars) |
| defaultActivity | enum | No | SOAP | Default activity type (SOAP/OIA/DBS/HEAR) |
| days | number | No | 30 | Number of days (1-360) |
| coverImageUrl | string | No | - | Cover image URL |

**Success Response (200 OK):**
```json
{
  "success": true,
  "program": {
    "id": "program-uuid",
    "name": "30 Days of Romans",
    "description": "A journey through the book of Romans",
    "defaultActivity": "SOAP",
    "days": 30,
    "coverImageUrl": null,
    "creatorId": "user-uuid",
    "isActive": true,
    "createdAt": "2025-12-14T10:00:00.000Z",
    "updatedAt": "2025-12-14T10:00:00.000Z",
    "lessons": [
      {
        "id": "lesson-uuid",
        "studyProgramId": "program-uuid",
        "dayNumber": 1,
        "activities": [
          {
            "id": "activity-uuid",
            "lessonId": "lesson-uuid",
            "type": "SOAP",
            "status": "PENDING",
            "orderNumber": 1,
            "video": null
          }
        ]
      }
      // ... 30 lessons total
    ]
  }
}
```

**Notes:**
- Automatically creates `days` number of lessons
- Each lesson gets one default activity with the specified `defaultActivity` type

---

#### List User's Programs
```http
GET /api/programs
```

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "programs": [
    {
      "id": "program-uuid",
      "name": "30 Days of Romans",
      "description": "...",
      "defaultActivity": "SOAP",
      "days": 30,
      "coverImageUrl": "https://...",
      "creatorId": "user-uuid",
      "isActive": true,
      "createdAt": "2025-12-14T10:00:00.000Z",
      "updatedAt": "2025-12-14T10:00:00.000Z"
    }
  ]
}
```

**Notes:**
- Returns programs owned by authenticated user only
- Only returns active programs (`isActive: true`)
- Sorted by `updatedAt` descending (most recent first)

---

#### Get Program Details
```http
GET /api/programs/:id
```

**Authentication:** Required

**URL Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Program UUID |

**Success Response (200 OK):**
```json
{
  "success": true,
  "program": {
    "id": "program-uuid",
    "name": "30 Days of Romans",
    "lessons": [
      {
        "id": "lesson-uuid",
        "dayNumber": 1,
        "activities": [
          {
            "id": "activity-uuid",
            "type": "SOAP",
            "status": "COMPLETE",
            "passageReference": "Romans 1:1-7",
            "bookNumber": 45,
            "video": null
          },
          {
            "id": "activity-uuid-2",
            "type": "VIDEO",
            "status": "COMPLETE",
            "videoId": "video-uuid",
            "video": {
              "id": "video-uuid",
              "title": "Introduction to Romans",
              "playbackUrl": "https://...",
              "thumbnailUrl": "https://...",
              "duration": 180,
              "status": "ready"
            }
          }
        ]
      }
    ]
  }
}
```

---

#### Update Program
```http
PATCH /api/programs/:id
```

**Authentication:** Required

**Request Body:**
```json
{
  "name": "Updated Name",
  "description": "Updated description",
  "days": 45,
  "coverImageUrl": null
}
```

**Request Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | No | Updated name (1-200 chars) |
| description | string | No | Updated description |
| days | number | No | New day count (creates/removes lessons) |
| coverImageUrl | string\|null | No | Updated cover image (null to remove) |

**Notes:**
- If `days` increases: new lessons are created with default activities
- If `days` decreases: lessons from the end are deleted (with their activities)

---

#### Delete Program (Soft Delete)
```http
DELETE /api/programs/:id
```

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true
}
```

**Notes:**
- Sets `isActive: false` (soft delete)
- Program and lessons retained in database
- Does not appear in program lists

---

#### Reorder Lessons
```http
POST /api/programs/:id/reorder-lessons
```

**Authentication:** Required

**Request Body:**
```json
{
  "lessonOrder": ["lesson-uuid-3", "lesson-uuid-1", "lesson-uuid-2"]
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "program": { ... }
}
```

**Notes:**
- Reorders `dayNumber` values based on array order
- Must include all lesson IDs in the program
- First item becomes day 1, second becomes day 2, etc.

---

### Lesson Operations

#### Delete Lesson
```http
DELETE /api/programs/:programId/lessons/:lessonId
```

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true
}
```

**Notes:**
- Deletes lesson and all its activities
- Remaining lessons are reordered
- Program `days` count is decremented
- Cannot delete the last lesson

---

### Activity Operations

#### Create Activity
```http
POST /api/programs/:programId/lessons/:lessonId/activities
```

**Authentication:** Required

**Request Body (Study Activity):**
```json
{
  "type": "SOAP"
}
```

**Request Body (Video Activity - with video):**
```json
{
  "type": "VIDEO",
  "videoId": "video-uuid"
}
```

**Request Body (Video Activity - placeholder):**
```json
{
  "type": "VIDEO"
}
```

**Request Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | enum | No | Activity type (default: SOAP) |
| videoId | string | No | Video UUID (optional for VIDEO type) |

**Success Response (200 OK) - VIDEO with video:**
```json
{
  "success": true,
  "activity": {
    "id": "activity-uuid",
    "lessonId": "lesson-uuid",
    "type": "VIDEO",
    "status": "COMPLETE",
    "orderNumber": 2,
    "videoId": "video-uuid",
    "video": {
      "id": "video-uuid",
      "title": "My Video",
      "playbackUrl": "https://...",
      "thumbnailUrl": "https://...",
      "duration": 180,
      "status": "ready"
    }
  }
}
```

**Success Response (200 OK) - VIDEO placeholder:**
```json
{
  "success": true,
  "activity": {
    "id": "activity-uuid",
    "lessonId": "lesson-uuid",
    "type": "VIDEO",
    "status": "PENDING",
    "orderNumber": 2,
    "videoId": null,
    "video": null
  }
}
```

**Error Responses:**

400 Bad Request - Study limit exceeded:
```json
{
  "success": false,
  "error": "Maximum 1 study method activity allowed per lesson (SOAP, OIA, DBS, or HEAR)",
  "details": {
    "allowed": false,
    "categoryCount": 1,
    "categoryMax": 1
  }
}
```

404 Not Found - Video not accessible:
```json
{
  "success": false,
  "error": "Video not found or not accessible"
}
```

**Notes:**
- **Study activities (SOAP/OIA/DBS/HEAR)**: Only ONE total per lesson (mutually exclusive)
- **VIDEO activities**: Unlimited per lesson
- VIDEO activities start as **PENDING** if no videoId provided
- VIDEO activities are **COMPLETE** if videoId provided at creation
- Video must belong to authenticated user (if provided)
- User can update activity later via PATCH to add videoId

---

#### Update Activity
```http
PATCH /api/activities/:id
```

**Authentication:** Required

**Request Body (Update Passage):**
```json
{
  "passageReference": "Romans 1:1-7",
  "bookNumber": 45,
  "bookName": "Romans",
  "chapterStart": 1,
  "verseStart": 1,
  "verseEnd": 7,
  "highlightMode": "VERSE",
  "selectedVerses": ["45-1-1", "45-1-3", "45-1-5"]
}
```

**Request Body (Update Video):**
```json
{
  "videoId": "video-uuid",
  "videoUrl": "https://customer-xyz.cloudflarestream.com/video-uid/manifest/video.m3u8"
}
```

**Request Body (Change Type):**
```json
{
  "type": "VIDEO",
  "videoId": "video-uuid",
  "videoUrl": "https://customer-xyz.cloudflarestream.com/video-uid/manifest/video.m3u8"
}
```

**Request Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| passageReference | string\|null | No | Human-readable passage |
| bookNumber | number\|null | No | Book number (1-66) |
| bookName | string\|null | No | Book name |
| chapterStart | number\|null | No | Starting chapter |
| chapterEnd | number\|null | No | Ending chapter |
| verseStart | number\|null | No | Starting verse |
| verseEnd | number\|null | No | Ending verse |
| highlightMode | enum | No | HIGHLIGHT/CHAPTER/VERSE |
| startElementId | string\|null | No | Highlight start (word-level) |
| startOffset | number\|null | No | Character offset |
| endElementId | string\|null | No | Highlight end |
| endOffset | number\|null | No | Character offset |
| selectedVerses | string[]\|null | No | Selected verse IDs |
| videoId | string\|null | No | Video UUID |
| videoUrl | string\|null | No | Cloudflare Stream playback URL |
| type | enum | No | Activity type |
| status | enum | No | PENDING/COMPLETE |

**Notes:**
- Setting `passageReference` auto-completes the activity
- Setting `videoId` auto-completes the activity
- Changing type TO VIDEO clears all passage fields
- Changing type FROM VIDEO clears videoId and videoUrl
- Type change validates limits (same rules as create)

---

#### Delete Activity
```http
DELETE /api/activities/:id
```

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true
}
```

**Error Response (Cannot delete last activity):**
```json
{
  "success": false,
  "error": "Cannot delete the last activity in a lesson"
}
```

**Notes:**
- Cannot delete the last activity in a lesson
- Remaining activities are reordered

---

#### Reset Activity
```http
POST /api/activities/:id/reset
```

**Authentication:** Required

**Purpose:** Reset activity to initial state (clear all data).

**Success Response (200 OK):**
```json
{
  "success": true,
  "activity": {
    "id": "activity-uuid",
    "type": "SOAP",
    "status": "PENDING",
    "passageReference": null,
    "videoId": null,
    "video": null
  }
}
```

**Notes:**
- Clears passage reference and all highlight data
- Clears videoId
- Resets status to PENDING
- Keeps type and orderNumber

---

### Activity Type Configuration

#### Get Activity Types
```http
GET /api/activity-types
```

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "activityTypes": [
    {
      "id": "config-uuid",
      "type": "SOAP",
      "maxPerLesson": null,
      "category": "STUDY",
      "categoryMax": 1,
      "displayName": "SOAP Method",
      "description": "Scripture, Observation, Application, Prayer"
    },
    {
      "id": "config-uuid",
      "type": "VIDEO",
      "maxPerLesson": null,
      "category": null,
      "categoryMax": null,
      "displayName": "Video",
      "description": "Video content activity"
    }
  ]
}
```

---

#### Get Lesson Activity Capacity
```http
GET /api/programs/:programId/lessons/:lessonId/activity-capacity
```

**Authentication:** Required

**Purpose:** Get remaining capacity for each activity type in a lesson. Useful for UI to show what can still be added.

**Success Response (200 OK):**
```json
{
  "success": true,
  "capacity": {
    "SOAP": {
      "type": "SOAP",
      "displayName": "SOAP Method",
      "currentCount": 1,
      "maxPerLesson": null,
      "remaining": 0,
      "categoryBlocked": false
    },
    "OIA": {
      "type": "OIA",
      "displayName": "OIA Method",
      "currentCount": 0,
      "maxPerLesson": null,
      "remaining": 0,
      "categoryBlocked": true
    },
    "VIDEO": {
      "type": "VIDEO",
      "displayName": "Video",
      "currentCount": 2,
      "maxPerLesson": null,
      "remaining": null,
      "categoryBlocked": false
    }
  }
}
```

**Response Fields:**
| Field | Type | Description |
|-------|------|-------------|
| currentCount | number | Activities of this type in lesson |
| maxPerLesson | number\|null | Type-specific limit (null = unlimited) |
| remaining | number\|null | How many more can be added (null = unlimited) |
| categoryBlocked | boolean | True if another type in same category exists |

**Notes:**
- `categoryBlocked: true` means another study type exists, so this one cannot be added
- `remaining: null` means unlimited
- `remaining: 0` means limit reached

---

### Cover Image Upload

#### Upload Cover Image
```http
POST /api/programs/:id/cover-image
```

**Authentication:** Required

**Request Body:**
```json
{
  "imageData": "data:image/jpeg;base64,/9j/4AAQ...",
  "contentType": "image/jpeg"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "coverImageUrl": "https://r2-public-url/program-images/program-uuid-timestamp.jpeg",
  "program": { ... }
}
```

**Notes:**
- Creates three image variants: original (1200px), medium (400px), thumbnail (150px)
- iOS app can derive variant URLs by appending `-md` or `-thumb` before extension
- Images stored in Cloudflare R2
