# Card Component Architecture

## Overview

The MakeReady iPhone app uses a **type-specific card component system** with four distinct card types:
- **CardStudy** - For Bible studies and study groups
- **CardEvent** - For events and calendar items
- **CardGroup** - For community groups and teams
- **CardVideo** - For sermon videos and media content

Each card type supports two sizes:
- **Row** - Full-width horizontal layout for lists
- **Mini** - Fixed-width (120px) vertical layout for carousels

## File Structure

```
MakeReady/Components/Card/
├── CardData.swift          # Shared data models and enums
├── DataComponent.swift     # Metadata display component
├── CardStudy.swift         # Study card component
├── CardEvent.swift         # Event card component
├── CardGroup.swift         # Group card component
└── CardVideo.swift         # Video card component
```

---

## Shared Components

### CardData.swift

Provides shared enums and helpers used by all card components:

**Enums:**
- `CardSize` - `.row` or `.mini`
- `CardImageStyle` - `.photo(url)`, `.icon(name, color)`, or `.dateDisplay(day, month)`
- `CardStatus` - `.confirmed`, `.pending`, or `.selected`

**Helpers:**
- `AnyShape` - Shape wrapper for dynamic corner radius
- `CardLoadingPlaceholder` - Loading state view
- `Color.cardBackground` - White 10% opacity
- `Color.iconContainerBackground(for:)` - Icon background colors

### DataComponent.swift

Displays metadata items with two variants:
- **Icon type**: Icon (14×14) + value (e.g., clock icon + "28")
- **Number type**: Number + label (e.g., "28" + "Members")

Used in all card types to show supplementary information.

---

## Card Type Specifications

### 1. CardStudy

**Purpose:** Bible studies, study groups, and educational content

#### Row Layout
- **Dimensions**: Full width × 140px height
- **Layout**: Content left, image right
- **Image**: 72×108px portrait (right side)
- **Background**: White 10% opacity
- **Corner radius**: 8px
- **Padding**: 16px all sides

**Content:**
- **Title**: 17pt bold, white 100%, 1 line max
- **Description**: 13pt regular, white 70%, 2 lines max
- **Metadata**: Multiple data items with 16px gaps
- **Status badge**: "UNCONFIRMED" for pending status (purple, top-right)

#### Mini Layout
- **Dimensions**: 120×188px
- **Image**: 120×114px (fills width at top)
- **Title**: 12pt bold, white 100%, 0.1px tracking, max 32px height (2 lines)
- **Metadata**: **Only 1 data item** (first item only)
- **Padding**: 8px
- **Status badge**: "UNCONFIRMED" for pending status

**Figma References:**
- Row: [node-id=970-14132](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=970-14132)
- Mini: [node-id=970-14134](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=970-14134)

**Usage:**
```swift
CardStudy(
    data: CardStudyData(
        id: "study-1",
        title: "Gospel of John",
        description: "Deep dive into the fourth gospel",
        imageStyle: .photo(imageURL: "https://..."),
        metadata: [
            DataItem(icon: "clock", value: "28"),
            DataItem(number: "28", label: "Participants")
        ],
        status: .pending,
        onTap: { print("Tapped") }
    ),
    size: .row
)
```

---

### 2. CardEvent

**Purpose:** Calendar events, services, meetings

#### Row Layout
- **Dimensions**: Full width × 140px height
- **Layout**: Image/date left, content right
- **Image**: 80×116px (left side)
- **Date display**: Day (28pt bold) + Month (11pt bold uppercase)
- **Background**: White 10% opacity
- **Padding**: 16px

**Content:**
- **Title**: 17pt bold, white 100%, 1 line max
- **No subtitle/description**
- **Metadata**: Multiple data items (time, location, etc.)

#### Mini Layout
- **Dimensions**: 120×188px
- **Image**: 120×96px (fills width at top)
- **Title**: 17pt bold (NOT 12pt like Study/Group)
- **Metadata**: Multiple data items
- **Padding**: 8px

**Usage:**
```swift
CardEvent(
    data: CardEventData(
        id: "event-1",
        title: "Sunday Service",
        imageStyle: .dateDisplay(day: 15, month: "JAN"),
        metadata: [
            DataItem(icon: "clock", value: "10:00 AM"),
            DataItem(icon: "mappin", value: "Main Chapel")
        ],
        onTap: nil
    ),
    size: .row
)
```

---

### 3. CardGroup

**Purpose:** Community groups, teams, organizations

#### Row Layout
- **Dimensions**: Full width × 104px height (72 + 16×2 padding)
- **Layout**: Circular image left, content right
- **Image**: 72×72px **circular**
- **Background**: White 10% opacity
- **Padding**: 16px

**Content:**
- **Title**: 17pt bold, white 100%, 1 line max
- **No subtitle/description**
- **Metadata**: Usually number+label format (e.g., "28 Members")
- **Selection state**: Purple 80% overlay + checkmark (24×24)

#### Mini Layout
- **Dimensions**: 120×188px
- **Image**: 72×72px circle centered in 114px height container
- **Title**: 12pt bold, 0.1px tracking, max 32px height (2 lines)
- **Metadata**: Multiple data items
- **Padding**: 8px
- **Selection state**: Purple overlay + checkmark

**Selection Animation:**
- Easing: cubic-bezier(0.25, 0.1, 0.25, 1)
- Duration: 0.5s
- Icon fades in/out with overlay

**Usage:**
```swift
CardGroup(
    data: CardGroupData(
        id: "group-1",
        title: "Young Professionals",
        imageStyle: .photo(imageURL: "https://..."),
        metadata: [
            DataItem(number: "28", label: "Members")
        ],
        isSelected: true,
        onTap: nil
    ),
    size: .row
)
```

---

### 4. CardVideo

**Purpose:** Sermon videos, worship recordings, media content

#### Row Layout
- **Dimensions**: Full width × 140px height
- **Layout**: Thumbnail left, content right
- **Image**: 116×116px (left side)
- **Background**: White 10% opacity
- **Padding**: 16px

**Content:**
- **Title**: 17pt bold, white 100%, 1 line max
- **Category**: 13pt regular, white 70%, 1 line (e.g., "Sermons", "Worship")
- **Metadata**: Multiple items (views, time, shares)

#### Mini Layout
- **Dimensions**: 120×188px
- **Image**: 120×96px with play button overlay
- **Play button**: 40×40px white circle (90% opacity) with play icon (16pt)
- **Title**: 17pt bold (NOT 12pt)
- **Metadata**: Multiple data items
- **Padding**: 8px

**Usage:**
```swift
CardVideo(
    data: CardVideoData(
        id: "video-1",
        title: "Sunday Sermon: Faith in Action",
        category: "Sermons",
        imageStyle: .photo(imageURL: "https://..."),
        metadata: [
            DataItem(icon: "eye", value: "1.2K"),
            DataItem(icon: "clock", value: "5 mins ago"),
            DataItem(icon: "square.and.arrow.up", value: "45")
        ],
        onTap: nil
    ),
    size: .row
)
```

---

## Design System

### Typography

| Element | Size | Weight | Color | Tracking |
|---------|------|--------|-------|----------|
| Row title | 17pt | Bold | White 100% | 0 |
| Mini title (Study/Group) | 12pt | Bold | White 100% | 0.1px |
| Mini title (Event/Video) | 17pt | Bold | White 100% | 0 |
| Subtitle/Description | 13pt | Regular | White 70% | 0 |
| Metadata value | 13pt | Regular | White 100% | 0 |
| Metadata label | 13pt | Regular | White 70% | 0 |
| Date display (day) | 28pt | Bold | White 100% | 0 |
| Date display (month) | 11pt | Bold | White 70% | 0 |

### Colors

```swift
// Background
Color.white.opacity(0.1)           // rgba(255,255,255,0.1)

// Text
Color.white                        // White 100%
Color.white.opacity(0.7)           // White 70%

// Icon container (fallback)
Color(hex: "#15151D")              // Dark background

// Group icon background
Color(red: 72/255, green: 84/255, blue: 112/255).opacity(0.5)  // Row
Color(red: 72/255, green: 84/255, blue: 112/255).opacity(0.8)  // Mini

// Status badge
Color(hex: "#6c47ff")              // Purple

// Selection overlay
Color(hex: "#6c47ff").opacity(0.8)  // Purple 80%
```

### Spacing

| Element | Value |
|---------|-------|
| Card padding (Row) | 16px |
| Card padding (Mini) | 8px |
| HStack spacing | 16px |
| VStack spacing | 8px |
| Metadata gap | 16px |
| Corner radius | 8px |

### Image Dimensions

| Card Type | Row Size | Mini Size | Shape |
|-----------|----------|-----------|-------|
| Study | 72×108 (portrait) | 120×114 | Rectangle |
| Event | 80×116 | 120×96 | Rectangle |
| Group | 72×72 | 72×72 | Circle |
| Video | 116×116 | 120×96 | Rectangle |

---

## Migration from Unified Card

### Old Pattern (Deprecated)

```swift
// ❌ Old unified Card component
Card(
    data: CardData(
        id: "1",
        type: .study,  // Lots of conditional logic
        title: "Title",
        // ...
    ),
    size: .row
)
```

### New Pattern

```swift
// ✅ New type-specific components
CardStudy(data: CardStudyData(...), size: .row)
CardEvent(data: CardEventData(...), size: .row)
CardGroup(data: CardGroupData(...), size: .row)
CardVideo(data: CardVideoData(...), size: .row)
```

### Benefits

1. **No conditional logic mess** - Each component is clean and focused
2. **Type-safe data structures** - Each card has its own data type
3. **Easier to maintain** - Changes to one card don't affect others
4. **Better code organization** - Clear separation in Components/Card/ folder
5. **Simpler to understand** - Each file is ~200 lines vs 700+ lines

---

## Best Practices

1. **Always use the appropriate card type** - Don't force a Study card to display event data
2. **Respect size constraints** - Mini Study cards can only show 1 metadata item
3. **Provide fallback images** - Use `.icon()` style when photo URLs fail
4. **Use semantic metadata** - Icon types for time/location, number types for counts
5. **Handle tap events** - All cards support optional `onTap` callbacks
6. **Preview your changes** - Each card file has comprehensive `#Preview` examples

---

## Testing

Each card component includes preview examples. To test:

```bash
# Build and launch app
/rebuild-iphone

# Or open in Xcode and view previews
open MakeReady.xcodeproj
# Cmd+Option+Enter to show canvas
# Navigate to CardStudy.swift (or Event/Group/Video)
```

Preview examples include:
- Row layouts with various data
- Mini layouts in horizontal scrolls
- Different image styles (photo, icon, date)
- Status states (pending, selected, confirmed)
- Edge cases (long titles, missing data)

---

## Future Enhancements

Potential improvements for card components:

1. **Swipeable actions** - Add slide-to-delete/edit like SwipeableGroupCard
2. **Skeleton loading states** - Animated placeholders while data loads
3. **Haptic feedback** - Tactile response on tap/select
4. **Accessibility labels** - VoiceOver support for all elements
5. **Dark mode support** - Alternative color schemes
6. **Custom animations** - Entry/exit transitions
7. **Badge overlays** - "New", "Updated", "Live" indicators

---

## Troubleshooting

### Build Errors

**Error: "No such module 'CardData'"**
- Solution: Clean build folder (Cmd+Shift+K) and rebuild

**Error: "Cannot find 'CardStudy' in scope"**
- Solution: Ensure all files are in Xcode project (check project.pbxproj)

### Visual Issues

**Images not loading**
- Check URL validity
- Verify fallback icon is working
- Test with local fixture data

**Text truncating incorrectly**
- Check lineLimit values
- Verify frame maxHeight constraints
- Test with various content lengths

**Selection overlay not animating**
- Ensure isSelected binding updates properly
- Check animation timing curve values
- Verify checkmark icon asset exists

---

## Resources

- **Figma Design**: [Make Ready Mobile](https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile)
- **SwiftUI Documentation**: [Apple Developer](https://developer.apple.com/documentation/swiftui/)
- **Project README**: See `/iphone/.claude/CLAUDE.md` for component library

---

**Last Updated**: 2025-11-08
**Version**: 2.0 (Type-specific refactor)
