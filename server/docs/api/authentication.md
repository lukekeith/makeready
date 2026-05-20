# Authentication API

The MakeReady API supports **two independent authentication systems**:

1. **User Authentication** (Google OAuth) - For organization owners and administrators
2. **Member Authentication** (Phone Verification) - For organization members accessing their own data

Both authentication systems use session-based cookies and can coexist in the same session.

---

## User Authentication (Google OAuth)

Google OAuth 2.0 for organization owners and administrators. The authentication flow differs between web and iOS platforms.

### Web Flow
1. Client redirects to `/auth/google`
2. User authenticates with Google
3. Server redirects to `/auth/google/callback`
4. Server sets session cookie and redirects to `${CLIENT_URL}/home`
5. Browser automatically includes session cookie in subsequent requests

### iOS Flow
1. iOS app opens `/auth/google?platform=ios`
2. User authenticates with Google
3. Server redirects to `/auth/google/callback`
4. Server generates one-time auth code and redirects to `makeready://auth/callback?code=xxx`
5. iOS app exchanges code at `/auth/exchange`
6. Server returns signed session cookie
7. iOS app includes cookie in all authenticated requests

---

## Member Authentication (Phone Verification)

Phone-based authentication for organization members. Members can access their own profile and groups after verifying their phone number.

### Member Authentication Flow
1. Member requests verification code: `POST /api/members/verify-phone` (with `organizationId` for branded SMS)
2. Member receives SMS with 6-digit code (shows org name if `organizationId` provided)
3. Member confirms code: `POST /api/members/confirm-verification`
4. Server creates member session (stores `memberId` in session)
5. Member can access their own resources using session cookie
6. Member can logout: `POST /api/members/logout`

**Org-branded SMS:** When `organizationId` is included in the verification request, the SMS will display the organization's name (e.g., "Your Acme Church verification code is: 123456") instead of "MakeReady".

### Member Session Details
- **Session Cookie**: Same `connect.sid` cookie as User authentication
- **Session Data**: Both `userId` (from Google OAuth) and `memberId` (from phone verification) can exist in same session
- **Expiration**: 24 hours (same as User sessions)
- **Scope**: Members can only access their own resources (profile, groups)

---

## Session Configuration

- **Session Cookie Name**: `connect.sid`
- **Cookie Security**: HttpOnly, Secure (in production)
- **Session Expiration**: Configured via express-session
- **Session Secret**: Set via `SESSION_SECRET` environment variable

---

## Endpoints

### Initiate Google OAuth
```http
GET /auth/google
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| platform | string | No | Set to `ios` for iOS flow, omit for web |

**Example (Web):**
```bash
curl http://localhost:3001/auth/google
```

**Example (iOS):**
```bash
curl http://localhost:3001/auth/google?platform=ios
```

**Response:** Redirects to Google OAuth consent screen

---

### OAuth Callback
```http
GET /auth/google/callback
```

Handles OAuth callback from Google. Not called directly by clients.

**Response:**
- Web: Redirects to `${CLIENT_URL}/home` with session cookie
- iOS: Redirects to `makeready://auth/callback?code={authCode}`

---

### Exchange Auth Code (iOS Only)
```http
POST /auth/exchange
```

Exchange one-time authorization code for session cookie.

**Request Body:**
```json
{
  "code": "abc123xyz789"
}
```

**Request Schema:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| code | string | Yes | One-time auth code from callback URL |

**Success Response (200 OK):**
```json
{
  "sessionId": "s:abc123...",
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Responses:**

400 Bad Request - Missing code:
```json
{
  "error": "Code required"
}
```

401 Unauthorized - Invalid or expired code:
```json
{
  "error": "Invalid or expired code"
}
```

**Notes:**
- Auth codes expire after 5 minutes
- Auth codes are single-use only
- Store `sessionId` as `connect.sid` cookie for subsequent requests

---

### Get Current User
```http
GET /auth/me
```

**Authentication:** Required (session cookie)

**Success Response (200 OK):**
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "googleId": "123456789",
    "email": "user@example.com",
    "name": "John Doe",
    "picture": "https://lh3.googleusercontent.com/...",
    "phoneNumber": "+12025551234",
    "phoneVerified": true,
    "organizationId": "org-uuid",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:30:00.000Z"
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": "Not authenticated"
}
```

**Example:**
```bash
curl -X GET http://localhost:3001/auth/me \
  -H "Cookie: connect.sid=s:abc123..."
```

---

### Logout
```http
POST /auth/logout
```

**Authentication:** Required (session cookie)

**Success Response (200 OK):**
```json
{
  "message": "Logged out successfully"
}
```

**Error Response (500 Internal Server Error):**
```json
{
  "error": "Logout failed"
}
```

**Example:**
```bash
curl -X POST http://localhost:3001/auth/logout \
  -H "Cookie: connect.sid=s:abc123..."
```
