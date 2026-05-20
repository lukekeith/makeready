# Membership & Group Architecture Implementation Summary

**Date:** November 17, 2025
**Status:** Code Complete - Awaiting Database Migration
**PRD Reference:** `/Users/lukekeith/www/makeready/_md/membership-group-schema-prd.md`

---

## 📋 Implementation Status

### ✅ Completed Tasks

1. **Prisma Schema Updated** (`prisma/schema.prisma`)
   - Created `Organization` model with owner relationship
   - Created `Member` model with phone verification fields
   - Added `organizationId` to `User` model
   - Added `organizationId` and `isActive` to `Group` model
   - Added `memberId` and `isActive` to `GroupMember` model
   - All indexes added per PRD specification

2. **Migration Files Created**
   - Migration SQL: `prisma/migrations/20251117233959_add_organizations_and_members/migration.sql`
   - Data migration script: `scripts/migrate-organizations.ts`
   - Both ready to execute when database connection is restored

3. **Authentication Flow Updated** (`src/config/passport.ts`)
   - Auto-creates organization on new user signup
   - Uses transaction to ensure atomic user + organization creation
   - Links user to their organization automatically

4. **Service Layer Created**
   - `src/services/organization.ts` - Organization CRUD and verification
   - `src/services/member.ts` - Member management and group relationships
   - Follows existing service pattern with typed results

5. **Authorization Middleware** (`src/middleware/auth.ts`)
   - `requireAuth` - Basic authentication check
   - `requireOrgOwner` - Verify organization ownership
   - `requireMemberOrOrgOwner` - Member or org owner access
   - `requireGroupAccess` - Group access via organization ownership
   - `requireSameOrganization` - Verify member/group same org

6. **API Routes Created**
   - `src/routes/organizations.ts` - Organization management endpoints
   - `src/routes/members.ts` - Member management and phone verification
   - `src/routes/group-members.ts` - Group membership management
   - All routes mounted in `src/index.ts`

---

## 🗂️ New API Endpoints

### Organization Endpoints

#### `GET /api/organizations/:organizationId`
Get organization details
- **Auth:** Organization owner only
- **Returns:** Organization with owner info

#### `GET /api/organizations/my/organization`
Get current user's organization
- **Auth:** Authenticated user
- **Returns:** User's organization

#### `PATCH /api/organizations/:organizationId`
Update organization name
- **Auth:** Organization owner only
- **Body:** `{ name: string }`
- **Returns:** Updated organization

#### `GET /api/organizations/:organizationId/members`
List all members in organization
- **Auth:** Organization owner only
- **Query:** `?search=query&includeInactive=true`
- **Returns:** Array of members with count

### Member Endpoints

#### `POST /api/members/verify-phone`
Initiate phone verification for member
- **Auth:** Public (for member self-registration)
- **Body:** `{ phoneNumber: string (E.164), organizationId?: string }`
- **Returns:** `{ memberExists: boolean, memberId?: string }`

#### `POST /api/members/confirm-verification`
Confirm verification code and create/update member
- **Auth:** Public
- **Body:** `{ phoneNumber, code, organizationId, firstName?, lastName?, email?, birthday? }`
- **Returns:** Member object

#### `GET /api/members/:memberId`
Get member profile
- **Auth:** Member or organization owner
- **Returns:** Member with organization info

#### `PATCH /api/members/:memberId`
Update member profile
- **Auth:** Member or organization owner
- **Body:** `{ firstName?, lastName?, email?, birthday?, profilePicture? }`
- **Returns:** Updated member

#### `DELETE /api/members/:memberId`
Soft delete member (sets isActive = false)
- **Auth:** Member or organization owner
- **Returns:** Success message
- **Side effect:** Also soft deletes all group memberships

#### `GET /api/members/:memberId/groups`
Get all groups a member belongs to
- **Auth:** Member or organization owner
- **Query:** `?includeInactive=true`
- **Returns:** Array of groups with count

### Group Membership Endpoints

#### `GET /api/groups/:groupId/members`
Get all members in a group
- **Auth:** Group owner (via organization)
- **Query:** `?includeInactive=true`
- **Returns:** Array of members with role and joinedAt

#### `POST /api/groups/:groupId/members`
Add member to group
- **Auth:** Group owner (via organization)
- **Body:** `{ memberId: string, role: 'member' | 'leader' }`
- **Returns:** Success message
- **Validation:** Verifies member and group belong to same organization

#### `DELETE /api/groups/:groupId/members/:memberId`
Remove member from group (soft delete)
- **Auth:** Group owner (via organization)
- **Returns:** Success message

---

## ⚠️ Pending Tasks

### 1. Apply Database Migration

**When database connection is restored:**

```bash
# Option 1: Apply migration using Prisma
npx prisma migrate dev --name add_organizations_and_members

# If drift is detected, you may need to resolve it:
npx prisma migrate resolve --applied 20251117233959_add_organizations_and_members
```

### 2. Run Data Migration

**After schema migration is applied:**

```bash
# Run the data migration script to create organizations for existing users
npx tsx scripts/migrate-organizations.ts
```

**What the script does:**
- Creates an organization for each existing user (if not exists)
- Links users to their organizations
- Updates all groups to belong to creator's organization
- Validates no users or groups are left without organizations

### 3. Enable Foreign Key Constraints

**After data migration completes successfully:**

The migration SQL has commented out these constraints (to allow data migration first):

```sql
-- In migration file, uncomment and run:
ALTER TABLE "users" ADD CONSTRAINT "users_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "groups" ADD CONSTRAINT "groups_organizationId_fkey"
  FOREIGN KEY ("organizationId") REFERENCES "organizations"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
```

### 4. Regenerate Prisma Client

```bash
npx prisma generate
```

### 5. Test All Endpoints

Use Postman or curl to test:
- Organization CRUD operations
- Member creation via phone verification
- Adding/removing members from groups
- Authorization checks (cross-organization access should be denied)

### 6. Update Postman Collection

```bash
# After testing, regenerate Postman collection with new endpoints
# (Custom command or manual update to postman/MakeReady.postman_collection.json)
```

---

## 🏗️ Schema Changes Summary

### New Tables

**`organizations`**
- id (PK), name, ownerId (FK → users), isActive, createdAt, updatedAt
- One organization per user (group leader)
- Owns all members and groups

**`members`**
- id (PK), organizationId (FK → organizations), phoneNumber (unique), phoneVerified, firstName, lastName, email, birthday, profilePicture, isActive, lastVerifiedAt, createdAt, updatedAt
- Separate from users (users = group leaders, members = invited people)

### Modified Tables

**`users`**
- Added: organizationId (FK → organizations, nullable)

**`groups`**
- Added: organizationId (FK → organizations), isActive (default: true)

**`group_members`**
- Added: memberId (FK → members, nullable), isActive (default: true)
- Kept: userId temporarily for migration compatibility
- Will remove userId after full migration to memberId

---

## 🔐 Security & Authorization

### Access Control Model

1. **Organization-Based Access:**
   - Group leaders own exactly one organization
   - All members invited by a group leader belong to that organization
   - Group leaders have full access to all members in their organization

2. **Cross-Organization Protection:**
   - Members cannot be added to groups from different organizations
   - Group leaders cannot access other organizations' data
   - All endpoints validate organization ownership

3. **Member Privacy:**
   - Members can access their own profile
   - Organization owners can access their members' profiles
   - Future: Add member-level authentication for member self-service

### Phone Verification Flow

1. User provides phone number → `POST /api/members/verify-phone`
2. System sends 6-digit code via Twilio
3. User submits code → `POST /api/members/confirm-verification`
4. System creates/updates member with verified phone
5. Member can provide additional profile info (name, birthday, email)

---

## 📊 Data Access Patterns

All queries follow PRD specifications:

```typescript
// Get all members for a group leader (including orphaned)
const members = await getOrganizationMembers(organizationId)

// Get all groups a member belongs to
const groups = await getMemberGroups(memberId)

// Get all members in a specific group
const groupMembers = await getGroupMembers(groupId)

// Add member to group (with organization validation)
await addMemberToGroup(memberId, groupId, role)

// Remove member from group (soft delete)
await removeMemberFromGroup(memberId, groupId)
```

---

## 🧪 Testing Checklist

### When Database is Available

- [ ] Apply schema migration successfully
- [ ] Run data migration script
- [ ] Verify all users have organizations
- [ ] Verify all groups have organizationId
- [ ] Test organization creation on new user signup
- [ ] Test member phone verification flow
- [ ] Test adding member to group
- [ ] Test removing member from group
- [ ] Test cross-organization access denial
- [ ] Test soft delete behavior
- [ ] Test member accessing multiple groups
- [ ] Test orphaned member access (member removed from all groups)
- [ ] Run Prisma generate to regenerate client
- [ ] Update Postman collection
- [ ] Test all endpoints with Postman

### Authorization Tests

- [ ] Verify requireOrgOwner blocks non-owners
- [ ] Verify requireGroupAccess blocks non-org-owners
- [ ] Verify requireSameOrganization blocks cross-org operations
- [ ] Verify requireMemberOrOrgOwner allows member or org owner
- [ ] Test unauthenticated access is blocked

---

## 📝 File Manifest

### Schema & Migrations
- `prisma/schema.prisma` - Updated schema with organizations and members
- `prisma/migrations/20251117233959_add_organizations_and_members/migration.sql` - Migration SQL
- `scripts/migrate-organizations.ts` - Data migration script

### Services
- `src/services/organization.ts` - Organization business logic
- `src/services/member.ts` - Member business logic

### Middleware
- `src/middleware/auth.ts` - Authorization middleware (new file)

### Routes
- `src/routes/organizations.ts` - Organization API endpoints
- `src/routes/members.ts` - Member API endpoints
- `src/routes/group-members.ts` - Group membership API endpoints
- `src/index.ts` - Updated to mount new routes

### Config
- `src/config/passport.ts` - Updated to auto-create organizations

---

## 🚀 Next Steps

1. **Immediate (when database is available):**
   - Apply schema migration
   - Run data migration script
   - Enable foreign key constraints
   - Regenerate Prisma client
   - Test all endpoints

2. **Short-term:**
   - Update Postman collection with new endpoints
   - Write integration tests for new endpoints
   - Add API documentation (OpenAPI/Swagger)

3. **Future Enhancements:**
   - Member-level authentication (members can log in directly)
   - Activity system integration (per PRD future considerations)
   - Communication history tracking
   - Analytics dashboard for group leaders
   - Multi-tier organizations (parent-child relationships)

---

## 🐛 Known Issues

1. **Database Connection Timeout:**
   - Database experiencing connection timeouts
   - Migration files are ready but cannot be applied yet
   - Wait for connection to be restored

2. **Deprecated userId Field:**
   - GroupMember.userId is kept temporarily for migration
   - Should be removed after full migration to memberId
   - Update any existing code that references userId

3. **Member Authentication:**
   - Members currently don't have their own authentication
   - requireMemberOrOrgOwner only checks org owner (member check commented out)
   - Future: Implement member-level sessions

---

## 📚 References

- PRD: `/Users/lukekeith/www/makeready/_md/membership-group-schema-prd.md`
- Architecture Spec: `.project/ARCHITECTURE_SPEC.md`
- Prisma Docs: https://www.prisma.io/docs/
- Railway Docs: https://docs.railway.com

---

## ✅ Sign-off

**Implementation:** Complete (Code Ready)
**Database Migration:** Pending (Connection Issue)
**Testing:** Pending (Awaiting Migration)

All code has been implemented according to the PRD specifications. The system is ready for database migration and testing as soon as the database connection is restored.
