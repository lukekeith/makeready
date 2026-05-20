# Google OAuth Setup Instructions for MakeReady

**For Domain Administrator**

This document provides step-by-step instructions for setting up Google OAuth authentication for the MakeReady application.

---

## 📋 Prerequisites

- Access to Google Cloud Console (console.cloud.google.com)
- Admin access to the MakeReady domain
- Ability to create OAuth 2.0 credentials

---

## 🚀 Step-by-Step Setup

### Step 1: Access Google Cloud Console

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with your Google account that has admin privileges
3. If you don't have a project yet, create one:
   - Click "Select a project" at the top
   - Click "New Project"
   - Name it: **MakeReady**
   - Click "Create"

---

### Step 2: Enable Google+ API

1. In the left sidebar, go to **APIs & Services** → **Library**
2. Search for **"Google+ API"** or **"Google People API"**
3. Click on it and press **"Enable"**

---

### Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Choose **External** (unless MakeReady has a Google Workspace)
3. Fill in the required information:

   **App Information:**
   - **App name**: `MakeReady`
   - **User support email**: `support@makeready.com` (or your support email)
   - **App logo**: (Optional - upload MakeReady logo if available)

   **App Domain:**
   - **Application home page**: `https://makeready.com`
   - **Application privacy policy**: `https://makeready.com/privacy`
   - **Application terms of service**: `https://makeready.com/terms`

   **Developer Contact Information:**
   - **Email addresses**: `dev@makeready.com` (or appropriate dev contact)

4. Click **Save and Continue**

5. **Scopes** - Add the following scopes:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - Click **Save and Continue**

6. **Test users** (if in testing mode):
   - Add email addresses of users who can test the app
   - Click **Save and Continue**

7. Review and click **Back to Dashboard**

---

### Step 4: Create OAuth 2.0 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Choose **Application type**: **Web application**
4. Fill in the details:

   **Name**: `MakeReady Web App`

   **Authorized JavaScript origins**:
   ```
   http://localhost:3000
   https://makeready.com
   https://www.makeready.com
   https://app.makeready.com
   ```

   **Authorized redirect URIs**:
   ```
   http://localhost:3000/auth/google/callback
   https://makeready.com/auth/google/callback
   https://www.makeready.com/auth/google/callback
   https://app.makeready.com/auth/google/callback
   ```

   ℹ️ **Note**: Add all domains/subdomains where users will authenticate (staging, production, etc.)

5. Click **Create**

---

### Step 5: Save Your Credentials

After creation, you'll see a popup with:
- **Client ID**: `123456789-abc123def456.apps.googleusercontent.com`
- **Client Secret**: `GOCSPX-abc123def456ghi789`

**⚠️ IMPORTANT**: Copy both values immediately!

---

## 📦 What to Send to the Development Team

Please provide the following information:

### **Production Environment**
```
GOOGLE_CLIENT_ID=<your-client-id>
GOOGLE_CLIENT_SECRET=<your-client-secret>
```

### **Example:**
```
GOOGLE_CLIENT_ID=123456789-abc123def456.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abc123def456ghi789
```

**Where to send:**
- Securely share via password manager (1Password, LastPass, etc.)
- Or use encrypted email
- **Do NOT share via Slack/unencrypted channels**

---

## 🔧 Additional Configuration (Optional but Recommended)

### Add Branding

1. Go to **OAuth consent screen**
2. Click **Edit App**
3. Upload **App logo** (MakeReady logo - 120x120px minimum)
4. Add **App homepage** and **Privacy policy links**
5. Save changes

### Verify Domain Ownership

1. Go to **OAuth consent screen** → **Edit App**
2. Scroll to **Authorized domains**
3. Add: `makeready.com`
4. You may need to verify domain ownership via Google Search Console

---

## 📱 For iPhone App (iOS)

If you need OAuth for the iPhone app as well, create an additional credential:

1. Go to **Credentials** → **+ CREATE CREDENTIALS** → **OAuth client ID**
2. Choose **Application type**: **iOS**
3. Fill in:
   - **Name**: `MakeReady iOS App`
   - **Bundle ID**: `com.makeready.app` (get this from iOS developer)
4. Click **Create**
5. Save the **iOS Client ID** and send to dev team

---

## 🌍 Environment-Specific Setup

### Development (localhost)
Already included in redirect URIs above:
```
http://localhost:3000/auth/google/callback
```

### Staging (if applicable)
Add staging domain:
```
https://staging.makeready.com/auth/google/callback
```

### Production
Already included:
```
https://makeready.com/auth/google/callback
https://app.makeready.com/auth/google/callback
```

---

## ✅ Verification Checklist

Before sending credentials to the dev team, verify:

- [ ] OAuth consent screen is configured
- [ ] App name and logo are set (if available)
- [ ] All redirect URIs are added (localhost, staging, production)
- [ ] JavaScript origins include all domains
- [ ] Client ID and Client Secret are copied and saved securely
- [ ] Credentials are ready to send to dev team via secure channel

---

## 🔒 Security Best Practices

1. **Never commit credentials to Git** - Developers will store them in `.env` files
2. **Rotate secrets periodically** - Update Client Secret every 6-12 months
3. **Monitor usage** - Check Google Cloud Console for unusual activity
4. **Use separate credentials for staging/production** (optional but recommended)

---

## 🆘 Troubleshooting

### "Redirect URI mismatch" error
- Double-check that the redirect URI in code matches exactly what's in Google Console
- Ensure `http://` vs `https://` matches
- Check for trailing slashes

### "This app isn't verified"
- App is in testing mode - add users to Test Users list
- Or publish the app (requires verification if using sensitive scopes)

### Can't find OAuth consent screen
- Make sure you've selected the correct Google Cloud project at the top

---

## 📞 Support

If you encounter any issues during setup:
- **Google Cloud Console Help**: [https://cloud.google.com/support](https://cloud.google.com/support)
- **MakeReady Dev Team**: dev@makeready.com

---

## 📝 Summary - What Devs Need

Send this information to the development team:

```bash
# Production
GOOGLE_CLIENT_ID=<your-client-id-here>
GOOGLE_CLIENT_SECRET=<your-client-secret-here>

# iOS (if applicable)
GOOGLE_IOS_CLIENT_ID=<ios-client-id-here>
```

**That's it!** Once you send these credentials, the development team can configure Google authentication for MakeReady.

---

**Created**: $(date)
**Last Updated**: $(date)
**Version**: 1.0
