# Claude Code Instructions for MakeReady iPhone App

## 🎯 CONTEXT: YOU ARE IN THE IPHONE PROJECT

**This is the iPhone Swift/SwiftUI project ONLY. Do NOT use patterns from other projects.**

When working in `/Users/lukekeith/www/makeready/iphone/`:
- ✅ ONLY use Swift/SwiftUI patterns
- ✅ ONLY use slash commands from `iphone/.claude/commands/`
- ✅ ONLY reference iPhone component architecture
- ❌ NEVER use React/TypeScript/web client patterns
- ❌ NEVER use slash commands from root `.claude/commands/` (those are for web client)
- ❌ NEVER mention CVA, SCSS, Storybook, MobX, or other web technologies

**If you accidentally reference web patterns, STOP immediately and correct yourself.**

---

## 🌐 Web Client MCP Server (makeready-client)

**When creating links, URLs, deep links, or anything that interfaces with the web app (app.makeready.org), ALWAYS use the `makeready-client` MCP tools first to get accurate route paths and page structure.**

Available MCP tools:
- `mcp__makeready-client__list_routes` - List all web routes (filter by section, method, or path)
- `mcp__makeready-client__get_route_detail` - Get full details for a specific route
- `mcp__makeready-client__list_components` - List web UI components
- `mcp__makeready-client__get_component_detail` - Get component documentation
- `mcp__makeready-client__list_pages` - List all pages and layouts
- `mcp__makeready-client__list_stores` - List client stores
- `mcp__makeready-client__search_client` - Search the client codebase

**When to use:**
- Building URLs that link to the web app (e.g., invite links, share links, deep links)
- Ensuring route paths match the actual web app routes
- Understanding what pages/views exist on the web side
- Coordinating features between iPhone and web apps

**Web app base URL:** `https://app.makeready.org`

---

## ⚠️ PRIME DIRECTIVE

**NEVER create authentication bypasses, test modes, or skip login functionality without explicitly asking the user for permission first.**

This includes but is not limited to:
- Adding "Skip Login" buttons
- Setting `authManager.isAuthenticated = true` directly
- Creating test/debug flags that bypass authentication
- Modifying login flows to skip OAuth
- Any other mechanism that circumvents the intended authentication flow

**Always ask first:** "Would you like me to add a temporary bypass for testing?" and wait for explicit approval.

---

**NEVER commit changes to git without explicit permission from the user.**

This includes:
- Running `git commit` commands
- Creating commits after making changes
- Committing fixes, features, or updates

**Always ask first:** "Would you like me to commit these changes?" and wait for explicit approval before running any git commit commands.

**Exception:** You may still run `git status`, `git diff`, and `git add` commands as needed, but NEVER `git commit` without permission.

---

**NEVER NEVER NEVER build the project without explicit permission from the user.**

**This is an absolute, non-negotiable rule. There are ZERO exceptions. ALWAYS ask first.**

This includes:
- Running `xcodebuild` commands (build, archive, clean, ANY xcodebuild invocation)
- Running `/rebuild-iphone` slash command
- Running `xcrun simctl install` or `xcrun simctl launch`
- Opening the Simulator app
- Any simulator-related commands
- Running builds "to verify changes compile" — DO NOT DO THIS

**You MUST ask first:** "Would you like me to build?" and wait for explicit "yes" before running ANY build command. Do not assume. Do not build to "check if it compiles." Do not build as a verification step. The user will build when they are ready.

**Exception:** You may run `xcrun simctl list` to check available simulators, but NEVER build, install, or launch without permission.

---

**NEVER create custom UI elements without checking for existing components first.**

## 🚨 Component Reuse Protocol

Before implementing ANY UI element (buttons, headers, inputs, lists, cards, etc.), you MUST:

1. ✅ **Stop and search** - Review the "Components" section below for existing solutions
2. ✅ **Check variants** - Existing components often have multiple variants (e.g., PageTitle has 8 variants)
3. ✅ **Prefer adaptation** - Use existing components with different props/variants rather than creating new ones
4. ✅ **Ask before creating** - If unsure, ask: "I found [Component] with variants [X, Y, Z]. Should I use it or create custom?"

**Examples of what NOT to do:**
- ❌ Creating custom header with HStack + Text + Button (use PageTitle component)
- ❌ Building manual button with padding/background (use ActionButton component)
- ❌ Custom text input layout (use TextInput component)
- ❌ Hand-rolled search field (use SearchField component)
- ❌ Replacing an existing component with a manual implementation (e.g., replacing SearchField with HStack + TextField)

**Why this matters:**
- Maintains design system consistency
- Reduces code duplication
- Ensures correct styling (colors, spacing, typography)
- Prevents reinventing existing solutions
- Preserves animations and interactions built into components

**CRITICAL: Never replace existing components with manual implementations.**
When editing code that already uses a component (like SearchField), KEEP using that component. Do not substitute it with a basic SwiftUI implementation (like HStack + TextField). Existing components have animations, styling, and interactions that manual implementations will lack.

**If you create custom UI when a component exists, the user will catch it and you'll need to refactor.**

---

**ALWAYS check the makeready-api MCP server before implementing API-dependent features.**

Before implementing any feature that calls backend APIs:
1. **Use the `makeready-api` MCP tools** as the source of truth for endpoints:
   - `mcp__makeready-api__list_api_endpoints` - List all server endpoints
   - `mcp__makeready-api__get_endpoint_detail` - Full request/response spec for an endpoint
   - `mcp__makeready-api__search_api` - Search the server API by keyword
   - `mcp__makeready-api__get_schema` - Database schema for a model
2. **Validate request/response formats** match the API documentation
3. **Check authentication requirements** (session cookies, headers)
4. **Verify base URLs** (local: http://127.0.0.1:3010, production: https://api.makeready.org)
5. **Follow documented patterns** for error handling and data models (see the "API Endpoints" section below)

This ensures API implementations match server specifications and prevents integration issues.

---

**ALWAYS check SWIFTUI_TRANSITIONS.md before implementing page transitions or animations.**

Before implementing any page transitions, modal presentations, or animations:
1. **Read `.claude/SWIFTUI_TRANSITIONS.md`** for documented patterns and common pitfalls
2. **Use explicit `withAnimation()`** instead of implicit `.animation()` modifier for user-triggered transitions
3. **Add `.buttonStyle(.plain)`** to buttons that trigger page transitions
4. **Update the transitions document** when you discover and fix new animation issues

This prevents recurring issues with elements animating incorrectly during transitions.

---

**ALWAYS check SWIFTUI_ANIMATION_PATTERNS.md before implementing drag gestures, menus, or animated overlays.**

Before implementing any drag gestures, swipe-to-dismiss, or animated menus/modals:
1. **Read `.claude/SWIFTUI_ANIMATION_PATTERNS.md`** for jitter-free animation patterns
2. **Use `@GestureState`** instead of `@State` for drag tracking
3. **Use `ModalAnimations` utility** for consistent modal/menu animations
4. **Use `presentMenu()`** for menus - provides swipe-to-dismiss, dark overlay, and unified animations
5. **Never mix animation curves** (e.g., easeOut + spring in same transition)

This prevents jitter, lagging subviews, and ghosting in animations.

---

**ALWAYS check SWIFTUI_PREVIEW_ERRORS.md before adding cards/variations to a `#Preview` or when a preview fails to build.**

Before adding new cards, stress tests, or many variations to an existing `#Preview`, and whenever a preview fails with errors like "unable to type-check this expression in reasonable time" or phantom "Cannot find type" errors:
1. **Read `.claude/SWIFTUI_PREVIEW_ERRORS.md`** for the diagnosis and fix playbook
2. **Wrap groups of children in `Group { }`** to stay under the ~10-child ViewBuilder limit
3. **Extract stress tests into a `private struct: View`** with helper functions instead of inlining
4. **Split large previews into multiple `#Preview` tabs** — each tab is an isolated type-check scope
5. **Add explicit type annotations** to tuple/array literals in preview helpers
6. **Never disable a preview** to work around the error — fix the root cause

This prevents recurring type-checker timeouts and ViewBuilder limit failures when iterating on component previews.

---

**SwiftLint gates every build against the audit conventions (Phase 5.1) — new code only.**

The `SwiftLint (audit conventions)` build phase fails the build when NEW code violates:
no `print`/`NSLog` (use the `Log.<domain>` wrappers — `Utilities/Log.swift`), no
`try!`/`as!`, no inline `Color(hex:)` outside `Colors.swift`, no raw `.system(size:)`
outside `Typography.swift`, no `asyncAfter(deadline:)` choreography, formatters must be
`static`, and no lazy containers in animated overlay files. The ~1,100 existing
violations (2,449 at gate creation) are grandfathered in
`iphone/.swiftlint-baseline.json` — never regenerate the baseline to silence a new
violation; fix the code, or (for a consciously-accepted case like a toast timer) regenerate
deliberately and say so in the commit message:
`cd iphone && swiftlint lint --write-baseline .swiftlint-baseline.json`

---

**ALWAYS use OverlayManager for modals and menus. NEVER use .fullScreenCover for forms, dialogs, or editing pages.**

Before presenting any modal, menu, or overlay:
1. **Use the /present-overlay skill** — it scaffolds the Route registration and presentation correctly
2. **Read `MakeReady/Components/Layout/MODAL_GUIDE.md`** for the correct pattern
3. **Register a `Route` case** in `Services/Route.swift` (id + only-if-non-default priority/chrome/dismissOnTapOutside) — chrome and z-order live on the type, never at the call site
4. **Present via `overlayManager.present(.yourRoute)`** for forms, menus, confirmations, and push-style pages alike
5. **Only use `.fullScreenCover`** for video recording, video playback, and photo pickers (hardware access)

This prevents flickering, z-order bugs, missing drag indicators, and inconsistent dismiss behavior.

---

## 🏛️ State Management Architecture (CRITICAL)

**This app uses a centralized observable state pattern. ALL new views MUST follow this pattern.**

### Core Principle: AppState + Actions

```
┌─────────────────────────────────────────────────────────────┐
│                      AppState.shared                         │
│  (Single source of truth - @Observable singleton)           │
│                                                              │
│  programs: EntityStore<StudyProgram>                        │
│  groups: EntityStore<UserGroup>                             │
│  enrollments: EntityStore<EnrollmentWithProgram>            │
│  videos: EntityStore<Video>                                 │
│  lessons: EntityStore<Lesson>                               │
│  activities: EntityStore<StudyActivity>                     │
└─────────────────────────────────────────────────────────────┘
           ▲                              │
           │ mutate                       │ observe
           │                              ▼
┌──────────┴────────┐           ┌─────────────────┐
│     Actions       │           │     Views       │
│ ProgramActions()  │           │ (auto-rerender) │
│ GroupActions()    │           │                 │
│ EnrollmentActions()│          │                 │
│ VideoActions()    │           │                 │
└───────────────────┘           └─────────────────┘
```

### ✅ CORRECT Pattern for New Views

```swift
struct MyNewPage: View {
    // 1. Access centralized state (NOT @State or @StateObject for app data)
    private var state: AppState { AppState.shared }

    // 2. Local UI state only (modals, selections, loading flags)
    @State private var showModal = false
    @State private var isLoading = false

    var body: some View {
        // 3. Read from state - view auto-rerenders when data changes
        ForEach(state.orderedPrograms) { program in
            Text(program.name)
        }
    }

    // 4. Use Actions to load/modify data (NEVER call API directly).
    //    Failures route through the error channel — see "Error Handling" below.
    private func loadData() async {
        do {
            try await ProgramActions().loadPrograms()
        } catch {
            // Load/refresh failure: record, console-only (surface defaults to false)
            state.recordError(error, context: "MyNewPage.loadData")
        }
    }

    // 5. Use Actions for mutations — a failed user-initiated action surfaces the banner
    private func deleteProgram(_ id: String) async {
        do {
            try await ProgramActions().deleteProgram(id: id)
            // No need to update local state - AppState updates, view auto-rerenders
        } catch {
            state.recordError(error, context: "MyNewPage.deleteProgram",
                              surface: true,
                              friendlyMessage: "Couldn't delete the program",
                              retry: { Task { await deleteProgram(id) } })
        }
    }
}
```

### ❌ WRONG Patterns (Never Do This)

```swift
// ❌ WRONG: Storing app data in local @State
@State private var programs: [StudyProgram] = []

// ❌ WRONG: Direct API calls in views
let response = try await URLSession.shared.data(from: url)

// ❌ WRONG: Creating your own data manager
class MyCustomManager: ObservableObject { ... }

// ❌ WRONG: Fetching data without Actions
let data = try await api.get("/api/programs")

// ❌ WRONG: Swallowing errors (log-and-stop) — route through the error channel
catch { NSLog("Error: \(error)") }   // use state.recordError(...) instead
```

### Available Actions

| Action | Purpose | Key Methods |
|--------|---------|-------------|
| `ProgramActions()` | Study programs, lessons, activities | `loadPrograms()`, `getProgram(id:)`, `createProgram()`, `deleteProgram()`, `updateActivity()` |
| `GroupActions()` | Groups, posts, members | `loadGroups()`, `getGroup(id:)`, `createGroup()`, `loadPosts()`, `loadMembers()` |
| `EnrollmentActions()` | Enrollments | `loadEnrollments(groupId:)`, `createEnrollment()`, `deleteEnrollment()` |
| `VideoActions()` | Video library | `loadVideos()`, `uploadAndCreateVideo()`, `deleteVideo()` |
| `HomeActions()` | Home dashboard, calendar | `loadHomeData(forceRefresh:)`, `loadCalendarEvents(forceRefresh:)` |
| `MediaActions()` | Media library (photos, tags) | `loadLibrary()`, `searchLibrary()`, `uploadPhoto(image:title:)`, `loadDetail(id:)`, `loadUsages(id:)`, `updateMedia(id:title:description:)`, `deleteMedia(id:)`, `addTags()`, `removeTags()`, `syncTags()`, `loadAllMediaTags()` |
| `NotificationActions()` | In-app notifications | `loadNotifications()`, `loadUnreadCount()`, `markAsRead(ids:)`, `markAllAsRead()` |
| `DeviceTokenActions()` | APNs push tokens | `registerToken(_:environment:)`, `removeToken(_:)` |
| `ThemeActions()` | Text themes for content styling | `loadThemes()` |
| `InviteActions()` | Group/org invites & QR codes | `createInvite(groupId:expiresAt:)`, `generateQRCode(...)` |
| `OrgActions()` | Organization info | `loadMemberCount(organizationId:)` |

Note: `ProgramActions` is split across three files (`ProgramActions.swift` +
`ProgramActions+Lessons.swift` + `ProgramActions+Activities.swift`) — one struct, extension files by topic.

### Error Handling — Route Failures Through the Error Channel

Every `catch` must do one of three things (the **/ios-error-surface** skill walks the decision):

1. **Route to the error channel:** `state.recordError(error, context: "Page.action")`.
   Console-only by default. Pass `surface: true` (+ `friendlyMessage:`, optional `retry:`
   closure) ONLY when the user just took the action that failed (save, upload, delete,
   send) — the top `ErrorBanner` then shows it (4s auto-dismiss, swipe-up, retry button).
   Background refreshes and prefetches stay console-only (`surface: false`, the default).
2. **Recover meaningfully** — fallback value, cached data, retry logic.
3. **Justify staying silent** with a `// Silent: <why>` comment.

New logging goes through `Log.<domain>` (os.Logger wrappers in `Utilities/Log.swift`:
`auth`/`state`/`nav`/`media`/`api`/`push`/`ui`/`bible`) — SwiftLint blocks new
`print`/`NSLog`. Example: `Log.media.error("upload failed: \(error.localizedDescription, privacy: .public)")`.

### Cache-First Loading Pattern

Actions implement cache-first loading automatically:
1. **If cached data exists**: Return immediately, refresh in background
2. **If no cache**: Show loading state, fetch from API
3. **On mutation**: Update AppState, persist to disk

```swift
// This automatically uses cache if available
try await ProgramActions().loadPrograms(forceRefresh: false)

// Force fresh data (e.g., pull-to-refresh)
try await ProgramActions().loadPrograms(forceRefresh: true)
```

### Accessing Related Data

Use AppState helper methods for relationships:

```swift
// Get lessons for a program
let lessons = state.lessonsFor(programId: programId)

// Get enrollments for a group
let enrollments = state.enrollmentsFor(groupId: groupId)

// Get posts for a group
let posts = state.postsFor(groupId: groupId)
```

### File Locations

```
MakeReady/State/
├── AppState.swift              # Central @Observable singleton
├── EntityStore.swift           # Generic normalized storage
├── RelationshipIndex.swift     # Parent→child mappings
├── LoadingStateManager.swift   # Per-entity loading states
├── Models/                     # Data models split by domain (audit 5.7)
│   ├── Contact.swift
│   ├── EnrollmentModels.swift
│   ├── GroupMembershipModels.swift
│   ├── LessonModels.swift
│   ├── MediaModels.swift
│   ├── ModelFormatters.swift
│   ├── NotificationModels.swift
│   ├── ThemeModels.swift
│   └── VideoModels.swift
├── API/
│   └── APIClient.swift         # HTTP client (used by Actions only)
├── Actions/
│   ├── ProgramActions.swift            # + extension files by topic:
│   ├── ProgramActions+Lessons.swift
│   ├── ProgramActions+Activities.swift
│   ├── GroupActions.swift
│   ├── EnrollmentActions.swift
│   ├── VideoActions.swift
│   ├── HomeActions.swift
│   ├── MediaActions.swift
│   ├── NotificationActions.swift
│   ├── DeviceTokenActions.swift
│   ├── ThemeActions.swift
│   ├── InviteActions.swift
│   └── OrgActions.swift
└── Persistence/
    ├── StatePersistence.swift  # Disk read/write
    └── PersistedState.swift    # Codable snapshot
```

---

## 🎯 Overview

This is the **MakeReady iPhone App** - a native iOS application built with SwiftUI.

**Technology Stack:**
- **Framework**: SwiftUI
- **Language**: Swift 5
- **Minimum iOS**: iOS 17.0
- **Authentication**: Google OAuth via ASWebAuthenticationSession
- **Networking**: URLSession with async/await (via APIClient)
- **Architecture**: Centralized @Observable State + Actions pattern (see State Management section above)

## 🏗️ Project Structure

```
iphone/
├── MakeReady.xcodeproj/     # Xcode project
├── MakeReady/
│   ├── MakeReadyApp.swift   # App entry point
│   ├── AuthManager.swift    # Authentication state
│   ├── MainView.swift       # Main navigation (root view)
│   │
│   ├── State/               # ⭐ CENTRALIZED STATE (see State Management section)
│   │   ├── AppState.swift           # @Observable singleton
│   │   ├── EntityStore.swift        # Generic storage
│   │   ├── Models/                  # Domain models (Contact, Enrollment, Group, …)
│   │   ├── Actions/                 # Data operations (see Available Actions table)
│   │   └── Persistence/             # Disk caching
│   │
│   ├── Pages/               # Page views (use AppState + Actions)
│   │   ├── View/            # Main tab pages
│   │   ├── Manage/          # Management pages (programs, groups, etc.)
│   │   └── Video/           # Video recording/library
│   │
│   ├── Components/          # Reusable UI components
│   │   ├── Navigation/      # Headers, nav bars
│   │   ├── Input/           # Form inputs
│   │   ├── Display/         # Cards, lists, avatars
│   │   └── Charts/          # Data visualizations
│   │
│   └── Assets.xcassets/     # Images and colors
└── Info.plist               # App configuration
```

**Key Architecture Rules:**
- **State folder**: Contains ALL data management - never bypass this
- **Pages**: Read from `AppState.shared`, mutate via Actions
- **Pure components (default)**: Pure UI, receive data via props, no state access
- **Connected components (explicit exceptions)**: A small, fixed list of components that may READ `AppState.shared` (never call `APIClient` directly; mutations still go through Actions). Currently:
  - `Components/Input/MediaLibraryPicker.swift`
  - `Components/Input/BlockStyleEditor.swift`
  - `Components/Navigation/UserMenu.swift`
  - `Components/Feedback/ErrorBanner.swift` (ErrorBannerHost observes `AppState.activeSurfacedError`)

  Any new connected component requires adding it to this list. Default to pure components unless there is a strong reason not to.

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

### `/qr-code` - QR Code Generation Guide

Comprehensive guide for implementing QR code generation in the MakeReady iPhone app.

**Usage:**
```
/qr-code
```

**What it covers:**
- Server-side QR code generation with logo embedding
- InviteQRCodeView component usage
- API endpoint documentation
- Caching prevention strategies
- Integration examples
- Common issues and solutions

**When to use:**
- Implementing QR code features for invites
- Debugging QR code display issues
- Understanding server-client QR architecture
- Adding logo embedding to QR codes
- Troubleshooting cache issues

**Key Features:**
- Logo embedding (default: ON)
- Server-generated QR codes via `/api/qrcode/generate`
- No caching (fresh generation every time)
- Customizable size, colors, and error correction

## 📱 Component Library

**IMPORTANT:** Always use existing components before creating new ones. Check this section first when implementing UI.

### Navigation Components

**PageHeader**
- Tabs with active indicator, notification icon, avatar button
- Usage: Primary pages (Home, Schedule, Members)
- Example:
  ```swift
  PageHeader(
      title: "Home",
      tabs: ["All", "Active"],
      selectedTab: $selectedTab,
      onNotificationTap: { showNotifications = true },
      onAvatarTap: { showUserMenu = true }
  )
  ```

**PageTitle**
- 8 variants: icon+title, icon+link, icon+title+icon, title+icon, title+link, title only, link only, icon+title+link
- Always centers title regardless of other content
- Usage: Secondary pages, detail views, modals
- Examples:
  ```swift
  PageTitle.iconTitle(title: "Profile", icon: "chevron.left", onIconTap: { dismiss() })
  PageTitle.titleLink(title: "Settings", link: "Done", onLinkTap: { save() })
  ```

**NavBar**
- Bottom navigation: Home, Schedule, Members tabs + centered Add button
- Example:
  ```swift
  NavBar(currentTab: $currentTab, onAddTap: { showAddMenu = true })
  ```

### Buttons

**ActionButton** (5 variants)
- `.purple` - Purple background with label
- `.purpleIcon` - Purple background, icon only
- `.white` - White 10% opacity background with label
- `.whiteIcon` - White 10% opacity background, icon only
- `.whitePurple` - Solid white background, purple icon (icon only)
- Examples:
  ```swift
  ActionButton(label: "Invite", icon: "plus", variant: .purple) { createInvite() }
  ActionButton(icon: "arrow.right", variant: .whitePurple) { next() }
  ```

### Cards & Lists

**GroupCard**
- Displays group info with selection state
- Props: title, duration, dateRange, memberCount, imageURL, isSelected
- Example:
  ```swift
  GroupCard(
      title: "Young professionals",
      duration: "30 days",
      dateRange: "Aug 1 - Sept 18",
      memberCount: 27,
      imageURL: url,
      isSelected: $isSelected
  )
  ```

**SwipeableGroupCard**
- GroupCard wrapper with slide-out action buttons
- Buttons scale 24-48px, icons 12-20px, opacity 0-100% based on slide
- Example:
  ```swift
  SwipeableGroupCard(
      group: group,
      slideButtons: [
          SlideButton(icon: "trash", style: .destructive) { delete() },
          SlideButton(icon: "pencil", style: .normal) { edit() }
      ]
  )
  ```

**MemberListItem** (4 variants)
- `.contact` - Contact with invite button
- `.memberWithInvite` - Member with invite status
- `.member` - Basic member display
- `.memberMultipleGroups` - Member with group badges
- Examples:
  ```swift
  MemberListItem(contact: contact, onInviteTap: { invite(contact) })
  MemberListItem(member: member, variant: .memberWithInvite, onInviteTap: { resend() })
  ```

### Form Inputs

**TextInput**
- Single-line text with validation & input types
- Types: `.alphanumeric`, `.email`, `.phone`, `.number`, `.url`, `.password`, etc.
- Two styles: placeholder or labeled (with optional icon)
- Examples:
  ```swift
  TextInput(placeholder: "Name", text: $name)
  TextInput(label: "Email", icon: "envelope.fill", inputType: .email, text: $email)
  ```

**MultilineTextInput / LargeTextInput**
- Multi-line text entry for descriptions, notes, etc.
- Example:
  ```swift
  MultilineTextInput(label: "Description", text: $description, maxLength: 500)
  ```

**SearchField**
- Animated search: centers when inactive, left-aligns when focused
- Example:
  ```swift
  SearchField(
      isActive: $isActive,
      searchText: $searchText,
      isFocused: $isFocused,
      placeholder: "Search members"
  )
  ```

**ToggleControl & ToggleGroup**
- Toggle with title/description, wrap multiple in ToggleGroup for proper spacing
- Example:
  ```swift
  ToggleGroup {
      ToggleControl(
          title: "Private Group",
          description: "Only members can see this group",
          isOn: $isPrivate
      )
      ToggleControl(title: "Allow Invites", isOn: $allowInvites)
  }
  ```

**DatePickerField**
- Date picker with label
- Example:
  ```swift
  DatePickerField(label: "Start date", date: $startDate)
  ```

**MenuInput**
- Menu selection input
- Example:
  ```swift
  MenuInput(label: "Group", options: groups, selection: $selectedGroup)
  ```

### Display Components

**Avatar** (6 sizes)
- Sizes: `.xs`(24px), `.sm`(32px), `.md`(40px), `.lg`(48px), `.xl`(64px), `.xxl`(96px)
- Fallback order: photo URL → initials → icon
- Examples:
  ```swift
  Avatar(imageURL: user.avatarURL, initials: "JD", size: .lg)
  Avatar(firstName: "John", lastName: "Doe", size: .xl)
  ```

**AlphabetScrubber**
- Vertically-centered alphabet navigation for scrollable lists
- Example:
  ```swift
  AlphabetScrubber { letter in
      scrollTo(letter)
  }
  ```

**InviteQRCodeView**
- Server-generated QR codes with embedded logo
- Logo embedding ON by default, caching disabled
- Example:
  ```swift
  InviteQRCodeView(inviteCode: "ABC123", size: 320, includeLogo: true)
  ```
- See `/qr-code` command for complete documentation

### Charts

**Available Chart Types:**
- `HeatMapChart` - Heat map visualization
- `VerticalBarChart` - Vertical bar chart
- `HorizontalBarChart` - Horizontal bar chart
- `DonutChart` - Donut/pie chart
- `LineChart` - Line graph

All charts support customizable colors, labels, and data formatting.

### Overlays & Sheets

**Menus:**
- `UserMenu` - User profile menu (avatar, name, My Profile, Logout)
- `AddMenu` - Add action menu (triggered by NavBar + button)
- `HamburgerMenu` - Navigation menu overlay

**Sheets:**
- `GroupSelectorSheet` - Group selection bottom sheet
- `ShareInviteSheet` - Invite sharing with QR code display

All menus/sheets support binding for presentation state (`@Binding var isPresented: Bool`).

### Authentication

**AuthManager**
- `@Published var currentUser: User?`
- `@Published var isAuthenticated: Bool`
- `signInWithGoogle()` - Initiates OAuth flow
- `signOut()` - Logs out user
- Handles session persistence with UserDefaults

**OAuth Flow:**
1. App opens: `\(Configuration.baseURL)/auth/google?platform=ios` (local: `http://127.0.0.1:3010`, production: `https://api.makeready.org`)
2. User signs in with Google (in SafariViewController)
3. Callback: `makeready://auth/callback?code=xxx`
4. App exchanges code for session with `/auth/exchange`
5. Session cookie stored in UserDefaults

## 🎨 Design System

### Colors

Defined as `Color` extensions in `MakeReady/Colors.swift` (the ONLY file
allowed to contain `Color(hex:)` — the SwiftLint gate enforces this):
- `Color.appBackground` — main background (#0d101a)
- `Color.brandPrimary` — brand purple (#6c47ff)
- `Color.cardBackground`, `.backgroundDark`, `.error`, `.success`,
  `.warning`, `.accentBlue`, `.destructive`, … (see Colors.swift)

**Usage:**
```swift
.background(Color.appBackground)
.foregroundColor(Color.brandPrimary)
// Need a color that has no token? Add it to Colors.swift first.
```

### Typography

**SF Pro Text** (iOS system font), via `Typography` tokens in
`MakeReady/Typography.swift` (the ONLY file allowed to contain raw
`.system(size:)` — the SwiftLint gate enforces this). Tokens are named by
size+weight (`s17Bold` = 17pt bold) at the app's current fixed sizes;
semantic naming and Dynamic Type are parked as Decision Point C.

**Usage:**
```swift
Text("Title")
    .font(Typography.s17Bold)
// Need a new size/weight combo? Add a token to Typography.swift first.
```

### Spacing

- Standard padding: 16px
- Component spacing: 8px, 16px, 24px
- Page margins: 16px

## 🔧 Development Workflow

### Building and Running

```bash
# Build the app
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
        Log.auth.error("sign-in failed: \(error.localizedDescription, privacy: .public)")
    }
}
```

### SF Symbols

Use SF Symbols for icons:

```swift
Image(systemName: "chevron.left")
    .font(Typography.s20)

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

### Generate QR Codes for Invites

1. Use `InviteQRCodeView` component for display
2. Logo embedding is ON by default
3. Consult `/qr-code` command for complete guide
4. Example usage:
   ```swift
   InviteQRCodeView(
       inviteCode: "ABC123XYZ",
       size: 320,
       includeLogo: true  // Optional: defaults to true
   )
   ```

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
- Check server is running on port 3010
- Verify redirect URI in Google Console
- Check `makeready://` URL scheme in `Info.plist`

### Logging

New code logs through the per-domain `os.Logger` wrappers in `Utilities/Log.swift`
(SwiftLint blocks new `print`/`NSLog`; the existing call sites are baselined and
migrate opportunistically):

```swift
Log.nav.info("navigated to \(destination, privacy: .public)")
Log.media.error("upload failed: \(error.localizedDescription, privacy: .public)")
```

Mark interpolations `.public` only when they carry no user data (route names, counts,
durations); user identifiers and content stay private (the default). View with Console.app
or `log stream --predicate 'subsystem == "<bundle id>"'`.

## 📖 Resources

### Internal Documentation
- [Video Recording Guide](.claude/VIDEO_RECORDING.md) - Correct video orientation handling with RotationCoordinator
- **API Reference** - Use the `makeready-api` MCP tools (`list_api_endpoints`, `get_endpoint_detail`, `search_api`, `get_schema`) for backend endpoint specifications, plus the "API Endpoints" section below
- [Build Configuration](.claude/BUILD_CONFIGURATION.md) - TestFlight and environment setup
- [SwiftUI Transitions](.claude/SWIFTUI_TRANSITIONS.md) - Patterns for page transitions, modals, and animations
- [SwiftUI Animation Patterns](.claude/SWIFTUI_ANIMATION_PATTERNS.md) - Jitter-free gestures, menus, and overlay animations
- [SwiftUI Preview Errors](.claude/SWIFTUI_PREVIEW_ERRORS.md) - Fix playbook for `#Preview` type-checker timeouts and ViewBuilder limits
- [Modal Presentation Guide](MakeReady/Components/Layout/MODAL_GUIDE.md) - **ALWAYS use OverlayManager for modals/menus**, not fullScreenCover

### External References
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SF Symbols App](https://developer.apple.com/sf-symbols/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Swift Language Guide](https://docs.swift.org/swift-book/)

## 🌐 API Endpoints

The iPhone app communicates with the MakeReady backend server running at `http://127.0.0.1:3010` (local development), `https://staging.api.makeready.org` (staging), or `https://api.makeready.org` (production).

### Base URL

The base URL is resolved at runtime by `Configuration.baseURL` (see `MakeReady/Configuration.swift`) — never hardcode it:

```swift
Configuration.baseURL
// Local (simulator):  http://127.0.0.1:3010
// Local (device):     http://<local server IP>:3010 (configurable on Profile screen)
// Staging:            https://staging.api.makeready.org
// Production:         https://api.makeready.org
```

### Authentication Endpoints

#### `GET /auth/google`
Initiate Google OAuth flow
- **Query params**:
  - `platform=ios` - Required for iOS redirect
- **Response**: Redirects to Google OAuth
- **Usage**: Open in ASWebAuthenticationSession

#### `POST /auth/exchange`
Exchange OAuth code for session cookie
- **Body**: `{ code: string }`
- **Response**: `{ success: boolean, user: User }`
- **Sets cookie**: `connect.sid` (session cookie)
- **Usage**: After OAuth callback, exchange code for session

#### `GET /auth/me`
Get current authenticated user
- **Auth**: Requires session cookie
- **Response**: `{ id, email, name, avatarURL, ... }`
- **Usage**: Verify session, load user data

#### `POST /auth/logout`
End user session
- **Auth**: Requires session cookie
- **Response**: `{ success: boolean }`
- **Clears cookie**: `connect.sid`

### User Endpoints

#### `GET /api/users`
Get all users
- **Auth**: Requires session
- **Response**: `User[]`

#### `GET /api/users/:id`
Get user by ID
- **Auth**: Requires session
- **Response**: `User`

### QR Code Endpoints

#### `POST /api/qrcode/generate`
Generate styled QR code with invite link
- **Auth**: Requires session
- **Body**:
  ```typescript
  {
    data: string                // Required: invite code/data to encode
    color?: string              // Hex color (default: #6c47ff)
    backgroundColor?: string    // Hex color (default: #ffffff)
    size?: number              // Pixels (default: 300, min: 100, max: 2000)
    errorCorrectionLevel?: 'L'|'M'|'Q'|'H'  // Default: 'M'
    includeLogo?: boolean      // Default: true
  }
  ```
- **Response**:
  ```typescript
  {
    success: boolean
    qrCode: string    // Base64 data URL: "data:image/png;base64,..."
    url: string       // Full invite URL
    error?: string
  }
  ```
- **Example**:
  ```swift
  let body = [
      "data": "ABC123",
      "color": "#6c47ff",
      "size": 600,
      "includeLogo": false
  ]
  // Returns base64 PNG you can decode to UIImage
  ```

### SMS/Phone Verification Endpoints

#### `POST /api/verification/send`
Send SMS verification code
- **Body**: `{ phoneNumber: string }`  // E.164 format: +1XXXXXXXXXX
- **Response**: `{ success: boolean, message: string }`

#### `POST /api/verification/verify`
Verify SMS code
- **Body**: `{ phoneNumber: string, code: string }`
- **Response**: `{ success: boolean, message: string }`

#### `POST /api/sms/send`
Send SMS message (admin)
- **Auth**: Requires session
- **Body**: `{ phoneNumber: string, message: string }`
- **Response**: `{ success: boolean, messageSid: string }`

### Invite Endpoints

#### `GET /api/invites`
Get all invites
- **Auth**: Requires session
- **Response**: `Invite[]`

#### `POST /api/invites`
Create new invite
- **Auth**: Requires session
- **Body**: `{ groupId?: string, expiresAt?: Date, ... }`
- **Response**: `{ success: boolean, invite: Invite }`

### Making Authenticated Requests

All authenticated requests go through `APIClient.shared` (`MakeReady/State/API/APIClient.swift`). It resolves the base URL from `Configuration.baseURL` and attaches the `connect.sid` session cookie automatically. **Only Actions call APIClient — views must go through Actions.**

```swift
// In an Actions struct (MakeReady/State/Actions/)
struct NotificationActions {

    private let api = APIClient.shared
    private var state: AppState { AppState.shared }

    @MainActor
    func loadNotifications() async throws {
        let response: NotificationListResponse = try await api.get(
            "/api/notifications?limit=50",
            responseType: NotificationListResponse.self
        )

        guard response.success, let notifications = response.notifications else {
            throw APIError.serverError(response.error ?? "Failed to load notifications")
        }

        state.notifications.replaceAll(notifications)
    }
}
```

`APIClient` also provides `post(_:body:responseType:)`, `patch(_:body:responseType:)`, `delete(_:responseType:)`, `upload(...)`, and `uploadImage(...)`. Never call `APIClient` or `URLSession` directly from a view — add a method to the appropriate Actions struct instead.

**Sanctioned `URLSession` exceptions** (everything else goes through Actions → APIClient; `APIClient` requires a session cookie, so endpoints that must work unauthenticated cannot route through it):
- `ImageCache` / CDN image fetches (e.g. cover images) — loads media bytes from Cloudflare URLs, not the API
- `LocalPortHealer` — dev-only port probing before auth exists
- `ProfilePage` environment health checks — probes `/health` on arbitrary environments
- `BibleCacheManager` / `BibleSearchService` — `/api/bible/*` and `/api/search/smart|suggestions` are deliberately session-optional on the server
- `InviteQRCodeView` test endpoint — `/api/qrcode/test` exists precisely for the no-session case
- `AuthManager` — legacy; owns the session lifecycle itself (being dissolved into Actions)

### Example: Generate QR Code

QR code generation lives in `AuthManager.generateQRCode(...)` (a legacy exception that builds its request from `Configuration.baseURL` with the session cookie — it disables caching so QR codes are always fresh):

```swift
// In AuthManager.swift (actual implementation, abridged)
func generateQRCode(
    data: String,
    color: String = "#6c47ff",
    backgroundColor: String = "#ffffff",
    size: Int = 600,
    errorCorrectionLevel: String = "M",
    includeLogo: Bool = true
) async throws -> UIImage {
    guard let url = URL(string: "\(Configuration.baseURL)/api/qrcode/generate") else {
        throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.cachePolicy = .reloadIgnoringLocalCacheData  // Never cache QR codes
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let sessionCookie = sessionCookie {
        request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: [
        "data": data,
        "color": color,
        "backgroundColor": backgroundColor,
        "size": size,
        "errorCorrectionLevel": errorCorrectionLevel,
        "includeLogo": includeLogo
    ])

    let (responseData, _) = try await URLSession.shared.data(for: request)
    let qrResponse = try JSONDecoder().decode(QRCodeResponse.self, from: responseData)

    guard qrResponse.success, let qrCodeDataURL = qrResponse.qrCode,
          let base64String = qrCodeDataURL.components(separatedBy: ",").last,
          let imageData = Data(base64Encoded: base64String),
          let image = UIImage(data: imageData) else {
        throw NSError(domain: "QRCode", code: -1,
                     userInfo: [NSLocalizedDescriptionKey: qrResponse.error ?? "Failed to generate QR code"])
    }

    return image
}
```

### API Response Types

```swift
// Common response structures
struct APIResponse: Codable {
    let success: Bool
    let error: String?
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let avatarURL: String?
    let phoneNumber: String?
    // ... other fields
}

struct QRCodeResponse: Codable {
    let success: Bool
    let qrCode: String?
    let url: String?
    let error: String?
}
```

## 🏗️ Build Configurations & Environments

The app automatically switches between local development and production environments based on build configuration. **No manual changes needed!**

### Automatic Environment Switching

| Build Type | DEV_MODE | Base URL | Auth Bypass |
|------------|----------|----------|-------------|
| **Debug (Xcode Run)** | YES (environment switcher in user menu) | http://127.0.0.1:3010 (Local), https://staging.api.makeready.org (Staging), https://api.makeready.org (Production — default) | Enabled when Local selected |
| **Development** | NO | http://127.0.0.1:3010 | Disabled |
| **Staging** | NO | https://staging.api.makeready.org | Disabled |
| **Release (Archive)** | NO | https://api.makeready.org | Disabled |

Defined in `MakeReady/Configuration/*.xcconfig` and resolved at runtime by `MakeReady/Configuration.swift`. With DEV_MODE on, the selected environment persists in UserDefaults and defaults to Production until changed. On a physical device, Local uses the IP/port configured on the Profile screen (default `192.168.1.65:3010`).

### For Local Development

```bash
# Run normally in Xcode (Debug), then select "Local" in the
# user-menu environment switcher to use the local server at 127.0.0.1:3010
```

### For TestFlight

```bash
# 1. Archive in Xcode
Product → Archive

# 2. Upload to App Store Connect
# Automatically uses production server (api.makeready.org)
```

**See `.claude/BUILD_CONFIGURATION.md` for complete guide on building for TestFlight, custom configurations, and troubleshooting.**

## ⚡️ Quick Commands

### Sub-Agent Commands
```bash
# Build and launch app
/rebuild-iphone

# QR code generation guide
/qr-code
```

### Simulator Commands
```bash
# List simulators
xcrun simctl list devices

# Boot simulator
xcrun simctl boot "iPhone 17 Pro Max"

# Open simulator
open -a Simulator

# View logs
xcrun simctl spawn booted log stream --predicate 'process == "MakeReady"'
```
