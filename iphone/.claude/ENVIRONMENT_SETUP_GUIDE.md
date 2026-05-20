# iPhone App Environment Setup Guide

## Overview

This guide explains the best-practice multi-environment setup for iOS development, allowing you to run:
- **Debug** - Local development with debugger (127.0.0.1)
- **Development** - Local development without debugger (127.0.0.1)
- **Staging** - Testing environment (staging.makeready.org)
- **Production** - Live app (api.makeready.org) for TestFlight/App Store

## Architecture

```
┌─────────────────┐
│  xcconfig Files │ ← Environment-specific settings
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│ Build Configs   │ ← Debug, Development, Staging, Release
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│    Schemes      │ ← When to use each configuration
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│ Configuration.  │ ← Swift code reads environment
│    swift        │
└─────────────────┘
```

## File Structure

```
iphone/
├── MakeReady/
│   ├── Configuration/
│   │   ├── Debug.xcconfig         ← Local with debugger
│   │   ├── Development.xcconfig   ← Local without debugger
│   │   ├── Staging.xcconfig       ← Staging server
│   │   └── Release.xcconfig       ← Production server
│   ├── Configuration.swift        ← Reads environment settings
│   └── Info.plist                 ← Receives xcconfig values
```

## Setup Instructions

### Step 1: Link xcconfig Files to Build Configurations

1. Open `MakeReady.xcodeproj` in Xcode
2. Select the **MakeReady project** (blue icon)
3. Go to **Info** tab
4. Under **Configurations**:
   - For **Debug** → Set to `Debug.xcconfig`
   - For **Development** → Set to `Development.xcconfig`
   - For **Staging** → Set to `Staging.xcconfig`
   - For **Release** → Set to `Release.xcconfig`

**Note:** If you don't see Development/Staging configurations:
- Click **+** → **Duplicate "Debug"** → Name it **"Development"**
- Click **+** → **Duplicate "Release"** → Name it **"Staging"**

### Step 2: Create Schemes (Optional but Recommended)

Schemes let you quickly switch environments from the toolbar.

1. **Product → Scheme → Manage Schemes...**
2. Select **MakeReady** scheme
3. Click the **gear icon** → **Duplicate**
4. Name it **"MakeReady-Development"**
5. Edit the new scheme:
   - **Run** → Build Configuration: **Development**
   - **Archive** → Build Configuration: **Development**
6. Repeat for **Staging** and **Release**

Now you'll have:
- **MakeReady** (Debug) - For day-to-day development
- **MakeReady-Development** (Development) - Test without debugger
- **MakeReady-Staging** (Staging) - Test staging server
- **MakeReady-Release** (Release) - Production builds

### Step 3: Verify Setup

Build and check the console output:

```
🔧 MakeReady Configuration
   Environment: Debug
   Base URL: http://127.0.0.1:3001
   Bundle ID: com.makeready.app.debug
   Auth Bypass: Enabled
   Debug Info: Enabled
   Is Production: No
```

## Environment Details

### Debug (Default for Xcode Run)

```swift
// Debug.xcconfig
API_BASE_URL = http://127.0.0.1:3001
PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.debug
PRODUCT_NAME = MakeReady-Debug
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
```

**Use when:**
- Daily development
- Using breakpoints
- Need hot reload

**Features:**
- Auth bypass enabled
- Debug info shown
- Local server only

### Development

```swift
// Development.xcconfig
API_BASE_URL = http://127.0.0.1:3001
PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.dev
PRODUCT_NAME = MakeReady-Dev
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEVELOPMENT
```

**Use when:**
- Testing without debugger
- Performance testing
- Install alongside production app

**Features:**
- Local server
- Debug info shown
- Different bundle ID (install alongside other builds)

### Staging

```swift
// Staging.xcconfig
API_BASE_URL = https://staging.makeready.org
PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging
PRODUCT_NAME = MakeReady-Staging
SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING
```

**Use when:**
- Testing staging server
- QA testing
- Pre-production verification

**Features:**
- Staging server
- Can install alongside dev and production
- Different app icon (recommended)

### Release (Production)

```swift
// Release.xcconfig
API_BASE_URL = https://api.makeready.org
PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app
PRODUCT_NAME = MakeReady
SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE
```

**Use when:**
- TestFlight builds
- App Store submission
- Production testing

**Features:**
- Production server only
- Auth bypass disabled
- Optimized build

## Switching Environments

### Method 1: Change Scheme (Recommended)

1. Click scheme dropdown (next to stop button)
2. Select:
   - **MakeReady** → Debug/Local
   - **MakeReady-Staging** → Staging server
   - **MakeReady-Release** → Production server
3. Click Run (⌘R)

### Method 2: Edit Active Scheme

1. **Product → Scheme → Edit Scheme...**
2. Select **Run** on left
3. Change **Build Configuration**
4. Click Close
5. Run (⌘R)

### Method 3: Temporary Override

In `Configuration.swift`, you can temporarily force an environment:

```swift
static var baseURL: String {
    // TEMPORARY: Force production URL for testing
    // return "https://api.makeready.org"

    // Normal behavior:
    if let apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
        return apiBaseURL
    }
    // ...
}
```

## Benefits of This Approach

### ✅ Multiple Apps Side-by-Side

Each environment has a different bundle ID:
- `com.makeready.app.debug`
- `com.makeready.app.dev`
- `com.makeready.app.staging`
- `com.makeready.app`

You can install all four simultaneously on a device and test switching between them.

### ✅ Visual Differentiation

Each build can have its own:
- App name (MakeReady-Debug, MakeReady-Staging, etc.)
- App icon (recommended: add badges or colors)
- Launch screen

### ✅ Compiler Optimizations

- Debug: No optimizations, full debugging
- Development: Minimal optimizations
- Staging: Some optimizations
- Release: Full optimizations, smallest binary

### ✅ Feature Flags

Use compiler conditions to enable/disable features:

```swift
#if DEBUG || DEVELOPMENT
// Show debug menu
#endif

#if STAGING || RELEASE
// Enable analytics
#endif

#if RELEASE
// Enable crash reporting
#endif
```

### ✅ Clean Configuration Management

All environment-specific settings in `.xcconfig` files:
- No hardcoded values in Swift
- Easy to update
- No accidental production deployment with debug settings

## Advanced: Environment-Specific App Icons

1. Create app icon sets in `Assets.xcassets`:
   - `AppIcon-Debug` (with "DEV" badge)
   - `AppIcon-Staging` (with "STG" badge)
   - `AppIcon` (production, no badge)

2. Update xcconfig files:

```
// Debug.xcconfig
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Debug

// Staging.xcconfig
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Staging

// Release.xcconfig
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
```

3. Rebuild - each environment has its own icon!

## TestFlight Deployment

### For Production TestFlight:

1. Select **MakeReady-Release** scheme (or edit scheme to use Release config)
2. **Product → Archive**
3. **Distribute App** → App Store Connect
4. Upload

App will use:
- `https://api.makeready.org`
- Bundle ID: `com.makeready.app`
- No auth bypass
- Production optimizations

### For Staging TestFlight (Optional):

1. Select **MakeReady-Staging** scheme
2. **Product → Archive**
3. Upload with bundle ID `com.makeready.app.staging`
4. QA team can install both staging and production builds

## Troubleshooting

### Q: Build configuration not changing?

**A:** Clean build folder: **Product → Clean Build Folder** (⌘⇧K)

### Q: xcconfig values not appearing in Info.plist?

**A:**
1. Check xcconfig is linked in Project settings
2. Ensure `$(API_BASE_URL)` syntax in Info.plist
3. Clean and rebuild

### Q: Multiple app versions conflict?

**A:** Ensure each build configuration has a unique bundle ID:
- Debug: `.debug`
- Development: `.dev`
- Staging: `.staging`
- Release: (base ID)

### Q: Can't tell which environment I'm running?

**A:** Add visual indicator in app:

```swift
#if DEBUG || DEVELOPMENT
VStack {
    Text("Environment: \(Configuration.current.displayName)")
        .font(.caption)
        .foregroundColor(.red)
}
#endif
```

### Q: Want to test production API locally?

**A:** Change scheme to Release, or temporarily override in Configuration.swift

## Best Practices

### ✅ DO:
- Use schemes for quick switching
- Keep xcconfig files in version control
- Test staging before production
- Use different bundle IDs per environment
- Add visual indicators for non-production builds

### ❌ DON'T:
- Hardcode URLs in Swift files
- Use same bundle ID for all environments
- Commit temporary environment overrides
- Skip testing in staging
- Mix debug/release settings

## Summary

Your environment setup is now:

```
┌──────────┬──────────────┬────────────────────────┬──────────────────┐
│ Scheme   │ Config       │ Server                 │ Bundle ID        │
├──────────┼──────────────┼────────────────────────┼──────────────────┤
│ Default  │ Debug        │ http://127.0.0.1:3001  │ .app.debug       │
│ Dev      │ Development  │ http://127.0.0.1:3001  │ .app.dev         │
│ Staging  │ Staging      │ https://staging...org  │ .app.staging     │
│ Release  │ Release      │ https://api...org      │ .app             │
└──────────┴──────────────┴────────────────────────┴──────────────────┘
```

**Just select a scheme and run - that's it!** 🚀
