# Railway Deployment Guide

## Overview

This guide walks you through deploying the MakeReady server to Railway with Railway Postgres (pgvector).

## Prerequisites

- Railway account (https://railway.app)
- Railway project with PostgreSQL database (pgvector enabled)
- Google OAuth credentials
- Twilio account (for SMS features)

## 1. Railway Configuration File

The `railway.toml` file is already configured with:
- ✅ Automatic Prisma migrations on deploy
- ✅ Health checks at `/health`
- ✅ Restart policy on failure
- ✅ Proper build commands

## 2. Environment Variables Setup

In your Railway project dashboard, add these environment variables:

### Database (Required)

```bash
# Railway Postgres connection URL
DATABASE_URL=postgresql://postgres:PASSWORD@HOST:PORT/railway
```

### Application (Required)

```bash
NODE_ENV=production
PORT=3001
```

### Session (Required)

```bash
# Generate a secure random string for production
SESSION_SECRET=your-secure-random-string-here
```

**How to generate SESSION_SECRET:**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### Client URL (Required)

```bash
# Your frontend URL (e.g., Vercel, Netlify, or another Railway deployment)
CLIENT_URL=https://your-frontend-app.vercel.app
```

### Google OAuth (Required for authentication)

```bash
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>

# Update this with your Railway app URL once deployed
GOOGLE_CALLBACK_URL=https://your-app.railway.app/auth/google/callback
```

### Twilio (Optional - for SMS features)

```bash
TWILIO_ACCOUNT_SID=<your-twilio-account-sid>
TWILIO_AUTH_TOKEN=<your-twilio-auth-token>
TWILIO_VERIFY_SERVICE_ID=<your-twilio-verify-service-id>
TWILIO_PHONE_NUMBER=<your-twilio-phone-number>
```

### Cloudflare R2 (File/Image Storage)

```bash
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
R2_BUCKET_NAME=your_bucket_name
R2_PUBLIC_URL=https://your-r2-public-url
```

## 3. Deployment Steps

### Step 1: Connect Repository

1. Go to Railway dashboard
2. Click "New Project"
3. Select "Deploy from GitHub repo"
4. Choose your `makeready/server` repository
5. Railway will detect the `railway.toml` automatically

### Step 2: Add Environment Variables

1. In your Railway project, go to "Variables"
2. Add all environment variables listed above
3. Click "Deploy" or wait for auto-deployment

### Step 3: Update Google OAuth Callback

1. Once deployed, Railway will give you a URL like: `https://your-app.railway.app`
2. Update `GOOGLE_CALLBACK_URL` environment variable:
   ```
   GOOGLE_CALLBACK_URL=https://your-app.railway.app/auth/google/callback
   ```
3. Update your Google Cloud Console OAuth credentials:
   - Add `https://your-app.railway.app` to Authorized JavaScript origins
   - Add `https://your-app.railway.app/auth/google/callback` to Authorized redirect URIs

### Step 4: Verify Deployment

1. Check deployment logs in Railway dashboard
2. Look for successful migration output:
   ```
   Applying migration `20231215_initial_schema`
   Database migrations applied successfully!
   ```
3. Visit your health check endpoint:
   ```
   https://your-app.railway.app/health
   ```
   Should return:
   ```json
   {
     "status": "ok",
     "timestamp": "2024-01-15T12:00:00.000Z",
     "database": {
       "status": "healthy"
     }
   }
   ```

## 4. Understanding the Deployment Process

When you push to Railway:

1. **Build Phase**:
   - Installs dependencies (`npm install`)
   - Generates Prisma client (`prisma generate`)
   - Compiles TypeScript (`tsc`)
   - Runs tests (`npm run test:ci`)
   - Copies static files to `dist/`

2. **Deploy Phase**:
   - Runs database migrations (`prisma migrate deploy`)
   - Starts the server (`npm start`)
   - Health checks begin after 10 seconds
   - Restarts on failure (up to 10 times)

## 5. Railway Postgres Connection

Railway provides a single `DATABASE_URL` for your PostgreSQL database. This is used for both application queries and migrations.

- **DATABASE_URL**: Used for all query operations and migrations
  - Railway manages connection pooling internally
  - Supports pgvector extension for embeddings

## 6. Monitoring and Logs

### View Logs
```bash
# In Railway dashboard, go to "Deployments" tab
# Click on latest deployment to view logs
```

### Check Health
```bash
curl https://your-app.railway.app/health
```

### Check API
```bash
curl https://your-app.railway.app/api
```

## 7. Troubleshooting

### Migration Fails

**Error**: `prepared statement already exists`
- **Cause**: Using session pooler (port 5432) for migrations
- **Fix**: Ensure `DIRECT_URL` uses port 6543

### Health Check Fails

**Error**: `Health check timeout`
- **Cause**: Database connection too slow
- **Fix**: Already configured with 300ms timeout in `railway.toml`

### OAuth Redirect Error

**Error**: `redirect_uri_mismatch`
- **Cause**: Google OAuth callback URL not configured
- **Fix**: Add Railway URL to Google Cloud Console

### Database Connection Error

**Error**: `Can't reach database server`
- **Cause**: Incorrect DATABASE_URL
- **Fix**: Verify DATABASE_URL connection string in Railway variables

## 8. Production Checklist

Before going live:

- [ ] Generate new `SESSION_SECRET` (use crypto.randomBytes)
- [ ] Verify `DATABASE_URL` is correct
- [ ] Update `GOOGLE_CALLBACK_URL` with Railway domain
- [ ] Add Railway URL to Google OAuth allowed origins
- [ ] Update `CLIENT_URL` with production frontend URL
- [ ] Rotate any credentials that were committed to git (if applicable)
- [ ] Enable Railway custom domain (optional)
- [ ] Configure CORS for production frontend domain
- [ ] Test OAuth flow end-to-end
- [ ] Test API endpoints with Postman
- [ ] Monitor logs for errors

## 9. Useful Commands

### Local Development
```bash
npm run dev          # Start development server
npm run build:prod   # Build for production
npm start            # Start production build locally
```

### Database
```bash
npx prisma migrate dev    # Create and apply migration (development)
npx prisma migrate deploy # Apply migrations (production - used by Railway)
npx prisma studio         # Open Prisma Studio
npx prisma generate       # Regenerate Prisma client
```

### Testing
```bash
npm test              # Run tests in watch mode
npm run test:ci       # Run tests once (used in build)
```

## 10. Next Steps

After successful deployment:

1. **Deploy Frontend**: Deploy client app to Vercel/Netlify
2. **Update CORS**: Add production client URL to CORS whitelist
3. **Custom Domain**: Configure custom domain in Railway (optional)
4. **Monitoring**: Set up error tracking (Sentry, etc.)
5. **Analytics**: Add API analytics if needed

## Support

- Railway Docs: https://docs.railway.app
- Railway Docs: https://docs.railway.com
- Prisma Docs: https://www.prisma.io/docs
- Project Issues: https://github.com/your-org/makeready/issues
