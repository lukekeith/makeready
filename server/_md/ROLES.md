# MakeReady RBAC System Documentation

## Overview

MakeReady implements a comprehensive **Role-Based Access Control (RBAC)** system that provides granular permission management for organizations, groups, members, and content. The system supports both system-defined roles and custom organizational roles, with permission inheritance and flexible assignment capabilities.

### Key Features

- **5 System Roles**: Pre-configured roles with appropriate permissions
- **24 Permissions**: Granular access control across 5 resource types
- **Permission Inheritance**: Organization-level roles automatically apply to all groups
- **Platform-wide Super Admin**: Bypasses all permission checks
- **Custom Roles**: Organizations can create custom roles with specific permissions
- **Dual Authentication**: User (OAuth) vs Member (phone verification)
- **Content Visibility**: Three-tier system (public, members, group)
- **Creator Ownership**: Content creators can modify their own content

---

## Database Schema

### Core RBAC Models

```prisma
model Role {
  id             String           @id @default(uuid())
  name           String           // "Owner", "Admin", "Group Leader", etc.
  description    String?
  organizationId String?          // NULL for system roles
  isSystem       Boolean          @default(false)
  permissions    RolePermission[]
  userRoles      UserRole[]
  @@unique([name, organizationId])
}

model Permission {
  id          String           @id @default(uuid())
  resource    String           // "organization", "group", "member", "media", "role"
  action      String           // "create", "read", "update", "delete", "invite", "publish"
  name        String           @unique // "organization.update", "event.create"
  description String?
  roles       RolePermission[]
}

model UserRole {
  id             String       @id @default(uuid())
  userId         String
  roleId         String
  organizationId String       // Scope of this role assignment
  assignedAt     DateTime     @default(now())
  assignedBy     String?      // User ID who assigned this role
  @@unique([userId, roleId, organizationId])
}
```

---

## System Roles

### 1. Super Admin
**Platform-wide administrator with unlimited access**

- **Scope**: Platform-wide (not organization-specific)
- **Set via**: `User.isSuperAdmin = true` (database field)
- **Permissions**: ALL - Bypasses all permission checks
- **Use Case**: Platform operators, system maintenance
- **Special Note**: Not assignable via API, must be set directly in database

### 2. Owner
**Organization owner with full control**

- **Scope**: Per-organization
- **Permissions**: 21 total
  - **Organization**: read, update, delete, invite
  - **Groups**: create, read, update, delete, invite
  - **Members**: create, read, update, delete
  - **Media**: create, read, update, delete, publish
  - **Roles**: create, read, update, delete, assign

- **Use Case**: Primary organization administrator
- **Auto-assigned**: When user creates organization (`Organization.ownerId` → `UserRole`)
- **Multiple Allowed**: Yes - organizations can have multiple Owners

### 3. Admin
**Organization administrator with most permissions**

- **Scope**: Per-organization
- **Permissions**: 19 total (all Owner permissions except `organization.delete` and `role.create`)
  - **Organization**: read, update, invite (no delete)
  - **Groups**: create, read, update, delete, invite
  - **Members**: create, read, update, delete
  - **Media**: create, read, update, delete, publish
  - **Roles**: read, assign (no create/update/delete)

- **Use Case**: Trusted administrators who shouldn't delete the organization
- **Limitations**: Cannot delete organization, cannot create custom roles

### 4. Group Leader
**Can manage groups and create content**

- **Scope**: Per-organization
- **Permissions**: 13 total
  - **Groups**: read, update, invite (no create/delete)
  - **Members**: read, update (within groups only)
  - **Media**: create, read, update, delete, publish

- **Use Case**: Small group leaders, ministry leaders, team captains
- **Ideal For**: Users who manage specific groups but not the whole organization

### 5. Contributor
**Can create content but cannot delete or modify others' content**

- **Scope**: Per-organization
- **Permissions**: 4 total
  - **Groups**: read
  - **Members**: read
  - **Media**: create, read

- **Use Case**: Content creators, volunteers, assistants
- **Note**: Can only modify their own content (via creator ownership check)

---

## Permissions Reference

### Resource Types

| Resource | Description |
|----------|-------------|
| `organization` | Organization settings and configuration |
| `group` | Groups within organizations |
| `member` | Members (phone-authenticated users) |
| `media` | Photos, videos, documents |
| `role` | Role management and assignment |

### Actions

| Action | Description | Resources |
|--------|-------------|-----------|
| `create` | Create new resources | All except organization |
| `read` | View resource details | All |
| `update` | Modify existing resources | All |
| `delete` | Remove resources | All |
| `invite` | Invite users/members | organization, group |
| `publish` | Publish content to members | media |
| `assign` | Assign roles to users | role |

### Complete Permission List (24 Total)

**Organization (5)**
- `organization.create` - Create new organizations
- `organization.read` - View organization details
- `organization.update` - Update organization settings
- `organization.delete` - Delete organization
- `organization.invite` - Invite users to organization

**Group (5)**
- `group.create` - Create new groups
- `group.read` - View group details
- `group.update` - Update group settings
- `group.delete` - Delete groups
- `group.invite` - Invite members to groups

**Member (4)**
- `member.create` - Add new members
- `member.read` - View member details
- `member.update` - Update member information
- `member.delete` - Remove members

**Media (5)**
- `media.create` - Upload media files
- `media.read` - View media files
- `media.update` - Update media metadata
- `media.delete` - Delete media files
- `media.publish` - Publish media to members

**Role (5)**
- `role.create` - Create custom roles
- `role.read` - View roles
- `role.update` - Update role permissions
- `role.delete` - Delete custom roles
- `role.assign` - Assign roles to users

---

## Permission Checking

### How Permissions Work

1. **User must be authenticated** (`requireAuth`)
2. **User must have role** in the target organization
3. **Role must have permission** for the requested action
4. **OR user is Super Admin** (bypasses all checks)
5. **OR user is content creator** (for modify operations only)

### Permission Middleware

#### `requirePermission(permission, resourceType, getResourceId)`

Dynamic permission checking middleware factory.

```typescript
// Example: Require permission to create events in an organization
router.post(
  '/organizations/:orgId/events',
  requireAuth,
  requirePermission('event.create', 'organization', (req) => req.params.orgId),
  createEvent
)

// Example: Require permission to update a specific event
router.patch(
  '/events/:eventId',
  requireAuth,
  requirePermission('event.update', 'event', (req) => req.params.eventId),
  updateEvent
)
```

**Parameters:**
- `permission`: Permission name (e.g., "event.create")
- `resourceType`: Type of resource ("organization", "group", "event", etc.)
- `getResourceId`: Function to extract resource ID from request

**Flow:**
1. Extracts `userId` from `req.user`
2. Checks if user is Super Admin → Allow
3. Gets resource's organization ID
4. Gets user's roles in that organization
5. Checks if any role has the required permission
6. Returns 403 if no permission found

#### `requireModifyPermission(contentType, getContentId)`

Allows content modification if user has update permission OR is the creator.

```typescript
// Example: Allow update if user has permission OR is creator
router.patch(
  '/events/:eventId',
  requireAuth,
  requireModifyPermission('event', (req) => req.params.eventId),
  updateEvent
)
```

**Flow:**
1. Checks if user has `{contentType}.update` permission
2. If not, checks if user is the content creator
3. Allows if either condition is true

#### `requireMemberContentAccess(contentType, getContentId)`

Member access validation for SMS link viewing.

```typescript
// Example: Member views event via SMS link
router.get(
  '/member/events/:eventId',
  requireMemberAuth,
  requireMemberContentAccess('event', (req) => req.params.eventId),
  viewEvent
)
```

**Flow:**
1. Checks if member is authenticated (phone verified)
2. Gets content visibility level
3. If `public` → Allow
4. If `members` → Check member belongs to organization
5. If `group` → Check member belongs to specific group

---

## Content Visibility System

### Visibility Levels

| Level | Description | Who Can Access |
|-------|-------------|----------------|
| `public` | Anyone can view | All members, even without organization membership |
| `members` | Organization members only | Members who belong to the organization |
| `group` | Specific group only | Members who belong to the specific group |

### Member Access Rules

**Members (phone-authenticated users) can access content via SMS links:**

1. **Public Content**: Always accessible (no authentication required in some cases)
2. **Members-Only Content**: Must belong to the organization
3. **Group-Specific Content**: Must belong to the specific group

**Example Flow:**
```
1. Organization creates event with visibility="group" and groupId="group-123"
2. System generates SMS link: makeready://event/event-456
3. Member clicks link → Verifies phone → System checks:
   - Is member in group-123? YES → Show event
   - Is member in group-123? NO → Error: "Join the group first"
```

---

## API Endpoints

### Role Management

#### List Roles
```http
GET /api/organizations/:organizationId/roles
Authorization: Requires 'role.read' permission

Response:
{
  "success": true,
  "data": [
    {
      "id": "role-123",
      "name": "Owner",
      "description": "Full organizational control",
      "isSystem": true,
      "permissions": [...],
      "_count": { "userRoles": 2 }
    }
  ],
  "count": 5
}
```

#### Get Role Details
```http
GET /api/organizations/:organizationId/roles/:roleId
Authorization: Requires 'role.read' permission

Response:
{
  "success": true,
  "data": {
    "id": "role-123",
    "name": "Owner",
    "permissions": [
      { "id": "perm-1", "name": "organization.read", "resource": "organization", "action": "read" }
    ],
    "userRoles": [
      { "userId": "user-456", "user": { "name": "John Doe", "email": "john@example.com" } }
    ]
  }
}
```

#### Create Custom Role
```http
POST /api/organizations/:organizationId/roles
Authorization: Requires 'role.create' permission

Body:
{
  "name": "Ministry Leader",
  "description": "Can manage ministry groups and content"
}

Response:
{
  "success": true,
  "data": {
    "id": "role-789",
    "name": "Ministry Leader",
    "isSystem": false,
    "organizationId": "org-123"
  }
}
```

#### Update Custom Role
```http
PATCH /api/organizations/:organizationId/roles/:roleId
Authorization: Requires 'role.update' permission

Body:
{
  "name": "Updated Role Name",
  "description": "Updated description"
}

Note: System roles cannot be modified
```

#### Delete Custom Role
```http
DELETE /api/organizations/:organizationId/roles/:roleId
Authorization: Requires 'role.delete' permission

Response:
{
  "success": true,
  "data": { "message": "Role deleted successfully" }
}

Note:
- System roles cannot be deleted
- Cannot delete roles with assigned users
```

### Permission Management

#### List All Permissions
```http
GET /api/permissions
Authorization: Requires authentication

Response:
{
  "success": true,
  "data": [
    {
      "id": "perm-1",
      "resource": "organization",
      "action": "read",
      "name": "organization.read",
      "description": "View organization details"
    }
  ],
  "count": 24
}
```

#### Get Role Permissions
```http
GET /api/organizations/:organizationId/roles/:roleId/permissions
Authorization: Requires 'role.read' permission

Response:
{
  "success": true,
  "data": [
    { "id": "perm-1", "name": "group.read" },
    { "id": "perm-2", "name": "group.update" }
  ],
  "count": 2
}
```

#### Update Role Permissions
```http
PUT /api/organizations/:organizationId/roles/:roleId/permissions
Authorization: Requires 'role.update' permission

Body:
{
  "permissionIds": ["perm-1", "perm-2", "perm-3"]
}

Response:
{
  "success": true,
  "data": [
    { "id": "perm-1", "name": "group.read" },
    { "id": "perm-2", "name": "group.update" },
    { "id": "perm-3", "name": "member.read" }
  ]
}

Note: System roles cannot be modified
```

### User Role Assignment

#### Get User Roles
```http
GET /api/organizations/:organizationId/users/:userId/roles
Authorization: Requires 'role.read' permission

Response:
{
  "success": true,
  "data": [
    {
      "id": "user-role-1",
      "userId": "user-123",
      "roleId": "role-456",
      "organizationId": "org-789",
      "assignedAt": "2025-01-15T12:00:00Z",
      "role": {
        "name": "Admin",
        "permissions": [...]
      }
    }
  ],
  "count": 2
}
```

#### Assign Role to User
```http
POST /api/organizations/:organizationId/users/:userId/roles
Authorization: Requires 'role.assign' permission

Body:
{
  "roleId": "role-456"
}

Response:
{
  "success": true,
  "data": {
    "id": "user-role-123",
    "userId": "user-456",
    "roleId": "role-789",
    "organizationId": "org-123",
    "assignedBy": "user-admin",
    "role": { "name": "Group Leader" },
    "user": { "name": "Jane Doe", "email": "jane@example.com" }
  }
}
```

#### Remove Role from User
```http
DELETE /api/organizations/:organizationId/users/:userId/roles/:roleId
Authorization: Requires 'role.assign' permission

Response:
{
  "success": true,
  "data": { "message": "Role removed successfully" }
}
```

#### Get Users with Specific Role
```http
GET /api/organizations/:organizationId/roles/:roleId/users
Authorization: Requires 'role.read' permission

Response:
{
  "success": true,
  "data": [
    {
      "userId": "user-123",
      "user": {
        "id": "user-123",
        "name": "John Doe",
        "email": "john@example.com",
        "picture": "https://..."
      },
      "role": { "name": "Admin" }
    }
  ],
  "count": 3
}
```

---

## Usage Examples

### Example 1: Organization Setup

```javascript
// 1. User creates organization (auto-assigned Owner role)
POST /api/organizations
{
  "name": "Grace Church"
}

// 2. Owner assigns Admin role to another user
POST /api/organizations/org-123/users/user-456/roles
{
  "roleId": "admin-role-id"
}

// 3. Owner creates custom "Ministry Leader" role
POST /api/organizations/org-123/roles
{
  "name": "Ministry Leader",
  "description": "Manages ministry groups"
}

// 4. Get all permissions to assign to custom role
GET /api/permissions

// 5. Assign specific permissions to custom role
PUT /api/organizations/org-123/roles/custom-role-id/permissions
{
  "permissionIds": [
    "group.read",
    "group.update",
    "group.invite",
    "member.read",
    "media.create",
    "media.read"
  ]
}

// 6. Assign custom role to ministry leaders
POST /api/organizations/org-123/users/user-789/roles
{
  "roleId": "custom-role-id"
}
```

### Example 2: Permission Checking in Routes

```typescript
import { Router } from 'express'
import { requireAuth, requirePermission } from '../middleware/auth.js'

const router = Router()

// Only users with 'group.create' permission can create groups
router.post(
  '/organizations/:orgId/groups',
  requireAuth,
  requirePermission('group.create', 'organization', (req) => req.params.orgId),
  async (req, res) => {
    // Create group logic
  }
)

// Only users with 'member.read' permission can list members
router.get(
  '/organizations/:orgId/members',
  requireAuth,
  requirePermission('member.read', 'organization', (req) => req.params.orgId),
  async (req, res) => {
    // List members logic
  }
)

// Users with 'media.update' OR creators can update media
router.patch(
  '/media/:mediaId',
  requireAuth,
  requireModifyPermission('media', (req) => req.params.mediaId),
  async (req, res) => {
    // Update media logic
  }
)
```

### Example 3: Member Content Access

```typescript
// Member clicks SMS link to view event
// URL: makeready://event/event-123

// Backend route:
router.get(
  '/member/events/:eventId',
  requireMemberAuth,
  requireMemberContentAccess('event', (req) => req.params.eventId),
  async (req, res) => {
    // Return event details
    const event = await getEvent(req.params.eventId)
    res.json({ success: true, data: event })
  }
)

// Access Flow:
// 1. Member verifies phone → memberId stored in session
// 2. Middleware checks event.visibility:
//    - "public" → Allow
//    - "members" → Check member belongs to event.organizationId
//    - "group" → Check member belongs to event.groupId
// 3. If allowed → Return event data
// 4. If denied → 403 "You do not have access to this content"
```

---

## Permission Inheritance

### Organization → Groups

**Key Concept**: Organization-level roles automatically apply to all groups within that organization.

```
Example:
- User has "Admin" role in Organization A
- Admin role has "group.update" permission
- User can update ALL groups in Organization A (group-1, group-2, group-3, etc.)
```

**No explicit group-level role assignment needed** - organization permissions cascade down.

### Why This Matters

1. **Simplicity**: Assign role once at org level, works everywhere
2. **Consistency**: Admins have same permissions across all groups
3. **Scalability**: Add 100 groups, permissions still work

---

## Custom Roles

### When to Create Custom Roles

- **Delegation**: Need to delegate specific responsibilities
- **Least Privilege**: Users should only have permissions they need
- **Complex Organizations**: Multiple leadership tiers

### Custom Role Workflow

```javascript
// 1. Create custom role
POST /api/organizations/org-123/roles
{
  "name": "Youth Leader",
  "description": "Manages youth ministry groups and content"
}

// 2. Assign specific permissions
PUT /api/organizations/org-123/roles/custom-role-id/permissions
{
  "permissionIds": [
    "group.read",
    "group.update",    // Can update groups
    "group.invite",    // Can invite members
    "member.read",     // Can view members
    "media.create",    // Can upload media
    "media.read",      // Can view media
    "media.update",    // Can edit media
    "media.publish"    // Can publish media
  ]
}

// 3. Assign to users
POST /api/organizations/org-123/users/user-456/roles
{
  "roleId": "custom-role-id"
}
```

### Custom Role Limitations

- **Cannot modify system roles** (Owner, Admin, Group Leader, Contributor, Super Admin)
- **Cannot delete roles with assigned users** - must remove all users first
- **Organization-scoped** - custom roles only work within their organization

---

## Migration Guide

### Migrating Existing Organizations

The seed script (`prisma/seed.ts`) automatically migrates existing organizations:

```typescript
// Finds all organizations with ownerId
// Creates UserRole record with "Owner" role
// Migration is idempotent (safe to run multiple times)

Example:
Organization: { id: "org-123", ownerId: "user-456" }
↓
UserRole: {
  userId: "user-456",
  roleId: "owner-role-id",
  organizationId: "org-123"
}
```

**Run migration:**
```bash
npx prisma db seed
```

### Backward Compatibility

- `Organization.ownerId` field **retained** but deprecated
- `User.organizationId` field **retained** but deprecated
- Old middleware (`requireOrgOwner`) replaced with `requirePermission`
- All existing functionality preserved

---

## Best Practices

### 1. Assign Minimal Permissions
Only grant permissions users actually need. Start restrictive, add permissions as needed.

### 2. Use System Roles When Possible
System roles cover most common use cases. Create custom roles only when necessary.

### 3. Regular Permission Audits
Periodically review who has which roles:
```http
GET /api/organizations/:orgId/roles/:roleId/users
```

### 4. Document Custom Roles
When creating custom roles, use clear names and descriptions:
```javascript
{
  "name": "Sunday School Coordinator",  // Clear, specific
  "description": "Manages Sunday school groups, creates content, views attendance"
}
```

### 5. Test Permission Changes
Before assigning new permissions, test with a non-admin account.

### 6. Use Creator Ownership
For content modification, use `requireModifyPermission` to allow creators to edit their own content without needing broad permissions.

---

## Troubleshooting

### "Insufficient permissions" Error

**Cause**: User doesn't have required permission

**Check:**
1. Does user have a role in this organization?
   ```http
   GET /api/organizations/:orgId/users/:userId/roles
   ```

2. Does the role have the required permission?
   ```http
   GET /api/organizations/:orgId/roles/:roleId/permissions
   ```

3. Is the permission spelled correctly?
   ```http
   GET /api/permissions
   ```

### User Can't Access Organization

**Cause**: User doesn't have any role in the organization

**Fix**: Assign a role
```http
POST /api/organizations/:orgId/users/:userId/roles
{ "roleId": "..." }
```

### Can't Delete Custom Role

**Cause**: Role has users assigned

**Fix**: Remove all users first
```http
GET /api/organizations/:orgId/roles/:roleId/users
# For each user:
DELETE /api/organizations/:orgId/users/:userId/roles/:roleId
# Then delete role:
DELETE /api/organizations/:orgId/roles/:roleId
```

### Can't Modify System Role

**Cause**: System roles are protected

**Fix**: Create a custom role instead
```http
POST /api/organizations/:orgId/roles
{
  "name": "Custom Admin",
  "description": "Admin with specific permissions"
}
```

---

## Future Enhancements

### Planned Features

- [ ] **Group-Level Roles**: Assign roles specific to individual groups
- [ ] **Time-Based Permissions**: Temporary role assignments with expiration
- [ ] **Permission Templates**: Pre-configured permission sets for common scenarios
- [ ] **Audit Logs**: Track all permission changes and role assignments
- [ ] **Bulk Operations**: Assign/remove roles for multiple users at once
- [ ] **Permission Requests**: Users can request specific permissions from admins
- [ ] **Resource-Level Permissions**: Fine-grained control per individual resource

---

## Technical Reference

### Service Layer

**`src/services/permission.ts`**
- `hasPermission()` - Check if user has specific permission
- `canMemberAccessContent()` - Check if member can view content
- `canModifyContent()` - Check if user can modify content
- `isSuperAdmin()` - Check if user is platform admin
- `getUserRolesForOrg()` - Get user's roles in organization
- `getPermissionsForRole()` - Get all permissions for a role

**`src/services/role.ts`**
- `getOrganizationRoles()` - List all roles for organization
- `createRole()` - Create custom role
- `updateRole()` - Update role name/description
- `deleteRole()` - Delete custom role
- `assignRole()` - Assign role to user
- `removeRole()` - Remove role from user
- `updateRolePermissions()` - Update role's permissions

**`src/services/content.ts`**
- Media CRUD operations with permission checks

### Middleware Layer

**`src/middleware/auth.ts`**
- `requireAuth` - Require user authentication
- `requireMemberAuth` - Require member authentication
- `requirePermission()` - Check specific permission
- `requireModifyPermission()` - Check modify permission OR ownership
- `requireMemberContentAccess()` - Check member content access

### Route Layer

**`src/routes/roles.ts`** - Role management API
**`src/routes/media.ts`** - Media management API
**`src/routes/organizations.ts`** - Organization API (updated with permissions)
**`src/routes/group-members.ts`** - Group member API (updated with permissions)

---

## Database Schema Reference

### Seed Data

**Run seed:**
```bash
npx prisma db seed
```

**What it creates:**
- 24 permissions across 5 resource types
- 5 system roles with permission mappings
- Migrates existing organization owners to UserRole
- Safe to run multiple times (idempotent)

**Seed file:** `prisma/seed.ts`

### Schema File

**Location:** `prisma/schema.prisma`

**Key Models:**
- `Role` - Role definitions
- `Permission` - Permission definitions
- `RolePermission` - Role-Permission mapping
- `UserRole` - User-Role-Organization assignments
- `Media` - Content with visibility levels

---

## Support

For questions or issues:
1. Check this documentation first
2. Review API endpoint examples
3. Test with Postman collection
4. Check server logs for permission errors
5. Verify role assignments and permissions

**Permission Logs:**
The permission service logs all checks to console:
- `✅ [Permission] User {userId} has permission "{permission}"` - Granted
- `❌ [Permission] User {userId} does not have permission "{permission}"` - Denied
- `✅ [Member Access] Content is public - GRANTED` - Public content
- `❌ [Member Access] Member does not belong to organization - DENIED` - Access denied

---

**Last Updated**: January 2025
**Version**: 1.0.0
**System**: MakeReady RBAC
