---
description: Test live production API endpoints
---

You are testing the **live production API** to verify all endpoints are working correctly.

## Test Configuration

**Production URL:** https://app.makeready.org
**Fallback URL:** https://makeready-server-production.up.railway.app

## Your Task

1. **Update the test file URL** to use app.makeready.org:
   - Edit `test/integration/production.test.ts`
   - Change `PRODUCTION_URL` to `'https://app.makeready.org'`

2. **Run the production test suite:**
   ```bash
   npm run test:prod
   ```

3. **Analyze the results:**
   - Count how many tests passed vs failed
   - Identify any critical failures
   - Check for:
     - Health endpoint working
     - Authentication endpoints accessible
     - Protected endpoints requiring auth
     - Security headers configured
     - Database connectivity

4. **Test key endpoints manually** if needed:
   ```bash
   # Health check
   curl https://app.makeready.org/health

   # API status
   curl https://app.makeready.org/api

   # Auth check (should return 401)
   curl https://app.makeready.org/auth/me

   # Google OAuth (should redirect)
   curl -I https://app.makeready.org/auth/google
   ```

5. **Report results** to the user:
   - ✅ Pass rate (X/17 tests passing)
   - ⚠️ Any failures and what they mean
   - 🔍 Critical issues vs minor issues
   - 💡 Recommendations for fixes

6. **If redirect errors occur:**
   - The custom domain may still have the Cloudflare redirect loop
   - Fall back to testing the Railway URL instead
   - Update the test file to use `https://makeready-server-production.up.railway.app`
   - Explain to the user that the Railway URL works but custom domain needs Cloudflare SSL fix

## Success Criteria

- Health endpoint returns `{"status":"ok"}`
- At least 12/17 tests passing
- No 5xx errors (500, 502, 503)
- Protected endpoints return 401 (not 500)
- Public endpoints accessible without auth

## Important

- Do NOT make any code changes unless tests reveal bugs
- Focus on TESTING, not fixing
- Clearly explain what each failure means
- Differentiate between critical failures and minor issues
