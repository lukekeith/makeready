import type { OAS3Definition } from 'swagger-jsdoc'

export const definition: OAS3Definition = {
  openapi: '3.1.0',
  info: {
    title: 'MakeReady API',
    version: '2.0.0',
    description: `
# MakeReady API Documentation

MakeReady is a platform for Bible study groups. This API supports both web and iOS clients.

## Authentication

MakeReady uses two distinct authentication systems:

### User Authentication (Google OAuth)
For group leaders and administrators who manage groups, programs, and content.
- Initiate OAuth: \`GET /auth/google?platform=ios|web\`
- For iOS: Receive auth code via deep link, exchange for session
- For web: Session cookie set automatically after redirect

### Member Authentication (Phone/SMS)
For group members who access study content via SMS invitations.
- Send code: \`POST /api/members/verify-phone\`
- Verify code: \`POST /api/members/confirm-verification\`
- Session established on successful verification

### Account Linking
Users and Members can link their accounts for bidirectional access:
- **User → Member**: User verifies phone to link to Member account
- **Member → User**: Member authenticates with Google to link to User account
- See the "Account Linking" tag for endpoints

## Making Authenticated Requests

All authenticated requests use HTTP-only session cookies. Include credentials in requests:

\`\`\`javascript
// Web
fetch('/api/groups', { credentials: 'include' })

// iOS
URLSession with HTTPCookieStorage
\`\`\`

## Response Format

All endpoints return consistent JSON responses:

\`\`\`json
// Success
{ "success": true, "data": {...} }

// Error
{ "success": false, "error": "Error message" }
\`\`\`
      `,
    contact: {
      name: 'MakeReady Support',
      url: 'https://makeready.org',
    },
  },
  servers: [
    {
      url: 'https://api.makeready.org',
      description: 'Production',
    },
    {
      url: 'http://localhost:3001',
      description: 'Development',
    },
  ],
  tags: [
    {
      name: 'Authentication',
      description: 'Google OAuth authentication for users (group leaders)',
    },
    {
      name: 'Members',
      description: 'Phone verification and member authentication',
    },
    {
      name: 'Groups',
      description: 'Group CRUD operations and management',
    },
    {
      name: 'Group Members',
      description: 'Add, remove, and manage group memberships',
    },
    {
      name: 'Join Requests',
      description: 'Join request workflow for private groups',
    },
    {
      name: 'Programs',
      description: 'Bible study programs and lessons',
    },
    {
      name: 'Enrollments',
      description: 'Group enrollment in study programs',
    },
    {
      name: 'Activities',
      description: 'Lesson activities (SOAP, OIA, DBS, HEAR, VIDEO)',
    },
    {
      name: 'Activity Progress',
      description: 'Track activity completion',
    },
    {
      name: 'Member Lessons',
      description: 'Member progress through lessons',
    },
    {
      name: 'Notes',
      description: 'Unified notes system for study content',
    },
    {
      name: 'Events',
      description: 'Calendar events and RSVPs',
    },
    {
      name: 'Posts',
      description: 'Group feed posts',
    },
    {
      name: 'Bible',
      description: 'Bible passages and translations',
    },
    {
      name: 'Search',
      description: 'Smart search (direct refs + semantic)',
    },
    {
      name: 'Videos',
      description: 'Cloudflare Stream video management',
    },
    {
      name: 'Media',
      description: 'Media uploads',
    },
    {
      name: 'Organizations',
      description: 'Organization management',
    },
    {
      name: 'Roles',
      description: 'RBAC permissions',
    },
    {
      name: 'Invites',
      description: 'Group invitations',
    },
    {
      name: 'QR Codes',
      description: 'QR code generation',
    },
    {
      name: 'SMS',
      description: 'SMS sending via Twilio',
    },
    {
      name: 'Verification',
      description: 'Twilio Verify SMS verification',
    },
    {
      name: 'Users',
      description: 'User profile management',
    },
    {
      name: 'Account Linking',
      description: 'Bidirectional linking between User (Google OAuth) and Member (phone verified) accounts',
    },
    {
      name: 'Activity Logs',
      description: 'Audit logging (read-only)',
    },
    {
      name: 'Status',
      description: 'Health checks and system status',
    },
    {
      name: 'Public',
      description: 'Public endpoints (OG tags, previews)',
    },
    {
      name: 'Join',
      description: 'Public join pages',
    },
  ],
  components: {
    securitySchemes: {
      userSession: {
        type: 'apiKey',
        in: 'cookie',
        name: 'connect.sid',
        description: 'User session cookie (Google OAuth authenticated users - group leaders)',
      },
      memberSession: {
        type: 'apiKey',
        in: 'cookie',
        name: 'connect.sid',
        description: 'Member session cookie (Phone verified members)',
      },
    },
    schemas: {
      Error: {
        type: 'object',
        properties: {
          success: { type: 'boolean', example: false },
          error: { type: 'string', example: 'Error message' },
        },
      },
      User: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          email: { type: 'string', format: 'email' },
          name: { type: 'string' },
          picture: { type: 'string', format: 'uri', nullable: true },
          googleId: { type: 'string' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Member: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          phoneNumber: { type: 'string', example: '+15551234567' },
          phoneVerified: { type: 'boolean' },
          firstName: { type: 'string', nullable: true },
          lastName: { type: 'string', nullable: true },
          email: { type: 'string', format: 'email', nullable: true },
          birthday: { type: 'string', format: 'date-time', nullable: true },
          profilePicture: { type: 'string', format: 'uri', nullable: true },
          isActive: { type: 'boolean' },
          userId: { type: 'string', format: 'cuid', nullable: true, description: 'Linked User account ID' },
          userLinkedAt: { type: 'string', format: 'date-time', nullable: true, description: 'When account was linked to User' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Group: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          organizationId: { type: 'string', format: 'cuid' },
          code: { type: 'string', example: 'ABC123', description: '6-character join code' },
          name: { type: 'string' },
          description: { type: 'string', nullable: true },
          coverImageUrl: { type: 'string', format: 'uri', nullable: true },
          isPrivate: { type: 'boolean' },
          allowInvites: { type: 'boolean' },
          welcomeMessage: { type: 'string', nullable: true },
          ageRange: {
            type: 'object',
            nullable: true,
            properties: {
              min: { type: 'integer', nullable: true },
              max: { type: 'integer', nullable: true },
            },
          },
          maxMembers: { type: 'integer', nullable: true },
          memberCount: { type: 'integer' },
          creatorId: { type: 'string', format: 'cuid' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      GroupMember: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          groupId: { type: 'string', format: 'cuid' },
          memberId: { type: 'string', format: 'cuid' },
          role: { type: 'string', enum: ['member', 'leader', 'admin'] },
          joinedAt: { type: 'string', format: 'date-time' },
          isActive: { type: 'boolean' },
        },
      },
      Program: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          title: { type: 'string' },
          description: { type: 'string', nullable: true },
          coverImageUrl: { type: 'string', format: 'uri', nullable: true },
          isPublished: { type: 'boolean' },
          lessonCount: { type: 'integer' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Lesson: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          programId: { type: 'string', format: 'cuid' },
          title: { type: 'string' },
          description: { type: 'string', nullable: true },
          orderIndex: { type: 'integer' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Enrollment: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          groupId: { type: 'string', format: 'cuid' },
          programId: { type: 'string', format: 'cuid' },
          currentLessonId: { type: 'string', format: 'cuid', nullable: true },
          startedAt: { type: 'string', format: 'date-time' },
          completedAt: { type: 'string', format: 'date-time', nullable: true },
          isActive: { type: 'boolean' },
        },
      },
      Event: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          groupId: { type: 'string', format: 'cuid' },
          title: { type: 'string' },
          description: { type: 'string', nullable: true },
          startTime: { type: 'string', format: 'date-time' },
          endTime: { type: 'string', format: 'date-time', nullable: true },
          location: { type: 'string', nullable: true },
          isRecurring: { type: 'boolean' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      EventAttendee: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          eventId: { type: 'string', format: 'cuid' },
          memberId: { type: 'string', format: 'cuid' },
          status: { type: 'string', enum: ['pending', 'confirmed', 'declined', 'maybe'] },
          respondedAt: { type: 'string', format: 'date-time', nullable: true },
          createdAt: { type: 'string', format: 'date-time' },
          member: {
            type: 'object',
            nullable: true,
            properties: {
              id: { type: 'string', format: 'cuid' },
              firstName: { type: 'string', nullable: true },
              lastName: { type: 'string', nullable: true },
              profilePicture: { type: 'string', format: 'uri', nullable: true },
            },
          },
        },
      },
      EventAttachment: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          eventId: { type: 'string', format: 'cuid' },
          name: { type: 'string' },
          url: { type: 'string', format: 'uri' },
          type: { type: 'string', example: 'application/pdf' },
          size: { type: 'integer', example: 1024 },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
      Post: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          groupId: { type: 'string', format: 'cuid' },
          authorId: { type: 'string', format: 'cuid' },
          content: { type: 'string' },
          mediaUrls: { type: 'array', items: { type: 'string', format: 'uri' } },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Note: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          memberId: { type: 'string', format: 'cuid' },
          activityId: { type: 'string', format: 'cuid', nullable: true },
          type: { type: 'string', enum: ['soap', 'journal', 'prayer', 'general'] },
          content: { type: 'object' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Organization: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'cuid' },
          name: { type: 'string' },
          ownerId: { type: 'string', format: 'cuid' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
    },
  },
}
