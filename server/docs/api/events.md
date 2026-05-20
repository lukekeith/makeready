# Events API

Comprehensive event management for groups with support for recurrence, attendees, attachments, and location.

**Source:** `src/routes/events.ts`

---

## Models

### Event

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| code | String | 6-character alphanumeric code (unique) |
| groupId | UUID | Parent group |
| type | EventType | LESSON, MEETING, ONLINE, DEADLINE, SOCIAL, OTHER |
| title | String | Event title (required) |
| description | String | Event description |
| date | DateTime | Event date |
| startTime | String | Start time "HH:mm" |
| endTime | String | End time "HH:mm" |
| isAllDay | Boolean | All-day event flag |
| timezone | String | Timezone (e.g., "America/Chicago") |
| coverImageUrl | String | Cloudflare R2 storage URL |
| externalUrl | String | External link (Zoom, website) |
| visibility | EventVisibility | PRIVATE or PUBLIC |
| locationName | String | Location name |
| locationAddress | String | Full address |
| locationLat | Decimal | Latitude |
| locationLng | Decimal | Longitude |
| googlePlaceId | String | Google Places ID |
| recurrenceFrequency | RecurrenceFrequency | NONE, DAILY, WEEKLY, BIWEEKLY, MONTHLY, YEARLY |
| recurrenceEndDate | DateTime | When recurrence stops |
| recurrenceCount | Int | Stop after N occurrences |
| recurrenceGroupId | UUID | Links recurring instances |
| isRecurrenceParent | Boolean | True for template event |
| alertMinutesBefore | Int | Alert timing (5, 10, 30, 60, 120, 1440, 2880, 10080) |
| createdById | UUID | User who created |
| isActive | Boolean | Soft delete flag |
| createdAt | DateTime | Creation timestamp |
| updatedAt | DateTime | Last update timestamp |

### EventAttendee

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| eventId | UUID | Parent event |
| groupMemberId | UUID | For private events (link to GroupMember) |
| phoneNumber | String | For public events |
| firstName | String | For public events |
| lastName | String | For public events |
| gender | String | For public events |
| birthdate | DateTime | For public events |
| rsvpStatus | RsvpStatus | GOING, MAYBE, NOT_GOING, PENDING |
| rsvpAt | DateTime | When they responded |
| checkedIn | Boolean | Check-in status |
| checkedInAt | DateTime | Check-in timestamp |

### EventAttachment

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| eventId | UUID | Parent event |
| url | String | Cloudflare R2 storage URL |
| fileName | String | Original filename |
| fileType | String | MIME type |
| fileSize | Int | Size in bytes |
| uploadedById | UUID | User who uploaded |

---

## Endpoints

### Event CRUD

#### Create Event

```
POST /api/groups/:groupId/events
```

**Auth:** User (must be group owner)

**Request:**
```json
{
  "type": "MEETING",
  "title": "Weekly Standup",
  "description": "Team sync meeting",
  "date": "2025-01-15T10:00:00Z",
  "startTime": "10:00",
  "endTime": "11:00",
  "isAllDay": false,
  "timezone": "America/Chicago",
  "visibility": "PRIVATE",
  "locationName": "Conference Room A",
  "locationAddress": "123 Main St, Dallas, TX 75201",
  "locationLat": 32.7767,
  "locationLng": -96.7970,
  "googlePlaceId": "ChIJN1t_tDeuEmsR...",
  "recurrenceFrequency": "WEEKLY",
  "recurrenceEndDate": "2025-06-15T10:00:00Z",
  "alertMinutesBefore": 30
}
```

**Response (201):**
```json
{
  "success": true,
  "event": { ... },
  "recurrence": {
    "count": 22,
    "recurrenceGroupId": "uuid"
  }
}
```

---

#### List Group Events

```
GET /api/groups/:groupId/events
```

**Auth:** User (must be group owner)

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| startDate | ISO DateTime | Filter events starting from |
| endDate | ISO DateTime | Filter events ending before |
| type | EventType | Filter by event type |
| limit | Int | Max results (default 50) |
| cursor | UUID | Cursor for pagination |

**Response:**
```json
{
  "success": true,
  "events": [...],
  "pagination": {
    "hasMore": true,
    "nextCursor": "uuid"
  }
}
```

---

#### Get Event by ID

```
GET /api/events/:id
```

**Auth:** User (must own event's group)

---

#### Get Public Event by Code

```
GET /api/events/code/:code
```

**Auth:** None (public)

**Note:** Only returns PUBLIC visibility events.

---

#### Update Event

```
PATCH /api/events/:id
```

**Auth:** User (must own event's group)

**Request:** Partial update with any event fields.

---

#### Delete Event

```
DELETE /api/events/:id
```

**Auth:** User (must own event's group)

**Note:** Soft delete (sets isActive = false).

---

### Recurrence

#### Update Series

```
PATCH /api/events/:id/update-series?scope=future
```

**Auth:** User (must own event's group)

**Query Parameters:**
| Parameter | Values | Description |
|-----------|--------|-------------|
| scope | this, future, all | Which events to update |

**Request:** Partial update with event fields.

---

#### Delete Series

```
DELETE /api/events/:id/delete-series?scope=all
```

**Auth:** User (must own event's group)

**Query Parameters:**
| Parameter | Values | Description |
|-----------|--------|-------------|
| scope | this, future, all | Which events to delete |

---

### Cover Image

#### Upload Cover Image

```
POST /api/events/:id/cover-image
```

**Auth:** User (must own event's group)

**Request:**
```json
{
  "imageData": "base64-encoded-image",
  "contentType": "image/jpeg"
}
```

**Response:**
```json
{
  "success": true,
  "coverImageUrl": "https://..."
}
```

**Note:** Generates 3 variants (original, -md, -thumb) stored in `event-covers` bucket.

---

### Attachments

#### Upload Attachment

```
POST /api/events/:id/attachments
```

**Auth:** User (must own event's group)

**Request:**
```json
{
  "fileData": "base64-encoded-file",
  "fileName": "menu.pdf",
  "fileType": "application/pdf"
}
```

**Allowed Types:** JPEG, PNG, GIF, WebP, PDF

**Max Size:** 5MB

---

#### Delete Attachment

```
DELETE /api/events/:id/attachments/:attachmentId
```

**Auth:** User (must own event's group)

---

### Attendees & RSVP

#### List Attendees

```
GET /api/events/:id/attendees
```

**Auth:** User (must own event's group)

**Response:**
```json
{
  "success": true,
  "attendees": [...],
  "stats": {
    "going": 15,
    "maybe": 5,
    "notGoing": 2,
    "pending": 10
  }
}
```

---

#### Invite Group Members

```
POST /api/events/:id/invite
```

**Auth:** User (must own event's group)

**Request:**
```json
{
  "memberIds": ["uuid1", "uuid2"],
  "inviteAll": false
}
```

**Note:** Use `inviteAll: true` to invite all group members.

---

#### RSVP (Private Event)

```
POST /api/events/:id/rsvp
```

**Auth:** Member (must be group member)

**Request:**
```json
{
  "rsvpStatus": "GOING"
}
```

---

#### RSVP (Public Event)

```
POST /api/events/code/:code/rsvp
```

**Auth:** None (public)

**Request:**
```json
{
  "phoneNumber": "+12145551234",
  "firstName": "John",
  "lastName": "Doe",
  "gender": "male",
  "birthdate": "1990-01-15T00:00:00Z",
  "rsvpStatus": "GOING"
}
```

---

#### Update Attendee

```
PATCH /api/events/:id/attendees/:attendeeId
```

**Auth:** User (must own event's group)

**Request:**
```json
{
  "rsvpStatus": "GOING",
  "checkedIn": true
}
```

---

#### Remove Attendee

```
DELETE /api/events/:id/attendees/:attendeeId
```

**Auth:** User (must own event's group)

---

## Location Integration

Events support Google Places integration for location autocomplete:

1. **Client-side:** iOS/Web calls Google Places Autocomplete API
2. **User selects:** Place from suggestions
3. **Client fetches:** Place Details (address, coordinates)
4. **Client sends:** Structured data to server

```json
{
  "locationName": "Starbucks - Richardson",
  "locationAddress": "123 Main St, Richardson, TX 75080",
  "locationLat": 32.9483,
  "locationLng": -96.7299,
  "googlePlaceId": "ChIJN1t_tDeuEmsRUsoyG83frY4"
}
```

---

## Recurrence Logic

### Generation Limits

| Frequency | Max Instances |
|-----------|--------------|
| DAILY | 90 days |
| WEEKLY | 52 weeks |
| BIWEEKLY | 52 instances |
| MONTHLY | 24 months |
| YEARLY | 5 years |

### How It Works

1. Parent event is created with `isRecurrenceParent: true`
2. Child events are generated with same `recurrenceGroupId`
3. Each instance gets its own `id` and `code`
4. Editing options: this, future, or all events

---

## Alert Timing

Store as `alertMinutesBefore`:

| Display | Value |
|---------|-------|
| 5 minutes before | 5 |
| 10 minutes before | 10 |
| 30 minutes before | 30 |
| 1 hour before | 60 |
| 2 hours before | 120 |
| 1 day before | 1440 |
| 2 days before | 2880 |
| 1 week before | 10080 |

**Note:** Notification infrastructure is not yet implemented. Currently stores preference only.
