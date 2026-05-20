# SwiftUI #Preview Build Errors

Patterns for diagnosing and fixing `#Preview` compile failures — especially type-checker timeouts and ViewBuilder limits. Read this **before** adding new cards, stress tests, or many-variation previews.

---

## 🚨 Error: "The compiler is unable to type-check this expression in reasonable time"

### What It Means

SwiftUI's `@ViewBuilder` and `some View` force the compiler to solve one large type-inference problem per preview body. Every nested initializer, array literal, and inferred generic adds constraints. Past a threshold the solver gives up.

The full error looks like:

> the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions

This is **not** a "your code is wrong" error — the code is usually valid. It's a "this is too much work for one pass" error.

### Root Causes (in order of frequency)

1. **Too many children in a single `VStack` / `HStack` / `Group`** — especially when each child is a nested initializer like `CardLesson(data: CardLessonData(activities: [...], ...))`.
2. **Large array literals with nested initializers** inside a view builder.
3. **Type inference on tuples or closures** inside large builders — e.g. `let icons = [("a", "b"), ...]` instead of `let icons: [(String, String)] = [...]`.
4. **Many `.modifier()` calls chained** on a single nested view.
5. **Exceeding the 10-child `ViewBuilder` limit** (`@ViewBuilder` only has `buildBlock` overloads for up to 10 children). Over 10 may still compile via `TupleView` tricks but drastically increases type-check cost.

### Fix Playbook

Apply in order — stop when the preview compiles.

#### 1. Wrap groups of children in `Group { ... }`

Each `Group` counts as **one** ViewBuilder child, regardless of how many views it contains inside. This is the cheapest fix and preserves layout identically.

```swift
// ❌ Too many direct children — slow or fails
VStack {
    CardLesson(...)  // 1
    CardLesson(...)  // 2
    ...
    CardLesson(...)  // 15
}

// ✅ Grouped — VStack only sees 2 children
VStack {
    Group {
        CardLesson(...)  // 1-5
        ...
    }
    Group {
        CardLesson(...)  // 6-10
        ...
    }
}
```

**When to use:** Small number of cards (≤ ~15) with moderate nesting. Fast to apply, no helper functions needed.

#### 2. Extract the preview into a dedicated `private struct: View`

When `Group { }` isn't enough (usually because individual cards are very deeply nested), move the preview body into its own `View` struct. Each method type-checks independently, so the compiler no longer has to solve one giant expression.

```swift
#Preview("Stress Test") {
    MyStressTestPreview()
}

private struct MyStressTestPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                card(count: 4, title: "4 Activities")
                card(count: 8, title: "8 Activities")
                card(count: 12, title: "12 Activities")
                card(count: 20, title: "20 Activities")
                card(count: 30, title: "30 Activities")
            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func card(count: Int, title: String) -> some View {
        let data = CardLessonData(
            id: "stress-\(count)",
            day: 1,
            mode: .lesson,
            activities: stressActivities(count: count),
            title: title
        )
        CardLesson(data: data)
    }
}
```

**Key technique:** Build the `data` value in a `let` statement, then hand it to the component. This splits the expression into two small statements instead of one nested tree.

**When to use:** Stress tests, many variations of the same card, or any preview with 10+ items.

#### 3. Split the preview into multiple `#Preview` tabs

If one preview is too large, give it two tabs. Each `#Preview` is an isolated type-check scope.

```swift
#Preview("Lesson Mode") {
    // original cards only
}

#Preview("Lesson Mode - Stress Test") {
    // stress-test cards in a dedicated struct
}
```

**When to use:** Logical groupings have emerged (e.g. "normal cards" vs "edge cases"). Also great for UX — each tab is independently browsable in the Xcode canvas.

#### 4. Add explicit type annotations

The Swift type-checker is slowest on inference, particularly for tuples, arrays of tuples, and closures. Annotating eliminates that inference cost.

```swift
// ❌ Slow: tuple inference
let icons = [
    ("book.fill", "Read"),
    ("play.fill", "Watch"),
]

// ✅ Fast: explicit
let icons: [(String, String)] = [
    ("book.fill", "Read"),
    ("play.fill", "Watch"),
]
```

Also annotate empty arrays and dictionaries:

```swift
// ❌ Slow
var result = []

// ✅ Fast
var result: [LessonActivityData] = []
```

#### 5. Replace chains of array-of-struct literals with a factory function

```swift
// ❌ Slow: 30 LessonActivityData(...) inline in an array literal
CardLesson(data: CardLessonData(
    activities: [
        LessonActivityData(icon: "a", title: "A", status: .complete),
        LessonActivityData(icon: "b", title: "B", status: .incomplete),
        // ... 28 more
    ]
))

// ✅ Fast: helper function hides the literal from the view builder
CardLesson(data: CardLessonData(activities: makeActivities(count: 30)))

private func makeActivities(count: Int) -> [LessonActivityData] {
    (0..<count).map { i in
        LessonActivityData(icon: "...", title: "...", status: .complete)
    }
}
```

---

## 🚨 Error: "Cannot find type 'X' in scope" (in previews only)

### What It Means

The LSP (SourceKit) reports phantom errors for types defined in other files of the same target. Usually happens after adding many new lines to a file or when the LSP indexer gets out of sync.

### How to Diagnose

**Run `xcodebuild` from the CLI.** If the CLI build succeeds, the errors are LSP ghosts, not real compile errors:

```bash
cd /Users/lukekeith/www/makeready/iphone
xcodebuild -scheme MakeReady -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

### Fix

- **LSP reload:** Restart sourcekit-lsp (in pi: `lsp reload`). Usually clears the phantom errors after a few seconds.
- **Clean derived data:** If the LSP stays confused, `rm -rf ~/Library/Developer/Xcode/DerivedData/MakeReady-*` and rebuild.
- **If the CLI build also fails:** It's a real error. Look at the actual error message, not the LSP output.

---

## 🚨 Error: "Build database is locked"

### What It Means

Two `xcodebuild` invocations are trying to use the same derived-data directory simultaneously. Common when Xcode and the CLI run in parallel, or when a previous build hung.

### Fix

```bash
# Check for orphaned xcodebuild processes
pgrep -fl xcodebuild

# Kill any stragglers, then wait a few seconds
pkill -9 xcodebuild
sleep 5
```

Retry the build. If it still fails, delete the derived data directory and rebuild.

---

## 📋 Checklist: Before Adding Cards to an Existing Preview

When asked to add more cards / variations / stress tests to an existing `#Preview`:

- [ ] **Count the direct children of the root `VStack` / `HStack`.** If adding will push the count past ~10, plan to wrap in a `Group` or split into a second `#Preview`.
- [ ] **Check the nesting depth of each card.** If each card already has 3+ levels of nested initializers (e.g. `Component(data: Data(items: [Item(...)]))`), prefer extracting a helper function from the start.
- [ ] **Look for array literals of structs.** If the new cards involve arrays of 10+ struct literals, generate them via a helper instead of inlining.
- [ ] **Prefer a dedicated `#Preview` tab** for stress tests and edge cases. This keeps the main preview fast and the stress preview isolated.
- [ ] **If unsure, extract into a `private struct: View`** from the start. It's cheap insurance and matches the pattern used across the codebase.

---

## 📚 Known Good Patterns in This Codebase

- **`CardLesson.swift`** — `#Preview("Lesson Mode - Activity Counts")` uses a `private struct CardLessonStressTestPreview: View` with a `stressTestCard(id:day:count:title:)` helper. The main "Lesson Mode" preview uses nested `Group { }` wrappers to stay under the ViewBuilder limit.

- **Rule of thumb:** If a preview has more than ~8 cards with any nesting, extract into a struct from the start. Don't wait for the error.

---

## ⚠️ What NOT to Do

- ❌ **Don't disable the preview** just to make the error go away. Previews are valuable regression checks — fix the root cause.
- ❌ **Don't add `@ViewBuilder` everywhere hoping it helps.** It doesn't — `@ViewBuilder` is about accepting multiple children, not about speeding up type-checking.
- ❌ **Don't inline giant struct literals directly into preview bodies.** Always extract to a helper or `let` binding.
- ❌ **Don't assume the CLI build error matches the preview error.** SwiftUI previews use a separate, stricter type-check pass. A passing `xcodebuild` doesn't guarantee a passing preview.
- ❌ **Don't mix unrelated fixes in one pass.** Apply the playbook in order — stop when it compiles. Over-refactoring makes it hard to know what actually fixed the problem.
