# Groups API (iPhone Reference)

**Base URL (Local)**: http://localhost:3001
**Base URL (Production)**: https://makeready-production.up.railway.app

**Route files**: groups.ts, invites.ts, group-join-requests.ts, group-members.ts, join.ts

Last Updated: 2026-02-10

**NOTE**: This file was intended for /Users/lukekeith/www/makeready/iphone/.claude/docs/groups.md but was written here due to permissions. Copy it to the correct location:
```
cp server/.claude/docs/groups-iphone.md iphone/.claude/docs/groups.md
```

---

## Table of Contents

### Groups (groups.ts)
1. [POST /api/groups](#post-apigroups) - Create a new group
2. [GET /api/groups](#get-apigroups) - List user's groups
3. [GET /api/groups/code/:code](#get-apigroupscodecode) - Look up group by join code
4. [GET /api/groups/:id](#get-apigroupsid) - Get group by ID
5. [GET /api/groups/:id/invite](#get-apigroupsidinvite) - Get group invite info with QR code
6. [GET /api/groups/:id/public](#get-apigroupsidpublic) - Get public group info
7. [PATCH /api/groups/:id](#patch-apigroupsid) - Update group
8. [DELETE /api/groups/:id](#delete-apigroupsid) - Delete group
9. [POST /api/groups/:id/cover-image](#post-apigroupsidcover-image) - Upload group cover image

### Invites (invites.ts)
10. [POST /api/invites](#post-apiinvites) - Create a new invite
11. [POST /api/invites/send](#post-apiinvitessend) - Send group invitation via SMS
12. [GET /api/invites/:token](#get-apiinvitestoken) - Get invite details by token

### Join Requests (group-join-requests.ts)
13. [POST /api/groups/:groupId/join-requests](#post-apigroupsgroupidjoin-requests) - Submit a join request
14. [GET /api/groups/:groupId/join-requests/me](#get-apigroupsgroupidjoin-requestsme) - Check member's status for a group
15. [GET /api/groups/:groupId/join-requests](#get-apigroupsgroupidjoin-requests) - List join requests (leader)
16. [POST /api/groups/:groupId/join-requests/:requestId/approve](#post-apigroupsgroupidjoin-requestsrequestidapprove) - Approve a join request
17. [POST /api/groups/:groupId/join-requests/:requestId/reject](#post-apigroupsgroupidjoin-requestsrequestidreject) - Reject a join request

### Group Members (group-members.ts)
18. [GET /api/groups/:groupId/members](#get-apigroupsgroupidmembers) - List group members
19. [POST /api/groups/:groupId/members](#post-apigroupsgroupidmembers) - Add a member to a group
20. [DELETE /api/groups/:groupId/members/:memberId](#delete-apigroupsgroupidmembersmemberid) - Remove a member from a group

### Join Pages - HTML/OG Meta (join.ts)
21. [GET /join/group/:code](#get-joingroupcode) - OG meta page for group invite
22. [GET /join/group/:code/study/:studyCode](#get-joingroupcodestudystudycode) - OG meta page for scheduled lesson
23. [GET /join/study/:id](#get-joinstudyid) - OG meta page for study by ID or code
24. [GET /join/group/:code/event/:eventCode](#get-joingroupcodeeventeventcode) - OG meta page for event
25. [GET /join/:token](#get-jointoken) - OG meta page for direct invite token

---

## Authentication Types

This API uses two types of authentication:

- **User Session** (`requireAuth`): Google OAuth session. Used by group leaders/creators (the web dashboard user).
- **Member Session** (`requireMemberAuth`): Phone-verified member session. Used by group members (the iOS app user). Identified via `req.session.memberId`.

---

## Groups (groups.ts)

### POST /api/groups

Create a new group in the user's organization.

**Authentication**: User Session (requireAuth)

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | String | Yes | Group name (1-200 chars) |
| description | String | No | Group description (max 2000 chars) |
| coverImageUrl | String (URL) | No | Cover image URL |
| isPrivate | Boolean | No | Default: false |
| allowInvites | Boolean | No | Default: true |
| welcomeMessage | String | No | Welcome message (max 1000 chars) |
| ageRange | Object | No | `{ min: Int?, max: Int? }` (0-120) |
| maxMembers | Int | No | Minimum: 1 |

**Response** (200):

```json
{
  "success": true,
  "group": {
    "id": "uuid",
    "organizationId": "uuid",
    "code": "ABC123",
    "name": "Bible Study Group",
    "description": "Weekly study group",
    "coverImageUrl": null,
    "isPrivate": false,
    "allowInvites": true,
    "welcomeMessage": null,
    "ageRange": null,
    "maxMembers": null,
    "memberCount": 0,
    "creatorId": "uuid",
    "createdAt": "2026-02-10T12:00:00.000Z",
    "updatedAt": "2026-02-10T12:00:00.000Z"
  }
}
```

**Error Responses**: 400 (validation/no org), 401 (not authenticated), 500

**Swift Example**:

```swift
func createGroup(name: String, description: String? = nil, isPrivate: Bool = false) async throws -> Group {
    let body: [String: Any] = [
        "name": name,
        "description": description as Any,
        "isPrivate": isPrivate
    ].compactMapValues { $0 }

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GroupResponse.self, from: data)
    return response.group
}
```

---

### GET /api/groups

List all groups created by the authenticated user.

**Authentication**: User Session (requireAuth)

**Response** (200):

```json
{
  "success": true,
  "groups": [
    {
      "id": "uuid",
      "code": "ABC123",
      "name": "Bible Study Group",
      "description": "Weekly study group",
      "coverImageUrl": null,
      "isPrivate": false,
      "allowInvites": true,
      "welcomeMessage": null,
      "ageRange": null,
      "maxMembers": null,
      "memberCount": 12,
      "creatorId": "uuid",
      "createdAt": "2026-02-10T12:00:00.000Z",
      "updatedAt": "2026-02-10T12:00:00.000Z"
    }
  ]
}
```

**Error Responses**: 401, 500

**Swift Example**:

```swift
func listGroups() async throws -> [Group] {
    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups"))
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GroupsListResponse.self, from: data)
    return response.groups
}
```

---

### GET /api/groups/code/:code

Look up a group by its 6-character join code. Returns membership status if the caller has an active member session.

**Authentication**: None required (optional member session enhances response)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | String | 6-character alphanumeric group code (case-insensitive, normalized to uppercase) |

**Response** (200) - Unauthenticated:

```json
{
  "success": true,
  "group": {
    "id": "uuid",
    "code": "ABC123",
    "name": "Bible Study Group",
    "description": "Weekly study group",
    "coverImageUrl": null,
    "isPrivate": false,
    "memberCount": 12,
    "organizationId": "uuid",
    "creator": {
      "id": "uuid",
      "name": "John Doe",
      "picture": "https://..."
    },
    "createdAt": "2026-02-10T12:00:00.000Z"
  },
  "member": null,
  "membershipStatus": "none"
}
```

**Response** (200) - Authenticated member who is already a group member:

```json
{
  "success": true,
  "group": { "..." },
  "member": {
    "id": "uuid",
    "phoneNumber": "+12025551234",
    "firstName": "Jane",
    "lastName": "Smith"
  },
  "membershipStatus": "member",
  "membership": {
    "id": "uuid",
    "role": "member",
    "joinedAt": "2026-02-10T12:00:00.000Z",
    "groupName": "Bible Study Group"
  }
}
```

**Response** (200) - Authenticated member with pending join request:

```json
{
  "success": true,
  "group": { "..." },
  "member": { "..." },
  "membershipStatus": "pending",
  "request": {
    "id": "uuid",
    "status": "pending",
    "message": "I'd love to join!",
    "createdAt": "2026-02-10T12:00:00.000Z",
    "reviewedAt": null
  }
}
```

**membershipStatus values**: `"member"`, `"pending"`, `"approved"`, `"rejected"`, `"none"`

**Error Responses**: 400 (invalid code format), 404 (not found), 500

**Swift Example**:

```swift
func lookupGroupByCode(_ code: String) async throws -> GroupLookupResponse {
    let url = baseURL.appendingPathComponent("/api/groups/code/\(code)")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(GroupLookupResponse.self, from: data)
}
```

---

### GET /api/groups/:id

Get full details of a group by ID. User must be the group creator.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | Group UUID |

**Response** (200):

```json
{
  "success": true,
  "group": {
    "id": "uuid",
    "code": "ABC123",
    "name": "Bible Study Group",
    "description": "Weekly study group",
    "coverImageUrl": null,
    "isPrivate": false,
    "allowInvites": true,
    "welcomeMessage": "Welcome to our group!",
    "ageRange": { "min": 18, "max": 35 },
    "maxMembers": 50,
    "memberCount": 12,
    "creatorId": "uuid",
    "createdAt": "2026-02-10T12:00:00.000Z",
    "updatedAt": "2026-02-10T12:00:00.000Z"
  }
}
```

**Error Responses**: 401, 404, 500

**Swift Example**:

```swift
func getGroup(id: String) async throws -> Group {
    let url = baseURL.appendingPathComponent("/api/groups/\(id)")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GroupResponse.self, from: data)
    return response.group
}
```

---

### GET /api/groups/:id/invite

Get invite URL and QR code for a group. User must be the group creator.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | Group UUID |

**Response** (200):

```json
{
  "success": true,
  "invite": {
    "groupId": "uuid",
    "groupName": "Bible Study Group",
    "code": "ABC123",
    "inviteUrl": "https://app.makeready.org/join/group/ABC123",
    "qrCode": "data:image/png;base64,iVBOR..."
  }
}
```

**Error Responses**: 401, 404, 500

**Swift Example**:

```swift
func getGroupInvite(groupId: String) async throws -> GroupInvite {
    let url = baseURL.appendingPathComponent("/api/groups/\(groupId)/invite")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GroupInviteResponse.self, from: data)
    return response.invite
}
```

---

### GET /api/groups/:id/public

Get limited public information for a group. No authentication required.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | Group UUID |

**Response** (200):

```json
{
  "success": true,
  "group": {
    "id": "uuid",
    "code": "ABC123",
    "name": "Bible Study Group",
    "description": "Weekly study group",
    "coverImageUrl": null,
    "isPrivate": false,
    "memberCount": 12,
    "createdAt": "2026-02-10T12:00:00.000Z"
  }
}
```

**Error Responses**: 404, 500

**Swift Example**:

```swift
func getPublicGroupInfo(groupId: String) async throws -> PublicGroup {
    let url = baseURL.appendingPathComponent("/api/groups/\(groupId)/public")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(PublicGroupResponse.self, from: data)
    return response.group
}
```

---

### PATCH /api/groups/:id

Update group metadata. User must be the group creator. All fields are optional.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | Group UUID |

**Request Body** (all fields optional):

| Field | Type | Description |
|-------|------|-------------|
| name | String | Group name (1-200 chars) |
| description | String? | Nullable. Max 2000 chars |
| coverImageUrl | String? | Nullable URL |
| isPrivate | Boolean | Privacy setting |
| allowInvites | Boolean | Whether invites are allowed |
| welcomeMessage | String? | Nullable. Max 1000 chars |
| ageRange | Object? | Nullable. `{ min: Int?, max: Int? }` |
| maxMembers | Int? | Nullable. Minimum 1 |

**Response** (200): Same shape as create group response.

**Error Responses**: 400 (validation), 401, 404, 500

**Swift Example**:

```swift
func updateGroup(id: String, name: String? = nil, description: String? = nil) async throws -> Group {
    var body: [String: Any] = [:]
    if let name = name { body["name"] = name }
    if let description = description { body["description"] = description }

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups/\(id)"))
    request.httpMethod = "PATCH"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GroupResponse.self, from: data)
    return response.group
}
```

---

### DELETE /api/groups/:id

Soft-delete a group (sets `isActive = false`). User must be the group creator.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | Group UUID |

**Response** (200):

```json
{
  "success": true,
  "message": "Group deleted successfully"
}
```

**Error Responses**: 401, 404, 500

**Swift Example**:

```swift
func deleteGroup(id: String) async throws {
    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups/\(id)"))
    request.httpMethod = "DELETE"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(SuccessResponse.self, from: data)
    guard response.success else { throw APIError.deleteFailed }
}
```

---

### POST /api/groups/:id/cover-image

Upload a cover image for a group. Accepts base64-encoded image data. Automatically generates three sizes (original 1200px, medium 400px, thumbnail 150px) and uploads to Cloudflare R2.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | Group UUID |

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| imageData | String | Yes | Base64-encoded image data (with or without data URI prefix) |
| contentType | String | No | MIME type. Default: `"image/jpeg"` |

**Response** (200):

```json
{
  "success": true,
  "coverImageUrl": "https://images.makeready.org/group-covers/group-uuid-1707570000.jpeg"
}
```

**Error Responses**: 400 (validation), 401, 404, 500

**Swift Example**:

```swift
func uploadCoverImage(groupId: String, imageData: Data) async throws -> String {
    let base64String = imageData.base64EncodedString()
    let body: [String: Any] = [
        "imageData": base64String,
        "contentType": "image/jpeg"
    ]

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups/\(groupId)/cover-image"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(CoverImageResponse.self, from: data)
    return response.coverImageUrl
}
```

---

## Invites (invites.ts)

### POST /api/invites

Create a new invite token (for QR code generation). Optionally associate with a group.

**Authentication**: User Session (requireAuth)

**Request Body** (optional):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| groupId | String (UUID) | No | Group to associate the invite with |
| expiresAt | String (ISO 8601) | No | Expiration datetime |

**Response** (200):

```json
{
  "success": true,
  "invite": {
    "id": "uuid",
    "code": "ABC123XYZ9",
    "groupId": "uuid",
    "createdAt": "2026-02-10T12:00:00.000Z",
    "expiresAt": null,
    "userId": "uuid"
  }
}
```

**Note**: The response maps `token` to `code` and `inviterId` to `userId` for iPhone app compatibility.

**Error Responses**: 400 (validation), 401, 403 (not group creator), 404 (group not found), 500

**Swift Example**:

```swift
func createInvite(groupId: String? = nil, expiresAt: Date? = nil) async throws -> Invite {
    var body: [String: Any] = [:]
    if let groupId = groupId { body["groupId"] = groupId }
    if let expiresAt = expiresAt {
        body["expiresAt"] = ISO8601DateFormatter().string(from: expiresAt)
    }

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/invites"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(InviteResponse.self, from: data)
    return response.invite
}
```

---

### POST /api/invites/send

Send a group invitation via SMS to a phone number. Only the group creator can send invitations.

**Authentication**: User Session (requireAuth)

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| groupId | String (UUID) | Yes | Group to invite to |
| recipientPhone | String | Yes | Phone number in E.164 format (e.g., `+12025551234`) |

**Response** (200):

```json
{
  "success": true,
  "inviteId": "uuid",
  "inviteUrl": "https://app.makeready.org/join/ABC123XYZ9",
  "message": "Invite sent successfully"
}
```

**Error Responses**: 400 (invalid phone/validation), 401, 403 (not group creator), 404 (group not found), 500

**Swift Example**:

```swift
func sendInvite(groupId: String, recipientPhone: String) async throws -> SendInviteResponse {
    let body: [String: Any] = [
        "groupId": groupId,
        "recipientPhone": recipientPhone
    ]

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/invites/send"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(SendInviteResponse.self, from: data)
}
```

---

### GET /api/invites/:token

Get invite details by token. Public endpoint (no authentication required).

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| token | String | 10-character alphanumeric invite token |

**Response** (200):

```json
{
  "success": true,
  "invite": {
    "id": "uuid",
    "token": "ABC123XYZ9",
    "recipientPhone": "+12025551234",
    "expiresAt": "2026-12-31T23:59:59.000Z",
    "group": {
      "id": "uuid",
      "name": "Bible Study Group",
      "description": "Weekly study group"
    },
    "inviter": {
      "id": "uuid",
      "name": "John Doe",
      "picture": "https://..."
    }
  }
}
```

**Error Responses**: 400 (missing token), 404 (not found/expired), 500

**Swift Example**:

```swift
func getInvite(token: String) async throws -> InviteDetails {
    let url = baseURL.appendingPathComponent("/api/invites/\(token)")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(InviteDetailsResponse.self, from: data)
    return response.invite
}
```

---

## Join Requests (group-join-requests.ts)

### POST /api/groups/:groupId/join-requests

Submit a join request for a group. The member must not already be a member or have a pending request. If a previous request was rejected, a new one can be submitted.

**Authentication**: Member Session (requireMemberAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |

**Request Body** (optional):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| message | String | No | Message to include with the request (max 500 chars) |

**Response** (201):

```json
{
  "success": true,
  "request": {
    "id": "uuid",
    "groupId": "uuid",
    "status": "pending",
    "message": "I'd love to join your study group!",
    "createdAt": "2026-02-10T12:00:00.000Z"
  }
}
```

**Side Effect**: Sends a push notification to the group creator.

**Error Responses**: 400 (already member/pending request/validation), 401, 404 (group not found), 500

**Swift Example**:

```swift
func submitJoinRequest(groupId: String, message: String? = nil) async throws -> JoinRequest {
    var body: [String: Any] = [:]
    if let message = message { body["message"] = message }

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups/\(groupId)/join-requests"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if !body.isEmpty {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let (data, response) = try await URLSession.shared.data(for: request)
    let joinResponse = try JSONDecoder().decode(JoinRequestResponse.self, from: data)
    return joinResponse.request
}
```

---

### GET /api/groups/:groupId/join-requests/me

Check the current member's relationship with a group. Returns membership or request status.

**Authentication**: Member Session (requireMemberAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |

**Response** (200) - Already a member:

```json
{
  "success": true,
  "status": "member",
  "membership": {
    "id": "uuid",
    "role": "member",
    "joinedAt": "2026-02-10T12:00:00.000Z",
    "groupName": "Bible Study Group"
  }
}
```

**Response** (200) - Has a join request:

```json
{
  "success": true,
  "status": "pending",
  "request": {
    "id": "uuid",
    "status": "pending",
    "message": "I'd love to join!",
    "createdAt": "2026-02-10T12:00:00.000Z",
    "reviewedAt": null
  }
}
```

**Response** (200) - No relationship:

```json
{
  "success": true,
  "status": "none"
}
```

**Possible `status` values**: `"member"`, `"pending"`, `"approved"`, `"rejected"`, `"none"`

**Error Responses**: 401, 500

**Swift Example**:

```swift
func checkGroupStatus(groupId: String) async throws -> GroupStatusResponse {
    let url = baseURL.appendingPathComponent("/api/groups/\(groupId)/join-requests/me")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(GroupStatusResponse.self, from: data)
}
```

---

### GET /api/groups/:groupId/join-requests

List join requests for a group. Only the group creator can access this endpoint.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| status | String | `"pending"` | Filter by status: `"pending"`, `"approved"`, `"rejected"` |

**Response** (200):

```json
{
  "success": true,
  "requests": [
    {
      "id": "uuid",
      "status": "pending",
      "message": "I'd love to join!",
      "createdAt": "2026-02-10T12:00:00.000Z",
      "member": {
        "id": "uuid",
        "firstName": "Jane",
        "lastName": "Smith",
        "avatarUrl": "https://..."
      }
    }
  ],
  "count": 1
}
```

**Error Responses**: 401, 404 (not found/not creator), 500

**Swift Example**:

```swift
func listJoinRequests(groupId: String, status: String = "pending") async throws -> [JoinRequestWithMember] {
    var components = URLComponents(url: baseURL.appendingPathComponent("/api/groups/\(groupId)/join-requests"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "status", value: status)]

    var request = URLRequest(url: components.url!)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(JoinRequestsListResponse.self, from: data)
    return response.requests
}
```

---

### POST /api/groups/:groupId/join-requests/:requestId/approve

Approve a pending join request. Atomically updates the request status and adds the member to the group in a single transaction.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |
| requestId | String | Join request UUID |

**Request Body**: None

**Response** (200):

```json
{
  "success": true,
  "request": {
    "id": "uuid",
    "status": "approved",
    "reviewedAt": "2026-02-10T12:00:00.000Z"
  },
  "member": {
    "id": "uuid",
    "firstName": "Jane",
    "lastName": "Smith"
  }
}
```

**Error Responses**: 401, 404 (not found/not creator/not pending), 500

**Swift Example**:

```swift
func approveJoinRequest(groupId: String, requestId: String) async throws -> ApproveResponse {
    let url = baseURL.appendingPathComponent("/api/groups/\(groupId)/join-requests/\(requestId)/approve")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(ApproveResponse.self, from: data)
}
```

---

### POST /api/groups/:groupId/join-requests/:requestId/reject

Reject a pending join request. The member can submit a new request after rejection.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |
| requestId | String | Join request UUID |

**Request Body**: None

**Response** (200):

```json
{
  "success": true,
  "request": {
    "id": "uuid",
    "status": "rejected",
    "reviewedAt": "2026-02-10T12:00:00.000Z"
  }
}
```

**Error Responses**: 401, 404 (not found/not creator/not pending), 500

**Swift Example**:

```swift
func rejectJoinRequest(groupId: String, requestId: String) async throws -> RejectResponse {
    let url = baseURL.appendingPathComponent("/api/groups/\(groupId)/join-requests/\(requestId)/reject")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(RejectResponse.self, from: data)
}
```

---

## Group Members (group-members.ts)

### GET /api/groups/:groupId/members

List all members in a group.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| includeInactive | String | `"false"` | Set to `"true"` to include inactive members |

**Response** (200):

```json
{
  "success": true,
  "members": [
    {
      "id": "clxyz123abc",
      "userId": "clmember456def",
      "groupId": "clgroup789ghi",
      "role": "OWNER",
      "name": "John Doe",
      "avatarUrl": "https://example.com/avatar.jpg",
      "joinedAt": "2024-01-15T10:30:00.000Z"
    },
    {
      "id": "clxyz124abd",
      "userId": "clmember457deg",
      "groupId": "clgroup789ghi",
      "role": "MEMBER",
      "name": "Jane Smith",
      "avatarUrl": null,
      "joinedAt": "2024-01-20T14:45:00.000Z"
    }
  ]
}
```

**Note**: `id` is the GroupMember relationship ID, `userId` is the Member ID. Roles are uppercased: `OWNER`, `ADMIN`, `MEMBER`.

**Error Responses**: 401, 500

**Swift Example**:

```swift
func listGroupMembers(groupId: String, includeInactive: Bool = false) async throws -> [GroupMember] {
    var components = URLComponents(url: baseURL.appendingPathComponent("/api/groups/\(groupId)/members"), resolvingAgainstBaseURL: false)!
    if includeInactive {
        components.queryItems = [URLQueryItem(name: "includeInactive", value: "true")]
    }

    var request = URLRequest(url: components.url!)
    request.httpMethod = "GET"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GroupMembersResponse.self, from: data)
    return response.members
}
```

---

### POST /api/groups/:groupId/members

Add an existing member to a group. The member must belong to the same organization as the group.

**Authentication**: User Session (requireAuth) + `group.invite` permission

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| memberId | String | Yes | ID of the member to add |
| role | String | No | `"member"` (default) or `"leader"` |

**Response** (200):

```json
{
  "success": true,
  "message": "Member added to group successfully"
}
```

**Error Responses**: 400 (validation/already member), 401, 403 (no permission/org mismatch), 404 (group or member not found), 500

**Swift Example**:

```swift
func addMemberToGroup(groupId: String, memberId: String, role: String = "member") async throws {
    let body: [String: Any] = [
        "memberId": memberId,
        "role": role
    ]

    var request = URLRequest(url: baseURL.appendingPathComponent("/api/groups/\(groupId)/members"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(SuccessResponse.self, from: data)
    guard response.success else { throw APIError.addMemberFailed }
}
```

---

### DELETE /api/groups/:groupId/members/:memberId

Remove a member from a group (soft delete -- marks as inactive).

**Authentication**: User Session (requireAuth) + `group.update` permission

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | String | Group UUID |
| memberId | String | Member UUID to remove |

**Response** (200):

```json
{
  "success": true,
  "message": "Member removed from group successfully"
}
```

**Error Responses**: 401, 403 (no permission), 500

**Swift Example**:

```swift
func removeMemberFromGroup(groupId: String, memberId: String) async throws {
    let url = baseURL.appendingPathComponent("/api/groups/\(groupId)/members/\(memberId)")
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(SuccessResponse.self, from: data)
    guard response.success else { throw APIError.removeMemberFailed }
}
```

---

## Join Pages -- HTML/OG Meta (join.ts)

These endpoints return **HTML pages** (not JSON). They serve Open Graph meta tags for rich social media previews (iMessage, Facebook, Twitter, etc.) and automatically redirect the user to the client application.

### GET /join/group/:code

Generates an HTML page with OG meta tags for sharing a group invite link.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | String | 6-character alphanumeric group code |

**Response** (200): `text/html`

The HTML page includes:
- `og:title`: "Join [Group Name] on MakeReady"
- `og:description`: Group description or default text
- `og:image`: Group cover image or default
- Automatic redirect to `{CLIENT_URL}/join/group/{code}`

**Example URL**: `https://app.makeready.org/join/group/NNNM76`

**Swift Example** (opening in Safari/SFSafariViewController):

```swift
func openGroupInviteLink(code: String) {
    let url = URL(string: "https://app.makeready.org/join/group/\(code)")!
    UIApplication.shared.open(url)
}
```

---

### GET /join/group/:code/study/:studyCode

Generates an HTML page with OG meta tags for sharing a scheduled lesson (study) invite link within a group context.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | String | 6-character group code |
| studyCode | String | 6-character study/lesson code |

**Response** (200): `text/html`

The HTML page includes:
- Lesson title, group name, and scheduled time
- Automatic redirect to `{CLIENT_URL}/join/group/{code}/study/{studyCode}`

**Example URL**: `https://app.makeready.org/join/group/NNNM76/study/ABC123`

**Swift Example**:

```swift
func shareStudyLink(groupCode: String, studyCode: String) -> URL {
    return URL(string: "https://app.makeready.org/join/group/\(groupCode)/study/\(studyCode)")!
}
```

---

### GET /join/study/:id

Generates an HTML page with OG meta tags for sharing a scheduled lesson by ID or code.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | String | UUID or 6-character alphanumeric code |

**Response** (200): `text/html`

**Example URLs**:
- `https://app.makeready.org/join/study/765c2f2e-e0f6-45c4-ac44-6ee767da96ac`
- `https://app.makeready.org/join/study/ABC123`

**Swift Example**:

```swift
func shareStudyDirectLink(studyId: String) -> URL {
    return URL(string: "https://app.makeready.org/join/study/\(studyId)")!
}
```

---

### GET /join/group/:code/event/:eventCode

Generates an HTML page with OG meta tags for sharing an event link.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | String | 6-character group code |
| eventCode | String | 6-character event code |

**Response** (200): `text/html`

The HTML page includes:
- Event title, description, date/time, and location
- Automatic redirect to `{CLIENT_URL}/join/group/{code}/event/{eventCode}`

**Example URL**: `https://app.makeready.org/join/group/NNNM76/event/ABC123`

**Swift Example**:

```swift
func shareEventLink(groupCode: String, eventCode: String) -> URL {
    return URL(string: "https://app.makeready.org/join/group/\(groupCode)/event/\(eventCode)")!
}
```

---

### GET /join/:token

Generates an HTML page with OG meta tags for a direct (legacy) invite token link. Displays group info and inviter name if the invite is valid, or a fallback page if expired/invalid.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| token | String | Unique invite token string |

**Response** (200): `text/html`

For valid invites:
- `og:title`: "Join [Group Name] on MakeReady"
- `og:description`: "[Inviter] invited you to join [Group Name]. Tap to accept your invitation."
- `og:image`: Group cover image or default

For invalid/expired invites:
- `og:title`: "Join on MakeReady"
- `og:description`: "You've been invited to join a group on MakeReady."
- Fallback page with link to MakeReady homepage

Both cases auto-redirect to `{CLIENT_URL}/join/{token}`.

**Example URL**: `https://app.makeready.org/join/abc123xyz`

**Swift Example**:

```swift
func openInviteLink(token: String) {
    let url = URL(string: "https://app.makeready.org/join/\(token)")!
    UIApplication.shared.open(url)
}
```
