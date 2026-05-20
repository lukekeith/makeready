# Posts API

Manage posts in the group feed. Posts support infinite scroll with cursor-based pagination.

## Post Model

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | UUID |
| `groupId` | string | Group UUID |
| `authorId` | string? | Author UUID (null for system posts) |
| `authorName` | string | Display name (or "MakeReady" for system) |
| `authorAvatarUrl` | string? | Author avatar URL |
| `type` | string | Post type (see below) |
| `title` | string? | Optional title (max 200 chars) |
| `content` | string | Post content (max 5000 chars) |
| `imageUrl` | string? | Cover/attachment image URL |
| `pollOptions` | array? | For POLL: `[{id, text, voteCount}]` |
| `videoUrl` | string? | For VIDEO: Cloudflare Stream URL |
| `eventDate` | datetime? | For EVENT: Event date/time |
| `eventLocation` | string? | For EVENT: Location string |
| `enrollmentId` | string? | For WELCOME: Associated enrollment |
| `createdAt` | datetime | ISO 8601 timestamp |
| `updatedAt` | datetime | ISO 8601 timestamp |

### Post Types

| Type | Description | Auto-generated |
|------|-------------|----------------|
| `WELCOME` | Study program enrollment announcement | Yes (system) |
| `ANNOUNCEMENT` | General group announcement | No |
| `POLL` | Poll with voting options | No |
| `VIDEO` | Video post | No |
| `EVENT` | Event with date/location | No |

---

## Endpoints

### GET /api/groups/:groupId/posts

Get posts for a group with cursor-based pagination. Supports infinite scroll.

**Auth:** Required (User must be group creator or member)

**Query Parameters:**
| Parameter | Type | Default | Max | Description |
|-----------|------|---------|-----|-------------|
| `limit` | number | 20 | 50 | Number of posts to return |
| `cursor` | string | - | - | ISO timestamp for pagination (createdAt of last post) |

**Example Requests:**
```
# First page (newest posts)
GET /api/groups/:groupId/posts?limit=20

# Next page (older posts)
GET /api/groups/:groupId/posts?limit=20&cursor=2025-12-27T12:00:00.000Z
```

**Response (200):**
```json
{
  "success": true,
  "posts": [
    {
      "id": "post-uuid",
      "groupId": "group-uuid",
      "authorId": "user-uuid",
      "authorName": "John Smith",
      "authorAvatarUrl": "https://...",
      "type": "ANNOUNCEMENT",
      "title": "Welcome everyone!",
      "content": "Excited to start this study together...",
      "imageUrl": null,
      "pollOptions": null,
      "videoUrl": null,
      "eventDate": null,
      "eventLocation": null,
      "enrollmentId": null,
      "createdAt": "2025-12-28T00:00:00.000Z",
      "updatedAt": "2025-12-28T00:00:00.000Z"
    }
  ],
  "nextCursor": "2025-12-27T12:00:00.000Z"
}
```

**Pagination Notes:**
- `nextCursor` is `null` when there are no more posts
- Pass `nextCursor` as `cursor` param to get the next page
- Posts are ordered by `createdAt` descending (newest first)

**Errors:**
- `404`: Group not found or user not authorized

---

### GET /api/groups/:groupId/posts/public

Get posts for a group (public, no auth required). Used for invite preview pages.

**Auth:** None

**Query Parameters:** Same as authenticated endpoint

**Response:** Same format, but without enrollment details

---

### POST /api/groups/:groupId/posts

Create a new post in a group.

**Auth:** Required (User must be group creator)

**Request Body:**
```json
{
  "type": "ANNOUNCEMENT",
  "title": "Important Update",
  "content": "Here's what's happening this week...",
  "imageUrl": "https://example.com/image.jpg"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `POLL`, `VIDEO`, `EVENT`, or `ANNOUNCEMENT` |
| `title` | string | No | Post title (max 200 chars) |
| `content` | string | Yes | Post content (1-5000 chars) |
| `imageUrl` | string | No | Valid URL to image |
| `pollOptions` | array | No | For POLL type only |
| `videoUrl` | string | No | For VIDEO type only |
| `eventDate` | string | No | ISO datetime for EVENT type |
| `eventLocation` | string | No | Location for EVENT type (max 500 chars) |

**Poll Options Format:**
```json
{
  "type": "POLL",
  "content": "What day works best for our next meeting?",
  "pollOptions": [
    { "id": "opt1", "text": "Monday", "voteCount": 0 },
    { "id": "opt2", "text": "Wednesday", "voteCount": 0 },
    { "id": "opt3", "text": "Friday", "voteCount": 0 }
  ]
}
```

**Event Post Format:**
```json
{
  "type": "EVENT",
  "title": "Group Gathering",
  "content": "Join us for fellowship and food!",
  "eventDate": "2025-12-30T18:00:00.000Z",
  "eventLocation": "123 Main St, City"
}
```

**Response (200):**
```json
{
  "success": true,
  "post": {
    "id": "new-post-uuid",
    "groupId": "group-uuid",
    "authorId": "user-uuid",
    "authorName": "John Smith",
    "authorAvatarUrl": "https://...",
    "type": "ANNOUNCEMENT",
    "title": "Important Update",
    "content": "Here's what's happening this week...",
    "createdAt": "2025-12-28T00:00:00.000Z",
    "updatedAt": "2025-12-28T00:00:00.000Z"
  }
}
```

**Notes:**
- `WELCOME` posts are system-generated only (created when enrollment starts)
- Only group creators can create posts

---

### DELETE /api/posts/:id

Soft delete a post. Only the post author or group creator can delete.

**Auth:** Required (User must be post author or group creator)

**Response (200):**
```json
{
  "success": true
}
```

**Errors:**
- `404`: Post not found
- `403`: Not authorized to delete this post

---

## Infinite Scroll Implementation

### iOS Example

```swift
class PostsManager {
    private var nextCursor: String?
    private var isLoading = false

    func loadInitialPosts(groupId: String) async throws -> [Post] {
        let response = try await fetchPosts(groupId: groupId, cursor: nil)
        nextCursor = response.nextCursor
        return response.posts
    }

    func loadMorePosts(groupId: String) async throws -> [Post] {
        guard let cursor = nextCursor, !isLoading else { return [] }
        isLoading = true
        defer { isLoading = false }

        let response = try await fetchPosts(groupId: groupId, cursor: cursor)
        nextCursor = response.nextCursor
        return response.posts
    }

    var hasMorePosts: Bool {
        nextCursor != nil
    }
}
```

### Web Example

```typescript
const [posts, setPosts] = useState<Post[]>([]);
const [nextCursor, setNextCursor] = useState<string | null>(null);

const loadMore = async () => {
  const params = new URLSearchParams({ limit: '20' });
  if (nextCursor) params.set('cursor', nextCursor);

  const res = await fetch(`/api/groups/${groupId}/posts?${params}`);
  const data = await res.json();

  setPosts(prev => [...prev, ...data.posts]);
  setNextCursor(data.nextCursor);
};
```

---

## Database Performance

The Post model uses optimized indexes for infinite scroll:

```prisma
@@index([groupId])              // Filter by group
@@index([groupId, createdAt])   // Composite for pagination ✅
@@index([authorId])
@@index([type])
@@index([isActive])
```

The composite index `[groupId, createdAt]` ensures efficient pagination queries:
```sql
SELECT * FROM posts
WHERE groupId = ? AND isActive = true AND createdAt < ?
ORDER BY createdAt DESC
LIMIT 21
```

This allows the database to:
1. Filter by group using the index
2. Use the same index for date ordering
3. Avoid full table scans even with millions of posts
