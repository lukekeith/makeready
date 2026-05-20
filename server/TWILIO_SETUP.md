# Twilio Setup Guide

This guide covers the integration of Twilio services in the MakeReady server for phone verification and SMS messaging.

## 🔑 Environment Variables

Add the following to your `server/.env` file:

```env
# Twilio Configuration
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_VERIFY_SERVICE_ID=your_verify_service_id_here
TWILIO_PHONE_NUMBER=+1234567890
```

### Where to Find Your Credentials

1. **Account SID & Auth Token**
   - Login to [Twilio Console](https://console.twilio.com/)
   - Found on the main dashboard under "Account Info"

2. **Verify Service ID**
   - Navigate to: [Verify Services](https://console.twilio.com/us1/develop/verify/services)
   - Create a new service or use an existing one
   - The Service SID starts with `VA...`

3. **Phone Number**
   - Navigate to: [Phone Numbers](https://console.twilio.com/us1/develop/phone-numbers/manage/active)
   - Purchase a phone number if you don't have one
   - Use E.164 format (e.g., +1234567890)

## 📱 Features Implemented

### 1. Phone Verification (Twilio Verify API)

Used for verifying phone numbers during sign-up or adding phone to existing accounts.

**Endpoints:**

- `POST /api/verification/send` - Send verification code
- `POST /api/verification/verify` - Verify code
- `POST /api/verification/resend` - Resend verification code

**Flow:**
1. User enters phone number
2. Call `/api/verification/send` with phone number
3. User receives SMS with 6-digit code
4. Call `/api/verification/verify` with phone number and code
5. If authenticated, user's phone is saved and marked as verified

### 2. SMS Messaging (Twilio Programmable SMS)

Used for sending custom SMS messages to users.

**Endpoints:**

- `POST /api/sms/send` - Send SMS to any number (requires auth)
- `POST /api/sms/send-to-self` - Send SMS to authenticated user's verified phone

## 🚀 API Usage Examples

### Send Verification Code

```bash
curl -X POST http://localhost:3001/api/verification/send \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+1234567890"
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Verification code sent successfully",
  "status": "pending"
}
```

### Verify Code

```bash
curl -X POST http://localhost:3001/api/verification/verify \
  -H "Content-Type: application/json" \
  -H "Cookie: connect.sid=your_session_cookie" \
  -d '{
    "phoneNumber": "+1234567890",
    "code": "123456"
  }'
```

**Response:**
```json
{
  "success": true,
  "valid": true,
  "message": "Phone number verified successfully"
}
```

### Send Custom SMS

```bash
curl -X POST http://localhost:3001/api/sms/send \
  -H "Content-Type: application/json" \
  -H "Cookie: connect.sid=your_session_cookie" \
  -d '{
    "to": "+1234567890",
    "message": "Hello from MakeReady!"
  }'
```

**Response:**
```json
{
  "success": true,
  "messageSid": "SM...",
  "message": "SMS sent successfully"
}
```

### Send SMS to Self

```bash
curl -X POST http://localhost:3001/api/sms/send-to-self \
  -H "Content-Type: application/json" \
  -H "Cookie: connect.sid=your_session_cookie" \
  -d '{
    "message": "Test message to myself"
  }'
```

**Response:**
```json
{
  "success": true,
  "messageSid": "SM...",
  "message": "SMS sent to your phone number"
}
```

## 📊 Database Schema

The User model has been updated with phone fields:

```prisma
model User {
  id            String   @id @default(uuid())
  googleId      String   @unique
  email         String   @unique
  name          String
  picture       String?
  phoneNumber   String?  @unique      // E.164 format
  phoneVerified Boolean  @default(false)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
}
```

## 🔒 Security Features

1. **Phone Number Validation**
   - All phone numbers validated as E.164 format
   - Regex: `^\+[1-9]\d{1,14}$`

2. **Authentication**
   - SMS endpoints require authentication
   - Verification can work without auth (for sign-up flow)

3. **Rate Limiting**
   - Consider implementing rate limiting on verification endpoints
   - Twilio Verify API has built-in rate limiting

4. **Error Handling**
   - All Twilio errors caught and logged
   - User-friendly error messages returned
   - Credentials never exposed in responses

## 🛠️ Service Layer

Located at `src/services/twilio.ts`

**Functions:**

- `sendVerificationCode(phoneNumber)` - Send verification code via Verify API
- `verifyCode(phoneNumber, code)` - Check verification code
- `sendSMS(to, message)` - Send custom SMS
- `isValidPhoneNumber(phoneNumber)` - Validate E.164 format

## 📝 Testing

1. **Test Verification Flow:**
   ```bash
   # 1. Send code
   curl -X POST http://localhost:3001/api/verification/send \
     -H "Content-Type: application/json" \
     -d '{"phoneNumber": "+1234567890"}'

   # 2. Check your phone for the code

   # 3. Verify code
   curl -X POST http://localhost:3001/api/verification/verify \
     -H "Content-Type: application/json" \
     -d '{"phoneNumber": "+1234567890", "code": "123456"}'
   ```

2. **Test SMS:**
   ```bash
   # Must be authenticated first
   curl -X POST http://localhost:3001/api/sms/send \
     -H "Content-Type: application/json" \
     -H "Cookie: connect.sid=..." \
     -d '{"to": "+1234567890", "message": "Test"}'
   ```

## 💰 Twilio Costs

- **Verify API**: ~$0.05 per verification
- **Programmable SMS**: ~$0.0075 per message (US)
- **Phone Number**: ~$1.15/month

[View current pricing](https://www.twilio.com/pricing)

## 🐛 Troubleshooting

### Error: "Twilio credentials not found"
- Ensure all environment variables are set in `.env`
- Restart the server after adding variables

### Error: "Invalid phone number format"
- Phone numbers must be in E.164 format: `+[country code][number]`
- Example: `+14155551234` (US number)

### Error: "Verify Service SID not configured"
- Create a Verify service in Twilio Console
- Add the Service SID (starts with `VA...`) to `.env`

### Verification code not received
- Check Twilio Console logs
- Ensure phone number is verified in Twilio (for trial accounts)
- Trial accounts can only send to verified numbers

## 📚 Additional Resources

- [Twilio Verify API Docs](https://www.twilio.com/docs/verify/api)
- [Twilio SMS API Docs](https://www.twilio.com/docs/sms/api)
- [E.164 Phone Number Format](https://www.twilio.com/docs/glossary/what-e164)

## 🔗 Integration Notes

- Verification endpoints work without authentication (for sign-up flow)
- If user is authenticated during verification, phone is saved to their account
- SMS endpoints require authentication to prevent abuse
- Phone numbers are unique per user in the database
- Phone verification status is tracked per user
