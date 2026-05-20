# Organizations API

Organizations represent businesses, clubs, or other entities that manage members and groups. Each organization has a single owner (the authenticated user).

---

## Data Model

```typescript
{
  id: string              // UUID
  name: string            // Organization name
  ownerId: string         // User UUID (owner)
  isActive: boolean       // Soft delete flag
  createdAt: string       // ISO 8601 datetime
  updatedAt: string       // ISO 8601 datetime
}
```

---

## Endpoints

### Get Organization by ID
```http
GET /api/organizations/:organizationId
```

**Authentication:** Required (organization owner only)

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "org-uuid",
    "name": "Acme Sports Club",
    "ownerId": "user-uuid",
    "isActive": true,
    "createdAt": "2024-01-01T12:00:00.000Z",
    "updatedAt": "2024-01-01T12:00:00.000Z"
  }
}
```

**Error Responses:**

403 Forbidden - Not organization owner:
```json
{
  "success": false,
  "error": "You do not have permission to access this organization"
}
```

---

### Get My Organization
```http
GET /api/organizations/my/organization
```

**Authentication:** Required

**Purpose:** Get the organization owned by the currently authenticated user.

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "org-uuid",
    "name": "Acme Sports Club",
    "ownerId": "user-uuid",
    "isActive": true,
    "createdAt": "2024-01-01T12:00:00.000Z",
    "updatedAt": "2024-01-01T12:00:00.000Z"
  }
}
```

**Notes:**
- Returns the organization where `ownerId` matches the authenticated user
- Users can only own one organization

---

### Update Organization Name
```http
PATCH /api/organizations/:organizationId
```

**Authentication:** Required (organization owner only)

**Request Body:**
```json
{
  "name": "New Organization Name"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "org-uuid",
    "name": "New Organization Name",
    "updatedAt": "2024-01-15T10:30:00.000Z"
  }
}
```

---

### Get Organization Members
```http
GET /api/organizations/:organizationId/members
```

**Authentication:** Required (organization owner only)

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| search | string | No | - | Search by name, email, or phone |
| includeInactive | string | No | false | Include inactive members |

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "member-uuid",
      "phoneNumber": "+12025551234",
      "phoneVerified": true,
      "firstName": "John",
      "lastName": "Doe",
      "email": "john@example.com",
      "isActive": true
    }
  ],
  "count": 1
}
```

**Example - Search for members:**
```bash
curl "http://localhost:3001/api/organizations/org-uuid/members?search=john" \
  -H "Cookie: connect.sid=s:abc123..."
```

**Notes:**
- Search matches against first name, last name, email (case-insensitive), and phone (exact)
- Results ordered by creation date (newest first)
