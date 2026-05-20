# Card Component Requirements Document

**Version:** 1.0
**Date:** 2025-01-07
**Component:** Card + Data Component System
**Platform:** iOS (SwiftUI)
**Figma:** [Card Component](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=947-13921) | [Data Component](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=951-14806)

---

## 1. Overview

### Purpose
The **Card component** is a central, reusable UI element used throughout the MakeReady iPhone app to display various types of content in a consistent, visually appealing format. It serves as a container for Events, Groups, Studies, and Videos.

### Scope
This document defines specifications for two related components:
1. **Card Component** (parent) - The primary content container
2. **Data Component** (child) - Small metadata display elements used within cards

### Migration Plan
- **Replace:** Existing `GroupCard` and `SwipeableGroupCard` components
- **Consolidate:** All card-based UIs into single Card component system
- **Update:** All views currently using GroupCard to use new Card component

---

## 2. Data Component Specifications

The **Data component** displays small pieces of metadata information and appears within every Card instance.

### 2.1 Component Variants

#### Type 1: Icon + Value
- **Structure:** Icon (left) → Value text (right)
- **Example:** `[clock icon] 28`
- **Use cases:** Time durations, counts without labels

#### Type 2: Number + Text
- **Structure:** Number (left) → Label text (right)
- **Example:** `28 Members`
- **Use cases:** Labeled counts, statistics

### 2.2 Visual Specifications

**Typography:**
- Font family: SF Pro Text (iOS system)
- Font size: 13pt (Footnote)
- Font weight: Regular (400)
- Line height: 18px

**Colors:**
- Value/Number: `#FFFFFF` (white 100%)
- Label text: `rgba(255, 255, 255, 0.7)` (white 70%)
- Icon fill: `#FFFFFF` (white 100%)

**Spacing:**
- Component height: 18px (fixed)
- Gap between icon and value: 4px
- Gap between number and label: 4px
- **Gap between Data components: 16px** (when multiple appear in row)

**Icon Specifications:**
- Size: 14×14px
- Common icons: clock, person.2, calendar, eye, share

### 2.3 Layout Within Cards

Data components appear in a **horizontal row** with 16px gaps between each item:

```
[Data 1] <--16px--> [Data 2] <--16px--> [Data 3]
```

**Primary vs Secondary:**
- Row cards: Different primary metadata (e.g., location for Events)
- Mini cards: Different primary metadata (e.g., time for Events)

### 2.4 Common Use Cases

| Icon Type | Example | Usage |
|-----------|---------|-------|
| Clock + value | `[clock] 28` | Duration or time |
| People + value | `[person.2] 28` | Member/participant count |
| Calendar + value | `[calendar] Jan 15` | Date information |
| Eye + value | `[eye] 1.2K` | View count |
| Share + value | `[share] 45` | Share count |

| Number Type | Example | Usage |
|-------------|---------|-------|
| Members | `28 Members` | Group member count |
| Participants | `15 Participants` | Study participant count |
| Views | `1.2K views` | Video view count |

---

## 3. Card Component Specifications

### 3.1 Card Types (4 Variants)

The Card component supports four distinct content types:

1. **Event** - Scheduled events and gatherings
2. **Group** - Community groups and circles
3. **Study** - Bible studies and devotionals
4. **Video** - Video content and media

### 3.2 Card Sizes (2 Variants)

#### Row Size
- **Purpose:** Full-width component designed to be stacked in vertical lists
- **Width:** 355px (fills container width)
- **Height:** Varies by type
  - Groups: 104px
  - Events/Studies/Videos: 140px
- **Layout:** Horizontal (image/icon left, content right)

#### Mini Size
- **Purpose:** Fixed-width component for horizontal scrolling rows
- **Width:** 120px (fixed)
- **Height:** 188px (fixed)
- **Layout:** Vertical (image/icon top, content bottom)

### 3.3 Universal Card Specifications

**Background:**
- Default: `#15151D` (dark gray)
- Corner radius: 12px
- Padding: 12px (Row), 8px (Mini)

**Typography:**
- Font family: SF Pro Text
- **Card title:** 17pt, Bold (weight 600), line height 22px, color `#FFFFFF`
- **Subtitle/Category:** 13pt, Regular (weight 400), line height 18px, color `rgba(255, 255, 255, 0.7)`
- **Description:** 13pt, Regular (weight 400), line height 18px, color `rgba(255, 255, 255, 0.7)`

**Internal Spacing:**
- Image/icon to content: 12px
- Title to subtitle: 4px
- Between metadata items: 16px (Data component gap)

**Images:**
- Corner radius: 8px
- Object fit: Cover
- Clipping: Rounded rectangle

---

## 4. Event Card

### 4.1 Description
Event cards display scheduled events, meetings, and gatherings with date/time information.

### 4.2 Content Structure

**Required Fields:**
- Title (string)
- Description (string)
- Day (integer, 1-31)
- Month (string, 3 characters: "JAN", "FEB", etc.)
- Data row (array of DataItems)

**Display Rules:**
- **Never show images** - Events always display day/month instead
- Primary metadata (Row): Location
- Primary metadata (Mini): Time

### 4.3 Visual Specifications

**Date Display:**
- Day number: 28pt, Bold, white
- Month text: 11pt, Bold, white 70%, uppercase
- Background: Dark container (same as card background)
- Size (Row): 80×80px
- Size (Mini): 120×96px (spans full width at top)
- Corner radius: 8px

**Row Layout:**
```
[Day/Month] | [Event Title]
  80×80px   | [Event Description]
            | [Data: Location, etc.]
```

**Mini Layout:**
```
[Day/Month - full width 120×96px]
[Event Title]
[Data: Time, etc.]
```

### 4.4 Example Data

```swift
EventCard(
    title: "Sunday Service",
    description: "Join us for worship and fellowship",
    day: 15,
    month: "JAN",
    metadata: [
        DataItem(type: .icon, value: "10:00 AM", iconName: "clock"),
        DataItem(type: .text, value: "Main Chapel")
    ]
)
```

---

## 5. Group Card

### 5.1 Description
Group cards display community groups with member counts and optional images. This is the **only card type with a selected state**.

### 5.2 Content Structure

**Required Fields:**
- Group name (string)
- Member count (integer)
- Image URL (optional)
- Selected state (boolean)

**Display Rules:**
- Show uploaded image if available
- Fall back to group icon if no image
- Always show member count in Data row
- Selected state: Purple border + checkmark overlay

### 5.3 Visual Specifications

**Image Handling:**
- **Photo style:** User-uploaded group photo
  - Size (Row): 80×80px
  - Size (Mini): 120×96px
  - Corner radius: 8px
  - Object fit: Cover

- **Icon style:** Default when no photo
  - Container: 48×48px circular dark background
  - Icon: 24×24px, people/users icon
  - Icon color: White

**Selected State:**
- Border: 2px solid `#6c47ff` (brand purple)
- Optional: Checkmark icon overlay on image
- Background tint: Subtle purple overlay

**Row Layout:**
```
[Image/Icon] | [Group Name]
   80×80px   | [Data: 28 Members]
```

**Mini Layout:**
```
[Image/Icon - 120×96px]
[Group Name]
[Data: 28 Members]
```

### 5.4 Example Data

```swift
GroupCard(
    name: "Young Professionals",
    imageURL: "https://...",
    memberCount: 28,
    isSelected: false
)

// Icon fallback version
GroupCard(
    name: "Bible Study Group",
    imageURL: nil, // Will show icon
    memberCount: 15,
    isSelected: true // Shows purple border
)
```

---

## 6. Study Card

### 6.1 Description
Study cards display Bible studies and devotionals with confirmation status and participant information.

### 6.2 Content Structure

**Required Fields:**
- Study title (string)
- Description (string)
- Time interval (string: "Daily", "Weekly", etc.)
- Participant count (integer)
- Image URL (optional)
- Confirmation status (enum: confirmed | pending)

**Display Rules:**
- Show uploaded image if available
- Fall back to book icon on colored background if no image
- Show interval (daily/weekly) and participant count in Data row
- Display "UNCONFIRMED" badge for pending studies

### 6.3 Visual Specifications

**Image Handling:**
- **Photo style:** User-uploaded study image
  - Size (Row): 116×116px
  - Size (Mini): 120×96px
  - Corner radius: 8px

- **Icon style:** Default when no photo
  - Container: Colored circular background (varies)
  - Icon: Book icon, 24×24px
  - Icon color: White

**Status Badge (Pending Only):**
- Text: "UNCONFIRMED"
- Background: `#6c47ff`
- Text color: White
- Font: 11pt, Bold
- Padding: 4px 8px
- Corner radius: 4px
- Position: Top-right corner of card

**Row Layout:**
```
[Image/Icon] | [Study Title]
  116×116px  | [Description]
             | [Data: Weekly, 15 Participants]
             | [Badge: UNCONFIRMED] (if pending)
```

**Mini Layout:**
```
[Badge: UNCONFIRMED] (if pending, top-right)
[Image/Icon - 120×96px]
[Study Title]
[Data: Weekly, 15 Participants]
```

### 6.4 Example Data

```swift
StudyCard(
    title: "Gospel of John",
    description: "Deep dive into the fourth gospel",
    interval: "Weekly",
    participantCount: 15,
    imageURL: nil, // Will show book icon
    status: .pending // Shows UNCONFIRMED badge
)
```

---

## 7. Video Card

### 7.1 Description
Video cards display video content with view counts and playback controls. **Every video always has an image** (no icon fallback).

### 7.2 Content Structure

**Required Fields:**
- Video title (string)
- Video category (string)
- Image URL (string, required)
- Views count (integer)
- Time posted (string: "5 mins ago", "2 hours ago", etc.)
- Share count (integer)

**Display Rules:**
- Always has image (user-provided or auto-generated screenshot)
- Display white play button overlay on image (bottom-center)
- Show views, time since posted, and share count in Data row

### 7.3 Visual Specifications

**Image (Always Present):**
- Size (Row): 116×116px
- Size (Mini): 120×96px
- Corner radius: 8px
- Object fit: Cover

**Play Button Overlay:**
- Style: White circle with dark play icon
- Circle size: 40×40px
- Circle color: White with 90% opacity
- Icon: Play triangle, dark color
- Position: Bottom-center of image
- Bottom offset: 8px from image bottom edge

**Row Layout:**
```
[Image + Play] | [Video Title]
  116×116px    | [Category]
               | [Data: 1.2K views, 5 mins ago, 45 shares]
```

**Mini Layout:**
```
[Image + Play - 120×96px]
[Video Title]
[Data: 1.2K views, 5 mins ago]
```

### 7.4 Example Data

```swift
VideoCard(
    title: "Sunday Sermon: Faith in Action",
    category: "Sermons",
    imageURL: "https://...", // Required
    views: 1200,
    timePosted: "5 mins ago",
    shareCount: 45
)
```

---

## 8. SwiftUI Implementation Structure

### 8.1 Enums

```swift
enum CardType {
    case event
    case group
    case study
    case video
}

enum CardSize {
    case row    // Full width, horizontal layout
    case mini   // Fixed width, vertical layout
}

enum CardImageStyle {
    case photo(imageURL: String)
    case icon(systemName: String, backgroundColor: Color)
    case dateDisplay(day: Int, month: String) // Event only
}

enum CardStatus {
    case confirmed
    case pending      // Study only
    case selected     // Group only
}
```

### 8.2 Data Structures

```swift
struct CardData {
    let id: String
    let type: CardType
    let title: String
    let subtitle: String?        // Category for Videos, Description for others
    let description: String?     // Not used for all types
    let imageStyle: CardImageStyle
    let metadata: [DataItem]
    let status: CardStatus?      // Optional, used by Study and Group
}

struct DataItem: Identifiable {
    let id = UUID()
    let type: DataItemType
    let value: String
    let label: String?           // For number type
    let iconName: String?        // For icon type
}

enum DataItemType {
    case icon    // Icon + value
    case number  // Number + label
}
```

### 8.3 Component Files

**Primary Files:**
- `Card.swift` - Main card component with all variants
- `DataComponent.swift` - Metadata display component

**Supporting Files:**
- `CardViewModel.swift` - Data transformation and logic (optional)

### 8.4 Color Assets (Assets.xcassets)

Add these color definitions:

```
Colors/
├── cardBackground          → #15151D
├── cardBorderSelected      → #6c47ff
├── textPrimary             → #FFFFFF
├── textSecondary           → rgba(255, 255, 255, 0.7)
├── brandPurple             → #6c47ff
├── statusBadgeBackground   → #6c47ff
└── playButtonOverlay       → rgba(255, 255, 255, 0.9)
```

### 8.5 SF Symbols Mapping

Common icons used in Data components:

| Semantic | SF Symbol |
|----------|-----------|
| Time/Duration | `clock` or `clock.fill` |
| Members | `person.2` or `person.2.fill` |
| Participants | `person.3` or `person.3.fill` |
| Location | `mappin` or `mappin.circle.fill` |
| Views | `eye` or `eye.fill` |
| Shares | `square.and.arrow.up` |
| Calendar | `calendar` |
| Book | `book` or `book.fill` |
| Play | `play.circle.fill` |
| Checkmark | `checkmark.circle.fill` |

---

## 9. Component Usage Examples

### 9.1 Event Card Example

```swift
Card(
    data: CardData(
        id: "event-1",
        type: .event,
        title: "Sunday Service",
        subtitle: nil,
        description: "Join us for worship and fellowship",
        imageStyle: .dateDisplay(day: 15, month: "JAN"),
        metadata: [
            DataItem(type: .icon, value: "10:00 AM", iconName: "clock"),
            DataItem(type: .icon, value: "Main Chapel", iconName: "mappin")
        ],
        status: nil
    ),
    size: .row
)
```

### 9.2 Group Card Example

```swift
Card(
    data: CardData(
        id: "group-1",
        type: .group,
        title: "Young Professionals",
        subtitle: nil,
        description: nil,
        imageStyle: .photo(imageURL: "https://..."),
        metadata: [
            DataItem(type: .number, value: "28", label: "Members")
        ],
        status: .selected
    ),
    size: .mini
)
```

### 9.3 Study Card Example

```swift
Card(
    data: CardData(
        id: "study-1",
        type: .study,
        title: "Gospel of John",
        subtitle: nil,
        description: "Deep dive into the fourth gospel",
        imageStyle: .icon(systemName: "book.fill", backgroundColor: .blue),
        metadata: [
            DataItem(type: .icon, value: "Weekly", iconName: "calendar"),
            DataItem(type: .number, value: "15", label: "Participants")
        ],
        status: .pending
    ),
    size: .row
)
```

### 9.4 Video Card Example

```swift
Card(
    data: CardData(
        id: "video-1",
        type: .video,
        title: "Sunday Sermon: Faith in Action",
        subtitle: "Sermons",
        description: nil,
        imageStyle: .photo(imageURL: "https://..."),
        metadata: [
            DataItem(type: .icon, value: "1.2K", iconName: "eye"),
            DataItem(type: .icon, value: "5 mins ago", iconName: "clock"),
            DataItem(type: .icon, value: "45", iconName: "square.and.arrow.up")
        ],
        status: nil
    ),
    size: .row
)
```

---

## 10. Migration Plan

### 10.1 Files to Remove

- `GroupCard.swift` - Delete entirely
- `SwipeableGroupCard.swift` - Delete entirely

### 10.2 Files to Update

**Views using GroupCard:**
1. `HomePage.swift` - Update group listings
2. `GroupsPage.swift` - Update group grid/list
3. Any other views displaying groups

**Update pattern:**
```swift
// Old:
GroupCard(
    title: group.name,
    memberCount: group.memberCount,
    imageURL: group.imageURL,
    isSelected: $selectedGroup == group.id
)

// New:
Card(
    data: CardData(
        id: group.id,
        type: .group,
        title: group.name,
        imageStyle: group.imageURL != nil
            ? .photo(imageURL: group.imageURL!)
            : .icon(systemName: "person.2.fill", backgroundColor: .gray),
        metadata: [
            DataItem(type: .number, value: "\(group.memberCount)", label: "Members")
        ],
        status: selectedGroup == group.id ? .selected : nil
    ),
    size: .row
)
```

### 10.3 Testing Checklist

Before removing old components, verify:

- [ ] All 4 card types render correctly (Event, Group, Study, Video)
- [ ] Both sizes work (Row and Mini)
- [ ] Data components display with correct 16px spacing
- [ ] Images load properly
- [ ] Icon fallbacks work when no image provided
- [ ] Selected state works (Groups only)
- [ ] Status badges display (Studies only)
- [ ] Play button overlay appears (Videos only)
- [ ] Date display works (Events only)
- [ ] All GroupCard usages replaced
- [ ] No build errors after deletion

---

## 11. Component Page (Storybook) Requirements

### 11.1 Examples to Display

Create a dedicated "Cards" tab on the components page showing:

**Event Cards:**
- Row size example
- Mini size example

**Group Cards:**
- Row size with photo
- Row size with icon fallback
- Row size in selected state
- Mini size with photo
- Mini size in selected state

**Study Cards:**
- Row size confirmed (with photo)
- Row size pending (with UNCONFIRMED badge)
- Mini size with icon fallback

**Video Cards:**
- Row size example
- Mini size example

**Minimum: 13 card examples total**

### 11.2 Example Layout

```swift
struct CardsComponentPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Event Cards Section
                SectionHeader(title: "Event Cards")
                CardExample(title: "Row Size", card: eventRowCard)
                CardExample(title: "Mini Size", card: eventMiniCard)

                // Group Cards Section
                SectionHeader(title: "Group Cards")
                CardExample(title: "Row - Photo", card: groupRowPhoto)
                CardExample(title: "Row - Icon", card: groupRowIcon)
                CardExample(title: "Row - Selected", card: groupRowSelected)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        groupMiniPhoto
                        groupMiniSelected
                    }
                }

                // Study Cards Section
                SectionHeader(title: "Study Cards")
                CardExample(title: "Row - Confirmed", card: studyRowConfirmed)
                CardExample(title: "Row - Pending", card: studyRowPending)
                CardExample(title: "Mini - Icon", card: studyMiniIcon)

                // Video Cards Section
                SectionHeader(title: "Video Cards")
                CardExample(title: "Row Size", card: videoRowCard)
                CardExample(title: "Mini Size", card: videoMiniCard)
            }
            .padding()
        }
    }
}
```

---

## 12. Acceptance Criteria

### 12.1 Functional Requirements

- [ ] Card component supports all 4 types (Event, Group, Study, Video)
- [ ] Card component supports both sizes (Row, Mini)
- [ ] Data component supports both display types (Icon, Number)
- [ ] Data components space correctly (16px gap)
- [ ] Images load with proper fallbacks
- [ ] Selected state works for Groups
- [ ] Status badges work for Studies
- [ ] Play button overlay works for Videos
- [ ] Date display works for Events
- [ ] GroupCard component removed
- [ ] SwipeableGroupCard component removed
- [ ] All previous GroupCard usages migrated

### 12.2 Visual Requirements

- [ ] Colors match Figma specifications
- [ ] Typography matches Figma (17pt bold titles, 13pt regular body)
- [ ] Spacing matches Figma (12px/8px padding, 16px gaps)
- [ ] Corner radius correct (12px cards, 8px images)
- [ ] Images clip to rounded corners
- [ ] Status badges positioned correctly
- [ ] Play button positioned correctly (bottom-center)
- [ ] Selected state border visible (2px purple)

### 12.3 Code Quality

- [ ] Components follow SwiftUI best practices
- [ ] Proper use of @State, @Binding, @ObservableObject
- [ ] Reusable and composable structure
- [ ] Clear prop naming and documentation
- [ ] No hardcoded values (use design tokens)
- [ ] Accessible labels for screen readers
- [ ] Preview providers for Xcode Canvas

### 12.4 Documentation

- [ ] Component usage documented in CLAUDE.md
- [ ] All examples working on Components page
- [ ] Code comments for complex logic
- [ ] Migration guide followed

---

## 13. Design Tokens Reference

Quick reference for implementation:

| Token | Value | Usage |
|-------|-------|-------|
| `card.background` | `#15151D` | Default card background |
| `card.radius` | `12px` | Card corner radius |
| `card.padding.row` | `12px` | Internal padding (Row size) |
| `card.padding.mini` | `8px` | Internal padding (Mini size) |
| `card.gap.internal` | `8px` | Gap between card elements |
| `card.gap.metadata` | `16px` | Gap between Data components |
| `image.radius` | `8px` | Image corner radius |
| `image.size.row.group` | `80×80px` | Group image in Row |
| `image.size.row.other` | `116×116px` | Other images in Row |
| `image.size.mini` | `120×96px` | All images in Mini |
| `icon.container` | `48×48px` | Icon container size |
| `icon.size` | `24×24px` | Icon size within container |
| `data.icon.size` | `14×14px` | Data component icon size |
| `data.gap` | `4px` | Gap within Data component |
| `text.primary` | `#FFFFFF` | Titles, values (100%) |
| `text.secondary` | `rgba(255,255,255,0.7)` | Descriptions, labels (70%) |
| `brand.purple` | `#6c47ff` | Accents, borders, badges |
| `font.title.size` | `17pt` | Card title size |
| `font.title.weight` | `Bold (600)` | Card title weight |
| `font.body.size` | `13pt` | All other text |
| `font.body.weight` | `Regular (400)` | All other text weight |

---

## 14. Additional Notes

### 14.1 Performance Considerations

- Use `AsyncImage` for remote images
- Implement image caching for better performance
- Consider lazy loading for lists with many cards
- Use `@StateObject` appropriately to avoid unnecessary re-renders

### 14.2 Accessibility

- Provide meaningful accessibility labels for images
- Ensure Data icons have accessibility descriptions
- Selected state should be announced to screen readers
- Play button should be accessible as a button element

### 14.3 Future Enhancements

Potential additions (not in current scope):
- Additional card sizes (e.g., "Featured" size)
- Animation on selection
- Skeleton loading states
- Swipe actions (like previous SwipeableGroupCard)
- Long-press context menus
- Drag-and-drop reordering

### 14.4 Questions / Clarifications Needed

If any of these arise during implementation:
1. Exact color for Study card icon backgrounds (varies in design)
2. Animation duration for selected state transitions
3. Tap behavior for different card types
4. Loading state appearance while images fetch
5. Error state appearance if image fails to load

---

**Document End**

For questions or clarifications, refer to:
- Figma designs: [Card](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=947-13921) | [Data](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=951-14806)
- iPhone CLAUDE.md: `/Users/lukekeith/www/makeready/iphone/.claude/CLAUDE.md`
- Component Library section for integration patterns
