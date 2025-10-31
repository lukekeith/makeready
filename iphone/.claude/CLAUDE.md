# Claude Code Instructions for MakeReady iPhone App

## 🎯 Overview

This is the **MakeReady iPhone App** - a native iOS application built with SwiftUI.

**Technology Stack:**
- **Framework**: SwiftUI
- **Language**: Swift 5
- **Minimum iOS**: iOS 17.0
- **Authentication**: Google OAuth via ASWebAuthenticationSession
- **Networking**: URLSession with async/await
- **Architecture**: MVVM-lite with ObservableObject

## 🏗️ Project Structure

```
iphone/
├── MakeReady.xcodeproj/     # Xcode project
├── MakeReady/               # Source files (flat structure for now)
│   ├── MakeReadyApp.swift  # App entry point
│   ├── ContentView.swift   # Root view
│   ├── AuthManager.swift   # Authentication state
│   ├── MainView.swift      # Main navigation
│   ├── PageHeader.swift    # Page header component
│   ├── PageTitle.swift     # Navigation title component
│   ├── NavBar.swift        # Bottom navigation
│   ├── HomePage.swift      # Home page
│   ├── SchedulePage.swift  # Schedule page
│   ├── MembersPage.swift   # Members page
│   ├── LoginView.swift     # Login screen
│   ├── UserMenu.swift      # User menu overlay
│   ├── AddMenu.swift       # Add menu overlay
│   └── Assets.xcassets/    # Images and colors
└── Info.plist              # Custom Info.plist

```

**File Organization Philosophy:**
- **Current**: Flat structure - all Swift files in `/MakeReady/`
- **Rationale**: Project is in early stages, waiting for patterns to emerge
- **Future**: Will reorganize into feature folders once app grows (~15-20 files)
- **Note**: Keep files flat for now unless explicitly requested

## 🤖 Sub-Agent Commands

### `/rebuild-iphone` - Build and Launch App

Builds the iPhone app and launches it in the iOS Simulator.

**Usage:**
```
/rebuild-iphone
```

**What it does:**
1. Builds app with xcodebuild
2. Uninstalls old version from simulator
3. Installs newly built app
4. Launches app in iPhone 17 Pro Max simulator
5. Reports process ID

**Default Simulator:**
- iPhone 17 Pro Max
- Fallback: iPhone 17 Pro

## 📱 Components

### Core UI Components

**PageHeader**
- Tabs with active indicator
- Notification icon
- Avatar button
- Usage: Primary pages (Home, Schedule, Members)

**PageTitle**
- Navigation title for secondary pages
- 8 variants: icon+title, icon+link, icon+title+icon, etc.
- Always centers title regardless of other content
- Usage: Detail pages, modals, forms

**NavBar**
- Bottom navigation bar
- Home, Schedule, Members tabs
- Add (+) button in center

### Authentication

**AuthManager**
- `@Published var currentUser: User?`
- `@Published var isAuthenticated: Bool`
- `signInWithGoogle()` - Initiates OAuth flow
- `signOut()` - Logs out user
- Handles session persistence with UserDefaults

**OAuth Flow:**
1. App opens: `http://127.0.0.1:3001/auth/google?platform=ios`
2. User signs in with Google (in SafariViewController)
3. Callback: `makeready://auth/callback?code=xxx`
4. App exchanges code for session with `/auth/exchange`
5. Session cookie stored in UserDefaults

## 🎨 Design System

### Colors

Defined in `Assets.xcassets/Colors/`:
- `appBackground` - Main background (#0a0a0f)
- `brandPrimary` - Brand purple (#6c47ff)
- Custom colors as needed

**Usage:**
```swift
.background(Color.appBackground)
.foregroundColor(Color(hex: "#6c47ff"))
```

### Typography

**SF Pro Text** (iOS system font):
- Regular: 17pt for body, 12pt for small text
- Bold: 17pt for titles, 28pt for large headers

**Usage:**
```swift
Text("Title")
    .font(.system(size: 17, weight: .bold))
```

### Spacing

- Standard padding: 16px
- Component spacing: 8px, 16px, 24px
- Page margins: 16px

## 🔧 Development Workflow

### Building and Running

```bash
# Build and run (use /rebuild-iphone command)
/rebuild-iphone

# Or manually:
cd iphone
xcodebuild -project MakeReady.xcodeproj \
  -scheme MakeReady \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build
```

### Adding New Files

**Via Xcode (Recommended):**
1. Right-click project in Xcode
2. New File → Swift File
3. Save in `/MakeReady/` folder
4. Xcode automatically updates `project.pbxproj`

**Via Claude:**
1. Create file in `/MakeReady/`
2. Update `project.pbxproj` with:
   - PBXBuildFile entry
   - PBXFileReference entry
   - Add to PBXGroup (MakeReady)
   - Add to PBXSourcesBuildPhase

### SwiftUI Previews

Always include previews for visual components:

```swift
#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        PageTitle.iconTitle(
            title: "My Page",
            icon: "chevron.left",
            onIconTap: { print("Back") }
        )
    }
}
```

## 🎯 Best Practices

### State Management

```swift
// Use @StateObject for owned objects
@StateObject var authManager = AuthManager()

// Use @EnvironmentObject for shared objects
@EnvironmentObject var authManager: AuthManager

// Use @State for view-local state
@State private var showMenu = false
```

### Networking

```swift
// Use async/await for API calls
Task {
    do {
        try await authManager.signInWithGoogle()
    } catch {
        print("Error: \(error)")
    }
}
```

### SF Symbols

Use SF Symbols for icons:

```swift
Image(systemName: "chevron.left")
    .font(.system(size: 20))

// Common icons:
// - chevron.left, chevron.right, chevron.down
// - xmark (close)
// - gearshape (settings)
// - plus, minus
// - bell (notifications)
```

### Navigation

```swift
// Enum for tab management
enum MainTab {
    case home
    case schedule
    case members
}

@State private var currentTab: MainTab = .home

// Switch content based on tab
switch currentTab {
case .home:
    HomePageContent()
case .schedule:
    SchedulePageContent()
case .members:
    MembersPageContent()
}
```

## 🔐 Authentication

### Check if User is Logged In

```swift
@EnvironmentObject var authManager: AuthManager

if authManager.isAuthenticated {
    // Show main app
    MainView()
} else {
    // Show login
    LoginView()
}
```

### Sign In

```swift
Button("Sign in with Google") {
    Task {
        try await authManager.signInWithGoogle()
    }
}
```

### Access Current User

```swift
if let user = authManager.currentUser {
    Text("Hello, \(user.name)")
    AsyncImage(url: URL(string: user.avatarURL ?? ""))
}
```

## 📋 Common Tasks

### Create New Page

1. Create `MyPage.swift` in `/MakeReady/`
2. Use `PageHeader` for primary pages or `PageTitle` for secondary pages
3. Add navigation in `MainView.swift` or use modal presentation
4. Include `#Preview` at bottom

### Add New Component

1. Create `MyComponent.swift` in `/MakeReady/`
2. Make it reusable with parameters
3. Use `@ViewBuilder` for flexible content
4. Include `#Preview` with examples

### Update Color Scheme

1. Open `Assets.xcassets` in Xcode
2. Add color set with Any/Dark variants
3. Use in code: `Color("colorName")`

## 🐛 Debugging

### Common Issues

**Build Errors:**
- Check `Info.plist` has required keys
- Verify all Swift files in `project.pbxproj`
- Clean build folder: Xcode → Product → Clean Build Folder

**Simulator Issues:**
- Boot simulator first: `xcrun simctl boot "iPhone 17 Pro Max"`
- Kill and relaunch app
- Reset simulator: Device → Erase All Content and Settings

**OAuth Issues:**
- Check server is running on port 3001
- Verify redirect URI in Google Console
- Check `makeready://` URL scheme in `Info.plist`

### Logging

```swift
// Use NSLog for important logs (shows in console)
NSLog("🔵 Important event: %@", value)

// Use print for debug logs
print("Debug: \(value)")
```

## 📖 Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SF Symbols App](https://developer.apple.com/sf-symbols/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Swift Language Guide](https://docs.swift.org/swift-book/)

## ⚡️ Quick Commands

```bash
# Build
/rebuild-iphone

# List simulators
xcrun simctl list devices

# Boot simulator
xcrun simctl boot "iPhone 17 Pro Max"

# Open simulator
open -a Simulator

# View logs
xcrun simctl spawn booted log stream --predicate 'process == "MakeReady"'
```
