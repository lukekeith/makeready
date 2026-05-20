# MakeReady API Documentation

## Overview

The MakeReady API is a RESTful API built with Express.js and Prisma ORM. It provides endpoints for authentication, member management, organization management, study programs, Bible reading, and video uploads.

**Base URL:** `http://localhost:3001` (development)

---

## API Sections

| Section | Description | Auth Required |
|---------|-------------|---------------|
| [Authentication](./docs/api/authentication.md) | Google OAuth & phone verification | Varies |
| [Members](./docs/api/members.md) | Member profiles, phone verification | Mixed |
| [Groups](./docs/api/groups.md) | Group management, join codes, cover images | Mixed |
| [Posts](./docs/api/posts.md) | Group feed posts, infinite scroll | Mixed |
| [Organizations](./docs/api/organizations.md) | Organization management, member lists | Yes |
| [Programs](./docs/api/programs.md) | Study programs, lessons, activities | Yes |
| [Notes](./docs/api/notes.md) | Study notes with polymorphic linking | Yes |
| [Bible](./docs/api/bible.md) | Reading, search, highlights, verse notes | Mixed |
| [Videos](./docs/api/videos.md) | Upload, management via Cloudflare Stream | Yes |
| [Events](./docs/api/events.md) | Calendar events, RSVPs, attachments | Mixed |
| [Errors & Rate Limiting](./docs/api/errors.md) | Error formats, HTTP codes, limits | - |

---

## Authentication Overview

The API supports **two independent authentication systems**:

1. **User Authentication** (Google OAuth) - For organization owners and administrators
2. **Member Authentication** (Phone Verification) - For organization members accessing their own data

Both use session-based cookies (`connect.sid`) and can coexist in the same session.

**Details:** [Authentication Documentation](./docs/api/authentication.md)

---

## Quick Reference

### Common Response Format

**Success:**
```json
{
  "success": true,
  "data": { ... }
}
```

**Error:**
```json
{
  "success": false,
  "error": "Error message"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | OK |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 500 | Internal Server Error |

---

## Endpoint Summary

### Authentication
```
GET  /auth/google                    # Initiate Google OAuth
POST /auth/exchange                  # Exchange code for session (iOS)
GET  /auth/me                        # Get current user
POST /auth/logout                    # Logout user
```

### Members
```
POST /api/members/verify-phone       # Send SMS verification code
POST /api/members/confirm-verification  # Verify code & create session
GET  /api/members/me                 # Get current member
GET  /api/members/session            # Check member session
POST /api/members/logout             # Logout member
GET  /api/members/:id                # Get member by ID
PATCH /api/members/:id               # Update member
DELETE /api/members/:id              # Soft delete member
GET  /api/members/:id/groups         # Get member's groups
```

### Groups
```
POST /api/groups                     # Create group (auto-generates code)
GET  /api/groups                     # List user's groups
GET  /api/groups/:id                 # Get group by ID
GET  /api/groups/:id/public          # Get public group info (no auth)
GET  /api/groups/:id/invite          # Get invite info with QR code
GET  /api/groups/code/:code          # Look up group by 6-char code (no auth)
PATCH /api/groups/:id                # Update group
DELETE /api/groups/:id               # Soft delete group
POST /api/groups/:id/cover-image     # Upload cover image
GET  /api/groups/:id/members         # List group members
POST /api/groups/:id/members         # Add member to group
DELETE /api/groups/:id/members/:memberId  # Remove member
```

### Posts
```
GET  /api/groups/:groupId/posts      # List posts (cursor pagination)
GET  /api/groups/:groupId/posts/public  # Public posts (no auth)
POST /api/groups/:groupId/posts      # Create post (creator only)
DELETE /api/posts/:id                # Delete post
```

### Group Join Requests
```
POST /api/groups/:groupId/join-requests         # Submit join request (member)
GET  /api/groups/:groupId/join-requests         # List requests (leader)
GET  /api/groups/:groupId/join-requests/me      # Check my request status
POST /api/groups/:groupId/join-requests/:id/approve  # Approve request
POST /api/groups/:groupId/join-requests/:id/reject   # Reject request
```

### Events
```
POST /api/groups/:groupId/events                # Create event (creator)
GET  /api/groups/:groupId/events                # List events (creator)
GET  /api/events/:id                            # Get event details
GET  /api/events/code/:code                     # Get public event by code
PATCH /api/events/:id                           # Update event
DELETE /api/events/:id                          # Delete event
PATCH /api/events/:id/update-series             # Update recurring series
DELETE /api/events/:id/delete-series            # Delete recurring series
POST /api/events/:id/cover-image                # Upload cover image
POST /api/events/:id/attachments                # Upload attachment
DELETE /api/events/:id/attachments/:attachmentId  # Delete attachment
GET  /api/events/:id/attendees                  # List attendees
POST /api/events/:id/invite                     # Invite group members
POST /api/events/:id/rsvp                       # RSVP (member, private event)
POST /api/events/code/:code/rsvp                # RSVP (public event)
PATCH /api/events/:id/attendees/:attendeeId     # Update attendee
DELETE /api/events/:id/attendees/:attendeeId    # Remove attendee
```
**Source:** `src/routes/events.ts` | [Full docs](docs/api/events.md)

### Organizations
```
GET  /api/organizations/:id          # Get organization
GET  /api/organizations/my/organization  # Get user's organization
PATCH /api/organizations/:id         # Update organization
GET  /api/organizations/:id/members  # Get organization members
```

### Programs
```
GET  /api/activity-types             # List activity type configs
GET  /api/programs/me                # Get user's programs
GET  /api/programs/:id               # Get program with lessons
POST /api/programs                   # Create program
PATCH /api/programs/:id              # Update program
DELETE /api/programs/:id             # Delete program
POST /api/programs/:id/reorder-lessons  # Reorder lessons
POST /api/programs/:id/lessons       # Create lesson
PATCH /api/lessons/:id               # Update lesson
DELETE /api/lessons/:id              # Delete lesson
POST /api/programs/:id/lessons/:id/activities  # Create activity
GET  /api/programs/:id/lessons/:id/activity-capacity  # Get activity limits
PATCH /api/activities/:id            # Update activity
POST /api/activities/:id/reset       # Reset activity content
DELETE /api/activities/:id           # Delete activity
```

### Study Notes
```
POST /api/member/notes               # Create note (member)
GET  /api/member/notes               # Get notes with filtering (member)
GET  /api/member/notes/:noteId       # Get single note (member)
PATCH /api/member/notes/:noteId      # Update note (member)
DELETE /api/member/notes/:noteId     # Delete note (member)
GET  /api/member/notes/entity/:refType/:refId  # Get notes for entity
GET  /api/member/notes/llm           # Get notes formatted for LLM
POST /api/notes                      # Create note (user)
GET  /api/notes                      # Get notes (user)
GET  /api/notes/:noteId              # Get single note (user)
PATCH /api/notes/:noteId             # Update note (user)
DELETE /api/notes/:noteId            # Delete note (user)
GET  /api/notes/types                # Get available note/link types
```

### Activity Progress
```
POST /api/member/activities/:id/progress  # Save SOAP progress with notes
GET  /api/member/activities/:id/progress  # Get activity progress
```

### Bible
```
GET  /api/bible/translations         # List translations
GET  /api/bible/translations/:code/books  # Get books
GET  /api/bible/:code/:book/:chapter # Read chapter
GET  /api/bible/:code/:book/:chapter/:verse  # Read verse
POST /api/search/smart               # Smart search (reference + semantic)
GET  /api/search/suggestions         # Book autocomplete
GET  /api/bible/search               # Full-text search
GET  /api/bible/translations/:code/download  # Download for offline
GET/POST/PATCH/DELETE /api/bible/highlights  # User highlights
GET/POST/PATCH/DELETE /api/bible/notes       # User notes
GET/POST/DELETE /api/bible/bookmarks         # User bookmarks
```

### Videos
```
POST /api/videos/upload-url          # Get Cloudflare upload URL
POST /api/videos                     # Create video record
GET  /api/videos/me                  # Get user's videos
GET  /api/videos/:id                 # Get video by ID
PATCH /api/videos/:id                # Update video metadata
POST /api/videos/:id/refresh         # Refresh status from Cloudflare
DELETE /api/videos/:id               # Delete video
```

---

## Environment Variables

```env
PORT=3001
NODE_ENV=development

# Google OAuth
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_CALLBACK_URL=http://localhost:3001/auth/google/callback

# Session
SESSION_SECRET=...

# Client URL
CLIENT_URL=http://localhost:5173

# Database
DATABASE_URL="postgresql://..."

# Twilio (SMS)
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_VERIFY_SERVICE_SID=...

# Cloudflare Stream (video)
CLOUDFLARE_ACCOUNT_ID=...
CLOUDFLARE_API_TOKEN=...

# Cloudflare R2 (file/image storage)
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET_NAME=...
R2_PUBLIC_URL=...
```

---

## Additional Resources

| Resource | Location |
|----------|----------|
| Database Schema | `prisma/schema.prisma` |
| Postman Collection | `postman/MakeReady.postman_collection.json` |
| Bible Integration Guide | `BIBLE_INTEGRATION_README.md` |
| TypeScript Types | `src/generated/prisma/index.d.ts` |

### Source Files

| Feature | Route File | Service File |
|---------|------------|--------------|
| Auth | `src/routes/auth.ts` | - |
| Members | `src/routes/members.ts` | `src/services/member.ts`, `src/services/twilio.ts` |
| Groups | `src/routes/groups.ts` | - |
| Group Join Requests | `src/routes/group-join-requests.ts` | - |
| Posts | `src/routes/posts.ts` | - |
| Organizations | `src/routes/organizations.ts` | `src/services/organization.ts` |
| Programs | `src/routes/programs.ts` | `src/services/activity-type.ts` |
| Study Notes | `src/routes/notes.ts` | `src/services/notes.service.ts` |
| Activity Progress | `src/routes/activity-progress.ts` | `src/services/notes.service.ts` |
| Bible | `src/routes/bible.ts` | - |
| Videos | `src/routes/videos.ts` | `src/services/cloudflare.ts` |
| Events | `src/routes/events.ts` | - |

---

**Last Updated:** January 2026
**API Version:** 1.3
