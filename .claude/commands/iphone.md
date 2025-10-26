# iPhone Build and Run Command

You are an expert at building, running, and testing the MakeReady iPhone app in the iOS Simulator.

## Your Responsibilities

1. **Build the iPhone app** correctly with proper Xcode settings
2. **Start the correct simulator** (iPhone 17 Pro Max by default)
3. **Install and launch** the app
4. **Handle common issues** with Info.plist, Xcode configuration, etc.
5. **Provide clear feedback** on what's happening

## Important Context

### Project Structure
- **Project location**: `/Users/lukekeith/www/makeready/iphone/`
- **Xcode project**: `MakeReady.xcodeproj`
- **Scheme**: `MakeReady`
- **Build output**: `./build/Build/Products/Debug-iphonesimulator/MakeReady.app`
- **Bundle ID**: `com.makeready.app`

### File Organization Philosophy

**Current Approach**: Flat structure (all Swift files in `/iphone/MakeReady/`)

**Rationale**:
- Project is still in early stages
- Waiting for patterns to emerge naturally
- Easier to refactor once we know what screens/features we have

**Future Plan**:
- Will reorganize into feature-based structure once app grows
- Likely structure: `Authentication/`, `Home/`, `Components/`, `Resources/`
- Will use Xcode to move files (keeps project.pbxproj in sync)
- Target threshold: ~15-20 Swift files or when clear feature boundaries emerge

**Note to AI**: Keep files flat for now. Don't create folders unless explicitly requested. When reorganization time comes, recommend feature-based structure.

### Preferred Simulator
- **Default**: iPhone 17 Pro Max
- **UUID**: 6290067E-E327-4F0C-A0A9-F559577963EF
- **Fallback**: iPhone 17 Pro (8A0AD810-F524-4CAE-8565-ACE65A2C51F8)

### Critical Info.plist Requirements
The custom Info.plist at `MakeReady/Info.plist` MUST include:
- `CFBundleExecutable` = `$(EXECUTABLE_NAME)`
- `CFBundleIdentifier` = `$(PRODUCT_BUNDLE_IDENTIFIER)`
- `UIApplicationSceneManifest` with proper scene configuration
- `UILaunchScreen` (can be empty dict)
- `CFBundleURLTypes` for `makeready://` URL scheme
- `NSAppTransportSecurity` for localhost HTTP access

### Common Issues and Fixes

**Issue: App appears zoomed in / wrong scale**
- Cause: Missing `UIApplicationSceneManifest` or `UILaunchScreen` in Info.plist
- Fix: Ensure both keys are present in the custom Info.plist

**Issue: "Missing bundle ID" error**
- Cause: Info.plist missing `CFBundleExecutable` or `CFBundleIdentifier`
- Fix: Add both keys with Xcode variable substitution values

**Issue: Xcode project corrupted**
- Cause: Manual edits to project.pbxproj went wrong
- Fix: Restore from git: `git checkout iphone/MakeReady.xcodeproj/project.pbxproj`

**Issue: Files not in Xcode project**
- Cause: Files created outside Xcode
- Fix: Open Xcode, right-click MakeReady folder, "Add Files to 'MakeReady'..."

## Workflow

### 1. Check Current State
```bash
# Check what's currently running
xcrun simctl list devices | grep Booted

# Check if app is installed
xcrun simctl listapps booted | grep com.makeready.app
```

### 2. Boot Correct Simulator
```bash
# Shutdown all simulators first
xcrun simctl shutdown all 2>/dev/null

# Boot iPhone 17 Pro Max
xcrun simctl boot 6290067E-E327-4F0C-A0A9-F559577963EF 2>/dev/null

# Open Simulator.app
open -a Simulator

# Wait for boot
sleep 3
```

### 3. Build the App
```bash
cd /Users/lukekeith/www/makeready/iphone

xcodebuild \
  -scheme MakeReady \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" \
  -configuration Debug \
  -derivedDataPath ./build \
  build
```

**Important**: Always check build output for errors. Common errors:
- Swift compilation errors (fix code)
- Info.plist errors (verify all required keys)
- Signing errors (usually auto-resolved for simulator)

### 4. Install the App
```bash
# Uninstall old version first (fresh install)
xcrun simctl uninstall booted com.makeready.app 2>/dev/null

# Install new version
xcrun simctl install booted /Users/lukekeith/www/makeready/iphone/build/Build/Products/Debug-iphonesimulator/MakeReady.app
```

### 5. Launch the App
```bash
xcrun simctl launch booted com.makeready.app
```

### 6. View Logs (Optional)
```bash
# Stream logs with emoji markers
xcrun simctl spawn booted log stream --process MakeReady --level debug
```

## Quick Commands

### Full Build and Run
```bash
cd /Users/lukekeith/www/makeready/iphone && \
xcrun simctl shutdown all 2>/dev/null && \
xcrun simctl boot 6290067E-E327-4F0C-A0A9-F559577963EF 2>/dev/null && \
open -a Simulator && \
sleep 3 && \
xcodebuild -scheme MakeReady -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -configuration Debug -derivedDataPath ./build build && \
xcrun simctl uninstall booted com.makeready.app 2>/dev/null && \
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/MakeReady.app && \
xcrun simctl launch booted com.makeready.app
```

### Just Restart App
```bash
xcrun simctl terminate booted com.makeready.app 2>/dev/null
xcrun simctl launch booted com.makeready.app
```

### Clean Rebuild
```bash
cd /Users/lukekeith/www/makeready/iphone
rm -rf build
# Then run full build
```

## Your Process

When the user asks to build/run/test the iPhone app:

1. **Acknowledge** what you're doing
2. **Check** current simulator state
3. **Boot** iPhone 17 Pro Max if needed
4. **Build** the app with xcodebuild
5. **Report** any build errors clearly
6. **Install** the app (fresh install)
7. **Launch** the app
8. **Confirm** the app is running with process ID
9. **Remind** the user what simulator is running

## Output Format

Use this format for clear communication:

```
🏗️ Building MakeReady for iPhone 17 Pro Max...
✅ Build succeeded
📱 Installing app...
✅ App installed
🚀 Launching app...
✅ App running (PID: 12345)

The app is now running in the iPhone 17 Pro Max simulator.
```

## Additional Notes

- **Never** manually edit `project.pbxproj` - use Xcode or restore from git
- **Always** use the custom Info.plist at `MakeReady/Info.plist`
- **Never** use auto-generated Info.plist (GENERATE_INFOPLIST_FILE should be NO)
- **Always** check that simulator is fully booted before installing
- **Consider** clearing build folder if weird issues occur
- **Remember** OAuth flow requires server running at localhost:3001

## Server Requirements

For OAuth to work, ensure:
```bash
# Check server is running
curl -s http://localhost:3001/auth/me

# Should return either user data or {"error":"Not authenticated"}
```

## 🔐 Google OAuth Authentication for iOS

### Architecture Overview

The MakeReady iPhone app uses **OAuth2 Authorization Code Flow** for authentication with Google. This is the industry-standard approach for mobile apps.

### Authentication Flow

```
1. User taps "Sign in with Google"
   ↓
2. App opens ASWebAuthenticationSession with:
   URL: http://127.0.0.1:3001/auth/google?platform=ios
   Callback scheme: makeready://
   ↓
3. User authenticates with Google in Safari View
   ↓
4. Server creates session and generates one-time auth code
   ↓
5. Server redirects to: makeready://auth/callback?code=xyz
   ↓
6. ASWebAuthenticationSession captures redirect
   ↓
7. App extracts auth code and calls: POST /auth/exchange
   ↓
8. Server validates code and returns SIGNED session cookie
   ↓
9. App stores signed cookie and uses it for subsequent requests
   ↓
10. App calls GET /auth/me with cookie → User authenticated!
```

### Critical Implementation Details

#### 1. **Session Cookie Signing** (MOST IMPORTANT!)

**Problem**: Express-session signs cookies using `cookie-signature`. You CANNOT just send the raw session ID.

**Solution**: The `/auth/exchange` endpoint MUST sign the session cookie:

```typescript
// server/src/routes/auth.ts
import signature from 'cookie-signature'

// In /auth/exchange endpoint:
const sessionSecret = process.env.SESSION_SECRET || 'your-secret-key'
const signedSessionId = 's:' + signature.sign(authData.sessionId, sessionSecret)

// Return signed cookie (format: s:sessionId.signature)
res.json({
  sessionId: signedSessionId,  // e.g., "s:abc123...xyz.def456...ghi"
  userId: authData.userId
})
```

**Why**: Express-session validates cookie signatures. Without proper signing:
- Server creates NEW session instead of using existing one
- User appears unauthenticated despite valid session
- Auth fails with 401 error

#### 2. **iOS App Cookie Management**

```swift
// iphone/MakeReady/AuthManager.swift

// Store the SIGNED session cookie (not just session ID!)
private func storeSessionCookie(_ signedCookie: String) {
    self.sessionCookie = signedCookie  // Already includes signature
    UserDefaults.standard.set(signedCookie, forKey: sessionCookieKey)
}

// Send cookie in ALL authenticated requests
func fetchCurrentUser() async throws {
    var request = URLRequest(url: url)

    if let sessionCookie = sessionCookie {
        // Send as Cookie header (express-session expects this)
        request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
    }

    let (data, response) = try await URLSession.shared.data(for: request)
    // ...
}
```

#### 3. **Server Configuration**

```typescript
// server/src/index.ts
app.use(session({
  secret: process.env.SESSION_SECRET || 'your-secret-key',  // MUST match signing secret!
  resave: false,
  saveUninitialized: false,
  cookie: {
    maxAge: 24 * 60 * 60 * 1000,  // 24 hours
    httpOnly: true,
    secure: false,   // HTTP for local development (iOS Simulator)
    sameSite: 'lax', // Required for OAuth redirects
    domain: undefined // Let browser set the domain
  }
}))
```

**Important Session Settings**:
- `secure: false` - Allows HTTP for localhost development
- `sameSite: 'lax'` - Enables OAuth redirect flows
- `domain: undefined` - Works with 127.0.0.1 in iOS Simulator

#### 4. **iOS Info.plist Requirements**

For OAuth to work, `MakeReady/Info.plist` MUST include:

```xml
<!-- URL Scheme for OAuth callback -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>makeready</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.makeready.app</string>
    </dict>
</array>

<!-- Allow HTTP to localhost (for development) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
        <key>127.0.0.1</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Common Auth Issues and Solutions

#### Issue 1: "User not authenticated" after successful OAuth

**Symptoms**:
- OAuth completes successfully
- Server logs show: `Session ID: abc123` → later `Session ID: xyz456` (different!)
- App receives 401 error on `/auth/me`

**Cause**: Session cookie not properly signed

**Solution**: Ensure `/auth/exchange` returns SIGNED cookie:
```typescript
const signedSessionId = 's:' + signature.sign(sessionId, sessionSecret)
```

**How to Verify**:
```bash
# Check server logs - should see:
✅ Code valid, returning signed session cookie
   Raw session ID: abc123...
   Signed cookie: s:abc123...xyz.def456...

# Later when app calls /auth/me:
🔍 /auth/me called
   Cookie header: connect.sid=s:abc123...xyz.def456...
   Session ID: abc123...  # SAME as original!
   Is Authenticated: true  # ✅
```

#### Issue 2: ASWebAuthenticationSession doesn't call callback

**Symptoms**:
- Safari opens and shows Google login
- User authenticates successfully
- Safari closes but app doesn't receive callback

**Cause**: Usually a URL scheme mismatch

**Solution**:
1. Verify Info.plist has `makeready` URL scheme
2. Check server redirects to: `makeready://auth/callback?code=...`
3. Check ASWebAuthenticationSession uses `callbackURLScheme: "makeready"`

#### Issue 3: "The operation couldn't be completed" error

**Symptoms**:
- App shows error immediately after tapping "Sign in"
- No Safari window opens

**Causes and Solutions**:
- **Missing `presentationContextProvider`**: Ensure set on ASWebAuthenticationSession
- **Invalid auth URL**: Check server is running at 127.0.0.1:3001
- **Missing Info.plist config**: Verify ATS allows localhost

### Testing Authentication

#### 1. Test OAuth Flow

```bash
# Start server
cd /Users/lukekeith/www/makeready && npm run dev --prefix server

# In another terminal, monitor logs
tail -f /path/to/server/logs

# In app: Tap "Sign in with Google"
# Watch for:
✅ Google OAuth callback successful
✅ Code valid, returning signed session cookie
✅ User authenticated
```

#### 2. Test Session Persistence

```bash
# 1. Sign in successfully
# 2. Kill and restart the app
# 3. App should automatically load user data (no re-auth needed)

# Verify by checking logs:
🔍 /auth/me called
   Cookie header: connect.sid=s:abc123...
   Is Authenticated: true
✅ User authenticated
```

#### 3. Clear Session (for testing)

```swift
// In iOS app (or via Settings.bundle if implemented):
UserDefaults.standard.removeObject(forKey: "makeready_session_cookie")
UserDefaults.standard.removeObject(forKey: "makeready_current_user")
```

### Dependencies

**Server**:
```json
{
  "cookie-signature": "^1.2.1",
  "express-session": "^1.18.0",
  "passport": "^0.7.0",
  "passport-google-oauth20": "^2.0.0"
}
```

**iOS**:
- `AuthenticationServices.framework` (built-in)
- `ASWebAuthenticationSession` API

### Security Considerations

1. **HTTPS in Production**: Switch to HTTPS with valid certificate in production
2. **Session Secret**: Use strong, random secret in production (stored securely)
3. **Cookie Security**: Set `secure: true` and `sameSite: 'strict'` in production
4. **Code Expiration**: Auth codes expire after 5 minutes (configurable)
5. **One-Time Use**: Auth codes are deleted after first exchange

### Files to Review

- **Server**: `/Users/lukekeith/www/makeready/server/src/routes/auth.ts`
- **iOS**: `/Users/lukekeith/www/makeready/iphone/MakeReady/AuthManager.swift`
- **Config**: `/Users/lukekeith/www/makeready/server/src/index.ts`
- **Info.plist**: `/Users/lukekeith/www/makeready/iphone/MakeReady/Info.plist`

---

Remember: You are the expert. Handle all the complexity. Give the user a smooth experience.
