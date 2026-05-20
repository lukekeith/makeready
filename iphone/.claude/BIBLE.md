# Bible Reader Architecture

This document captures key architectural decisions for the Bible reading experience in the MakeReady iPhone app. Use this as a reference when implementing Bible features elsewhere to prevent regressions.

---

## Overview

The Bible reader uses a **4-screen sliding window navigation** pattern with a **WKWebView-based infinite scroll reader** for the actual Bible content.

### File Structure

```
MakeReady/Pages/View/Bible/
├── BibleReaderPage.swift          # Main container with 4-screen navigation
├── BibleViewModel.swift           # View model with chapter navigation logic
├── BibleWebView.swift             # WKWebView wrapper for Bible content
├── BibleHTMLGenerator.swift       # Generates HTML for chapters
├── Models/
│   └── BibleModels.swift          # All Bible-specific data models
├── Rendering/
│   ├── BibleCSS.swift             # CSS for Bible display
│   └── BibleJavaScript.swift      # JS for selection, highlighting, scroll
└── Views/
    ├── BibleFullReader.swift      # Full reader with WebView
    ├── BibleSelectionMenu.swift   # Selection action menu
    └── BibleHighlightEditMenu.swift # Edit highlight menu

MakeReady/Pages/Manage/Program/
├── SelectBook.swift               # Book selection with search
├── SelectChapter.swift            # Chapter grid selector
└── SelectVerse.swift              # Verse grid selector

MakeReady/Services/
├── BibleCacheManager.swift        # Bible data caching
└── BibleSearchService.swift       # Search API integration

MakeReady/Components/Read/
├── ReaderSelection.swift          # Text selection handling
├── ReaderSelectionJS.swift        # JS for text selection
├── ReaderHighlight.swift          # Highlight rendering
└── ReaderHighlightJS.swift        # JS for highlight management
```

---

## Navigation Architecture

### 4-Screen Sliding Window

The `BibleReaderPage` uses a horizontal `HStack` with screen offsets for navigation:

```swift
enum BibleNavigationDepth: Int {
    case books = 0      // SelectBook
    case chapters = 1   // SelectChapter
    case verses = 2     // SelectVerse
    case reader = 3     // BibleFullReader
}
```

**Key Pattern:**
```swift
HStack(spacing: 0) {
    SelectBook(...)
        .frame(width: screenWidth)
    SelectChapter(...)
        .frame(width: screenWidth)
    SelectVerse(...)
        .frame(width: screenWidth)
    BibleFullReader(...)
        .frame(width: screenWidth)
}
.offset(x: -CGFloat(navigationDepth.rawValue) * screenWidth)
```

### Back Navigation Environment

Child views receive back navigation via environment:

```swift
// In parent (BibleReaderPage):
SelectChapter(...)
    .environment(\.bibleNavigationBack) {
        withAnimation { navigationDepth = .books }
    }

// In child (SelectChapter):
@Environment(\.bibleNavigationBack) var navigateBack
// Then: navigateBack?()
```

---

## Keyboard Handling (CRITICAL)

### The Problem

SwiftUI's default keyboard avoidance doesn't work properly with `ZStack` layouts that have `ignoresSafeArea()` on background elements.

### The Solution

Use **NotificationCenter-based keyboard height tracking** with dynamic bottom padding:

```swift
// State
@State private var keyboardHeight: CGFloat = 0

// In body
ScrollView {
    VStack {
        // Content
    }
    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 16)
}
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
        withAnimation(.easeOut(duration: 0.25)) {
            keyboardHeight = keyboardFrame.height
        }
    }
}
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
    withAnimation(.easeOut(duration: 0.25)) {
        keyboardHeight = 0
    }
}
```

### DO NOT USE:
- `.safeAreaInset(edge: .bottom)` alone - doesn't work with ZStack layouts
- Hardcoded padding values - not responsive to different keyboard sizes
- `ScrollViewReader` with `scrollTo` alone - only scrolls, doesn't add space

---

## SearchField State Management

### Two State Variables

The `SearchField` component has TWO distinct states:
- `isActive: Bool` - Visual state (expanded/collapsed appearance)
- `isFocused: Bool` - Keyboard focus state

### Resetting Search Field

When navigating away, you MUST reset BOTH states:

```swift
private func dismissKeyboard() {
    isSearchFocused = false      // Remove keyboard focus
    isSearchActive = false       // Reset visual state to collapsed
    searchText = ""              // Clear search text
    searchResults = []           // Clear results
    searchTask?.cancel()         // Cancel pending searches
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
```

**Call `dismissKeyboard()` when:**
- User selects a book
- User selects a search result
- User closes the modal (X button)

---

## Infinite Scroll WebView

### Architecture

The Bible reader uses a WKWebView with a "sliding window" of chapters:
1. Load prev + current + next chapters initially
2. Append chapters as user scrolls down
3. Prepend chapters as user scrolls up

### Key Callbacks

```swift
BibleWebView(
    htmlContent: baseHTML,
    scrollTargetVerse: targetVerseId,
    onScrollPositionChanged: { position in
        // Update header reference display
    },
    onLoadNextChapter: { request in
        // Append next chapter HTML
    },
    onLoadPrevChapter: { request in
        // Prepend previous chapter HTML
    },
    onPageReady: { coordinator in
        // Store coordinator, load initial chapters
    },
    onShowSelectionMenu: { selection in
        // Handle text selection
    },
    // ... more callbacks
)
```

### Verse ID Format

All verse references use the format: `"{bookNum}-{chapter}-{verse}"`

Example: `"43-3-16"` = John 3:16 (John is book 43)

---

## Highlighting System

### Auto-Highlight on Selection

When user selects text, highlights are created automatically (no menu):

```swift
private func autoHighlight(selection: BibleSelectionWithRect) {
    let highlightId = UUID().uuidString

    // 1. Save to view model
    viewModel.setHighlight(highlight)

    // 2. Remove temp span from DOM
    webViewCoordinator?.removeTempSpan(spanId: selection.tempHighlightId)

    // 3. Add permanent highlight to DOM
    webViewCoordinator?.addHighlightToDOM(
        startVerseId: selection.startVerseId,
        startOffset: selection.startOffset,
        endVerseId: selection.endVerseId,
        endOffset: selection.endOffset,
        highlightId: highlightId
    )
}
```

### Highlight Data Model

```swift
struct BibleHighlight: Identifiable, Equatable {
    let id: UUID
    let verseId: String      // e.g., "1-1-1"
    var startOffset: Int     // Character offset from start
    var endOffset: Int       // Character offset (exclusive)
}
```

### Highlight Merging

When highlights overlap, JavaScript detects and merges them, notifying Swift via `onHighlightsMerged`.

---

## Search Integration

### Smart Search

Uses `BibleSearchService.shared.smartSearch(query:)` with:
- 300ms debounce
- Task cancellation for rapid typing
- Converts results to `SearchResultItem` for display

### Direct Navigation from Search

When user taps a search result, navigate directly to the reader:

```swift
onSearchResultSelected: { result in
    Task {
        let bookName = await BibleCacheManager.shared.getBookName(from: result.bookNumber)
        await MainActor.run {
            selectedBook = bookName
            selectedChapter = result.chapter
            selectedVerse = result.verse
            withAnimation { navigationDepth = .reader }
        }
    }
}
```

---

## Bible Data

### Book Numbers

Old Testament: 1-39
New Testament: 40-66

### Verse Data Structure

```swift
struct CachedVerse: Codable {
    let b: Int     // Book number
    let c: Int     // Chapter
    let v: Int     // Verse
    let t: String  // Text content
}
```

### Caching

`BibleCacheManager` handles:
- Downloading Bible data on first use
- Local caching for offline access
- Book name ↔ number lookups

---

## Animation Timings

| Animation | Duration |
|-----------|----------|
| Screen transitions | 0.3s easeInOut |
| SearchField expand/collapse | 0.5s easeInOut |
| Keyboard padding | 0.25s easeOut |
| Highlight action bar | 0.5s easeInOut |

---

## Common Pitfalls

### 1. Forgetting to Reset SearchField Active State
**Wrong:** Only setting `isSearchFocused = false`
**Right:** Also set `isSearchActive = false` and clear `searchText`

### 2. Using ZStack with ignoresSafeArea for Backgrounds
This breaks keyboard avoidance. Use NotificationCenter-based keyboard height tracking instead.

### 3. Not Cancelling Search Tasks
Always cancel pending search tasks when:
- Search text changes
- User navigates away
- Modal closes

### 4. Hardcoding Keyboard Height
Different devices have different keyboard sizes. Always read from `keyboardFrameEndUserInfoKey`.

### 5. Not Animating Navigation
All navigation depth changes should use `withAnimation(.easeInOut(duration: 0.3))`.

---

## Testing Checklist

When modifying Bible features, verify:

- [ ] Can scroll to last book (Revelation) with keyboard visible
- [ ] Keyboard dismisses when selecting a book/result
- [ ] SearchField resets to collapsed state after selection
- [ ] Back navigation works from all screens
- [ ] Highlights persist after scrolling
- [ ] Search results navigate directly to correct verse
- [ ] Infinite scroll loads chapters smoothly
- [ ] Reference header updates while scrolling
