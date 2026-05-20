# Videos API

Video upload, management, and playback using Cloudflare Stream. Users upload videos directly to Cloudflare, then create records in the database.

---

## Data Model

```typescript
{
  id: string                    // UUID
  title?: string                // Optional video title
  description?: string          // Optional description
  cloudflareUid: string         // Cloudflare Stream video UID
  playbackUrl: string           // HLS playback URL
  thumbnailUrl?: string         // Auto-generated thumbnail URL
  duration?: number             // Duration in seconds
  status: string                // "pending" | "ready" | "error"
  userId: string                // User UUID (owner)
  isActive: boolean             // Soft delete flag
  createdAt: string             // ISO 8601 datetime
  updatedAt: string             // ISO 8601 datetime
}
```

---

## Video Status Values

| Status | Description |
|--------|-------------|
| `pending` | Video uploaded, processing in Cloudflare |
| `ready` | Video processed and ready for playback |
| `error` | Processing failed |

---

## Endpoints

### Generate Upload URL
```http
POST /api/videos/upload-url
```

**Authentication:** Required

**Purpose:** Generate a direct upload URL for client-side uploads to Cloudflare Stream.

**Request Body:**
```json
{
  "maxDurationSeconds": 300,
  "title": "Optional title"
}
```

**Request Schema:**
| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| maxDurationSeconds | number | No | 300 | Max video duration (1-600 seconds) |
| title | string | No | - | Optional video title (stored as metadata) |

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "uploadUrl": "https://upload.cloudflarestream.com/tus/...",
    "uid": "cloudflare-video-uid"
  }
}
```

**Notes:**
- Upload URL expires after ~30 minutes
- Client uploads video directly to Cloudflare
- Save `uid` for creating database record

---

### Create Video Record
```http
POST /api/videos
```

**Authentication:** Required

**Purpose:** Create a video record after uploading to Cloudflare.

**Request Body:**
```json
{
  "cloudflareUid": "uid-from-upload-url",
  "title": "Video Title",
  "description": "Optional description"
}
```

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "video-uuid",
    "title": "Video Title",
    "cloudflareUid": "cloudflare-uid",
    "playbackUrl": "https://...",
    "status": "pending",
    "duration": null,
    "thumbnailUrl": null
  }
}
```

**Notes:**
- Status will be "pending" until Cloudflare finishes processing
- Use `POST /api/videos/:id/refresh` to check processing status

---

### Get User's Videos (Library)
```http
GET /api/videos/me
```

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "video-uuid",
      "title": "My Video",
      "playbackUrl": "https://...",
      "thumbnailUrl": "https://...",
      "duration": 180,
      "status": "ready"
    }
  ],
  "count": 1
}
```

**Notes:**
- Returns active videos only
- Sorted by creation date (newest first)

---

### Get Video by ID
```http
GET /api/videos/:videoId
```

**Authentication:** Required (owner only)

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": { ... }
}
```

---

### Update Video Metadata
```http
PATCH /api/videos/:videoId
```

**Authentication:** Required (owner only)

**Request Body:**
```json
{
  "title": "New Title",
  "description": "New description"
}
```

---

### Refresh Video Status
```http
POST /api/videos/:videoId/refresh
```

**Authentication:** Required (owner only)

**Purpose:** Fetch latest video status from Cloudflare. Call to check if processing is complete.

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "video-uuid",
    "status": "ready",
    "thumbnailUrl": "https://...",
    "duration": 180
  }
}
```

**Notes:**
- Poll while `status` is "pending"
- Recommended polling interval: 3-5 seconds

---

### Delete Video
```http
DELETE /api/videos/:videoId
```

**Authentication:** Required (owner only)

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Video deleted successfully"
}
```

**Notes:**
- Deletes from both Cloudflare and database

---

## Video Upload Flow

```
1. Client calls POST /api/videos/upload-url
2. Client uploads video directly to Cloudflare using uploadUrl
3. Client calls POST /api/videos with cloudflareUid
4. Client polls POST /api/videos/:id/refresh until status === "ready"
5. Client plays video using playbackUrl (HLS format)
```

```
Client                      Server                      Cloudflare
  |                           |                            |
  |-- POST /upload-url ------>|                            |
  |<-- { uploadUrl, uid } ----|                            |
  |                           |                            |
  |-- POST video to uploadUrl --------------------------->|
  |<-- 200 OK -------------------------------------------|
  |                           |                            |
  |-- POST /videos { uid } -->|                            |
  |<-- { video, status:pending }                           |
  |                           |                            |
  |-- POST /refresh --------->|-- GET video status ------>|
  |<-- { status: pending } ---|<-- { processing } --------|
  |                           |                            |
  |  ... poll every 3 seconds ...                          |
  |                           |                            |
  |-- POST /refresh --------->|-- GET video status ------>|
  |<-- { status: ready } -----|<-- { ready, thumbnail } --|
```
