# Animation Patterns Reference

Before implementing or modifying ANY drag gestures, swipe-to-dismiss, animated menus/modals, async images in animated containers, or overlay animations, you MUST read this document AND `.claude/SWIFTUI_ANIMATION_PATTERNS.md` in full.

Key topics covered:
- `@GestureState` for jitter-free drag tracking
- Single animation block pattern (never mix curves)
- `ModalAnimations` utility for menus/modals
- `CachedAsyncImage` with synchronous cache pre-population
- `.compositingGroup()` before `.offset()`
- `OptimizedShadow` for animated views
- Swipeable card content rules
- `matchedGeometryEffect` best practices
- Code review checklist

Read `.claude/SWIFTUI_ANIMATION_PATTERNS.md` now and apply its patterns to the current task.
