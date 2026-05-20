# Production Integration Tests

Tests for the live API deployed at **app.makeready.org**

## Running the Tests

```bash
# Run all production tests once
npm run test:prod

# Run with watch mode (re-run on changes)
npm run test:prod:watch
```

## What Gets Tested

### 1. Health & Status
- `/health` endpoint returns 200 OK
- `/api` endpoint responds correctly
- CORS headers are configured

### 2. Authentication
- Google OAuth endpoints are accessible
- Protected endpoints require authentication
- `/auth/me` returns 401 when not authenticated

### 3. Public Endpoints
- Invite token lookup works without auth
- Returns proper 404 for invalid tokens

### 4. Protected Endpoints
All require authentication (return 401):
- `POST /api/invites` - Create invite
- `POST /api/invites/send` - Send SMS invite
- `POST /api/qrcode/generate` - Generate QR code
- `POST /api/sms/send` - Send SMS

### 5. Verification Endpoints
- Phone verification is public (no auth required)
- Phone number format validation works
- E.164 format is enforced

### 6. Security
- No `X-Powered-By` header exposed
- HTTPS is enforced
- Proper error response format

### 7. Database Connectivity
- Database connection is healthy
- Prisma client works correctly

## Recent Fixes

### Infinite Redirect Loop (Fixed: 2025-11-07)

**Problem:** app.makeready.org was experiencing infinite 301 redirects

**Root Cause:** Express wasn't configured to trust proxies (Railway/Cloudflare)

**Solution:**
```typescript
// Added to src/index.ts
app.set('trust proxy', 1)
```

When Express runs behind a reverse proxy (Railway) and CDN (Cloudflare), it needs to trust the proxy headers (`X-Forwarded-Proto`, `X-Forwarded-For`, etc.). Without this, Express doesn't recognize the connection as HTTPS and may cause redirect loops.

Also updated cookie security to be environment-aware:
```typescript
secure: process.env.NODE_ENV === 'production'
```

## Environment Requirements

Make sure Railway has these environment variables set:

```env
NODE_ENV=production
DATABASE_URL=<your-railway-postgres-url>
SESSION_SECRET=<your-secret>
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>
GOOGLE_CALLBACK_URL=https://app.makeready.org/auth/google/callback
CLIENT_URL=<your-client-url>
TWILIO_ACCOUNT_SID=<your-twilio-sid>
TWILIO_AUTH_TOKEN=<your-twilio-token>
TWILIO_VERIFY_SERVICE_ID=<your-twilio-service-id>
```

## Troubleshooting

### Tests Fail with "redirect count exceeded"

This means there's an infinite redirect loop. Check:

1. ✅ `app.set('trust proxy', 1)` is set in `src/index.ts`
2. ✅ `NODE_ENV=production` is set in Railway
3. ✅ DNS is correctly pointed to Railway
4. ✅ Railway domain is properly configured

### Tests Fail with "fetch failed"

1. Check if app.makeready.org is accessible in a browser
2. Verify Railway deployment succeeded
3. Check Railway logs for errors

### 404 Errors

1. Verify the route exists in `src/index.ts`
2. Check Railway deployment logs
3. Ensure build completed successfully

## CI/CD Integration

These tests can be added to CI/CD pipelines to verify deployments:

```yaml
# Example GitHub Actions
- name: Test Production API
  run: npm run test:prod
  env:
    NODE_ENV: production
```

## Writing New Tests

Follow this pattern for new integration tests:

```typescript
describe('My Feature', () => {
  it('should do something', async () => {
    const response = await fetch(`${PRODUCTION_URL}/api/my-endpoint`);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data).toHaveProperty('success', true);
  });
});
```

Use native `fetch()` API (available in Node 18+) instead of supertest for true integration tests.
