# Groups API

Manage groups for organizing members into study cohorts.

## Group Model

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | UUID |
| `code` | string | **Unique 6-character alphanumeric code** for public joining (auto-generated) |
| `name` | string | Group name (1-200 chars) |
| `description` | string? | Optional description (max 2000 chars) |
| `coverImageUrl` | string? | URL to cover image |
| `isPrivate` | boolean | Whether group is private (default: false) |
| `allowInvites` | boolean | Whether invites are allowed (default: true) |
| `welcomeMessage` | string? | Custom welcome message (max 1000 chars) |
| `ageRange` | object? | `{ min?: number, max?: number }` age restrictions |
| `maxMembers` | number? | Maximum member count |
| `memberCount` | number | Current active member count |
| `creatorId` | string | UUID of the group creator |
| `createdAt` | datetime | ISO 8601 timestamp |
| `updatedAt` | datetime | ISO 8601 timestamp |

### Group Code

The `code` field is a **unique 6-character alphanumeric identifier** automatically generated when a group is created. It uses only unambiguous characters (A-Z, 2-9, excluding 0, 1, O, I, L) for easy sharing and entry.

**Example codes:** `ABC123`, `XY7K9M`, `P3QRST`

**Use cases:**
- Share code verbally or in print for members to join
- Generate QR codes that link to `/join/:code`
- Look up group via `GET /api/groups/code/:code`

---

## Endpoints

### POST /api/groups

Create a new group. A unique 6-character `code` is automatically generated.

**Auth:** Required (User)

**Request Body:**
```json
{
  "name": "Young Professionals",
  "description": "Weekly Bible study for young adults",
  "coverImageUrl": "https://example.com/cover.jpg",
  "isPrivate": false,
  "allowInvites": true,
  "welcomeMessage": "Welcome to our group!",
  "ageRange": { "min": 18, "max": 35 },
  "maxMembers": 50
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Group name (1-200 chars) |
| `description` | string | No | Description (max 2000 chars) |
| `coverImageUrl` | string | No | Valid URL to cover image |
| `isPrivate` | boolean | No | Default: false |
| `allowInvites` | boolean | No | Default: true |
| `welcomeMessage` | string | No | Max 1000 chars |
| `ageRange` | object | No | `{ min?: 0-120, max?: 0-120 }` |
| `maxMembers` | number | No | Minimum: 1 |

**Response (201):**
```json
{
  "success": true,
  "group": {
    "id": "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab",
    "code": "ABC123",
    "name": "Young Professionals",
    "description": "Weekly Bible study for young adults",
    "coverImageUrl": "https://example.com/cover.jpg",
    "isPrivate": false,
    "allowInvites": true,
    "welcomeMessage": "Welcome to our group!",
    "ageRange": { "min": 18, "max": 35 },
    "maxMembers": 50,
    "memberCount": 0,
    "creatorId": "57ed656d-acc0-4dcf-a9dd-c655f01e7b06",
    "createdAt": "2025-12-28T00:00:00.000Z",
    "updatedAt": "2025-12-28T00:00:00.000Z"
  }
}
```

---

### GET /api/groups

List all groups created by the authenticated user.

**Auth:** Required (User)

**Response (200):**
```json
{
  "success": true,
  "groups": [
    {
      "id": "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab",
      "code": "ABC123",
      "name": "Young Professionals",
      "description": "Weekly Bible study",
      "coverImageUrl": "https://...",
      "isPrivate": false,
      "allowInvites": true,
      "welcomeMessage": "Welcome!",
      "ageRange": { "min": 18, "max": 35 },
      "maxMembers": 50,
      "memberCount": 12,
      "creatorId": "57ed656d-acc0-4dcf-a9dd-c655f01e7b06",
      "createdAt": "2025-12-28T00:00:00.000Z",
      "updatedAt": "2025-12-28T00:00:00.000Z"
    }
  ]
}
```

---

### GET /api/groups/:id

Get a single group by ID.

**Auth:** Required (User, must be creator)

**Response (200):**
```json
{
  "success": true,
  "group": {
    "id": "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab",
    "code": "ABC123",
    "name": "Young Professionals",
    "description": "Weekly Bible study",
    "coverImageUrl": "https://...",
    "isPrivate": false,
    "allowInvites": true,
    "welcomeMessage": "Welcome!",
    "ageRange": { "min": 18, "max": 35 },
    "maxMembers": 50,
    "memberCount": 12,
    "creatorId": "57ed656d-acc0-4dcf-a9dd-c655f01e7b06",
    "createdAt": "2025-12-28T00:00:00.000Z",
    "updatedAt": "2025-12-28T00:00:00.000Z"
  }
}
```

**Errors:**
- `404`: Group not found or not owned by user

---

### GET /api/groups/:id/public

Get public group information (no authentication required).

**Auth:** None

**Response (200):**
```json
{
  "success": true,
  "group": {
    "id": "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab",
    "code": "ABC123",
    "name": "Young Professionals",
    "description": "Weekly Bible study",
    "coverImageUrl": "https://...",
    "isPrivate": false,
    "memberCount": 12,
    "createdAt": "2025-12-28T00:00:00.000Z"
  }
}
```

---

### GET /api/groups/:id/invite

Get invite information for a group including a QR code. Used by group leaders to share invite links.

**Auth:** Required (User, must be creator)

**Response (200):**
```json
{
  "success": true,
  "invite": {
    "groupId": "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab",
    "groupName": "Young Professionals",
    "code": "ABC123",
    "inviteUrl": "https://app.makeready.org/join/group/ABC123",
    "qrCode": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg..."
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `groupId` | string | Group UUID |
| `groupName` | string | Group name |
| `code` | string | 6-character group code |
| `inviteUrl` | string | Full invite URL for sharing |
| `qrCode` | string | Base64 data URL of QR code PNG (512x512) |

**Usage:**
- Display the QR code in the app for scanning
- Share the `inviteUrl` via text, email, or social media
- Display the `code` for manual entry

**Errors:**
- `404`: Group not found or not owned by user

---

### GET /api/groups/code/:code

Look up a group by its 6-character code. Used for the public join page.

**Auth:** None

**URL Parameters:**
| Parameter | Description |
|-----------|-------------|
| `code` | 6-character alphanumeric code (case-insensitive) |

**Example:** `GET /api/groups/code/ABC123`

**Response (200):**
```json
{
  "success": true,
  "group": {
    "id": "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab",
    "code": "ABC123",
    "name": "Young Professionals",
    "description": "Weekly Bible study",
    "coverImageUrl": "https://...",
    "isPrivate": false,
    "memberCount": 12,
    "creator": {
      "id": "57ed656d-acc0-4dcf-a9dd-c655f01e7b06",
      "name": "John Smith",
      "picture": "https://..."
    },
    "createdAt": "2025-12-28T00:00:00.000Z"
  }
}
```

**Errors:**
- `400`: Invalid group code format (must be 6 alphanumeric characters)
- `404`: Group not found

---

### PATCH /api/groups/:id

Update group metadata.

**Auth:** Required (User, must be creator)

**Request Body:** (all fields optional)
```json
{
  "name": "Updated Name",
  "description": "Updated description",
  "coverImageUrl": "https://new-cover.jpg",
  "isPrivate": true,
  "allowInvites": false,
  "welcomeMessage": "New welcome message",
  "ageRange": { "min": 21, "max": 40 },
  "maxMembers": 100
}
```

**Response (200):**
```json
{
  "success": true,
  "group": { ... }
}
```

**Notes:**
- Set fields to `null` to clear them
- The `code` field cannot be changed

---

### DELETE /api/groups/:id

Soft delete a group (sets `isActive = false`).

**Auth:** Required (User, must be creator)

**Response (200):**
```json
{
  "success": true,
  "message": "Group deleted successfully"
}
```

---

### POST /api/groups/:id/cover-image

Upload a cover image for a group. Images are resized to multiple variants.

**Auth:** Required (User, must be creator)

**Request Body:**
```json
{
  "imageData": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
  "contentType": "image/jpeg"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `imageData` | string | Yes | Base64 encoded image (with or without data URI prefix) |
| `contentType` | string | No | MIME type (default: `image/jpeg`) |

**Response (200):**
```json
{
  "success": true,
  "coverImageUrl": "https://r2-public-url/group-covers/group-xxx-123.jpeg"
}
```

**Image Variants Created:**
| Variant | Max Width | Quality |
|---------|-----------|---------|
| Original | 1200px | 85% |
| Medium (`-md`) | 400px | 80% |
| Thumbnail (`-thumb`) | 150px | 75% |

---

## Group Members

See [Members API](./members.md) for member-related endpoints:
- `GET /api/groups/:groupId/members` - List group members
- `POST /api/groups/:groupId/members` - Add member to group
- `DELETE /api/groups/:groupId/members/:memberId` - Remove member from group

---

## Group Join Requests

When members join a group via the 6-character group code (not via invite link), they must be approved by the group leader. This differs from invite links which grant immediate access.

### GroupJoinRequest Model

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | UUID |
| `groupId` | string | Group UUID |
| `memberId` | string | Member UUID |
| `status` | string | `pending`, `approved`, or `rejected` |
| `message` | string? | Optional message from requester (max 500 chars) |
| `reviewedById` | string? | User who approved/rejected |
| `reviewedAt` | datetime? | When request was reviewed |
| `createdAt` | datetime | ISO 8601 timestamp |
| `updatedAt` | datetime | ISO 8601 timestamp |

---

### POST /api/groups/:groupId/join-requests

Submit a join request for a group (via group code).

**Auth:** Member session required (phone verified)

**Request Body:**
```json
{
  "message": "Hi! I'd love to join your study group."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | string | No | Optional message (max 500 chars) |

**Response (201):**
```json
{
  "success": true,
  "request": {
    "id": "request-uuid",
    "groupId": "group-uuid",
    "status": "pending",
    "message": "Hi! I'd love to join...",
    "createdAt": "2025-01-03T00:00:00.000Z"
  }
}
```

**Errors:**
- `400`: Already a member of this group
- `400`: Request already pending
- `404`: Group not found

---

### GET /api/groups/:groupId/join-requests/me

Check the current member's request status for a group.

**Auth:** Member session required

**Response (200):**
```json
{
  "success": true,
  "request": {
    "id": "request-uuid",
    "status": "pending",
    "message": "Hi! I'd love to join...",
    "createdAt": "2025-01-03T00:00:00.000Z",
    "reviewedAt": null
  }
}
```

**Errors:**
- `404`: No join request found

---

### GET /api/groups/:groupId/join-requests

List join requests for a group (group leader only).

**Auth:** User session required (must be group creator)

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `status` | string | `pending` | Filter by status (`pending`, `approved`, `rejected`) |

**Response (200):**
```json
{
  "success": true,
  "requests": [
    {
      "id": "request-uuid",
      "status": "pending",
      "message": "Hi! I'd love to join...",
      "createdAt": "2025-01-03T00:00:00.000Z",
      "member": {
        "id": "member-uuid",
        "firstName": "John",
        "lastName": "Doe",
        "avatarUrl": "https://..."
      }
    }
  ],
  "count": 1
}
```

---

### POST /api/groups/:groupId/join-requests/:requestId/approve

Approve a join request (adds member to group).

**Auth:** User session required (must be group creator)

**Response (200):**
```json
{
  "success": true,
  "request": {
    "id": "request-uuid",
    "status": "approved",
    "reviewedAt": "2025-01-03T00:00:00.000Z"
  },
  "member": {
    "id": "member-uuid",
    "firstName": "John",
    "lastName": "Doe"
  }
}
```

**Side Effects:**
- Creates `GroupMember` record with `role: "member"`
- Updates request status to `approved`

**Errors:**
- `404`: Pending request not found

---

### POST /api/groups/:groupId/join-requests/:requestId/reject

Reject a join request.

**Auth:** User session required (must be group creator)

**Response (200):**
```json
{
  "success": true,
  "request": {
    "id": "request-uuid",
    "status": "rejected",
    "reviewedAt": "2025-01-03T00:00:00.000Z"
  }
}
```

**Errors:**
- `404`: Pending request not found
