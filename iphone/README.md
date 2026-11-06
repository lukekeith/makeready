# MakeReady - iPhone App

Native iOS application built with Swift and SwiftUI.

## 🏗️ Architecture

This iPhone app follows the MakeReady architecture patterns adapted for SwiftUI:

```
iphone/
├── MakeReady.xcodeproj/          # Xcode project
├── MakeReady/
│   ├── MakeReadyApp.swift         # App entry point
│   ├── Views/                     # SwiftUI views (UI layer)
│   │   ├── Screens/               # Full screen views
│   │   ├── Components/            # Reusable UI components
│   │   └── Layouts/               # Layout wrappers
│   ├── ViewModels/                # Observable state (similar to UI stores)
│   ├── Services/                  # API clients, data services
│   ├── Models/                    # Data models, entities
│   ├── Utilities/                 # Helper functions, extensions
│   └── Assets.xcassets/           # Images, colors, assets
└── README.md                      # This file
```

## 📱 Development Setup

### Prerequisites

- macOS with Xcode 15.0+
- iOS 17.0+ SDK
- Active Apple Developer account (for device testing)

### Getting Started

1. **Open the project**:
   ```bash
   cd iphone
   open MakeReady.xcodeproj
   ```

2. **Select simulator**:
   - In Xcode, select a simulator from the device dropdown (e.g., "iPhone 15 Pro")

3. **Build and run**:
   - Press `⌘R` or click the Play button
   - App will launch in the simulator

### Running from Terminal

```bash
# Build the project
xcodebuild -project MakeReady.xcodeproj -scheme MakeReady -configuration Debug

# Run in simulator
xcodebuild -project MakeReady.xcodeproj \
  -scheme MakeReady \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

## 🎨 Design System

The iPhone app uses the same design tokens as the web app:

### Colors

Defined in `Assets.xcassets/Colors/`:
- **Primary**: #6C47FF (Purple)
- **Secondary**: #03A9F4 (Blue)
- **Background**: #0D101A (Dark blue-black)
- **Text**: #FFFFFF (White)
- **Destructive**: #F44336 (Red)

### Typography

Uses San Francisco (iOS system font) with custom weights:
- **Heading**: `.largeTitle`, `.title`, `.headline`
- **Body**: `.body`, `.callout`
- **Caption**: `.caption`, `.caption2`

## 🔄 State Management

Following MakeReady patterns, adapted for SwiftUI:

### Views (Similar to UI Components)
- Pure SwiftUI views
- No business logic
- Receive data via `@Binding` or props
- Reusable across screens

### ViewModels (Similar to UI Stores)
- Use `@Observable` (Swift 5.9+) or `@ObservableObject`
- Computed properties for view data
- Handle user interactions
- Coordinate with Services

### Services (Similar to Domain Stores)
- API communication
- Data persistence
- Business logic
- No UI concerns

## 📂 Monorepo Integration

### Shared Resources

The iPhone app can share resources with the web app:

1. **API Endpoints**:
   - Use same backend at `http://localhost:3000`
   - Share API contracts via `shared/` folder

2. **Assets**:
   - Logo, icons can be exported from `ui/assets/`
   - Use SF Symbols for iOS-native icons

3. **Color Palette**:
   - Colors match web app design system
   - Defined in both CSS and SwiftUI

## 🧩 Component Patterns

### Example View

```swift
// Views/Components/PrimaryButton.swift
import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("Primary"))
                .cornerRadius(8)
        }
    }
}
```

### Example ViewModel

```swift
// ViewModels/HomeViewModel.swift
import SwiftUI

@Observable
class HomeViewModel {
    var isLoading: Bool = false
    var userName: String = ""

    func loadUserData() async {
        isLoading = true
        // Call service
        isLoading = false
    }
}
```

### Example Screen

```swift
// Views/Screens/HomeScreen.swift
import SwiftUI

struct HomeScreen: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Text("Hello, \(viewModel.userName)!")
                PrimaryButton(title: "Refresh") {
                    Task {
                        await viewModel.loadUserData()
                    }
                }
            }
        }
        .task {
            await viewModel.loadUserData()
        }
    }
}
```

## 🔧 Development Commands

### Build
```bash
xcodebuild -project MakeReady.xcodeproj -scheme MakeReady build
```

### Test
```bash
xcodebuild -project MakeReady.xcodeproj -scheme MakeReady test
```

### Clean
```bash
xcodebuild -project MakeReady.xcodeproj -scheme MakeReady clean
```

### Archive (for release)
```bash
xcodebuild -project MakeReady.xcodeproj \
  -scheme MakeReady \
  -archivePath build/MakeReady.xcarchive \
  archive
```

## 📱 Simulator Management

### List available simulators
```bash
xcrun simctl list devices
```

### Boot a simulator
```bash
xcrun simctl boot "iPhone 15 Pro"
```

### Install app on simulator
```bash
xcrun simctl install booted build/Debug-iphonesimulator/MakeReady.app
```

### Launch app
```bash
xcrun simctl launch booted com.makeready.app
```

## 🚀 Deployment

### TestFlight

1. Archive the app (Xcode → Product → Archive)
2. Upload to App Store Connect
3. Add to TestFlight
4. Invite testers

### Staging from a local build

With `iphone/Staging.local.xcconfig` (git-ignored) in place, a Debug build on your phone keeps Local, Staging and Production, and selecting Staging shows Test data.

### Staging TestFlight build

The `MakeReady Staging` scheme archives the `Staging` configuration: bundle id `com.makeready.app`, the same as MakeReady Groups, home-screen name MakeReady-Staging, pointed at `staging.api.makeready.org`.

1. Create `iphone/Staging.local.xcconfig` (git-ignored) with `FIXTURE_ACCESS_KEY = <alphanumeric key>`, a value equal to the server's `FIXTURE_ACCESS_KEY`. Alphanumeric only, because `//` starts a comment in an xcconfig. Without it the archive shows no fixture picker and signs in through Google, and nothing fails the build.
2. Archive the `MakeReady Staging` scheme (Xcode: select it, Any iOS Device, Product → Archive).
3. Upload to the MakeReady Groups record in App Store Connect and test it in TestFlight. It replaces any other MakeReady build on the phone. **Never submit this build for App Store review**: store builds come only from the `MakeReady` scheme.
4. To rotate the key, change the server's `FIXTURE_ACCESS_KEY` setting, update `Staging.local.xcconfig` and rebuild.

### App Store

1. Archive and upload
2. Complete App Store listing
3. Submit for review
4. Release after approval

## 📋 TODO

- [ ] Set up API service layer
- [ ] Create authentication flow
- [ ] Add navigation structure
- [ ] Implement core screens
- [ ] Add error handling
- [ ] Set up remote notifications
- [ ] Configure app icons
- [ ] Add launch screen
- [ ] Set up CI/CD for iOS

## 🔗 Related Documentation

- [Main Project README](../README.md)
- [Architecture Spec](../.project/ARCHITECTURE_SPEC.md)
- [Web App](../client/README.md)
- [Backend API](../server/README.md)

## 💡 Tips

- Use SwiftUI Previews for rapid development
- Follow Apple's Human Interface Guidelines
- Test on multiple device sizes
- Use async/await for networking
- Leverage Swift's type safety
- Keep views small and focused

---

**Current Status**: 🟢 Ready for development

The iPhone app is bootstrapped and ready to build screens!
