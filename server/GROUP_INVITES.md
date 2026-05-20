# Group Invites Flow Documentation

Complete documentation for the MakeReady group invite system with SMS verification.

## 🎯 Overview

The group invite flow allows group leaders to invite members via SMS. Members receive a link, view group details, and verify their phone number before joining.

## 📊 Database Models

### Group
```prisma
model Group {
  id          String   @id @default(uuid())
  name        String
  description String?
  creatorId   String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  creator User
  members GroupMember[]
  invites Invite[]
}
```

### GroupMember
```prisma
model GroupMember {
  id        String   @id @default(uuid())
  groupId   String
  userId    String
  role      String   @default("member") // "admin", "member"
  joinedAt  DateTime @default(now())

  group Group
  user  User

  @@unique([groupId, userId])
}
```

### Invite
```prisma
model Invite {
  id             String    @id @default(uuid())
  token          String    @unique
  groupId        String
  inviterId      String
  recipientPhone String
  status         String    @default("pending") // "pending", "accepted", "expired"
  expiresAt      DateTime
  createdAt      DateTime  @default(now())
  acceptedAt     DateTime?

  group   Group
  inviter User
}
```

## 🔄 Complete User Flow

### Step 1: Group Leader Sends Invite

**Mobile App:**
```typescript
// User clicks "Invite Member" button
// Enters phone number or selects from contacts

const response = await fetch('http://localhost:3001/api/invites/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Cookie': sessionCookie, // Must be authenticated
  },
  body: JSON.stringify({
    groupId: '42a6006e-18ce-429d-8cc7-0d708e17fcf2',
    recipientPhone: '+12148623686',
  }),
});

const result = await response.json();
// {
//   success: true,
//   inviteId: "xxx",
//   inviteUrl: "http://localhost:5173/invite?token=xxx&phone=+12148623686",
//   message: "Invite sent successfully"
// }
```

**What Happens:**
- Server validates user is a member of the group
- Generates secure random token (32 chars)
- Creates invite record in database (expires in 7 days)
- Sends SMS via Twilio Programmable SMS:
  ```
  Luke Keith invited you to join "Test Group" on MakeReady! Tap here to join: http://localhost:5173/invite?token=xxx&phone=+12148623686. Msg & data rates may apply. Reply STOP to opt out, HELP for help.
  ```

### Step 2: Member Receives SMS and Clicks Link

**SMS Message:**
```
Luke Keith invited you to join "Test Group" on MakeReady! Tap here to join: http://localhost:5173/invite?token=abc123&phone=+12148623686. Msg & data rates may apply. Reply STOP to opt out, HELP for help.
```

**Web Page Opens:**
```
URL: http://localhost:5173/invite?token=abc123&phone=+12148623686
```

### Step 3: View Invite Details

**Frontend calls:**
```typescript
const response = await fetch(`http://localhost:3001/api/invites/${token}`);
const result = await response.json();

// {
//   success: true,
//   invite: {
//     id: "xxx",
//     token: "abc123",
//     recipientPhone: "+12148623686",
//     expiresAt: "2025-11-09T00:00:00.000Z",
//     group: {
//       id: "42a6006e-18ce-429d-8cc7-0d708e17fcf2",
//       name: "Test Group",
//       description: "A test group for invite flow"
//     },
//     inviter: {
//       id: "57ed656d-acc0-4dcf-a9dd-c655f01e7b06",
//       name: "Luke Keith",
//       picture: "https://..."
//     }
//   }
// }
```

**Page Shows:**
- Group name and description
- Inviter's name and photo
- "Join Group" button

### Step 4: Member Clicks "Join" Button

**Frontend sends verification code:**
```typescript
// User clicks "Join" button
const response = await fetch('http://localhost:3001/api/verification/send', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    phoneNumber: '+12148623686', // From URL param
  }),
});

// { success: true, message: "Verification code sent successfully" }
```

**What Happens:**
- Twilio Verify API generates 6-digit code
- Sends SMS to member's phone:
  ```
  Your verification code is 830160
  ```

### Step 5: Member Enters Verification Code

**UI shows:**
- Input field for 6-digit code
- "Verify" button

**Frontend submits code:**
```typescript
const response = await fetch('http://localhost:3001/api/verification/verify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    phoneNumber: '+12148623686',
    code: '830160',
    inviteToken: 'abc123', // ← Key part!
  }),
});

const result = await response.json();
// {
//   success: true,
//   valid: true,
//   message: "Phone number verified successfully",
//   userId: "new-user-id",
//   groupId: "42a6006e-18ce-429d-8cc7-0d708e17fcf2"
// }
```

**What Happens:**
1. ✅ Twilio verifies the code is correct
2. ✅ Check if user exists with this phone number
3. ✅ If no user → Create new user account
4. ✅ Accept invite → Add user to group
5. ✅ Return userId and groupId

### Step 6: Redirect to Group Page

**Frontend:**
```typescript
if (result.success && result.groupId) {
  // Redirect to group page
  window.location.href = `/groups/${result.groupId}`;
}
```

## 🔌 API Endpoints

### POST /api/invites/send
Send group invitation via SMS.

**Authentication:** Required

**Request:**
```json
{
  "groupId": "uuid",
  "recipientPhone": "+12148623686"
}
```

**Response:**
```json
{
  "success": true,
  "inviteId": "uuid",
  "inviteUrl": "http://localhost:5173/invite?token=xxx&phone=+12148623686",
  "message": "Invite sent successfully"
}
```

**Errors:**
- 401: Not authenticated
- 403: Not a member of the group
- 404: Group not found
- 400: Invalid phone number or SMS failed

---

### GET /api/invites/:token
Get invite details by token.

**Authentication:** None (public link)

**Response:**
```json
{
  "success": true,
  "invite": {
    "id": "uuid",
    "token": "abc123",
    "recipientPhone": "+12148623686",
    "expiresAt": "2025-11-09T00:00:00.000Z",
    "group": {
      "id": "uuid",
      "name": "Test Group",
      "description": "A test group"
    },
    "inviter": {
      "id": "uuid",
      "name": "Luke Keith",
      "picture": "https://..."
    }
  }
}
```

**Errors:**
- 404: Invite not found or expired

---

### POST /api/verification/verify (Enhanced)
Verify phone and optionally accept invite.

**Authentication:** Optional

**Request:**
```json
{
  "phoneNumber": "+12148623686",
  "code": "830160",
  "inviteToken": "abc123"
}
```

**Response:**
```json
{
  "success": true,
  "valid": true,
  "message": "Phone number verified successfully",
  "userId": "uuid",
  "groupId": "uuid"
}
```

**What It Does:**
1. Verifies code with Twilio
2. Creates user if doesn't exist
3. Accepts invite and adds to group
4. Returns user and group IDs

## 🔒 Security Features

### Invite Tokens
- 32-character random hex strings
- Cryptographically secure (crypto.randomBytes)
- Single-use (marked as "accepted" after use)
- Expire after 7 days

### Phone Verification
- 6-digit codes generated by Twilio
- Expire after 10 minutes
- Rate limited by Twilio
- Verified before account creation

### User Creation
- Automatic for phone-only sign-ups
- Placeholder email: `{phone_digits}@phone.makeready.app`
- Placeholder googleId: `phone_{phone_number}`
- User can update profile later

### Authorization
- Only group members can send invites
- Invites checked for expiration
- Duplicate membership prevented

## 🧪 Testing the Flow

### 1. Create a Test Group

```bash
npx tsx -e "
import { PrismaClient } from './src/generated/prisma/index.js';
(async () => {
  const prisma = new PrismaClient();
  const user = await prisma.user.findFirst();
  const group = await prisma.group.create({
    data: {
      name: 'Test Group',
      description: 'Testing invites',
      creatorId: user.id,
    },
  });
  console.log('Group ID:', group.id);
  process.exit(0);
})();
"
```

### 2. Send Test Invite

```bash
# Get session cookie from browser after logging in
# Replace with your actual session cookie
SESSION_COOKIE="connect.sid=s%3A..."

curl -X POST http://localhost:3001/api/invites/send \
  -H "Content-Type: application/json" \
  -H "Cookie: $SESSION_COOKIE" \
  -d '{
    "groupId": "42a6006e-18ce-429d-8cc7-0d708e17fcf2",
    "recipientPhone": "+12148623686"
  }'
```

### 3. Check SMS and Click Link

Check your phone for the invite SMS and click the link.

### 4. Get Invite Details

```bash
# Use token from SMS link
curl http://localhost:3001/api/invites/abc123
```

### 5. Request Verification Code

```bash
curl -X POST http://localhost:3001/api/verification/send \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+12148623686"}'
```

### 6. Verify and Join

```bash
# Use code from SMS
curl -X POST http://localhost:3001/api/verification/verify \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+12148623686",
    "code": "830160",
    "inviteToken": "abc123"
  }'
```

## 📱 Frontend Implementation

### React Component Example

```typescript
// InvitePage.tsx
import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';

export function InvitePage() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token');
  const phone = searchParams.get('phone');

  const [invite, setInvite] = useState(null);
  const [step, setStep] = useState('loading'); // loading, details, verify, success
  const [code, setCode] = useState('');

  useEffect(() => {
    // Load invite details
    fetch(`/api/invites/${token}`)
      .then(r => r.json())
      .then(data => {
        setInvite(data.invite);
        setStep('details');
      });
  }, [token]);

  const handleJoin = async () => {
    // Send verification code
    await fetch('/api/verification/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phoneNumber: phone }),
    });
    setStep('verify');
  };

  const handleVerify = async () => {
    const response = await fetch('/api/verification/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phoneNumber: phone,
        code,
        inviteToken: token,
      }),
    });

    const result = await response.json();
    if (result.success) {
      window.location.href = `/groups/${result.groupId}`;
    }
  };

  if (step === 'details') {
    return (
      <div>
        <h1>{invite.group.name}</h1>
        <p>{invite.group.description}</p>
        <p>Invited by: {invite.inviter.name}</p>
        <button onClick={handleJoin}>Join Group</button>
      </div>
    );
  }

  if (step === 'verify') {
    return (
      <div>
        <h1>Enter Verification Code</h1>
        <input
          value={code}
          onChange={e => setCode(e.target.value)}
          placeholder="6-digit code"
        />
        <button onClick={handleVerify}>Verify</button>
      </div>
    );
  }

  return <div>Loading...</div>;
}
```

## ✅ Success Criteria

- ✅ Group leader can send invites to any phone number
- ✅ Recipient receives SMS with invite link
- ✅ Link includes token and phone in URL
- ✅ Invite page shows group details
- ✅ "Join" triggers phone verification
- ✅ User enters 6-digit code
- ✅ Verification creates account if needed
- ✅ User is added to group
- ✅ Redirect to group page

## 🎉 Implementation Complete!

All endpoints are implemented and tested. The invite flow is ready to use!

**Next Steps:**
1. Build frontend UI components
2. Add group management features (create, edit, delete)
3. Add member management (remove, change roles)
4. Add group activity feed
