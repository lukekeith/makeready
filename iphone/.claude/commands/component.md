# iPhone Component Architecture Guide

## Purpose

This guide documents the SwiftUI component patterns, organization, and conventions used in the MakeReady iPhone app. Use this when creating new components or modifying existing ones to ensure consistency with established patterns.

## Component Organization

Components are organized into **7 semantic categories** by functionality:

```
/MakeReady/Components/
├── Button/              # Action buttons and interactive controls (2 components)
├── Card/                # Card variants with data models (15+ components)
├── Chart/               # Data visualization (5 chart types)
├── Display/             # Display-only components (10+ components)
├── Input/               # Form inputs and controls (12+ components)
├── Layout/              # Layout wrappers and containers (3 components)
└── Navigation/          # Navigation UI (7 components)
```

**Organization Philosophy:**
- ✅ Components organized by UI role, NOT by feature
- ✅ Flat structure within categories (no nested folders)
- ✅ Supports discovery - find all buttons, cards, inputs in one place
- ✅ Scalable - new components fit naturally into existing categories

## Category Reference

### Button/
**Purpose:** Interactive controls that trigger actions

**Components:**
- `ActionButton` - 6 variants (purple, purpleIcon, white, whiteIcon, whitePurple, swipeLarge)
- `BoxButton` - Box-style button variant

**When to use:** Any tappable control that performs an action

**Pattern:**
```swift
ActionButton(
    label: "Save",           // Optional label
    icon: "checkmark",       // Optional SF Symbol
    variant: .purple,        // Enum-based variant
    action: { save() }       // Closure callback
)
```

---

### Card/
**Purpose:** Structured content containers with consistent layout

**Components:**
- `CardGroup` - Group card with selection state
- `CardEvent`, `CardEventMini` - Event cards with date display
- `CardStudy`, `CardStudyMini` - Study cards with status
- `CardVideo`, `CardVideoMini` - Video cards
- `CardMember`, `CardContact` - Person cards
- `CardLesson` - Lesson card with activities
- `SwipeableCard` - Generic wrapper adding swipe-to-reveal actions
- `SlideButton` - Individual swipe action button
- `DataComponent` - Metadata display (number+label or icon+value)
- `CardData.swift` - Shared data models for all cards

**When to use:** Displaying structured content (groups, events, members, etc.)

**Pattern:**
```swift
// 1. Define data model
let cardData = CardGroupData(
    id: "123",
    title: "My Group",
    imageStyle: .photo(imageURL: "..."),
    metadata: [
        DataItem(icon: "person.2", value: "27"),
        DataItem(number: "30", label: "days")
    ],
    isSelected: false,
    onTap: { selectGroup() }
)

// 2. Use in view
CardGroup(data: cardData)

// 3. Or wrap with swipe actions
SwipeableCard(
    content: { CardGroup(data: cardData) },
    slideButtons: [
        SlideButton(icon: "trash", style: .destructive) { delete() }
    ]
)
```

**Key Files:**
- `CardData.swift` - Contains ALL data models (CardGroupData, CardEventData, etc.)
- Individual card components consume data models
- `SwipeableCard` wraps any card content

---

### Chart/
**Purpose:** Data visualization components

**Components:**
- `LineChart` - Line graph
- `VerticalBarChart` - Vertical bar chart
- `HorizontalBarChart` - Horizontal bar chart
- `DonutChart` - Pie/donut chart
- `HeatMapChart` - Heat map visualization

**When to use:** Displaying quantitative data visually

---

### Display/
**Purpose:** Display-only components (no user input)

**Components:**
- `Avatar` - Profile images with 6 sizes (xs, sm, md, lg, xl, xxl)
- `MemberListItem` - 4 variants (contact, memberWithInvite, member, memberMultipleGroups)
- `AlphabetScrubber` - Quick-scroll index for lists
- `Alert` - Alert/confirmation dialogs
- `GroupSelectorSheet` - Bottom sheet for group selection
- `QRCodeGenerator` - QR code display
- `ShareInviteSheet` - Invite sharing with QR code

**When to use:** Showing information without user interaction

**Pattern:**
```swift
// Avatar with fallback states
Avatar(
    imageURL: user.avatarURL,  // Tries image first
    initials: "JD",            // Falls back to initials
    size: .lg                  // Then to icon if both fail
)

// MemberListItem with variant
MemberListItem(
    member: member,
    variant: .memberWithInvite,
    onInviteTap: { resendInvite() }
)
```

---

### Input/
**Purpose:** Form inputs and interactive controls

**Components:**
- `TextInput` - Single-line text with validation & formatting
- `MultilineTextInput` - Multi-line text entry
- `LargeTextInput` - Another multi-line variant
- `SearchField` - Animated search with focus states
- `ToggleControl` + `ToggleGroup` - Toggle switches
- `DatePickerField` - Date selection
- `MenuInput` - Dropdown selection
- `CoverImagePicker` - Image selection
- `FieldGroup` - Groups related inputs
- `InputTypes.swift` - Shared InputType enum & utilities

**When to use:** Collecting user input

**Pattern:**
```swift
// Text input with validation
TextInput(
    label: "Email",
    icon: "envelope.fill",
    inputType: .email,              // Auto-formats & validates
    text: $email,                   // @Binding
    validationError: $emailError    // @Binding for errors
)

// Toggle with description
ToggleGroup {
    ToggleControl(
        title: "Private Group",
        description: "Only members can see this",
        isOn: $isPrivate            // @Binding
    )
    Divider()
    ToggleControl(
        title: "Allow Invites",
        isOn: $allowInvites
    )
}

// Field group for related inputs
FieldGroup {
    TextInput(label: "Name", text: $name)
    Divider()
    TextInput(label: "Email", text: $email)
}
```

**Input Types** (from InputTypes.swift):
- `.alphanumeric` - Letters and numbers
- `.phone` - Phone number formatting
- `.email` - Email validation
- `.integer`, `.float`, `.currency` - Numeric inputs
- `.percentage` - Percentage formatting
- `.password` - Secure text entry

---

### Layout/
**Purpose:** Layout wrappers and containers

**Components:**
- `ModalOverlay` - Full-screen modal with swipe-to-dismiss
- `SearchableList` - Searchable list wrapper
- `SectionedTableView` - Sectioned list layout

**When to use:** Wrapping content with layout behavior

**Pattern:**
```swift
// Modal overlay
ModalOverlay(
    isPresented: $showModal,
    title: "Create Group",
    content: {
        // Your content here
    }
)

// Searchable list
SearchableList(
    searchText: $searchText,
    items: members,
    content: { member in
        MemberListItem(member: member)
    }
)
```

---

### Navigation/
**Purpose:** Navigation UI components

**Components:**
- `PageHeader` - Top header with tabs, notification, avatar (primary pages)
- `PageTitle` - Title with left/right controls (secondary pages, 8 variants)
- `NavBar` - Bottom navigation (Home, Schedule, Members + Add button)
- `TabSlider` - Tab switching with animated indicator
- `UserMenu` - User profile menu overlay
- `AddMenu` - Action menu overlay
- `HamburgerMenu` - Navigation menu overlay

**When to use:** Page headers, navigation, menus

**Pattern:**
```swift
// Primary page header
PageHeader(
    title: "Home",
    tabs: ["All", "Active"],
    selectedTab: $selectedTab,
    onNotificationTap: { showNotifications = true },
    onAvatarTap: { showUserMenu = true }
)

// Secondary page title (8 variants)
PageTitle.iconTitle(
    title: "Profile",
    icon: "chevron.left",
    onIconTap: { dismiss() }
)

PageTitle.titleLink(
    title: "Settings",
    link: "Done",
    onLinkTap: { save() }
)

// Bottom navigation
NavBar(
    currentTab: $currentTab,
    onAddTap: { showAddMenu = true }
)
```

---

## Component Patterns & Conventions

### 1. File Naming

| Type | Pattern | Examples |
|------|---------|----------|
| **Components** | PascalCase.swift | `ActionButton.swift`, `PageTitle.swift` |
| **Data Models** | `[Component]Data.swift` | `CardData.swift` (contains all card data models) |
| **Utilities** | Purpose-descriptive | `InputTypes.swift`, `DirectionalPanGesture.swift` |
| **Enums** | Descriptive | `ActionButtonVariant`, `AvatarSize`, `InputType` |

**Rules:**
- ✅ PascalCase for all Swift files and types
- ✅ Data models grouped in dedicated files (e.g., CardData.swift has ALL card data structures)
- ✅ Helper components in same file as main component
- ✅ Shared utilities in descriptive files

---

### 2. Props/Parameters Pattern

**Principle:** Components accept simple, explicit parameters. No implicit state changes.

```swift
struct ActionButton: View {
    // Simple scalars for fixed content
    let label: String?
    let icon: String?              // SF Symbol name

    // Enums for variants (NOT strings)
    let variant: ActionButtonVariant

    // Closures for callbacks (NOT @Binding for actions)
    let action: () -> Void

    // Optional customization
    let customSize: CGFloat?
    let customIconSize: CGFloat?
    let customOpacity: Double?
}
```

**When to use @Binding:**
- ✅ Controlled inputs (TextInput, ToggleControl)
- ✅ Selection state that parent controls
- ✅ Validation errors from parent

**When to use closures:**
- ✅ Button taps, callbacks, events
- ✅ Actions triggered by user interaction
- ✅ Parent decides what happens

**Example:**
```swift
// ❌ Don't do this
Button(action: $isSelected) // Wrong - @Binding for action

// ✅ Do this
Button { isSelected.toggle() } // Closure lets parent decide
```

---

### 3. Variant Pattern

**Principle:** Use enums for styling options, not strings.

```swift
enum ActionButtonVariant {
    case purple          // Purple background with label
    case purpleIcon      // Purple background, icon only
    case white           // White 10% opacity with label
    case whiteIcon       // White 10% opacity, icon only
    case whitePurple     // Solid white, purple icon
    case swipeLarge      // Large variant for swipe actions
}

struct ActionButton: View {
    let variant: ActionButtonVariant

    var body: some View {
        switch variant {
        case .purple:
            // Purple styling
        case .purpleIcon:
            // Purple icon styling
        // ...
        }
    }
}
```

**Benefits:**
- ✅ Type-safe (compiler catches typos)
- ✅ Discoverable (autocomplete shows all options)
- ✅ Refactorable (rename variants safely)

**Example Components with Variants:**
- `ActionButton` - 6 variants
- `MemberListItem` - 4 variants
- `PageTitle` - 8 variants
- `Avatar` - 6 size variants

---

### 4. State Management Pattern

**Rules:**
1. **@Binding for controlled inputs** - Parent controls value
2. **@State for internal state** - Component-local animations, gestures
3. **@FocusState for keyboard** - Focus management
4. **NO @EnvironmentObject in components** - Components don't access app state

```swift
struct TextInput: View {
    // Parent controls these
    @Binding var text: String
    @Binding var validationError: String?

    // Component controls these internally
    @FocusState private var isFocused: Bool
    @State private var displayText: String  // For formatting without side effects

    var body: some View {
        TextField("", text: $displayText)
            .focused($isFocused)
            .onChange(of: displayText) { newValue in
                // Format display text, update bound value separately
                text = InputFormatter.unformat(newValue, for: inputType)
            }
    }
}
```

**Key Pattern:** Separate display text from bound value for formatting without side effects.

---

### 5. View Composition Pattern

**Principle:** Use @ViewBuilder for flexible content composition.

```swift
struct ModalOverlay<Content: View>: View {
    let content: Content

    init(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Modal background
            VStack {
                Text(title)
                content  // Arbitrary content
            }
        }
    }
}
```

**Benefits:**
- ✅ Type-safe composition
- ✅ Supports multiple children without wrapper views
- ✅ Familiar SwiftUI syntax

**Example Usage:**
```swift
ModalOverlay(isPresented: $showModal, title: "Settings") {
    ToggleControl(title: "Private", isOn: $isPrivate)
    Divider()
    ToggleControl(title: "Notifications", isOn: $notifications)
}
```

---

### 6. Data Model Pattern

**Principle:** Separate data structures from views for complex components.

**All card data models live in CardData.swift:**

```swift
// CardData.swift
public struct CardGroupData {
    public let id: String
    public let title: String
    public let imageStyle: CardImageStyle
    public let metadata: [DataItem]
    public let isSelected: Bool
    public let onTap: (() -> Void)?

    // Convenience initializer
    public init(
        id: String,
        title: String,
        imageStyle: CardImageStyle,
        metadata: [DataItem],
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.imageStyle = imageStyle
        self.metadata = metadata
        self.isSelected = isSelected
        self.onTap = onTap
    }
}

public enum CardImageStyle: Hashable {
    case photo(imageURL: String)
    case icon(systemName: String, backgroundColor: Color)
    case dateDisplay(day: Int, month: String)
}

public struct DataItem: Identifiable, Hashable {
    public let type: DataItemType
    public let value: String
    public let label: String?
    public let iconName: String?

    // Convenience initializers
    public init(icon: String, value: String) { /* ... */ }
    public init(number: String, label: String) { /* ... */ }
}
```

**Benefits:**
- ✅ Separates data from presentation
- ✅ Hashable/Identifiable for List rendering
- ✅ Convenience initializers for common cases
- ✅ Easy preview data generation

---

### 7. Styling Approach

**Hard-coded design values (no design tokens):**

```swift
// Typography
.font(.system(size: 17, weight: .bold))
.font(.system(size: 12, weight: .regular))
.font(.system(size: 28, weight: .bold))

// Colors
.foregroundColor(Color(hex: "#6c47ff"))  // Brand purple
.background(Color.appBackground)          // Main background
.foregroundColor(.white.opacity(0.5))     // Muted text

// Spacing
.padding(16)                              // Standard padding
.padding(.horizontal, 16)
.padding(.vertical, 8)

// Corner radius
.cornerRadius(8)                          // Cards
.cornerRadius(10)                         // Groups
.cornerRadius(30)                         // Buttons
```

**Color Extension Pattern** (for semantic names):

```swift
extension Color {
    static let cardBackground = Color(hex: "#333541")
    static let iconContainerBackground = Color(hex: "#485470").opacity(0.5)
    static let errorRed = Color(hex: "#FF4759")
}
```

**Standard Values:**
- Padding: 16px (standard), 8px (compact), 24px (spacious)
- Corner radius: 8px (default), 10px (groups), 30px (rounded)
- Font sizes: 12pt (small), 17pt (body/title), 28pt (large header)
- Brand purple: `#6c47ff`
- Background: `Color.appBackground` (#0a0a0f)

---

### 8. Preview Pattern

**EVERY component must have a #Preview showing multiple variants/states:**

```swift
#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Section headers
            Text("PRIMARY VARIANT")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            // Examples
            ActionButton(label: "Save", icon: "checkmark", variant: .purple) { }

            Text("ICON ONLY")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            ActionButton(icon: "plus", variant: .purpleIcon) { }

            Spacer()
        }
        .padding(20)
    }
}
```

**Preview Conventions:**
- ✅ Wrapped in `ZStack` with `Color.appBackground`
- ✅ Organized with section headers (uppercase, 50% opacity, 13pt semibold)
- ✅ Shows multiple variants/states
- ✅ Includes `Spacer()` to prevent crowding
- ✅ Standard padding (16-20px)
- ✅ VStack with spacing for vertical layout

**Why important:** Previews enable live development in Xcode without simulator builds.

---

### 9. Animation & Interaction

**Standard animations:**

```swift
// Spring animation (most common)
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)

// Easing curves
.animation(.easeOut(duration: 0.2), value: offset)
.animation(.easeInOut(duration: 0.3), value: scale)

// Haptic feedback
HapticManager.impact(.medium)  // On button tap
HapticManager.impact(.heavy)   // On swipe activation
```

**Gesture patterns:**

```swift
// Use DirectionalPanGesture for swipe disambiguation
DirectionalPanGesture(direction: .horizontal)
    .onChanged { value in
        // Progressive feedback with damping
        let damping: CGFloat = 0.3
        offset = value.translation.width * damping
    }
    .onEnded { value in
        // Velocity-based completion
        if abs(value.velocity.width) > 500 {
            completeGesture()
        }
    }
```

---

### 10. Convenience Initializers

**Provide multiple initializers for different use cases:**

```swift
struct Avatar: View {
    let imageURL: String?
    let initials: String?
    let systemIcon: String?
    let size: AvatarSize

    // Full control
    init(imageURL: String?, initials: String?, systemIcon: String? = "person.fill", size: AvatarSize) {
        // ...
    }

    // From name (auto-generates initials)
    init(firstName: String, lastName: String, size: AvatarSize) {
        let initials = "\(firstName.prefix(1))\(lastName.prefix(1))"
        self.init(imageURL: nil, initials: initials, size: size)
    }

    // Icon only
    init(systemIcon: String, size: AvatarSize) {
        self.init(imageURL: nil, initials: nil, systemIcon: systemIcon, size: size)
    }
}
```

**Benefits:**
- ✅ Discoverable - autocomplete shows all options
- ✅ DRY - common patterns simplified
- ✅ Flexible - advanced users can use full control init

---

### 11. Fallback States

**Components should gracefully degrade when data is missing:**

```swift
// Avatar: image → initials → icon
if let imageURL = imageURL {
    AsyncImage(url: URL(string: imageURL))
} else if let initials = initials {
    Text(initials)
} else {
    Image(systemName: systemIcon ?? "person.fill")
}

// Card image: photo → icon → placeholder
switch imageStyle {
case .photo(let url):
    AsyncImage(url: URL(string: url))
case .icon(let systemName, let bgColor):
    Image(systemName: systemName)
        .background(bgColor)
case .dateDisplay(let day, let month):
    VStack {
        Text("\(day)")
        Text(month)
    }
}
```

---

## Reusable Utilities

### InputTypes.swift

Centralized input formatting and validation:

```swift
enum InputType {
    case alphanumeric
    case phone
    case integer
    case float
    case currency
    case email
    case percentage
    case password

    var keyboardType: UIKeyboardType { /* ... */ }
    var icon: String? { /* ... */ }
}

class InputFormatter {
    static func format(_ text: String, for type: InputType) -> String
    static func unformat(_ text: String, for type: InputType) -> String
}

class InputValidator {
    static func validate(_ text: String, for type: InputType) -> String?
}
```

**Usage:**
```swift
TextInput(
    label: "Phone",
    inputType: .phone,  // Auto-formats as (555) 123-4567
    text: $phone
)
```

---

### DirectionalPanGesture

Custom gesture recognizer for swipe disambiguation in scrollable contexts:

```swift
DirectionalPanGesture(direction: .horizontal, threshold: 20)
    .onChanged { value in
        // Only fires for horizontal swipes
    }
```

**Used by:** SwipeableCard for proper gesture conflict resolution with ScrollView

---

### SlideButton

Individual swipe action button with progressive scaling/opacity:

```swift
SlideButton(
    icon: "trash",
    style: .destructive,  // or .normal
    action: { delete() }
)
```

**Behavior:**
- Scales 24px → 48px based on slide distance
- Icon scales 12px → 20px
- Opacity 0% → 100%
- Haptic feedback on full activation

---

### Color Extensions

Semantic color names for common UI elements:

```swift
extension Color {
    static let cardBackground = Color(hex: "#333541")
    static let iconContainerBackground = Color(hex: "#485470").opacity(0.5)
    static let errorRed = Color(hex: "#FF4759")
    static let brandPurple = Color(hex: "#6c47ff")
}
```

---

## Component Creation Checklist

When creating a new component, follow this checklist:

### 1. Determine Category
- [ ] Which category does this belong to? (Button/Card/Input/Display/Layout/Navigation/Chart)
- [ ] Is there an existing similar component I can extend?

### 2. Define Interface
- [ ] What props does it need?
- [ ] Does it need variants? (Create enum if yes)
- [ ] Does it need @Binding for parent control?
- [ ] Does it need callbacks? (Use closures)
- [ ] Is data complex? (Create data model in [Category]Data.swift)

### 3. Choose State Pattern
- [ ] @Binding for parent-controlled values (inputs, selections)
- [ ] @State for internal state (animations, gestures)
- [ ] @FocusState for keyboard management
- [ ] NO @EnvironmentObject (components are view-only)

### 4. Implement Component
- [ ] File name is PascalCase.swift
- [ ] Located in correct category folder
- [ ] Uses standard spacing (16px padding, 8-16px gaps)
- [ ] Uses brand colors (`#6c47ff`, `Color.appBackground`)
- [ ] Uses SF Symbols for icons
- [ ] Includes fallback states if applicable
- [ ] Animations use spring() or easing curves

### 5. Add Convenience Initializers
- [ ] Multiple init() for different use cases
- [ ] Default values for optional parameters
- [ ] Auto-generate derived values where possible

### 6. Create Preview
- [ ] Wrapped in ZStack with Color.appBackground
- [ ] Shows multiple variants/states
- [ ] Organized with section headers (uppercase, 50% opacity)
- [ ] Includes Spacer() for proper layout
- [ ] Standard padding (16-20px)

### 7. Documentation
- [ ] Component documented in CLAUDE.md (if significant)
- [ ] Usage examples in preview
- [ ] Edge cases handled (nil values, empty strings, etc.)

---

## Examples

### Example 1: Simple Button Component

```swift
// ActionButton.swift in /Components/Button/

enum ActionButtonVariant {
    case purple
    case purpleIcon
    case white
    case whiteIcon
}

struct ActionButton: View {
    let label: String?
    let icon: String?
    let variant: ActionButtonVariant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                }
                if let label = label {
                    Text(label)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(30)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .purple, .purpleIcon: return .white
        case .white, .whiteIcon: return .white
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .purple, .purpleIcon: return Color(hex: "#6c47ff")
        case .white, .whiteIcon: return .white.opacity(0.1)
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        VStack(spacing: 20) {
            Text("WITH LABEL")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            ActionButton(label: "Save", icon: "checkmark", variant: .purple) { }

            Text("ICON ONLY")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            ActionButton(icon: "plus", variant: .purpleIcon) { }

            Spacer()
        }
        .padding(20)
    }
}
```

---

### Example 2: Input Component with @Binding

```swift
// TextInput.swift in /Components/Input/

struct TextInput: View {
    let label: String
    let icon: String?
    let inputType: InputType
    @Binding var text: String
    @Binding var validationError: String?

    @FocusState private var isFocused: Bool
    @State private var displayText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    TextField("", text: $displayText)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .keyboardType(inputType.keyboardType)
                        .focused($isFocused)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )

            if let error = validationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FF4759"))
            }
        }
        .onChange(of: displayText) { newValue in
            text = InputFormatter.unformat(newValue, for: inputType)
        }
        .onChange(of: text) { newValue in
            displayText = InputFormatter.format(newValue, for: inputType)
        }
        .onChange(of: isFocused) { focused in
            if !focused {
                validationError = InputValidator.validate(text, for: inputType)
            }
        }
    }

    private var iconColor: Color {
        if let error = validationError, !error.isEmpty {
            return Color(hex: "#FF4759")
        }
        return .white.opacity(0.5)
    }

    private var borderColor: Color {
        if isFocused {
            return Color(hex: "#6c47ff")
        } else if let error = validationError, !error.isEmpty {
            return Color(hex: "#FF4759")
        }
        return .clear
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        VStack(spacing: 20) {
            TextInput(
                label: "Email",
                icon: "envelope.fill",
                inputType: .email,
                text: .constant("test@example.com"),
                validationError: .constant(nil)
            )

            TextInput(
                label: "Phone",
                icon: "phone.fill",
                inputType: .phone,
                text: .constant("5551234567"),
                validationError: .constant(nil)
            )

            Spacer()
        }
        .padding(20)
    }
}
```

---

### Example 3: Card with Data Model

```swift
// CardData.swift in /Components/Card/

public struct CardGroupData: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let imageStyle: CardImageStyle
    public let metadata: [DataItem]
    public let isSelected: Bool
    public let onTap: (() -> Void)?

    public init(
        id: String,
        title: String,
        imageStyle: CardImageStyle,
        metadata: [DataItem],
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.imageStyle = imageStyle
        self.metadata = metadata
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public static func == (lhs: CardGroupData, rhs: CardGroupData) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(isSelected)
    }
}

public enum CardImageStyle: Hashable {
    case photo(imageURL: String)
    case icon(systemName: String, backgroundColor: Color)
}

public struct DataItem: Identifiable, Hashable {
    public let id = UUID()
    public let type: DataItemType
    public let value: String
    public let label: String?
    public let iconName: String?

    public init(icon: String, value: String) {
        self.type = .iconValue
        self.value = value
        self.label = nil
        self.iconName = icon
    }

    public init(number: String, label: String) {
        self.type = .numberLabel
        self.value = number
        self.label = label
        self.iconName = nil
    }
}

public enum DataItemType {
    case iconValue
    case numberLabel
}

// CardGroup.swift in /Components/Card/

struct CardGroup: View {
    let data: CardGroupData

    var body: some View {
        Button(action: { data.onTap?() }) {
            HStack(spacing: 12) {
                // Image
                imageView
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        ForEach(data.metadata) { item in
                            DataComponent(item: item)
                        }
                    }
                }

                Spacer()

                // Selection indicator
                if data.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#6c47ff"))
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private var imageView: some View {
        switch data.imageStyle {
        case .photo(let url):
            AsyncImage(url: URL(string: url)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
        case .icon(let systemName, let bgColor):
            ZStack {
                bgColor
                Image(systemName: systemName)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        VStack(spacing: 16) {
            CardGroup(data: CardGroupData(
                id: "1",
                title: "Young Professionals",
                imageStyle: .icon(systemName: "person.2", backgroundColor: Color(hex: "#6c47ff")),
                metadata: [
                    DataItem(icon: "person.2", value: "27"),
                    DataItem(number: "30", label: "days")
                ],
                isSelected: false
            ))

            CardGroup(data: CardGroupData(
                id: "2",
                title: "Bible Study Group",
                imageStyle: .photo(imageURL: "https://example.com/image.jpg"),
                metadata: [
                    DataItem(icon: "person.2", value: "15")
                ],
                isSelected: true
            ))

            Spacer()
        }
        .padding(20)
    }
}
```

---

## Common Patterns Summary

| Pattern | When to Use | Example |
|---------|-------------|---------|
| **Enum Variants** | Component has multiple styles | `ActionButtonVariant`, `AvatarSize` |
| **Data Models** | Complex props (3+ related fields) | `CardGroupData`, `DataItem` |
| **@Binding inputs** | Parent controls value | `TextInput`, `ToggleControl` |
| **Closure callbacks** | Parent handles events | `onTap`, `onInviteTap`, `action` |
| **@ViewBuilder** | Flexible content composition | `ModalOverlay<Content>`, `ToggleGroup` |
| **Fallback states** | Optional data that may be missing | Avatar (image → initials → icon) |
| **Convenience init()** | Common use cases | `Avatar(firstName:lastName:)` |
| **#Preview** | Every component | Shows variants on Color.appBackground |
| **Color extensions** | Semantic color names | `Color.cardBackground` |
| **Shared utilities** | Formatting, validation, gestures | `InputFormatter`, `DirectionalPanGesture` |

---

## Anti-Patterns (What NOT to Do)

❌ **Don't use @EnvironmentObject in components**
```swift
// ❌ Bad
struct MyComponent: View {
    @EnvironmentObject var authManager: AuthManager
}

// ✅ Good - Pass data via props
struct MyComponent: View {
    let userName: String
    let avatarURL: String?
}
```

❌ **Don't use string-based variants**
```swift
// ❌ Bad
ActionButton(variant: "purple") { }  // Typos not caught

// ✅ Good
ActionButton(variant: .purple) { }   // Type-safe
```

❌ **Don't use @Binding for callbacks**
```swift
// ❌ Bad
ActionButton(isSelected: $isSelected)  // Component mutates parent state

// ✅ Good
ActionButton(onTap: { isSelected.toggle() })  // Parent decides
```

❌ **Don't skip previews**
```swift
// ❌ Bad - No preview, can't visually verify

// ✅ Good - Always include preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        MyComponent()
    }
}
```

❌ **Don't create new components when one exists**
```swift
// ❌ Bad - Reinventing Avatar
HStack {
    if let url = imageURL {
        AsyncImage(url: URL(string: url))
            .frame(width: 40, height: 40)
            .clipShape(Circle())
    } else {
        Text(initials)
            .frame(width: 40, height: 40)
            .background(Color.gray)
            .clipShape(Circle())
    }
}

// ✅ Good - Use existing component
Avatar(imageURL: imageURL, initials: initials, size: .md)
```

---

## Quick Reference

### Standard Spacing
- Padding: 16px (standard), 8px (compact), 24px (spacious)
- Component gaps: 8px (tight), 16px (normal), 20px (relaxed)
- Section spacing: 24px

### Standard Sizes
- Corner radius: 8px (default), 10px (groups), 30px (rounded buttons)
- Icon sizes: 12px (small), 20px (default), 24px (large)
- Avatar sizes: 24/32/40/48/64/96px (.xs/.sm/.md/.lg/.xl/.xxl)

### Standard Colors
- Brand purple: `#6c47ff`
- Background: `Color.appBackground` (#0a0a0f)
- Card background: `#333541`
- Error red: `#FF4759`
- Muted text: `.white.opacity(0.5)`

### Standard Typography
- Small: 12pt regular
- Body: 17pt regular
- Title: 17pt bold
- Large header: 28pt bold
- Section headers: 13pt semibold, uppercase, 50% opacity

### Standard Animations
- Spring: `.spring(response: 0.3, dampingFraction: 0.8)`
- Ease out: `.easeOut(duration: 0.2)`
- Ease in/out: `.easeInOut(duration: 0.3)`

---

## When to Create a New Component

✅ **Create new component when:**
- You need the same UI pattern in 2+ places
- The pattern is complex enough to encapsulate (10+ lines)
- It represents a distinct UI concept (button, card, input)
- You want to enforce consistency (same style everywhere)

❌ **Don't create new component when:**
- It's a one-off layout
- An existing component already does it (check this guide!)
- It's just 2-3 lines of basic SwiftUI
- It's too specific to one feature (put in feature file instead)

---

## Questions to Ask Before Creating Component

1. **Does a similar component already exist?**
   - Check the category folders
   - Review this guide's Component Library section

2. **What category does it belong to?**
   - Button, Card, Chart, Display, Input, Layout, or Navigation?

3. **Does it need variants?**
   - If yes, create enum

4. **Is data complex?**
   - If 3+ related fields, create data model

5. **Does parent need to control it?**
   - Use @Binding for values
   - Use closures for actions

6. **Is it reusable across features?**
   - If yes, it's a good candidate for /Components/
   - If no, keep it in feature file

---

## Conclusion

This component architecture emphasizes:
- ✅ **Consistency** - Uniform patterns across all components
- ✅ **Type safety** - Enum variants, data models, no strings
- ✅ **Separation of concerns** - Components don't access app state
- ✅ **Reusability** - Organized by UI role, not feature
- ✅ **Developer experience** - Comprehensive previews, discoverable APIs
- ✅ **Scalability** - Clear categories, can grow to 100+ components

When in doubt:
1. Check existing components first (don't reinvent)
2. Follow the patterns shown in this guide
3. Add comprehensive previews
4. Keep components view-only (no app logic)
