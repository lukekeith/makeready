# Groups API (Client Reference)

**Base URL (Local)**: http://localhost:3001
**Base URL (Production)**: https://makeready-production.up.railway.app

**Route files**: groups.ts, invites.ts, group-join-requests.ts, group-members.ts, join.ts

Last Updated: 2026-02-10

**NOTE**: This file was intended for /Users/lukekeith/www/makeready/client/.claude/docs/groups.md but was written here due to permissions. Copy it to the correct location:
```
cp server/.claude/docs/groups-client.md client/.claude/docs/groups.md
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

- **User Session** (`requireAuth`): Google OAuth session. Used by group leaders/creators (the web dashboard user). Credentials are stored in a session cookie.
- **Member Session** (`requireMemberAuth`): Phone-verified member session. Used by group members. Identified via `req.session.memberId`.

All `fetch` examples below assume `credentials: "include"` for cookie-based session handling.

---

## Groups (groups.ts)

### POST /api/groups

Create a new group in the user's organization.

**Authentication**: User Session (requireAuth)

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Group name (1-200 chars) |
| description | string | No | Group description (max 2000 chars) |
| coverImageUrl | string (URL) | No | Cover image URL |
| isPrivate | boolean | No | Default: false |
| allowInvites | boolean | No | Default: true |
| welcomeMessage | string | No | Welcome message (max 1000 chars) |
| ageRange | object | No | `{ min?: number, max?: number }` (0-120) |
| maxMembers | number | No | Minimum: 1 |

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

**TypeScript Example**:

```typescript
async function createGroup(data: {
  name: string;
  description?: string;
  isPrivate?: boolean;
  allowInvites?: boolean;
  welcomeMessage?: string;
  ageRange?: { min?: number; max?: number };
  maxMembers?: number;
}) {
  const res = await fetch("/api/groups", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  return res.json();
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

**TypeScript Example**:

```typescript
async function listGroups() {
  const res = await fetch("/api/groups", {
    credentials: "include",
  });
  return res.json();
}
```

---

### GET /api/groups/code/:code

Look up a group by its 6-character join code. Returns membership status if the caller has an active member session.

**Authentication**: None required (optional member session enhances response)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | string | 6-character alphanumeric group code (case-insensitive, normalized to uppercase) |

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

**TypeScript Example**:

```typescript
async function lookupGroupByCode(code: string) {
  const res = await fetch(`/api/groups/code/${code}`, {
    credentials: "include",
  });
  return res.json();
}
```

---

### GET /api/groups/:id

Get full details of a group by ID. User must be the group creator.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Group UUID |

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

**TypeScript Example**:

```typescript
async function getGroup(id: string) {
  const res = await fetch(`/api/groups/${id}`, {
    credentials: "include",
  });
  return res.json();
}
```

---

### GET /api/groups/:id/invite

Get invite URL and QR code for a group. User must be the group creator.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Group UUID |

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

**TypeScript Example**:

```typescript
async function getGroupInvite(groupId: string) {
  const res = await fetch(`/api/groups/${groupId}/invite`, {
    credentials: "include",
  });
  return res.json();
}

// Display QR code in an img tag
const { invite } = await getGroupInvite("some-group-id");
const img = document.createElement("img");
img.src = invite.qrCode;
```

---

### GET /api/groups/:id/public

Get limited public information for a group. No authentication required.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Group UUID |

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

**TypeScript Example**:

```typescript
async function getPublicGroupInfo(groupId: string) {
  const res = await fetch(`/api/groups/${groupId}/public`);
  return res.json();
}
```

---

### PATCH /api/groups/:id

Update group metadata. User must be the group creator. All fields are optional.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Group UUID |

**Request Body** (all fields optional):

| Field | Type | Description |
|-------|------|-------------|
| name | string | Group name (1-200 chars) |
| description | string \| null | Nullable. Max 2000 chars |
| coverImageUrl | string \| null | Nullable URL |
| isPrivate | boolean | Privacy setting |
| allowInvites | boolean | Whether invites are allowed |
| welcomeMessage | string \| null | Nullable. Max 1000 chars |
| ageRange | object \| null | Nullable. `{ min?: number \| null, max?: number \| null }` |
| maxMembers | number \| null | Nullable. Minimum 1 |

**Response** (200): Same shape as create group response.

**Error Responses**: 400 (validation), 401, 404, 500

**TypeScript Example**:

```typescript
async function updateGroup(id: string, data: Partial<{
  name: string;
  description: string | null;
  coverImageUrl: string | null;
  isPrivate: boolean;
  allowInvites: boolean;
  welcomeMessage: string | null;
  ageRange: { min?: number | null; max?: number | null } | null;
  maxMembers: number | null;
}>) {
  const res = await fetch(`/api/groups/${id}`, {
    method: "PATCH",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  return res.json();
}
```

---

### DELETE /api/groups/:id

Soft-delete a group (sets `isActive = false`). User must be the group creator.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Group UUID |

**Response** (200):

```json
{
  "success": true,
  "message": "Group deleted successfully"
}
```

**Error Responses**: 401, 404, 500

**TypeScript Example**:

```typescript
async function deleteGroup(id: string) {
  const res = await fetch(`/api/groups/${id}`, {
    method: "DELETE",
    credentials: "include",
  });
  return res.json();
}
```

---

### POST /api/groups/:id/cover-image

Upload a cover image for a group. Accepts base64-encoded image data. Automatically generates three sizes (original 1200px, medium 400px, thumbnail 150px) and uploads to Cloudflare R2.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Group UUID |

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| imageData | string | Yes | Base64-encoded image data (with or without data URI prefix) |
| contentType | string | No | MIME type. Default: `"image/jpeg"` |

**Response** (200):

```json
{
  "success": true,
  "coverImageUrl": "https://images.makeready.org/group-covers/group-uuid-1707570000.jpeg"
}
```

**Error Responses**: 400 (validation), 401, 404, 500

**TypeScript Example**:

```typescript
async function uploadCoverImage(groupId: string, file: File) {
  // Convert file to base64
  const reader = new FileReader();
  const base64 = await new Promise<string>((resolve) => {
    reader.onload = () => resolve(reader.result as string);
    reader.readAsDataURL(file);
  });

  const res = await fetch(`/api/groups/${groupId}/cover-image`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      imageData: base64,
      contentType: file.type || "image/jpeg",
    }),
  });
  return res.json();
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
| groupId | string (UUID) | No | Group to associate the invite with |
| expiresAt | string (ISO 8601) | No | Expiration datetime |

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

**TypeScript Example**:

```typescript
async function createInvite(data?: { groupId?: string; expiresAt?: string }) {
  const res = await fetch("/api/invites", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data ?? {}),
  });
  return res.json();
}
```

---

### POST /api/invites/send

Send a group invitation via SMS to a phone number. Only the group creator can send invitations.

**Authentication**: User Session (requireAuth)

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| groupId | string (UUID) | Yes | Group to invite to |
| recipientPhone | string | Yes | Phone number in E.164 format (e.g., `+12025551234`) |

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

**TypeScript Example**:

```typescript
async function sendInvite(groupId: string, recipientPhone: string) {
  const res = await fetch("/api/invites/send", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ groupId, recipientPhone }),
  });
  return res.json();
}
```

---

### GET /api/invites/:token

Get invite details by token. Public endpoint (no authentication required).

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| token | string | 10-character alphanumeric invite token |

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

**TypeScript Example**:

```typescript
async function getInvite(token: string) {
  const res = await fetch(`/api/invites/${token}`);
  return res.json();
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
| groupId | string | Group UUID |

**Request Body** (optional):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| message | string | No | Message to include with the request (max 500 chars) |

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

**TypeScript Example**:

```typescript
async function submitJoinRequest(groupId: string, message?: string) {
  const res = await fetch(`/api/groups/${groupId}/join-requests`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message }),
  });
  return res.json();
}
```

---

### GET /api/groups/:groupId/join-requests/me

Check the current member's relationship with a group. Returns membership or request status.

**Authentication**: Member Session (requireMemberAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group UUID |

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

**TypeScript Example**:

```typescript
async function checkGroupStatus(groupId: string) {
  const res = await fetch(`/api/groups/${groupId}/join-requests/me`, {
    credentials: "include",
  });
  return res.json();
}
```

---

### GET /api/groups/:groupId/join-requests

List join requests for a group. Only the group creator can access this endpoint.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group UUID |

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| status | string | `"pending"` | Filter by status: `"pending"`, `"approved"`, `"rejected"` |

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

**TypeScript Example**:

```typescript
async function listJoinRequests(groupId: string, status: string = "pending") {
  const params = new URLSearchParams({ status });
  const res = await fetch(`/api/groups/${groupId}/join-requests?${params}`, {
    credentials: "include",
  });
  return res.json();
}
```

---

### POST /api/groups/:groupId/join-requests/:requestId/approve

Approve a pending join request. Atomically updates the request status and adds the member to the group in a single transaction.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group UUID |
| requestId | string | Join request UUID |

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

**TypeScript Example**:

```typescript
async function approveJoinRequest(groupId: string, requestId: string) {
  const res = await fetch(
    `/api/groups/${groupId}/join-requests/${requestId}/approve`,
    {
      method: "POST",
      credentials: "include",
    }
  );
  return res.json();
}
```

---

### POST /api/groups/:groupId/join-requests/:requestId/reject

Reject a pending join request. The member can submit a new request after rejection.

**Authentication**: User Session (requireAuth)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group UUID |
| requestId | string | Join request UUID |

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

**TypeScript Example**:

```typescript
async function rejectJoinRequest(groupId: string, requestId: string) {
  const res = await fetch(
    `/api/groups/${groupId}/join-requests/${requestId}/reject`,
    {
      method: "POST",
      credentials: "include",
    }
  );
  return res.json();
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
| groupId | string | Group UUID |

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| includeInactive | string | `"false"` | Set to `"true"` to include inactive members |

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

**TypeScript Example**:

```typescript
async function listGroupMembers(
  groupId: string,
  includeInactive: boolean = false
) {
  const params = includeInactive
    ? new URLSearchParams({ includeInactive: "true" })
    : "";
  const res = await fetch(`/api/groups/${groupId}/members?${params}`, {
    credentials: "include",
  });
  return res.json();
}
```

---

### POST /api/groups/:groupId/members

Add an existing member to a group. The member must belong to the same organization as the group.

**Authentication**: User Session (requireAuth) + `group.invite` permission

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group UUID |

**Request Body**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| memberId | string | Yes | ID of the member to add |
| role | string | No | `"member"` (default) or `"leader"` |

**Response** (200):

```json
{
  "success": true,
  "message": "Member added to group successfully"
}
```

**Error Responses**: 400 (validation/already member), 401, 403 (no permission/org mismatch), 404 (group or member not found), 500

**TypeScript Example**:

```typescript
async function addMemberToGroup(
  groupId: string,
  memberId: string,
  role: "member" | "leader" = "member"
) {
  const res = await fetch(`/api/groups/${groupId}/members`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ memberId, role }),
  });
  return res.json();
}
```

---

### DELETE /api/groups/:groupId/members/:memberId

Remove a member from a group (soft delete -- marks as inactive).

**Authentication**: User Session (requireAuth) + `group.update` permission

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group UUID |
| memberId | string | Member UUID to remove |

**Response** (200):

```json
{
  "success": true,
  "message": "Member removed from group successfully"
}
```

**Error Responses**: 401, 403 (no permission), 500

**TypeScript Example**:

```typescript
async function removeMemberFromGroup(groupId: string, memberId: string) {
  const res = await fetch(`/api/groups/${groupId}/members/${memberId}`, {
    method: "DELETE",
    credentials: "include",
  });
  return res.json();
}
```

---

## Join Pages -- HTML/OG Meta (join.ts)

These endpoints return **HTML pages** (not JSON). They serve Open Graph meta tags for rich social media previews (iMessage, Facebook, Twitter, etc.) and automatically redirect the user to the client application. These are the URLs you should use when building share links.

### GET /join/group/:code

Generates an HTML page with OG meta tags for sharing a group invite link.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | string | 6-character alphanumeric group code |

**Response** (200): `text/html`

The HTML page includes:
- `og:title`: "Join [Group Name] on MakeReady"
- `og:description`: Group description or default text
- `og:image`: Group cover image or default
- Automatic redirect to `{CLIENT_URL}/join/group/{code}`

**Example URL**: `https://app.makeready.org/join/group/NNNM76`

**TypeScript Example**:

```typescript
function getGroupShareUrl(code: string): string {
  return `https://app.makeready.org/join/group/${code}`;
}

// Copy to clipboard
async function shareGroupLink(code: string) {
  const url = getGroupShareUrl(code);
  await navigator.clipboard.writeText(url);
}
```

---

### GET /join/group/:code/study/:studyCode

Generates an HTML page with OG meta tags for sharing a scheduled lesson (study) invite link within a group context.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | string | 6-character group code |
| studyCode | string | 6-character study/lesson code |

**Response** (200): `text/html`

The HTML page includes:
- Lesson title, group name, and scheduled time
- Automatic redirect to `{CLIENT_URL}/join/group/{code}/study/{studyCode}`

**Example URL**: `https://app.makeready.org/join/group/NNNM76/study/ABC123`

**TypeScript Example**:

```typescript
function getStudyShareUrl(groupCode: string, studyCode: string): string {
  return `https://app.makeready.org/join/group/${groupCode}/study/${studyCode}`;
}
```

---

### GET /join/study/:id

Generates an HTML page with OG meta tags for sharing a scheduled lesson by ID or code.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | UUID or 6-character alphanumeric code |

**Response** (200): `text/html`

**Example URLs**:
- `https://app.makeready.org/join/study/765c2f2e-e0f6-45c4-ac44-6ee767da96ac`
- `https://app.makeready.org/join/study/ABC123`

**TypeScript Example**:

```typescript
function getStudyDirectShareUrl(studyId: string): string {
  return `https://app.makeready.org/join/study/${studyId}`;
}
```

---

### GET /join/group/:code/event/:eventCode

Generates an HTML page with OG meta tags for sharing an event link.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| code | string | 6-character group code |
| eventCode | string | 6-character event code |

**Response** (200): `text/html`

The HTML page includes:
- Event title, description, date/time, and location
- Automatic redirect to `{CLIENT_URL}/join/group/{code}/event/{eventCode}`

**Example URL**: `https://app.makeready.org/join/group/NNNM76/event/ABC123`

**TypeScript Example**:

```typescript
function getEventShareUrl(groupCode: string, eventCode: string): string {
  return `https://app.makeready.org/join/group/${groupCode}/event/${eventCode}`;
}
```

---

### GET /join/:token

Generates an HTML page with OG meta tags for a direct (legacy) invite token link. Displays group info and inviter name if the invite is valid, or a fallback page if expired/invalid.

**Authentication**: None

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| token | string | Unique invite token string |

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

**TypeScript Example**:

```typescript
function getInviteShareUrl(token: string): string {
  return `https://app.makeready.org/join/${token}`;
}
```
