# Error Handling & Rate Limiting

---

## Standard Error Response Format

All error responses follow this format:

```json
{
  "success": false,
  "error": "Error message description"
}
```

---

## HTTP Status Codes

| Status Code | Description | Common Causes |
|-------------|-------------|---------------|
| 200 | OK | Successful request |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request body, missing fields, validation errors |
| 401 | Unauthorized | Missing or invalid session cookie |
| 403 | Forbidden | Authenticated but lacks permission |
| 404 | Not Found | Resource doesn't exist or is inactive |
| 409 | Conflict | Resource already exists (duplicate) |
| 500 | Internal Server Error | Database error, unexpected exception |

---

## Common Error Scenarios

### Authentication Errors

**Not Authenticated (401):**
```json
{
  "success": false,
  "error": "Not authenticated"
}
```
- **Cause:** Missing or invalid session cookie
- **Solution:** Authenticate via `/auth/google` flow

**No Permission (403):**
```json
{
  "success": false,
  "error": "You do not have permission to access this member"
}
```
- **Cause:** User is not the resource owner
- **Solution:** Ensure user owns the resource

### Validation Errors

**Invalid Phone Number (400):**
```json
{
  "success": false,
  "error": "Phone number must be in E.164 format"
}
```
- **Cause:** Phone not in E.164 format (+1XXXXXXXXXX)

**Invalid Verification Code (400):**
```json
{
  "success": false,
  "error": "Verification code must be 6 digits"
}
```

**Activity Limit Exceeded (400):**
```json
{
  "success": false,
  "error": "Maximum 1 study method activity allowed per lesson (SOAP, OIA, DBS, or HEAR)",
  "details": {
    "allowed": false,
    "categoryCount": 1,
    "categoryMax": 1
  }
}
```

**Missing Required Field (400):**
```json
{
  "success": false,
  "error": "videoId is required for VIDEO activities"
}
```

### Resource Not Found (404)

```json
{
  "success": false,
  "error": "Video not found or not accessible"
}
```
- **Cause:** Resource doesn't exist, is inactive, or user doesn't have access

### Server Errors (500)

```json
{
  "success": false,
  "error": "Internal server error"
}
```
- **Cause:** Database error, third-party API failure
- **Solution:** Check server logs, retry request

---

## Rate Limiting

### Twilio SMS Rate Limits

**Phone Verification Endpoints:**
- `/api/members/verify-phone`
- `/api/members/confirm-verification`

**Twilio Default Limits:**
- **SMS Sending:** 60 requests/minute per account
- **Verification Checks:** 5 checks per 10 minutes per phone number
- **Failed Verifications:** Max 5 attempts before code expires
- **Code Expiration:** 10 minutes

### Best Practices

1. **Implement Client-Side Rate Limiting:**
   - Add 60-second cooldown between verification requests
   - Disable resend button during cooldown
   - Show countdown timer to user

2. **Handle Rate Limit Errors:**
```json
{
  "success": false,
  "error": "Too many requests. Please try again later."
}
```

3. **Recommended Implementation:**
```typescript
const RESEND_COOLDOWN = 60000; // 60 seconds
let lastSendTime = 0;

async function sendVerificationCode(phoneNumber: string) {
  const now = Date.now();
  if (now - lastSendTime < RESEND_COOLDOWN) {
    const remaining = Math.ceil((RESEND_COOLDOWN - (now - lastSendTime)) / 1000);
    throw new Error(`Please wait ${remaining} seconds before resending`);
  }

  await fetch('/api/members/verify-phone', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phoneNumber })
  });

  lastSendTime = now;
}
```

---

## Environment Variables

### Required Configuration

```env
# Server
PORT=3001
NODE_ENV=development

# Google OAuth
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
GOOGLE_CALLBACK_URL=http://localhost:3001/auth/google/callback

# Session
SESSION_SECRET=your_secret_key_here

# Client URL
CLIENT_URL=http://localhost:5173

# Database
DATABASE_URL="postgresql://user@localhost:5432/makeready"

# Twilio (SMS verification)
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_VERIFY_SERVICE_SID=your_verify_service_sid

# Cloudflare Stream (video)
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_API_TOKEN=your_api_token

# Cloudflare R2 (file/image storage)
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
R2_BUCKET_NAME=your_bucket_name
R2_PUBLIC_URL=https://your-r2-public-url
```
