# Build Configuration Guide

This guide explains how to build the MakeReady iPhone app for different environments: local development, TestFlight, and production.

## Environment Configuration

The app uses `Configuration.swift` to automatically switch between environments based on build configuration:

```swift
// Configuration.swift
static var baseURL: String {
    switch current {
    case .development:
        return "http://127.0.0.1:3001"      // Local server
    case .production:
        return "https://makeready.app"      // Railway production
    }
}
```

## Build Configurations

### DEBUG (Default - Local Development)

- **Base URL**: `http://127.0.0.1:3001`
- **Auth Bypass**: Available (for testing)
- **Usage**: Xcode "Run" button, running from simulator
- **Server**: Must have local server running on port 3001

### Release (TestFlight & App Store)

- **Base URL**: `https://makeready.app`
- **Auth Bypass**: Disabled (stripped out at compile time)
- **Usage**: Archive builds, TestFlight, App Store submissions
- **Server**: Connects to Railway production server

## How It Works

The configuration system uses Swift compiler flags:

```swift
#if DEBUG
return .development    // Uses 127.0.0.1:3001
#else
return .production     // Uses makeready.app
#endif
```

**DEBUG flag is:**
- ✅ Enabled for: Xcode Run, Debug builds
- ❌ Disabled for: Archive, Release builds, TestFlight

This means:
- When you develop locally and click "Run" → Uses local server
- When you Archive for TestFlight → Automatically uses production server
- **No code changes needed!** It just works.

## Building for TestFlight

### Step 1: Archive the App

1. Open `MakeReady.xcodeproj` in Xcode
2. Select **Any iOS Device** as the destination (not a simulator!)
3. Go to **Product → Archive**
4. Wait for build to complete

### Step 2: Distribute to TestFlight

1. In the Organizer window (opens after Archive):
   - Select your archive
   - Click **Distribute App**
2. Choose **App Store Connect**
3. Choose **Upload**
4. Select your distribution certificate
5. Click **Upload**

### Step 3: Process in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to **TestFlight** tab
4. Wait for processing (10-30 minutes)
5. Add testers and enable testing

## Verifying Configuration

The app prints its configuration on launch:

```
🔧 MakeReady Configuration
   Environment: Production
   Base URL: https://makeready.app
   Auth Bypass: Disabled
   Debug Info: Disabled
```

Check the Xcode console or device logs to verify the correct environment is being used.

## Build Schemes

Xcode uses **build schemes** to determine which configuration to use:

### Current Schemes

| Scheme | Configuration | Environment | Base URL |
|--------|---------------|-------------|----------|
| **MakeReady** | Debug | Development | http://127.0.0.1:3001 |
| **MakeReady** | Release | Production | https://makeready.app |

### Checking Your Scheme

1. Click on the scheme dropdown (next to stop button)
2. Select **Edit Scheme...**
3. Look at **Run** → **Build Configuration**: Should be "Debug"
4. Look at **Archive** → **Build Configuration**: Should be "Release"

## Advanced: Custom Build Configurations (Optional)

If you want more control, you can create custom build configurations:

### 1. Create TestFlight Configuration

1. In Xcode, select the project in the navigator
2. Select the **MakeReady** project (blue icon)
3. Go to **Info** tab
4. Under **Configurations**, click **+** → **Duplicate "Release" Configuration**
5. Name it **TestFlight**

### 2. Configure TestFlight Scheme

1. Go to **Product → Scheme → Edit Scheme...**
2. Duplicate the scheme (click dropdown, **Duplicate Scheme**)
3. Name it **TestFlight**
4. Under **Archive**, change **Build Configuration** to "TestFlight"

### 3. Use Custom Configuration in Code

Update `Configuration.swift`:

```swift
static var current: Environment {
    #if TESTFLIGHT
    return .production
    #elseif DEBUG
    return .development
    #else
    return .production
    #endif
}
```

Then add a custom compiler flag:
1. Select your target
2. **Build Settings** → **Swift Compiler - Custom Flags**
3. Under **Other Swift Flags**, add `-DTESTFLIGHT` for TestFlight configuration

## Common Issues

### Issue: TestFlight build connects to localhost

**Cause**: Built with Debug configuration instead of Release
**Fix**: Use **Product → Archive** (not Run), ensure Archive uses Release configuration

### Issue: Local build can't connect to server

**Cause**: Local server not running
**Fix**: Start server with `cd server && npm run dev`

### Issue: Authentication bypass appears in production

**Cause**: Built with DEBUG flag enabled
**Fix**: Archive builds automatically use Release (no DEBUG flag)

### Issue: Want to test production API locally

**Solution**: Temporarily override in `Configuration.swift`:

```swift
static var baseURL: String {
    // Uncomment to test production API locally:
    // return "https://makeready.app"

    switch current {
    case .development:
        return "http://127.0.0.1:3001"
    case .production:
        return "https://makeready.app"
    }
}
```

## Testing Different Environments

### Test Local (Development)

```bash
# 1. Start local server
cd server && npm run dev

# 2. Run app in Xcode (⌘R)
# App uses http://127.0.0.1:3001
```

### Test Production (from Xcode)

```swift
// Temporarily change Configuration.swift
static var current: Environment {
    return .production  // Force production mode
}
```

Then run in Xcode - app will use production server.

### Test Production (TestFlight)

1. Archive and upload to TestFlight
2. Install from TestFlight on device
3. App automatically uses production server

## Summary

**For day-to-day development:**
- Just click Run in Xcode
- Uses local server automatically
- No configuration needed

**For TestFlight releases:**
- Product → Archive
- Upload to App Store Connect
- Automatically uses production server
- No code changes needed

**The system is designed to "just work" without manual intervention!**
