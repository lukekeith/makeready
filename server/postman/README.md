# MakeReady API Postman Collection

This folder contains the complete Postman collection for testing the MakeReady API.

## Files

- `makeready-api.postman_collection.json` - Complete API collection with 35 endpoints
- `makeready-local.postman_environment.json` - Local development environment (http://127.0.0.1:3001)
- `makeready-live.postman_environment.json` - Production environment (https://api.makeready.app)

## Getting Started

### 1. Import into Postman

1. Open Postman
2. Click **Import** → **Upload Files**
3. Select all three JSON files from this folder
4. Click **Import**

### 2. Select Environment

1. In the top-right corner of Postman, click the environment dropdown
2. Select **MakeReady Local** for local testing
3. Or select **MakeReady Live** for production testing

### 3. Test Endpoints

The collection is organized into folders:

- **System** (3 endpoints) - Health checks and status
- **Authentication** (5 endpoints) - Google OAuth flow
- **Members** (6 endpoints) - Member profile and verification
- **Organizations** (4 endpoints) - Organization management
- **Group Members** (3 endpoints) - Group membership management
- **Users** (2 endpoints) - User management (deprecated)
- **Verification** (3 endpoints) - Phone verification (Twilio)
- **SMS** (3 endpoints) - SMS messaging
- **Invites** (3 endpoints) - Group invitations
- **QR Code** (2 endpoints) - QR code generation
- **Public** (1 endpoint) - Public QR code generation

## Authentication

Most endpoints require authentication via Google OAuth:

1. **Web Flow:**
   - Call `GET /auth/google` in a browser
   - Complete Google sign-in
   - Browser will be redirected with session cookie
   - Use that session cookie for authenticated requests

2. **iOS Flow:**
   - Call `GET /auth/google?platform=ios`
   - Complete Google sign-in
   - Receive auth code via deep link
   - Call `POST /auth/exchange` with the code
   - Use returned session cookie for authenticated requests

3. **Check Authentication:**
   - Call `GET /auth/me` to verify your session

## Member Endpoints

All new member and organization endpoints are included:

### Member Management
- `POST /api/members/verify-phone` - Send verification code
- `POST /api/members/confirm-verification` - Confirm code and create/update member
- `GET /api/members/:memberId` - Get member profile
- `PATCH /api/members/:memberId` - Update member profile
- `DELETE /api/members/:memberId` - Delete member (soft delete)
- `GET /api/members/:memberId/groups` - Get member's groups

### Organization Management
- `GET /api/organizations/:organizationId` - Get organization
- `GET /api/organizations/my/organization` - Get current user's organization
- `PATCH /api/organizations/:organizationId` - Update organization
- `GET /api/organizations/:organizationId/members` - Get organization members

## Environment Variables

Both environments include:

- `baseUrl` - API base URL
- `authToken` - Authentication token (if using token-based auth)
- `sessionCookie` - Session cookie (for authenticated requests)

## Rate Limits

Some endpoints have rate limiting:

- Phone verification: 3 requests per 15 minutes per IP
- Code verification: 5 requests per 15 minutes per IP

## Testing Tips

1. Start with system endpoints to verify API is running
2. Use public endpoints (no auth required) for quick testing
3. Test authentication flow before protected endpoints
4. Use variables in URLs (e.g., `:memberId`) and replace with actual IDs
5. Check response bodies for error messages and status codes

## Regenerating Collection

To regenerate this collection after API changes:

```bash
# From server directory
/postman
```

This will scan all routes and update the collection automatically.

## Support

For issues or questions:
- Check the server logs for detailed error messages
- Verify environment is selected correctly
- Ensure request body format matches examples
- Check authentication is valid with `GET /auth/me`
