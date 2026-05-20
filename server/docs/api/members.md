# Members API

Members represent individuals within an organization who can join groups and receive communications. Members are identified by their phone number and can belong to multiple organizations.

---

## Data Model

```typescript
{
  id: string                    // UUID
  phoneNumber: string           // E.164 format (e.g., +12025551234)
  phoneVerified: boolean        // Phone verification status
  firstName?: string            // Optional first name
  lastName?: string             // Optional last name
  email?: string                // Optional email
  birthday?: string             // ISO 8601 datetime
  profilePicture?: string       // URL to profile image
  isActive: boolean             // Soft delete flag
  lastVerifiedAt?: string       // ISO 8601 datetime
  createdAt: string             // ISO 8601 datetime
  updatedAt: string             // ISO 8601 datetime
  organizations: Array<{        // Member can belong to multiple organizations
    organizationId: string      // Organization UUID
    joinedAt: string            // ISO 8601 datetime
    organization: {
      id: string
      name: string
      ownerId: string
    }
  }>
}
```

---

## Phone Verification Flow

1. Call `/api/members/verify-phone` with `organizationId` to send verification code
2. User receives SMS with 6-digit code (branded with organization name if `organizationId` provided)
3. Call `/api/members/confirm-verification` with code to verify phone
4. Member is created or updated with verified status
5. Session cookie is set for authenticated access

**Note:** When `organizationId` is provided, the SMS will display the organization's name (e.g., "Your Acme Church verification code is: 123456") instead of the default "MakeReady".

---

## Endpoints

### Initiate Phone Verification
```http
POST /api/members/verify-phone
```

**Authentication:** Public (no auth required)

**Purpose:** Send SMS verification code to phone number. Checks if member already exists.

**Request Body:**
```json
{
  "phoneNumber": "+12025551234",
  "organizationId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Request Schema:**
| Field | Type | Required | Format | Description |
|-------|------|----------|--------|-------------|
| phoneNumber | string | Yes | E.164 | Phone number with country code |
| organizationId | string | No | UUID | Organization ID for branded SMS and new member creation |

**Success Response (200 OK):**
```json
{
  "success": true,
  "memberExists": true,
  "memberId": "member-uuid-here",
  "organizations": ["org-uuid-1", "org-uuid-2"],
  "message": "Verification code sent"
}
```

**Error Responses:**

400 Bad Request - Invalid phone format:
```json
{
  "success": false,
  "error": "Phone number must be in E.164 format"
}
```

**Notes:**
- Phone number must be in E.164 format: `+{country_code}{number}`
- SMS code expires after 10 minutes (Twilio default)
- Rate limiting applies (see [Errors & Rate Limiting](./errors.md))
- **Org-branded SMS:** When `organizationId` is provided, the verification SMS will display the organization's name (e.g., "Your Acme Church verification code is: 123456") instead of "MakeReady"

---

### Confirm Phone Verification
```http
POST /api/members/confirm-verification
```

**Authentication:** Public (no auth required)

**Purpose:** Verify SMS code and create/update member. Creates member session upon successful verification.

**Request Body:**
```json
{
  "phoneNumber": "+12025551234",
  "code": "123456",
  "organizationId": "550e8400-e29b-41d4-a716-446655440000",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "birthday": "1990-01-15T00:00:00.000Z"
}
```

**Request Schema:**
| Field | Type | Required | Format | Description |
|-------|------|----------|--------|-------------|
| phoneNumber | string | Yes | E.164 | Phone number to verify |
| code | string | Yes | 6 digits | Verification code from SMS |
| organizationId | string | Yes | UUID | Organization to join (also used for org-branded verification) |
| firstName | string | No | - | Member's first name |
| lastName | string | No | - | Member's last name |
| email | string | No | email | Member's email address |
| birthday | string | No | ISO 8601 | Member's birthday |

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "member-uuid",
    "phoneNumber": "+12025551234",
    "phoneVerified": true,
    "firstName": "John",
    "lastName": "Doe",
    "organizations": [...]
  },
  "message": "Phone verified successfully"
}
```

**Error Responses:**

400 Bad Request - Invalid code:
```json
{
  "success": false,
  "error": "Invalid verification code"
}
```

**Notes:**
- Session cookie is set upon successful verification
- Member can now access their own resources

---

### Get Current Member Profile
```http
GET /api/members/me
```

**Authentication:** Member authentication required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "member-uuid",
    "phoneNumber": "+12025551234",
    "phoneVerified": true,
    "firstName": "John",
    "lastName": "Doe",
    "organizations": [...]
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "success": false,
  "error": "Member not authenticated"
}
```

---

### Check Member Session
```http
GET /api/members/session
```

**Authentication:** Public (checks if member session exists)

**Success Response - Authenticated:**
```json
{
  "success": true,
  "authenticated": true,
  "member": { ... },
  "authenticatedAt": "2024-01-15T10:30:00.000Z"
}
```

**Success Response - Not Authenticated:**
```json
{
  "success": true,
  "authenticated": false,
  "member": null
}
```

---

### Logout Member
```http
POST /api/members/logout
```

**Authentication:** Member authentication required

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

**Notes:**
- Clears `memberId` from session
- User authentication (Google OAuth) is not affected

---

### Get Member Profile
```http
GET /api/members/:memberId
```

**Authentication:** Required (User OR Member session)

**Authorization:**
- Organization owner can access any member in their organization
- Member can access their own profile only

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": { ... }
}
```

**Error Responses:**

403 Forbidden:
```json
{
  "success": false,
  "error": "You do not have permission to access this member"
}
```

---

### Update Member Profile
```http
PATCH /api/members/:memberId
```

**Authentication:** Required (User OR Member session)

**Authorization:**
- Organization owner can update any member in their organization
- Member can update their own profile only

**Request Body:**
```json
{
  "firstName": "Jane",
  "lastName": "Smith",
  "email": "jane@example.com",
  "birthday": "1992-05-20T00:00:00.000Z",
  "profilePicture": "https://example.com/new-profile.jpg"
}
```

**Notes:**
- All fields are optional
- Phone number cannot be updated (requires verification)

---

### Delete Member (Soft Delete)
```http
DELETE /api/members/:memberId
```

**Authentication:** Required

**Authorization:**
- Organization owner can delete any member in their organization
- Member can delete their own profile

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Member deleted successfully"
}
```

**Notes:**
- This is a soft delete (`isActive: false`)
- Member data retained in database

---

### Get Member Groups
```http
GET /api/members/:memberId/groups
```

**Authentication:** Required (User OR Member session)

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| includeInactive | string | No | false | Include inactive groups |

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "group-uuid",
      "name": "Basketball Team",
      "description": "Sunday morning basketball",
      "role": "member",
      "joinedAt": "2024-01-12T10:00:00.000Z"
    }
  ],
  "count": 1
}
```
