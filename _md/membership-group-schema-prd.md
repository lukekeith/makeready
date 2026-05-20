# Product Requirements Document: Membership & Group Architecture Schema

**Version:** 2.0
**Date:** November 19, 2025
**Status:** Implemented (Many-to-Many Migration Complete)
**Previous Version:** 1.0 (Nov 17, 2025) - One-to-Many Relationship

---

## 1. Executive Summary

This PRD defines the database schema and data architecture for a membership and group management system with **many-to-many member-organization relationships**. The system enables group leaders to manage multiple groups, invite members via SMS, and maintain member relationships across groups through an organization hierarchy.

**Key Feature:** Members can now belong to multiple organizations simultaneously, enabling cross-organization collaboration while maintaining a single member profile and phone number identity.

This architecture provides the foundation for future organizational expansion while maintaining simplicity for current group leader operations.

---

## 2. Problem Statement

The current system supports group leader authentication but lacks the schema to manage:
- Member profiles and phone verification
- Multi-group membership relationships
- Orphaned member access when groups are disbanded
- Future organizational hierarchy expansion

---

## 3. Goals & Objectives

### Primary Goals
1. Support multi-group membership where members can belong to multiple groups
2. Enable group leaders to maintain access to all members they've invited, even if groups are disbanded
3. Establish an invisible organization layer for future scalability
4. Support SMS-based identity verification via phone number

### Non-Goals
- Invite architecture implementation (handled separately)
- Activity management system (future scope)
- Multi-language support (future scope)

---

## 4. Database Schema Design

### 4.1 Schema Overview

The architecture introduces an invisible organization layer where each group leader automatically gets an organization. All members invited by that group leader are associated with their organization, ensuring persistent access regardless of group membership changes.

### 4.2 New Tables

#### **organizations**

Invisible organizational layer that owns all members invited by a group leader. Auto-created when a group leader account is created.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | text | PRIMARY KEY | Unique organization identifier |
| name | text | NOT NULL | Organization name (defaults to group leader name) |
| ownerId | text | NOT NULL, FOREIGN KEY → users(id) | Group leader who owns this organization |
| createdAt | timestamp | NOT NULL, DEFAULT now() | Organization creation timestamp |
| updatedAt | timestamp | NOT NULL, DEFAULT now() | Last update timestamp |
| isActive | boolean | NOT NULL, DEFAULT true | Soft delete flag |

**Indexes:**
- PRIMARY KEY on `id`
- INDEX on `ownerId`
- INDEX on `isActive`

**Relationships:**
- One organization belongs to one user (group leader)
- One organization has many members
- One organization has many groups

---

#### **members**

Represents people invited to groups or activities. Members can belong to multiple organizations through the member_organizations join table.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | text | PRIMARY KEY | Unique member identifier |
| phoneNumber | text | NOT NULL, UNIQUE | Primary identifier for SMS communication |
| phoneVerified | boolean | NOT NULL, DEFAULT false | Whether phone is verified via 6-digit code |
| firstName | text | NULL | Member's first name |
| lastName | text | NULL | Member's last name |
| email | text | NULL | Optional email address |
| birthday | date | NULL | Member's birth date |
| profilePicture | text | NULL | URL to profile picture |
| isActive | boolean | NOT NULL, DEFAULT true | Soft delete flag |
| lastVerifiedAt | timestamp | NULL | Last phone verification timestamp |
| createdAt | timestamp | NOT NULL, DEFAULT now() | Member creation timestamp |
| updatedAt | timestamp | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `phoneNumber`
- INDEX on `isActive`
- INDEX on `phoneNumber`

**Relationships:**
- One member can belong to many organizations (via member_organizations)
- One member can belong to many groups (via group_members)

**Validation Rules:**
- phoneNumber must be in E.164 format (e.g., +11234567890)
- email must be valid email format if provided
- firstName and lastName can be NULL initially, but should be required after first verification

---

#### **member_organizations**

Join table enabling many-to-many relationship between members and organizations. A member can belong to multiple organizations (invited by different group leaders).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | text | PRIMARY KEY | Unique relationship identifier |
| memberId | text | NOT NULL, FOREIGN KEY → members(id) | Member reference |
| organizationId | text | NOT NULL, FOREIGN KEY → organizations(id) | Organization reference |
| joinedAt | timestamp | NOT NULL, DEFAULT now() | When member joined this organization |
| createdAt | timestamp | NOT NULL, DEFAULT now() | Record creation timestamp |
| updatedAt | timestamp | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `(memberId, organizationId)` - Prevents duplicate memberships
- INDEX on `memberId`
- INDEX on `organizationId`

**Relationships:**
- Many members can belong to many organizations
- Cascade delete: Deleting a member or organization removes join table records

**Notes:**
- The unique constraint on (memberId, organizationId) ensures a member can join each organization only once
- joinedAt tracks when the member first joined that organization
- No soft delete flag - membership is either active (record exists) or inactive (record deleted)

---

#### **Modifications to Existing Tables**

#### **users** (modifications)

Add organization relationship for group leaders.

**New Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| organizationId | text | NULL, FOREIGN KEY → organizations(id) | Links user to their auto-created organization |

**Notes:**
- When a new user (group leader) is created, automatically create an organization
- Set the organization's name to the user's name initially
- Link the user to this organization via organizationId

---

#### **groups** (modifications)

Link groups to organizations instead of just users.

**New Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| organizationId | text | NOT NULL, FOREIGN KEY → organizations(id) | Organization this group belongs to |

**Notes:**
- Maintain creatorId for audit purposes
- organizationId defines ownership and member access rights
- Add INDEX on `organizationId`

---

#### **group_members** (modifications)

Update to reference members table instead of direct user references.

**Modified Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | text | PRIMARY KEY | Unique relationship identifier |
| groupId | text | NOT NULL, FOREIGN KEY → groups(id) | Group reference |
| memberId | text | NOT NULL, FOREIGN KEY → members(id) | Member reference (changed from userId) |
| role | text | NOT NULL, DEFAULT 'member' | Member role in group ('member', 'leader') |
| joinedAt | timestamp | NOT NULL, DEFAULT now() | When member joined group |
| isActive | boolean | NOT NULL, DEFAULT true | Soft delete flag for membership |

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `(groupId, memberId)`
- INDEX on `groupId`
- INDEX on `memberId`
- INDEX on `isActive`
- COMPOSITE INDEX on `(groupId, isActive)`

**Notes:**
- Replace userId with memberId to reference members table
- Maintain role field for future permission system
- Add isActive for soft deletes instead of hard deletes

---

### 4.3 Schema Relationships Diagram

```
                    users (group leaders)
                         │
                         │ (1:1)
                         ↓
                   organizations
                    │         │
         (many)     │         │  (many)
    ┌───────────────┘         └────────────┐
    ↓                                      ↓
member_organizations                    groups
    │                                      │
    │ (many)                               │ (many)
    ↓                                      ↓
members ─────────────────────────────> group_members
         (many-to-many via join table)
```

**Key Relationships:**
1. Each group leader (user) has exactly one organization (auto-created, 1:1)
2. Members and organizations have a many-to-many relationship via member_organizations join table
3. A member can belong to multiple organizations (when invited by different group leaders)
4. An organization can have many members (all people invited by that group leader or their team)
5. Each organization has many groups
6. Members can belong to many groups via group_members (many-to-many)
7. Group membership is within the same organization (members and groups must share an organization)

---

## 5. Data Access Patterns

### 5.1 Common Queries

#### Get all members for a group leader (including orphaned members)
```sql
SELECT DISTINCT m.*, mo.joinedAt as organizationJoinedAt
FROM members m
JOIN member_organizations mo ON m.id = mo.memberId
JOIN organizations o ON mo.organizationId = o.id
WHERE o.ownerId = {groupLeaderId}
  AND m.isActive = true
ORDER BY m.lastName, m.firstName;
```

#### Get all organizations a member belongs to
```sql
SELECT o.*, mo.joinedAt
FROM organizations o
JOIN member_organizations mo ON o.id = mo.organizationId
WHERE mo.memberId = {memberId}
  AND o.isActive = true
ORDER BY mo.joinedAt DESC;
```

#### Get all groups a member belongs to
```sql
SELECT g.*
FROM groups g
JOIN group_members gm ON g.id = gm.groupId
WHERE gm.memberId = {memberId}
  AND gm.isActive = true
  AND g.isActive = true
ORDER BY g.name;
```

#### Get all members in a specific group
```sql
SELECT m.*, gm.role, gm.joinedAt
FROM members m
JOIN group_members gm ON m.id = gm.memberId
WHERE gm.groupId = {groupId}
  AND gm.isActive = true
  AND m.isActive = true
ORDER BY gm.joinedAt DESC;
```

#### Get all active members for an organization
```sql
SELECT m.*, mo.joinedAt
FROM members m
JOIN member_organizations mo ON m.id = mo.memberId
WHERE mo.organizationId = {organizationId}
  AND m.isActive = true
ORDER BY m.lastName, m.firstName;
```

#### Find member by phone number and get all their organizations
```sql
SELECT m.*,
  ARRAY_AGG(mo.organizationId) as organizationIds,
  ARRAY_AGG(o.name) as organizationNames
FROM members m
LEFT JOIN member_organizations mo ON m.id = mo.memberId
LEFT JOIN organizations o ON mo.organizationId = o.id
WHERE m.phoneNumber = {phoneNumber}
  AND m.isActive = true
GROUP BY m.id;
```

#### Check if member belongs to a specific organization
```sql
SELECT EXISTS(
  SELECT 1
  FROM member_organizations mo
  WHERE mo.memberId = {memberId}
    AND mo.organizationId = {organizationId}
) as isMember;
```

---

## 6. Business Logic & Rules

### 6.1 Member Creation Flow

1. User receives SMS invite with URL (contains organizationId context)
2. User clicks URL and enters phone number
3. System checks if phone number exists in members table
4. **If member exists:**
   - Send verification code
   - Verify code
   - Check which organizations member currently belongs to (via member_organizations)
   - Return existing member with array of organizationIds
   - If not already in the inviting organization, add relationship to member_organizations
5. **If new member:**
   - Send verification code
   - Verify code
   - Create new member record in members table
   - Create relationship in member_organizations with organizationId from invite context
   - Prompt for firstName, lastName, birthday
6. After verification: Update member record with provided information
7. Member can now be invited to additional organizations (many-to-many)

### 6.2 Organization Rules

**Auto-Creation:**
- When a new user (group leader) account is created, automatically create an organization
- Set organization.name = user.name initially
- Set organization.ownerId = user.id
- Set user.organizationId = organization.id

**Member Association (Many-to-Many):**
- Members can belong to multiple organizations simultaneously
- When a group leader invites a member, a record is created in member_organizations
- If member already exists (has account with another organization), they are simply added to the new organization
- A member can be invited by multiple group leaders and will appear in each of their organizations
- Each organization relationship is tracked independently with its own joinedAt timestamp

**Orphaned Member Access:**
- If a member is removed from all groups within an organization, they remain in the member_organizations table
- Group leader can still access them via member_organizations relationship
- Members retain their profile and can be re-added to groups at any time
- If a member leaves/is removed from all organizations, they remain in members table but have no organization relationships

### 6.3 Group Membership Rules

**Multi-Group Membership:**
- A member can belong to multiple groups within the same organization
- Each group membership is tracked separately in group_members
- Removing a member from one group does not affect their other group memberships

**Soft Deletes:**
- Use isActive flags instead of hard deletes for members, groups, and group memberships
- Maintains data integrity and audit trail
- Allows for potential "undelete" functionality in the future

### 6.4 Phone Verification Rules

- Phone numbers must be unique across the entire system
- Phone numbers are in E.164 format (international format with country code)
- 6-digit verification codes expire after 10 minutes (implementation detail for later)
- phoneVerified flag tracks verification status
- lastVerifiedAt tracks most recent verification for security audit

---

## 7. API Endpoints (Schema-Focused)

The following endpoints are required to support the schema. Implementation details are out of scope but are listed here for completeness.

### 7.1 Member Management

**POST /api/members/verify-phone**
- Initiates phone verification flow
- Body: `{ phoneNumber: "+11234567890", organizationId: "org_abc123" }`
- **Returns (New Member):**
  ```json
  {
    "success": true,
    "memberExists": false,
    "organizations": [],
    "message": "Verification code sent"
  }
  ```
- **Returns (Existing Member):**
  ```json
  {
    "success": true,
    "memberExists": true,
    "memberId": "member_abc123",
    "organizations": ["org_uuid-1", "org_uuid-2"],
    "message": "Verification code sent"
  }
  ```

**POST /api/members/confirm-verification**
- Confirms 6-digit code
- Creates member if new, updates lastVerifiedAt if existing
- If new member, creates relationship in member_organizations
- If existing member not in organization, adds them to member_organizations
- Returns: member object with profile data

**PATCH /api/members/:memberId**
- Updates member profile (firstName, lastName, birthday, email, profilePicture)
- Authorization: Member can only update their own profile

**GET /api/members/:memberId**
- Retrieves member profile
- Authorization: Member themselves or their organization owner (group leader)

**GET /api/organizations/:organizationId/members**
- Lists all members for an organization (via member_organizations join table)
- Authorization: Organization owner (group leader)
- Supports filtering by isActive, search by name/phone
- Returns members with their joinedAt timestamp for this organization

**DELETE /api/members/:memberId**
- Soft deletes member (sets isActive = false)
- Authorization: Organization owner or member themselves
- Also sets isActive = false on all group_members records

---

### 7.2 Group Membership Management

**POST /api/groups/:groupId/members**
- Adds member to group
- Body: { memberId, role }
- Authorization: Group leader (via organizationId)
- Validation: Member must belong to same organization as group (checked via member_organizations)

**GET /api/groups/:groupId/members**
- Lists all members in a group
- Returns: members with their role and joinedAt
- Authorization: Group leader or group members

**DELETE /api/groups/:groupId/members/:memberId**
- Removes member from group (soft delete)
- Authorization: Group leader
- Sets group_members.isActive = false

**GET /api/members/:memberId/groups**
- Lists all groups a member belongs to
- Authorization: Member themselves or organization owner

---

### 7.3 Organization Management

**GET /api/organizations/:organizationId**
- Retrieves organization details
- Authorization: Organization owner

**PATCH /api/organizations/:organizationId**
- Updates organization name
- Authorization: Organization owner

---

## 8. Migration Strategy

### 8.1 Migration Steps

1. **Create organizations table**
2. **Add organizationId to users table**
3. **Create members table** (initially with organizationId for transitional phase)
4. **Add organizationId to groups table**
5. **Create temporary migration script to:**
   - Create organization for each existing user
   - Link users to their organizations
   - Migrate any existing group data to reference organizations
6. **Modify group_members table:**
   - Add memberId column
   - Migrate existing userId references to memberId (if any)
   - Add isActive column
   - Remove userId column (after data migration)
7. **Create member_organizations join table:**
   - Add id, memberId, organizationId, joinedAt columns
   - Add unique constraint on (memberId, organizationId)
   - Add indexes on memberId and organizationId
8. **Migrate to many-to-many relationship:**
   - Copy data from members.organizationId to member_organizations
   - Create one record per member with their current organization
   - Set joinedAt to member.createdAt
   - Verify all members have corresponding records in member_organizations
9. **Drop organizationId column from members table**
   - Only after verifying all data migrated successfully
   - Update application code to use member_organizations join table
   - Deploy application changes before dropping column

### 8.2 Rollback Plan

- Each migration should be reversible
- Maintain backup of database before migration
- Test migrations on staging environment first
- Keep old columns temporarily during transition period

---

## 9. Security & Privacy Considerations

### 9.1 Data Privacy

**Phone Numbers:**
- Store phone numbers encrypted at rest
- Never expose full phone numbers in logs
- Implement rate limiting on phone verification requests

**Member Data:**
- Members can only view/edit their own profile
- Group leaders can view members in their organization
- Members cannot see other members outside their shared groups

### 9.2 Authorization Model

**Organization-Based Access:**
- Group leaders have full access to all members in their organization
- Group leaders can only access groups in their organization
- Members can only access their own data and groups they belong to

**API Authorization Checks:**
- Every API endpoint must verify organizationId ownership
- Prevent cross-organization data access
- Validate member-to-group relationships before operations

---

## 10. Scalability Considerations

### 10.1 Indexing Strategy

The schema includes indexes optimized for:
- Organization-based member queries (most common)
- Group membership lookups
- Phone number uniqueness and lookup
- Soft delete filtering (isActive flags)

### 10.2 Future Expansion Support

**Many-to-Many Member-Organization Relationship (✅ Implemented):**
- Members can now belong to multiple organizations simultaneously
- Implemented via member_organizations join table
- Enables cross-organization collaboration scenarios
- Members maintain a single profile across all organizations they belong to

**Multi-Tier Organizations:**
- The current schema supports adding a parent-child relationship in organizations table
- Add parentOrganizationId column for hierarchical organizations
- Maintain backward compatibility with current "flat" structure

**Member Permissions:**
- Current role field in group_members can be expanded
- Future: Add permissions table for fine-grained access control
- Can add role field to member_organizations for organization-level permissions

**Cross-Organization Collaboration:**
- The many-to-many relationship enables members to participate in multiple organizations
- Future enhancements could include shared groups across organizations
- Member privacy settings to control visibility across organizations

---

## 11. Testing Requirements

### 11.1 Schema Validation Tests

- Verify all foreign key constraints work correctly
- Test cascade behavior on soft deletes
- Validate unique constraints (phone numbers)
- Test concurrent member creation with same phone number

### 11.2 Data Integrity Tests

- Orphaned member access after group deletion
- Multi-group membership scenarios
- Organization auto-creation on user signup
- Phone number uniqueness across organizations

### 11.3 Query Performance Tests

- Benchmark organization member queries with 1000+ members
- Test group membership queries with 100+ groups
- Validate index effectiveness on filtered queries

---

## 12. Success Metrics

### 12.1 Schema Metrics

- Support for 10,000+ members per organization
- Query response time < 100ms for member lookups
- Support for members in 50+ groups simultaneously
- Zero data loss on group deletions (orphaned members retained)

### 12.2 Data Quality Metrics

- 100% of members have valid phone numbers
- 95%+ phone verification rate
- 90%+ profile completion rate (name + birthday)

---

## 13. Open Questions & Future Considerations

### 13.1 Open Questions

1. ~~Should members be able to transfer between organizations?~~ **✅ Resolved:** Members can now belong to multiple organizations via many-to-many relationship
2. What happens if a group leader deletes their account? Transfer organization ownership?
3. Should we enforce a maximum number of groups per organization?
4. Should we enforce a maximum number of organizations a member can belong to?
5. Do we need member privacy settings (hide from other members)?
6. Should members have different roles in different organizations (via member_organizations.role)?

### 13.2 Future Considerations

**Activities System:**
- Add activities table linked to organizations
- Support activity invites separate from group membership
- Track activity participation separate from group membership

**Communication History:**
- Add message_logs table to track SMS communications
- Enable group leaders to see communication history
- Support communication preferences per member

**Analytics:**
- Member engagement tracking
- Group activity metrics
- Organization growth statistics

---

## 14. Appendix

### 14.1 Glossary

- **Group Leader:** A user who manages groups and invites members
- **Member:** A person invited to participate in groups or activities
- **Organization:** An invisible container that owns all members invited by a group leader
- **Orphaned Member:** A member who is not currently in any active group but remains accessible
- **Soft Delete:** Setting isActive = false instead of removing records

### 14.2 References

- Current schema visible in Prisma migrations
- E.164 phone format: https://en.wikipedia.org/wiki/E.164
- SMS verification best practices: Industry standard 6-digit codes with 10-minute expiry

---

## 15. Approval & Sign-off

**Document Owner:** [Your Name]  
**Technical Review:** [Pending]  
**Product Review:** [Pending]  
**Security Review:** [Pending]

---

**Document History:**
- v2.0 (Nov 19, 2025): Updated to reflect many-to-many member-organization relationship implementation
  - Added member_organizations join table
  - Removed organizationId from members table
  - Updated all queries to use join table
  - Updated API endpoints documentation
  - Updated business logic and migration strategy
- v1.0 (Nov 17, 2025): Initial draft with one-to-many relationship
